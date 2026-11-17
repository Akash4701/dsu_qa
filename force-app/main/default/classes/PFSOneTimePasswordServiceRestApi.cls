/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 10-13-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@RestResource(urlMapping='/PFSOtp/*')
global without sharing class PFSOneTimePasswordServiceRestApi {
    private static final String URL_BASE = '/PFSOtp/';
    private static final String URL_SEND = 'send';
    private static final String URL_VERIFY = 'verify';
    private static final String URL_VERIFY_EMAIL = 'verifyemail';

    private static final Integer HTTP_SUCCESS = 200;
    private static final Integer HTTP_BAD_REQUEST = 400;
    private static final Integer HTTP_NOT_FOUND = 404;

    private static final String ERROR_URL_INVALID = 'The request URL is invalid.';
    
   @HttpPost
global static void sendOtp() {
    String requestURI = RestContext.request.requestURI;
    requestURI = requestURI.replace(URL_BASE, '');
    String[] urlParts = requestURI.split('/');

    if (urlParts[0] != URL_SEND) {
        addError(HTTP_NOT_FOUND, ERROR_URL_INVALID);
        return;
    }

    RestRequest request = RestContext.request;
    system.debug('Request From POST '+ request);
    String emailOrPhone = request.params.get('contact');
    String isNoncontactBasedParam = request.params.get('isNoncontactBased');
    Boolean isNoncontactBased = isNoncontactBasedParam != null && isNoncontactBasedParam.toLowerCase() == 'true';

    if (String.isBlank(emailOrPhone)) {
        addError(HTTP_BAD_REQUEST, 'Missing contact details.');
        return;
    }

    Contact contactRecord;
    String recipientEmail;
     String otpNumber = String.valueOf(Math.round(Math.random() * 9000 + 1000));

    if (!isNoncontactBased) {
        List<Contact> applicants = [
            SELECT Id, Email, Phone, Name, RecordType.Name
            FROM Contact
            WHERE (Email = :emailOrPhone OR Phone = :emailOrPhone)
            AND RecordType.Name = 'Student'
            LIMIT 1
        ];

        if (applicants.isEmpty()) {
            addError(HTTP_BAD_REQUEST, 'Student Applicant not found.');
            return;
        }

        contactRecord = applicants[0];
        recipientEmail = contactRecord.Email;
        
         Id otpId = saveOtpInformation(contactRecord, otpNumber);
    //sendEmail(applicants[0], otpNumber, otpId);

    OtpResult successResult = new OtpResult();
    successResult.success = true;
    successResult.OTP = otpNumber;
    successResult.userId = contactRecord.Id;
          RestContext.response.addHeader('Content-Type', 'application/json');
    RestContext.response.statusCode = HTTP_SUCCESS;
    RestContext.response.responseBody = Blob.valueOf(JSON.serialize(successResult));
        
    } else {
        // When isNoncontactBased is true, use DSU_Email__c from hed__Affiliation__c
        List<hed__Affiliation__c> affiliations = [
            SELECT Id, DSU_Email__c, hed__Contact__c,hed__Contact__r.Phone,hed__Contact__r.Email
            FROM hed__Affiliation__c
            WHERE DSU_Email__c = :emailOrPhone
            AND Is_DSU_Email_Active__c = True
            LIMIT 1
        ];

        if (affiliations.isEmpty()) {
            addError(HTTP_BAD_REQUEST, 'Affiliation with provided DSU email not found.');
            return;
        }

    hed__Affiliation__c affiliation = affiliations[0];
if (affiliation.hed__Contact__c == null) {
    addError(HTTP_BAD_REQUEST, 'Affiliation record does not have an associated Contact.');
    return;
}

contactRecord = affiliation.hed__Contact__r; // <-- FIXED: assign contactRecord

recipientEmail = affiliation.DSU_Email__c;
deliverAffiliationOtp(affiliation, otpNumber);

OtpResult successResult = new OtpResult();
successResult.success = true;
//successResult.OTP = otpNumber;
successResult.userId = contactRecord.Id;
RestContext.response.addHeader('Content-Type', 'application/json');
RestContext.response.statusCode = HTTP_SUCCESS;
RestContext.response.responseBody = Blob.valueOf(JSON.serialize(successResult));

    }

   

   

  
}

    
    
    @httpGet
    global static void verifyOtp() {
        String requestURI = RestContext.request.requestURI;
        requestURI = requestURI.replace(URL_BASE, '');
        String[] urlParts = requestURI.split('/');
        Boolean isSuccess = true;
        
        if (urlParts[0] != URL_VERIFY) {
            isSuccess = false;
            addError(HTTP_NOT_FOUND, ERROR_URL_INVALID);
            return;
        }
        
        RestRequest request = RestContext.request;
        system.debug('Request '+request);
        String emailOrPhone = request.params.get('contact');
        String otpEntered = request.params.get('otpentered');
        
        if (String.isBlank(emailOrPhone)) {
            addError(HTTP_BAD_REQUEST, 'Missing contact details.');
            isSuccess = false;
            return;
        }
        
        List<One_Time_Password__c> otp = [
            SELECT Id, Mobile_Number__c, Expiry__c, Applicant__r.Name, Applicant__r.Email, Applicant__r.RecordType.Name , isValid__c, EMail__c, OTP__c, createdDate
            FROM One_Time_Password__c
            WHERE Mobile_Number__c = :emailOrPhone OR Email__c = :emailOrPhone
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        
        
        if (otp.size() == 0 || otp[0].Expiry__c < System.now()) {
            addError(HTTP_SUCCESS, 'OTP expired.');
            isSuccess = false;
            return;
        }
        
        if (otp[0].OTP__c != otpEntered) {
            addError(HTTP_SUCCESS, 'Invalid OTP.');
            isSuccess = false;
            return;
        }
        
        if (otp[0].Applicant__c != null) {
        Contact contactToUpdate = new Contact(
            Id = otp[0].Applicant__c,
            Last_Portal_Login_Date__c = System.today()
        );
        try {
            update contactToUpdate;
        } catch (Exception ex) {
            addError(HTTP_BAD_REQUEST, 'Failed to update Last_Portal_Login_Date__c: ' + ex.getMessage());
            return;
        }
    }
        system.debug('Applicant ID'+otp[0].Applicant__c);
        hed__Affiliation__c aff = [ SELECT Id,Name,DSU_Email__c FROM hed__Affiliation__c WHERE hed__Contact__c = :otp[0].Applicant__c AND DSU_Email__c = :emailOrPhone];

        DateTime loginTime = System.now();
        Portal_Session__c session = new Portal_Session__c();
        session.Contact__c = otp[0].Applicant__c;
        session.Login_Time__c = loginTime;
        session.Session_Status__c = 'Active';
        insert session;

        OtpResult successResult = new OtpResult();
        successResult.success = true;
        successResult.userId = otp[0].Applicant__c;
        successResult.userName = otp[0].Applicant__r.Name;
        successResult.userEmail = aff.DSU_Email__c;  //otp[0].Applicant__r.Email;
        successResult.userType = otp[0].Applicant__r.RecordType.Name;
        successResult.sessionId = session.Id;
        successResult.loginTime = String.valueOf(loginTime);
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.statusCode = HTTP_SUCCESS;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(successResult));

        delete otp[0];
    }
    
    public static void sendEmail(Contact applicants, String otpNumber, Id otpId) {
        EmailTemplate et = [
            SELECT Id, Body
            FROM EmailTemplate
            WHERE name = 'PFSOtpEmailTemplate'
            LIMIT 1
        ];
        
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setTargetObjectId(applicants.Id);
        message.setWhatId(otpId);
        message.setSaveAsActivity(false);
        message.setTemplateId(et.Id);
        message.setTreatTargetObjectAsRecipient(false);
        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage>{ message };
            Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);
    }
      public static void sendEmailforAffliation(hed__Affiliation__c affiliation, String otpNumber, Id otpId) {
    // Step 1: Get template
    EmailTemplate template = [
        SELECT Id 
        FROM EmailTemplate 
        WHERE Name = 'PFSOtpEmailTemplate' 
        LIMIT 1
    ];

    // Step 2: Render template (returns SingleEmailMessage object)
    Messaging.SingleEmailMessage rendered = 
        Messaging.renderStoredEmailTemplate(template.Id, affiliation.hed__Contact__c, otpId);

    // Step 3: Send email ONLY to DSU_Email__c with the merged content
    Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
    message.setToAddresses(new List<String>{ affiliation.DSU_Email__c });
    message.setSubject(rendered.getSubject());
    message.setHtmlBody(rendered.getHtmlBody());
    message.setSaveAsActivity(false);

    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
}


    
    /**
     * @description Delivers the OTP for the DSU-email (affiliation) login.
     *              Why: OTP emails are sent through Amazon SES so they do not use up the Salesforce daily email
     *              limit (switched on/off in CRM Org Parameters, see AmazonSesOtpService).
     *              Order matters: Amazon SES is called first because Salesforce does not allow an HTTP callout after
     *              DML; the OTP record is saved afterwards. The original Salesforce email below is sent only when
     *              Amazon SES is switched off or fails, so the student always receives the OTP.
     * @param affiliation Affiliation holding the DSU email.
     * @param otpNumber Generated OTP.
     */
    private static void deliverAffiliationOtp(hed__Affiliation__c affiliation, String otpNumber) {
        AmazonSesOtpService.Outcome emailOutcome = AmazonSesOtpService.sendStudentOtp(affiliation.DSU_Email__c, otpNumber);
        Id otpId = saveOtpInformationForAffliation(affiliation, otpNumber);
        if (emailOutcome == AmazonSesOtpService.Outcome.USE_SALESFORCE_EMAIL) {
            sendEmailforAffliation(affiliation, otpNumber, otpId);
        }
    }

    public static Id saveOtpInformation(Contact applicant, String otpNumber) {
        One_Time_Password__c otp = new One_Time_Password__c();
        otp.Mobile_Number__c = applicant.Phone;
        otp.Email__c = applicant.Email;
        otp.Applicant__c = applicant.Id;
        otp.OTP__c = otpNumber;
        otp.Expiry__c = System.now().addMinutes(10);
        
        insert otp;
        
        return otp.Id;
    }
    
     public static Id saveOtpInformationForAffliation(hed__Affiliation__c affiliations, String otpNumber) {
        One_Time_Password__c otp = new One_Time_Password__c();
        otp.Mobile_Number__c = affiliations.hed__Contact__r.Phone;
        otp.Email__c = affiliations.DSU_Email__c;
        otp.Applicant__c = affiliations.hed__Contact__c;
        otp.OTP__c = otpNumber;
        otp.Expiry__c = System.now().addMinutes(10);
        
        insert otp;
        
        return otp.Id;
    }
    
    private static void addError(Integer statusCode, String errorMessage) {
        OtpResult result = new OtpResult();
        result.success = false;
        result.errorMessage = errorMessage;
        
        RestContext.response.statusCode = statusCode;
        RestContext.response.headers.put('content-type', 'text/plain');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }
    
    public virtual class OtpResult {
        public Boolean success;
        public String errorMessage;
        public String userId;
        public String userName;
        public String userEmail;
        public String userType;
        public String OTP;
        public String sessionId;
        public String loginTime;
    }
}