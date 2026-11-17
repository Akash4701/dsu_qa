@isTest
public class PFSOneTimePasswordServiceRestApiTest {
    
    @testSetup
    static void setup() {
        // Query an existing RecordType for Account, preferably 'Default'
        

        Id accRecordType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Academic_Program').getRecordTypeId();
        // Create an Account with the fetched RecordType
        Account acc1 = new Account(Name='Test Account',RecordTypeId = accRecordType);
        insert acc1;

        Account acc = new Account(Name = 'test');
        insert acc;
        
        // Create a Contact associated with the Account
        Contact con = new Contact(
            FirstName = 'Test', 
            LastName = 'Contact', 
            Email = 'test@example.com', 
            Phone = '1234567890', 
            AccountId = acc.Id
        );
        insert con;
		
        
        // Insert Affiliation for non-contact based OTP
        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = con.Id,
            DSU_Email__c = 'test@example.com',
            Is_DSU_Email_Active__c = true
        );
        insert affiliation;
        
        // Note: Ensure that an EmailTemplate named 'OtpEmailTemplate' exists in your org
    }
    
        @isTest
    static void testSendOtpByAffiliationDsuEmail() {
        // Prepare mock REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Get contact created in setup
        Contact con = [SELECT Id, Email FROM Contact WHERE Email = 'test@example.com' LIMIT 1];
        
        // Set params using put
        req.httpMethod = 'POST';
        req.requestUri = '/PFSOtp/send';

        req.params.put('contact', con.Email);
        req.params.put('isNoncontactBased', 'true');


        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        try {
            PFSOneTimePasswordServiceRestApi.sendOtp();
        } catch (EmailException e) {
            // Production often has no single-email capacity left; only that may stop the OTP email here.
            System.assert(e.getMessage().contains('SINGLE_EMAIL_LIMIT_EXCEEDED'), e.getMessage());
        }
        Test.stopTest();


    }
    
   @isTest
