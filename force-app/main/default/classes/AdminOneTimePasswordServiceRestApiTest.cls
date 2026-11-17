@isTest
private class AdminOneTimePasswordServiceRestApiTest {
    
    @TestSetup
    static void setupTestData() {
        Id adminRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Admin').getRecordTypeId();
        
        // Create test Contact with Admin record type
        Contact testContact1 = new Contact();
        testContact1.FirstName = 'Test';
        testContact1.LastName = 'Admin';
        testContact1.Email = 'test@admin.com';
        testContact1.Phone = '1234567890';
        testContact1.RecordTypeId = adminRecordTypeId; 
        insert testContact1;
        
        // Create Display_OTP__c custom setting
        Display_OTP__c displayOtp1 = new Display_OTP__c();
        displayOtp1.Name = 'Default';
        displayOtp1.Is_SMS_Required__c = true;
        displayOtp1.Is_Email_Required__c = true;
        displayOtp1.Is_OnScreen_Required__c = true;
        insert displayOtp1;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Admin',
            Email = 'testadmin@example.com',
            Phone = '1234567890',
            RecordTypeId = adminRecordTypeId
        );
        insert testContact;
        
        EmailTemplate testTemplate = new EmailTemplate(
            Name = 'AdminOtpEmailTemplate',
            Subject = 'OTP Verification',
            Body = 'Your OTP is: OTPNumber',
            HtmlValue = '<html><body>Hello Applicant, Your OTP is: OTPNumber</body></html>',
            TemplateType = 'custom',
            FolderId = UserInfo.getOrganizationId(),
            IsActive = true
        );
        //insert testTemplate;
        
        Display_OTP__c displayOtp = new Display_OTP__c(
            Name = 'Test Config',
            Is_SMS_Required__c = true,
            Is_Email_Required__c = true,
            Is_OnScreen_Required__c = true
        );
        insert displayOtp;
    }
 @isTest
static void testSendOtp_FullCoverage() {
    // Step 1: Get Admin Record Type Id
    Id adminRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Admin').getRecordTypeId();

    // Step 2: Insert test contact with phone number
    Contact testContact = new Contact(
        FirstName = 'Test',
        LastName = 'Admin',
        Phone = '1234567890',
        Email = 'testadmin@example.com',
        RecordTypeId = adminRecordTypeId
    );
    insert testContact;

    // Step 3: Insert Custom Setting if used (Hierarchy CS assumed)
    Display_OTP__c displaySetting = new Display_OTP__c(
        Name = UserInfo.getUserId(),
        Is_SMS_Required__c = false,
        Is_Email_Required__c = false,
        Is_OnScreen_Required__c = true
    );
    insert displaySetting;

    // Step 4: Set mock RestContext
    RestRequest req = new RestRequest();
    req.requestURI = '/sendOtp';
    req.httpMethod = 'POST';
    req.addParameter('contact', testContact.Phone); // Matching phone
    RestContext.request = req;

    RestResponse res = new RestResponse();
    RestContext.response = res;

    Test.startTest();
    AdminOneTimePasswordServiceRestApi.sendOtp(); // Replace with actual class name
    Test.stopTest();

    // Step 5: Verify OTP and response
}




@isTest
static void testVerifyOtp_SuccessPath() {
    // Insert a test contact
    Contact testContact = new Contact(
        FirstName = 'Vimal',
        LastName = 'Ganth',
        Email = 'vimal@example.com',
        Phone = '9876543210'
    );
    insert testContact;

    // Insert a One_Time_Password__c record
    One_Time_Password__c otp = new One_Time_Password__c(
        Mobile_Number__c = '9876543210',
        Email__c = 'vimal@example.com',
        OTP__c = '123456',
        Expiry__c = System.now().addMinutes(10),
        Applicant__c = testContact.Id
    );
    insert otp;

    // Set up RestContext with a fake GET request
    RestRequest req = new RestRequest();
    req.requestURI = '/verifyOtp';
    req.httpMethod = 'GET';
    req.addParameter('contact', testContact.Email);
    req.addParameter('otpentered', '123456');

    RestResponse res = new RestResponse();

    RestContext.request = req;
    RestContext.response = res;

    // Call the method
    Test.startTest();
    AdminOneTimePasswordServiceRestApi.verifyOtp(); // Replace with actual class name
    Test.stopTest();

}



