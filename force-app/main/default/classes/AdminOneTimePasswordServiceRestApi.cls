@RestResource(urlMapping='/AdminOtp/*')
global class AdminOneTimePasswordServiceRestApi {
    private static final String URL_BASE = '/AdminOtp/';
    private static final String URL_SEND = 'send';
    private static final String URL_VERIFY = 'verify';

    private static final Integer HTTP_SUCCESS = 200;
    private static final Integer HTTP_BAD_REQUEST = 400;
    private static final Integer HTTP_NOT_FOUND = 404;

    private static final String ERROR_URL_INVALID = 'The request URL is invalid.';

    @httpPost
    global static void sendOtp() {
        String requestURI = RestContext.request.requestURI;
        requestURI = requestURI.replace(URL_BASE, '');
        System.debug('==request==='+RestContext.request);
        System.debug('reuest body-->'+JSON.serialize(RestContext.request.requestBody));
        System.debug('==requestURI==='+requestURI);
        String[] urlParts = requestURI.split('/');
        if (urlParts[0] != URL_SEND) {
            addError(HTTP_NOT_FOUND, ERROR_URL_INVALID+'==='+urlParts[0]);
            return;
        }
        RestRequest request = RestContext.request;
        String emailOrPhone = request.params.get('contact');
        System.debug('==emailOrPhone==='+emailOrPhone);

        if (String.isBlank(emailOrPhone)) {
            addError(HTTP_BAD_REQUEST, 'Missing contact details.');
            return;
        }                      
        Id adminRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' and  DeveloperName='Admin' limit 1].id;
            
        //Id adminRecordTypeId = schema.SObjectType.Account.getRecordTypeinfosbyname().get('Admin').getRecordTypeId();

        List<Contact> applicant = [ 
            SELECT Id, Email, Phone, Name 
            FROM Contact
            WHERE (Email = :emailOrPhone OR Phone = :emailOrPhone) AND RecordTypeId =: adminRecordTypeId
        ];
        
        /*List<Account> applicant = [ 
            SELECT Id, PersonEmail, Phone, Name , PersonContactId
            FROM Account
            WHERE (PersonEmail = :emailOrPhone OR Phone = :emailOrPhone) AND RecordTypeId =: adminRecordTypeId
        ];*/

        if (applicant.size() == 0) {
            addError(HTTP_BAD_REQUEST, 'User not found');
            return;
        }

        String otpNumber = String.valueOf(Math.round((Math.random() * (9000) + 1000)));
        String smsBody = String.format(Label.otpSmsTemplate, new List<String>{ otpNumber });

        Display_OTP__c[] display = Display_OTP__c.getAll().values();
        OtpResult successResult = new OtpResult();
        //if(display[0].Is_SMS_Required__c == true){
           // HttpResponse smsResponse = SMS_Integration_SendSmsApi.SMSCallouts(applicant[0].Phone,otpNumber, '');
        //}
        //Contact con = [Select Id,Name,Email,Phone from Contact where Id=:applicant[0].Id];
        // Admin OTP email switched off (Oct 2026): admins do not receive OTP emails - production has no Admin
        // contacts and the portal signs admins in through /PFSOtp. The OTP is still saved and returned below.
        // To switch the email back on: Id otpId = saveOtpInformation(...); and un-comment sendEmail(...) below.
        saveOtpInformation(applicant[0], otpNumber);
        //if(display[0].Is_OnScreen_Required__c == true){
            successResult.OTP = otpNumber;
        //}
        //if(display[0].Is_Email_Required__c == true){
        //     sendEmail(applicant[0], otpNumber, otpId);
        //}

        
        successResult.success = true;
        successResult.alumniId = applicant[0].Id;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.statusCode = HTTP_SUCCESS;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(successResult));
    }

    @httpGet
    global static void verifyOtp() {
        String requestURI = RestContext.request.requestURI;
        requestURI = requestURI.replace(URL_BASE, '');
        String[] urlParts = requestURI.split('/');
        Boolean isSuccess = true;
        System.debug('urlParts[0]'+urlParts[0]);
        if (urlParts[0] != URL_VERIFY) {
            isSuccess = false;
            addError(HTTP_NOT_FOUND, ERROR_URL_INVALID);
            return;
        }

        RestRequest request = RestContext.request;
        String emailOrPhone = request.params.get('contact');
        String otpEntered = request.params.get('otpentered');
        System.debug('request.params '+request.params);
        System.debug('emailOrPhone '+emailOrPhone);

        if (String.isBlank(emailOrPhone)) {
            addError(HTTP_BAD_REQUEST, 'Missing contact details.');
            isSuccess = false;
            return;
        }

        List<One_Time_Password__c> otp = [
            SELECT Id, Mobile_Number__c, Expiry__c, Applicant__r.Name, Applicant__r.Email,/*Applicant__r.Year_of_Graduation__c,*/ isValid__c, EMail__c, OTP__c, createdDate
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

        OtpResult successResult = new OtpResult();
        successResult.success = isSuccess;
        successResult.alumniId = otp[0].Applicant__c;
        successResult.alumniName = otp[0].Applicant__r.Name;
        successResult.alumniEmail = otp[0].Applicant__r.Email;
        //successResult.yearOfGraduation = String.valueOf(otp[0].Applicant__r.Year_of_Graduation__c);
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.statusCode = HTTP_SUCCESS;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(successResult));

        delete otp[0];
    }

  public static void sendEmail(Contact applicant, String otpNumber, Id otpId) {
    try {
        // Fetch the email template
        EmailTemplate et = [
            SELECT Id, Body, HtmlValue,Subject
            FROM EmailTemplate
            WHERE Name = 'AdminOtpEmailTemplate'
            LIMIT 1
        ];

        if (et == null) {
            System.debug('Email template not found.');
            return;
        }

        // Check if PersonContactId is null
        if (String.isBlank(applicant.Id)) {
            //System.debug('PersonContactId is null. Cannot send email.');
            return;
        }

        // Create the email message
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setTargetObjectId(applicant.Id); // Use PersonContactId for Person Accounts
        message.setSaveAsActivity(false); // Do not save as an activity
        message.setTemplateId(et.Id); // Assign email template ID
         message.setSubject(et.Subject);

        // Replace placeholders in the email body
        String body = et.HtmlValue;
        body = body.replaceAll('Applicant', applicant.Name);
        body = body.replaceAll('OTPNumber', otpNumber);
        message.setHtmlBody(body); // Set modified body for the email

        // Log debug information
        System.debug('Email template ID: ' + et.Id);
        System.debug('Applicant Name: ' + applicant.Name);
        System.debug('Email Body: ' + body);

        // Send the email
        Messaging.SingleEmailMessage[] messages = new List<Messaging.SingleEmailMessage>{message};
        Messaging.SendEmailResult[] results = Messaging.sendEmail(messages);

        // Check email send results
        if (results != null && results.size() > 0 && !results[0].success) {
            System.debug('Failed to send email: ' + results[0].errors[0].message);
        } else {
            System.debug('Email sent successfully.');
        }
    } catch (Exception e) {
        System.debug('Exception while sending email: ' + e.getMessage());
    }
}


    @TestVisible private static Id saveOtpInformation(Contact applicant, String otpNumber) {
     //@TestVisible private static Id saveOtpInformation(Account applicant, String otpNumber) {
        One_Time_Password__c otp = new One_Time_Password__c();
        otp.Mobile_Number__c = applicant.Phone;
        otp.Email__c = applicant.Email;
        //otp.Email__c = applicant.PersonEmail;
        otp.Applicant__c = applicant.Id;
        //otp.Applicant__c = applicant?.PersonContactId;
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
        public String alumniId;
        public String alumniName;
        public String alumniEmail;
        //public String yearOfGraduation;
        public String applicantId;
        public String applicantName;
        public String applicantEmail;
        public String OTP;
    }
    
   /* @TestVisible private static HttpResponse groupSMSCallouts(String phones, String Message, String senderName) {
        SMS_Integration_Cread__c record = SMS_Integration_Cread__c.getValues('S and S Solutions');
        if (String.isNotBlank(Message)) {
            Message = EncodingUtil.urlEncode(Message, 'UTF-8');
        } else {
            Message = '';
        }
        Http h = new Http();
        HttpRequest hr = new HttpRequest();
        hr.setEndpoint(
            record.Send_Api_Url__c +
            'apikey=' +
            record.API_Key__c +
            '&sender=' +
            record.SenderName__c +
            '&number=' +
            EncodingUtil.urlEncode(phones, 'UTF-8') +
            '&message=' +
            Message
        );
        hr.setMethod('GET');
        hr.setHeader('CONTENT-TYPE', 'text/xml');
        HttpResponse response = h.send(hr);

        return response;
    }
*/
    
}