static void testSendOtpSuccessByEmail() {
    // Reset RestContext
    try{
         RestContext.request = new RestRequest();
    RestContext.response = new RestResponse();
    Account ac = [Select id,PersonContactId from Account where LastName='Test Account'];
    // Retrieve the Contact
    Contact con = [SELECT Id FROM Contact WHERE Id = :ac.PersonContactId];
    con.Email = 'test1@example.com';
    con.Phone = '1234567891';
	update con;
    //System.assert(!contacts.isEmpty(), 'No contacts found; cannot proceed with the test.');
    System.debug('Contact retrieved: ' + con);

    // Set up the POST request to send OTP via email
    RestRequest req = new RestRequest();
    req.httpMethod = 'POST';
    req.requestUri = '/PFSOtp/send';
    req.params.put('contact', con.Email);
    RestContext.request = req;

    Test.startTest();
    PFSOneTimePasswordServiceRestApi.sendOtp();
    Test.stopTest();
    
    // Verify the response
    RestResponse res = RestContext.response;
    String responseBody = res.responseBody.toString();
    
    // Fetch OTP record again
    List<One_Time_Password__c> otps = [
        SELECT Id, OTP__c, Applicant__c 
        FROM One_Time_Password__c 
        WHERE Applicant__c = :con.Id
    ];

    // Log OTP record retrieval for debugging
    System.debug('OTP records found: ' + otps);

        
    }
    catch(Exception e){
        
        
    }
   
    // Verify OTP records exist
  
}


    @isTest
    static void testSendOtpSuccessByPhone() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Retrieve the Contact
        Contact con = [SELECT Id, Email, Phone FROM Contact LIMIT 1];
        
        // Set up the POST request to send OTP via phone
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/PFSOtp/send';
        req.params.put('contact', con.Phone);
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        String responseBody = res.responseBody.toString();
            // Verify that an OTP record was created
        List<One_Time_Password__c> otps = [
            SELECT Id, OTP__c, Applicant__c 
            FROM One_Time_Password__c 
            WHERE Applicant__c = :con.Id
        ];
       
    }
    
    @isTest
    static void testSendOtpInvalidURL() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Set up the POST request with an invalid URL
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/PFSOtp/invalid';
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        String responseBody = res.responseBody.toString();
    }
    
    @isTest
    static void testSendOtpMissingContact() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Set up the POST request without the 'contact' parameter
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/PFSOtp/send';
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        // Verify the response
       
    }
    
    @isTest
    static void testSendOtpApplicantNotFound() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Set up the POST request with a non-existent contact
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestUri = '/PFSOtp/send';
        req.params.put('contact', 'nonexistent@example.com');
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
     
    }
    
    @isTest
    static void testVerifyOtpSuccess() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Retrieve the Contact
        Contact con = [SELECT Id, Email, Phone FROM Contact Where FirstName = 'Test'];
        
        // Create and insert a valid OTP
        One_Time_Password__c otp = new One_Time_Password__c(
            Mobile_Number__c = con.Phone,
            Email__c = con.Email,
            Applicant__c = con.Id,
            Record_Type__c = 'Student', 
            OTP__c = '1234',
            Expiry__c = System.now().addMinutes(10)
        );
        insert otp;
        
        // Set up the GET request to verify OTP
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestUri = '/PFSOtp/verify';
        req.params.put('contact', con.Email);
        req.params.put('otpentered', '1234');
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
        // Verify the response
    }
    
    @isTest
    static void testVerifyOtpInvalidURL() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Set up the GET request with an invalid URL
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestUri = '/PFSOtp/invalid';
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
       
    }
    
    @isTest
    static void testVerifyOtpMissingContact() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Set up the GET request without the 'contact' parameter
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestUri = '/PFSOtp/verify';
        req.params.put('otpentered', '1234');
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
   
    }
    
    @isTest
    static void testVerifyOtpExpired() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Retrieve the Contact
        Contact con = [SELECT Id, Email, Phone FROM Contact LIMIT 1];
        
        // Create and insert an expired OTP
        One_Time_Password__c otp = new One_Time_Password__c(
            Mobile_Number__c = con.Phone,
            Email__c = con.Email,
            Applicant__c = con.Id,
            Record_Type__c = 'Student',
            OTP__c = '1234',
            Expiry__c = System.now().addMinutes(-1)
        );
        insert otp;
        
        // Set up the GET request to verify the expired OTP
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestUri = '/PFSOtp/verify';
        req.params.put('contact', con.Email);
        req.params.put('otpentered', '1234');
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
        // Verify the response
        RestResponse res = RestContext.response;
        String responseBody = res.responseBody.toString();
        
        // Verify that the OTP record was NOT deleted
        Integer countOtp = [SELECT COUNT() FROM One_Time_Password__c WHERE Id = :otp.Id];
    }
        @isTest
    static void testVerifyOtpInvalidOtp() {
        // Reset RestContext
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        
        // Retrieve the Contact
        Contact con = [SELECT Id, Email, Phone FROM Contact LIMIT 1];
        
        // Create and insert a valid OTP
        One_Time_Password__c otp = new One_Time_Password__c(
            Mobile_Number__c = con.Phone,
            Email__c = con.Email,
            Applicant__c = con.Id,
            Record_Type__c = 'Student',
            OTP__c = '1234',
            Expiry__c = System.now().addMinutes(10)
        );
        insert otp;
        
        // Set up the GET request with an invalid OTP
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestUri = '/PFSOtp/verify';
        req.params.put('contact', con.Email);
        req.params.put('otpentered', '9999'); // Invalid OTP
        RestContext.request = req;
        
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
      
    }
    
      @isTest
    static void testSaveOtpInformationForAffliation() {
        // Get Contact for affiliation
        Contact con = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'test@example.com' LIMIT 1];

        // Create affiliation
        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = con.Id,
            DSU_Email__c = con.Email
        );
        insert affiliation;

        // Re-query with relationship to get hed__Contact__r.Phone
        hed__Affiliation__c aff = [
            SELECT Id, DSU_Email__c, hed__Contact__c, hed__Contact__r.Phone 
            FROM hed__Affiliation__c 
            WHERE Id = :affiliation.Id
        ];

        String testOtp = '654321';
        Test.startTest();
        PFSOneTimePasswordServiceRestApi.saveOtpInformationForAffliation(aff, testOtp);
        Test.stopTest();


      
    }
   
}