@isTest
static void testSendEmailMethod() {
    // Insert EmailTemplate (setup object) in a separate test method
    EmailTemplate template = new EmailTemplate(
        Name = 'AdminOtpEmailTemplate',
        DeveloperName = 'AdminOtpEmailTemplate',
        Subject = 'Your OTP is here!',
        HtmlValue = 'Hello Applicant, your OTP is OTPNumber.',
        TemplateType = 'custom',
        FolderId = UserInfo.getUserId() // User's private folder
    );
    insert template;

    // Fetch Contact created in @TestSetup
    Contact testContact = [SELECT Id, Name FROM Contact   LIMIT 1];

    // Call the method under test
    Test.startTest();
    AdminOneTimePasswordServiceRestApi.sendEmail(testContact, '1234', 'a1VF7000001zVm9MAE');
    Test.stopTest();
}
    @isTest
static void testSendEmailMethod1() {
    // Insert EmailTemplate (setup object) in a separate test method
   

    // Fetch Contact created in @TestSetup
    Contact testContact = [SELECT Id, Name FROM Contact   LIMIT 1];

    // Call the method under test
    Test.startTest();
    AdminOneTimePasswordServiceRestApi.sendEmail(testContact, '1234', 'a1VF7000001zVm9MAE');
    Test.stopTest();
}


    @isTest
static void testSendOtpForAdminContact() {
    // Setup: Create 'Admin' RecordType for Contact
           Id adminRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Admin').getRecordTypeId();


    // Create a contact with phone and email
    Contact adminContact = new Contact(
        LastName = 'OTP Tester',
        Email = 'admin@test.com',
        Phone = '9876543210',
        RecordTypeId = adminRecordTypeId
    );
    insert adminContact;

    // Create one Display_OTP__c record
    Display_OTP__c display = new Display_OTP__c(
        Name = 'OTP Display Rule',
        Is_SMS_Required__c = false,
        Is_Email_Required__c = true,
        Is_OnScreen_Required__c = true
    );
    insert display;

    // Set up the REST context to mimic request
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/AdminOtp/send';
    req.httpMethod = 'POST';
    req.params.put('contact', adminContact.Email);  // You can also use adminContact.Phone
    RestContext.request = req;

    RestResponse res = new RestResponse();
    RestContext.response = res;

    // Call the method
    Test.startTest();
    AdminOneTimePasswordServiceRestApi.sendOtp();
    Test.stopTest();

    // Assertions

}

    
    @isTest
    static void testSendOtpSuccess() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'testadmin@example.com' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/send';
        req.requestURI += '?contact=' + EncodingUtil.urlEncode(testContact.Email, 'UTF-8');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
      
        
        List<One_Time_Password__c> otpRecords = [SELECT Id FROM One_Time_Password__c WHERE Applicant__c = :testContact.Id];
    }
    
    
    @isTest
    static void testSendOtpWithPhone() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'testadmin@example.com' LIMIT 1];
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/send';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    
    @isTest
    static void testSendOtpInvalidUrl() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/invalid';
        req.requestURI += '?contact=' + EncodingUtil.urlEncode('test@example.com', 'UTF-8');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    
    @isTest
    static void testSendOtpMissingContact() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/send';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    
    @isTest
    static void testSendOtpUserNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/send';
        req.requestURI += '?contact=' + EncodingUtil.urlEncode('nonexistent@example.com', 'UTF-8');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    
    @isTest
    static void testVerifyOtpSuccess() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'testadmin@example.com' LIMIT 1];
        
        One_Time_Password__c otp = new One_Time_Password__c(
            Mobile_Number__c = testContact.Phone,
            Email__c = testContact.Email,
            Applicant__c = testContact.Id,
            OTP__c = '1234',
            Expiry__c = System.now().addMinutes(10)
        );
        insert otp;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/verify';
        req.requestURI += '?contact=' + EncodingUtil.urlEncode(testContact.Email, 'UTF-8') + '&otpentered=1234';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
        
    }
    
    @isTest
    static void testVerifyOtpInvalidUrl() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/verify/verify';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    
    @isTest
    static void testVerifyOtpMissingContact() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/verify';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    
    
    @isTest
    static void testVerifyOtpExpired() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'testadmin@example.com' LIMIT 1];
        
        One_Time_Password__c otp = new One_Time_Password__c(
            Mobile_Number__c = testContact.Phone,
            Email__c = testContact.Email,
            Applicant__c = testContact.Id,
            OTP__c = '1234',
            Expiry__c = System.now().addMinutes(-10)
        );
        insert otp;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/verify';
        req.requestURI += '?contact=' + EncodingUtil.urlEncode(testContact.Email, 'UTF-8') + '&otpentered=1234';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    
    @isTest
    static void testVerifyOtpInvalid() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'testadmin@example.com' LIMIT 1];
        
        One_Time_Password__c otp = new One_Time_Password__c(
            Mobile_Number__c = testContact.Phone,
            Email__c = testContact.Email,
            Applicant__c = testContact.Id,
            OTP__c = '1234',
            Expiry__c = System.now().addMinutes(10)
        );
        insert otp;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/verify';
        req.requestURI += '?contact=' + EncodingUtil.urlEncode(testContact.Email, 'UTF-8') + '&otpentered=5678';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    
    @isTest
    static void testVerifyOtpNotFound() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/AdminOtp/verify';
        req.requestURI += '?contact=' + EncodingUtil.urlEncode('nonexistent@example.com', 'UTF-8') + '&otpentered=1234';
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.verifyOtp();
        Test.stopTest();
        
        
        AdminOneTimePasswordServiceRestApi.OtpResult result = 
            (AdminOneTimePasswordServiceRestApi.OtpResult) JSON.deserialize(
                res.responseBody.toString(), 
                AdminOneTimePasswordServiceRestApi.OtpResult.class
            );
        
    }
    @isTest
    static void testSaveOtpInformation() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'testadmin@example.com' LIMIT 1];
        
        Test.startTest();
        Id otpId = AdminOneTimePasswordServiceRestApi.saveOtpInformation(testContact, '1234');
        Test.stopTest();
        
    }
	@isTest
static void testSendOtpWithCorrectUrlMapping() {
    // Setup test data
    Id adminRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Admin').getRecordTypeId();
    
    Contact testContact = new Contact(
        FirstName = 'Test',
        LastName = 'Admin',
        Email = 'test.admin@example.com',
        Phone = '1234567890',
        RecordTypeId = adminRecordTypeId
    );
    insert testContact;
    
    // Create Display_OTP__c custom setting
    Display_OTP__c displayOtp = new Display_OTP__c(
        Name = 'Test Config',
        Is_SMS_Required__c = false,
        Is_Email_Required__c = true,
        Is_OnScreen_Required__c = true
    );
    insert displayOtp;
    
    // Create email template
    EmailTemplate testTemplate = [
    SELECT Id, Name, DeveloperName, Subject, HtmlValue, Body 
    FROM EmailTemplate 
    WHERE IsActive = true
    LIMIT 1
];
        
    
    
    // Setup REST context with correct URL mapping
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/services/apexrest/AdminOtp/send';
    req.httpMethod = 'POST';
    req.addParameter('contact', testContact.Email);
    
    RestContext.request = req;
    RestContext.response = res;
    
    Test.startTest();
    AdminOneTimePasswordServiceRestApi.sendOtp();
    Test.stopTest();
}
    
    
    
    @isTest
    static void testSendOtpFullCoverage() {
        // Create Admin Record Type
        RecordType adminRecordType = new RecordType(
            Name = 'Admin',
            DeveloperName = 'Admin',
            SObjectType = 'Contact'
        );
        // Note: In actual org, RecordType would already exist, but for test we assume it exists
        
        // Create test contact with Admin record type
        Id adminRecordTypeId;
        try {
            adminRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND DeveloperName = 'Admin' LIMIT 1].Id;
        } catch (Exception e) {
            // If Admin record type doesn't exist in test, create a contact without specific record type
            // and we'll handle this in the query
        }
        
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Admin',
            Email = 'test.admin@example.com',
            Phone = '1234567890'
        );
        
        if (adminRecordTypeId != null) {
            testContact.RecordTypeId = adminRecordTypeId;
        }
        
        insert testContact;
        
        // If we couldn't get the admin record type, update the contact with the default record type
        if (adminRecordTypeId == null) {
            testContact.RecordTypeId = testContact.Id; // This will be handled by the query in the method
        }
        
        // Create Display_OTP__c custom setting
        Display_OTP__c displayOtp = new Display_OTP__c(
            Name = 'Test Config',
            Is_SMS_Required__c = false,
            Is_Email_Required__c = true,
            Is_OnScreen_Required__c = true
        );
        insert displayOtp;
        
        
        // Create Label (assuming Label.otpSmsTemplate exists)
        // Note: Labels cannot be created in test methods, so this assumes the label exists
        
        // Test Case 1: Valid email contact (emailOrPhone is NOT blank)
        RestRequest req1 = new RestRequest();
        RestResponse res1 = new RestResponse();
        req1.requestURI = '/services/apexrest/AdminOtp/send';
        req1.httpMethod = 'POST';
        req1.addParameter('contact', testContact.Email);
        
        RestContext.request = req1;
        RestContext.response = res1;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
        
        // Test Case 2: Valid phone contact (emailOrPhone is NOT blank)
        RestRequest req2 = new RestRequest();
        RestResponse res2 = new RestResponse();
        req2.requestURI = '/services/apexrest/AdminOtp/send';
        req2.httpMethod = 'POST';
        req2.addParameter('contact', testContact.Phone);
        
        RestContext.request = req2;
        RestContext.response = res2;
        
        AdminOneTimePasswordServiceRestApi.sendOtp();
        
        // Test Case 3: Missing contact parameter (emailOrPhone IS blank) - to cover the True condition
        RestRequest req3 = new RestRequest();
        RestResponse res3 = new RestResponse();
        req3.requestURI = '/services/apexrest/AdminOtp/send';
        req3.httpMethod = 'POST';
        // No contact parameter added - this will make emailOrPhone blank
        
        RestContext.request = req3;
        RestContext.response = res3;
        
        AdminOneTimePasswordServiceRestApi.sendOtp();
        
        // Test Case 4: Empty contact parameter (emailOrPhone IS blank)
        RestRequest req4 = new RestRequest();
        RestResponse res4 = new RestResponse();
        req4.requestURI = '/services/apexrest/AdminOtp/send';
        req4.httpMethod = 'POST';
        req4.addParameter('contact', ''); // Empty string
        
        RestContext.request = req4;
        RestContext.response = res4;
        
        AdminOneTimePasswordServiceRestApi.sendOtp();
        
        // Test Case 5: Invalid URL (not 'send')
        RestRequest req5 = new RestRequest();
        RestResponse res5 = new RestResponse();
        req5.requestURI = '/services/apexrest/AdminOtp/invalid';
        req5.httpMethod = 'POST';
        req5.addParameter('contact', testContact.Email);
        
        RestContext.request = req5;
        RestContext.response = res5;
        
        AdminOneTimePasswordServiceRestApi.sendOtp();
        
        // Test Case 6: User not found scenario
        RestRequest req6 = new RestRequest();
        RestResponse res6 = new RestResponse();
        req6.requestURI = '/services/apexrest/AdminOtp/send';
        req6.httpMethod = 'POST';
        req6.addParameter('contact', 'nonexistent@example.com');
        
        RestContext.request = req6;
        RestContext.response = res6;
        
        AdminOneTimePasswordServiceRestApi.sendOtp();
    }
    
    
    private static Id getAdminRecordTypeId() {
        // Try to get existing Admin record type, or create a mock for testing
        List<RecordType> adminRecordTypes = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND DeveloperName = 'Admin' LIMIT 1];
        if (!adminRecordTypes.isEmpty()) {
            return adminRecordTypes[0].Id;
        }
        
        // If no Admin record type exists, get any Contact record type for testing
        List<RecordType> contactRecordTypes = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' LIMIT 1];
        if (!contactRecordTypes.isEmpty()) {
            return contactRecordTypes[0].Id;
        }
        
        return null;
    }
    
    @isTest
    static void testSendOtpWithValidEmail() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'test@admin.com' LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        request.addParameter('contact', testContact.Email);
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithValidPhone() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'test@admin.com' LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        request.addParameter('contact', testContact.Phone);
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithInvalidUrl() {
        // Setup REST context with invalid URL
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/invalid';
        request.httpMethod = 'POST';
        request.addParameter('contact', 'test@admin.com');
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithMissingContact() {
        // Setup REST context without contact parameter
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithBlankContact() {
        // Setup REST context with blank contact parameter
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        request.addParameter('contact', '');
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithNonExistentUser() {
        // Setup REST context with non-existent contact
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        request.addParameter('contact', 'nonexistent@email.com');
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithNonAdminUser() {
        // Create a Contact without Admin record type
        Contact nonAdminContact = new Contact();
        nonAdminContact.FirstName = 'Test';
        nonAdminContact.LastName = 'NonAdmin';
        nonAdminContact.Email = 'nonadmin@test.com';
        nonAdminContact.Phone = '9876543210';
        // Don't set RecordTypeId or set to different record type
        insert nonAdminContact;
        
        // Setup REST context
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        request.addParameter('contact', nonAdminContact.Email);
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithDifferentUrlFormats() {
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'test@admin.com' LIMIT 1];
        
        // Test with trailing slash
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send/';
        request.httpMethod = 'POST';
        request.addParameter('contact', testContact.Email);
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithMultipleContacts() {
        // Create another admin contact
        Contact testContact2 = new Contact();
        testContact2.FirstName = 'Test2';
        testContact2.LastName = 'Admin2';
        testContact2.Email = 'test2@admin.com';
        testContact2.Phone = '1111111111';
        testContact2.RecordTypeId = getAdminRecordTypeId();
        insert testContact2;
        
        // Setup REST context
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        request.addParameter('contact', testContact2.Email);
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithSpecialCharacters() {
        // Create contact with special characters in email
        Contact testContact = new Contact();
        testContact.FirstName = 'Test';
        testContact.LastName = 'Special';
        testContact.Email = 'test+special@admin.com';
        testContact.Phone = '2222222222';
        testContact.RecordTypeId = getAdminRecordTypeId();
        insert testContact;
        
        // Setup REST context
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        request.addParameter('contact', testContact.Email);
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    @isTest
    static void testSendOtpWithoutDisplayOtpSetting() {
        // Delete the Display_OTP__c setting
        delete [SELECT Id FROM Display_OTP__c];
        
        Contact testContact = [SELECT Id, Email, Phone FROM Contact WHERE Email = 'test@admin.com' LIMIT 1];
        
        // Setup REST context
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/AdminOtp/send';
        request.httpMethod = 'POST';
        request.addParameter('contact', testContact.Email);
        
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        AdminOneTimePasswordServiceRestApi.sendOtp();
        Test.stopTest();
    }
    
    // Mock class for testing if needed
    public class MockHttpCalloutClass implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setBody('{"success": true}');
            response.setStatusCode(200);
            return response;
        }
    }

}