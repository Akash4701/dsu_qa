/**
 * @description Tests for AmazonSesOtpService and the two OTP REST APIs that use it.
 *              - Switch (CRM Org Parameters): Amazon SES / SSO / original Salesforce email.
 *              - Amazon SES success, rejection and timeout (fallback to Salesforce email) and the Email Delivery Log.
 *              - Full student and admin login journeys (send OTP, then verify it) through the real REST classes.
 *              Amazon SES is never called for real: SesMock answers the HTTP callout.
 * @group OTP
 */
@IsTest
private class AmazonSesOtpServiceTest {
    private static final String DSU_EMAIL = 'ses.test.student@dsu.example.com';
    private static final String STUDENT_EMAIL = 'ses.test.student@example.com';
    private static final String ADMIN_EMAIL = 'ses.test.admin@example.com';
    private static final String UNKNOWN_EMAIL = 'nobody@example.com';
    private static final String OTP = '4821';
    private static final String TEST_TEMPLATE = 'SES Test OTP Template';
    private static final String TEST_TEMPLATE_NO_OTP = 'SES Test Template Without OTP';
    private static final String API_USER_LAST_NAME = 'SesOtpApiUser';
    private static final Pattern OTP_IN_EMAIL = Pattern.compile('Your OTP is (\\d{4})');
    private static final String MESSAGE_ID = '0109019a-test-message-id';

    @TestSetup
    static void setup() {
        // Setup objects (templates, user, permission set) are inserted as the running user to avoid MIXED_DML.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<EmailTemplate>{
                newTemplate(TEST_TEMPLATE, '<p>Your OTP is {{{One_Time_Password__c.OTP__c}}}.</p>'),
                newTemplate(TEST_TEMPLATE_NO_OTP, '<p>No OTP here.</p>')
            };
            // Mirrors the portal API user: System Administrator + SES_Email_Sender.
            User apiUser = new User(
                ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' WITH SYSTEM_MODE LIMIT 1].Id,
                LastName = API_USER_LAST_NAME,
                Email = 'ses.api.user@example.com',
                Username = 'ses.api.user.' + String.valueOf(Crypto.getRandomInteger()).replace('-', '') + '@dsu-ses-test.example.com',
                Alias = 'sesapi',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_IN',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
            insert apiUser;
            insert new PermissionSetAssignment(
                AssigneeId = apiUser.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'SES_Email_Sender' WITH SYSTEM_MODE LIMIT 1].Id
            );
        }

        Map<String, Schema.RecordTypeInfo> contactTypes = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
        Contact student = new Contact(
            FirstName = 'Ses',
            LastName = 'Student',
            Email = STUDENT_EMAIL,
            Phone = '9000000011',
            RecordTypeId = contactTypes.get('Student').getRecordTypeId()
        );
        Contact admin = new Contact(
            FirstName = 'Ses',
            LastName = 'Admin',
            Email = ADMIN_EMAIL,
            Phone = '9000000012',
            RecordTypeId = contactTypes.get('Admin').getRecordTypeId()
        );
        insert new List<Contact>{ student, admin };
        insert new hed__Affiliation__c(hed__Contact__c = student.Id, DSU_Email__c = DSU_EMAIL, Is_DSU_Email_Active__c = true);
    }

    // ------------------------------------------------------------------ helpers

    private static EmailTemplate newTemplate(String name, String html) {
        return new EmailTemplate(
            Name = name,
            DeveloperName = name.replace(' ', '_') + '_' + String.valueOf(Crypto.getRandomInteger()).replace('-', ''),
            TemplateType = 'custom',
            FolderId = UserInfo.getUserId(),
            IsActive = true,
            Subject = 'OTP for PFS Portal',
            HtmlValue = html
        );
    }

    private static User apiUser() {
        return [SELECT Id FROM User WHERE LastName = :API_USER_LAST_NAME WITH SYSTEM_MODE LIMIT 1];
    }

    /** Turns Amazon SES on, using the test template. */
    private static void useAmazonSes() {
        AmazonSesOtpService.switchOverride = new CRM_Org_Parameters__c(Use_Amazon_SES__c = true);
        AmazonSesOtpService.templateName = TEST_TEMPLATE;
    }

    private static void prepareRequest(String requestUri, Map<String, String> params) {
        RestRequest request = new RestRequest();
        request.httpMethod = 'POST';
        request.requestURI = requestUri;
        request.params.putAll(params);
        RestContext.request = request;
        RestContext.response = new RestResponse();
    }

    private static Map<String, Object> responseBody() {
        return (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    }

    private static List<Email_Delivery_Log__c> logs() {
        return [SELECT Status__c, Recipient__c, Details__c FROM Email_Delivery_Log__c WITH SYSTEM_MODE ORDER BY Name LIMIT 10];
    }

    // ------------------------------------------------------------------ switch + Amazon SES behaviour

    @IsTest
    static void sendsThroughSesWhenSwitchedOn() {
        System.runAs(apiUser()) {
            useAmazonSes();
            SesMock mock = acceptedMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            AmazonSesOtpService.Outcome outcome = AmazonSesOtpService.sendStudentOtp(DSU_EMAIL, OTP);
            Test.stopTest();

            Assert.areEqual(AmazonSesOtpService.Outcome.SENT_BY_SES, outcome, 'Amazon SES must send the email');
            Assert.isTrue(mock.lastBody.contains(OTP), 'The OTP must be in the email');
            Assert.isFalse(mock.lastBody.contains('{{{'), 'The merge field must be replaced');
            Assert.isTrue(mock.lastBody.contains('noreply@thekenverse.com'), 'Sender comes from the Custom Label');
            Email_Delivery_Log__c log = logs()[0];
            Assert.areEqual('Sent', log.Status__c, 'Successful send must be logged');
            Assert.isTrue(log.Details__c.contains(MESSAGE_ID), 'SES MessageId must be logged');
            Assert.isFalse(log.Details__c.contains(OTP), 'The OTP must never be logged');
        }
    }

    @IsTest
    static void fallsBackToSalesforceEmailWhenSesRejects() {
        System.runAs(apiUser()) {
            useAmazonSes();
            Test.setMock(HttpCalloutMock.class, new SesMock(403, '{"message":"signature mismatch"}'));

            Test.startTest();
            AmazonSesOtpService.Outcome outcome = AmazonSesOtpService.sendStudentOtp(DSU_EMAIL, OTP);
            Test.stopTest();

            Assert.areEqual(AmazonSesOtpService.Outcome.USE_SALESFORCE_EMAIL, outcome, 'SES error must fall back');
            Email_Delivery_Log__c log = logs()[0];
            Assert.areEqual('Failed', log.Status__c, 'Failure must be logged');
            Assert.isTrue(log.Details__c.contains('HTTP 403'), 'HTTP status must be logged');
        }
    }

    @IsTest
    static void fallsBackToSalesforceEmailWhenSesTimesOut() {
        System.runAs(apiUser()) {
            useAmazonSes();
            Test.setMock(HttpCalloutMock.class, timingOutMock());

            Test.startTest();
            AmazonSesOtpService.Outcome outcome = AmazonSesOtpService.sendStudentOtp(DSU_EMAIL, OTP);
            Test.stopTest();

            Assert.areEqual(AmazonSesOtpService.Outcome.USE_SALESFORCE_EMAIL, outcome, 'Timeout must fall back');
            Assert.isTrue(logs()[0].Details__c.contains('Read timed out'), 'Timeout must be logged');
        }
    }

    @IsTest
    static void sendsNothingWhenSsoIsOn() {
        System.runAs(apiUser()) {
            AmazonSesOtpService.switchOverride = new CRM_Org_Parameters__c(Use_SSO__c = true, Use_Amazon_SES__c = true);
            SesMock mock = acceptedMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            AmazonSesOtpService.Outcome outcome = AmazonSesOtpService.sendStudentOtp(DSU_EMAIL, OTP);
            Test.stopTest();

            Assert.areEqual(AmazonSesOtpService.Outcome.NOT_SENT, outcome, 'SSO wins: no OTP email');
            Assert.areEqual(0, mock.callCount, 'Amazon SES must not be called');
        }
    }

    @IsTest
    static void usesSalesforceEmailWhenSwitchedOff() {
        System.runAs(apiUser()) {
            AmazonSesOtpService.switchOverride = new CRM_Org_Parameters__c();
            SesMock mock = acceptedMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            AmazonSesOtpService.Outcome outcome = AmazonSesOtpService.sendStudentOtp(DSU_EMAIL, OTP);
            Test.stopTest();

            Assert.areEqual(AmazonSesOtpService.Outcome.USE_SALESFORCE_EMAIL, outcome, 'Both off: original email');
            Assert.areEqual(0, mock.callCount, 'Amazon SES must not be called');
            Assert.areEqual(0, logs().size(), 'Nothing is logged when Amazon SES is off');
        }
    }

    @IsTest
    static void neverSendsAnEmailWithoutTheOtp() {
        System.runAs(apiUser()) {
            useAmazonSes();
            SesMock mock = acceptedMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            AmazonSesOtpService.Outcome blankRecipient = AmazonSesOtpService.sendStudentOtp(' ', OTP);
            AmazonSesOtpService.templateName = TEST_TEMPLATE_NO_OTP;
            AmazonSesOtpService.Outcome badTemplate = AmazonSesOtpService.sendStudentOtp(DSU_EMAIL, OTP);
            Test.stopTest();

            Assert.areEqual(AmazonSesOtpService.Outcome.USE_SALESFORCE_EMAIL, blankRecipient, 'Blank recipient falls back');
            Assert.areEqual(AmazonSesOtpService.Outcome.USE_SALESFORCE_EMAIL, badTemplate, 'Template without OTP falls back');
            Assert.areEqual(0, mock.callCount, 'No email may be sent without the OTP');
        }
    }

    @IsTest
    static void readsTheOrgDefaultSwitch() {
        // Dummy values for the setting's existing required fields (token integration); not used by OTP emails.
        insert new CRM_Org_Parameters__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Name = 'CRM',
            Client_ID__c = 'test-client-id',
            Client_Secret__c = 'test-client-secret',
            Token__c = 'test-token',
            Last_Token_Generated_Date__c = System.now(),
            Use_Amazon_SES__c = true
        );
        System.runAs(apiUser()) {
            AmazonSesOtpService.templateName = TEST_TEMPLATE;
            Test.setMock(HttpCalloutMock.class, acceptedMock());

            Test.startTest();
            AmazonSesOtpService.Outcome outcome = AmazonSesOtpService.sendStudentOtp(DSU_EMAIL, OTP);
            Test.stopTest();

            Assert.areEqual(AmazonSesOtpService.Outcome.SENT_BY_SES, outcome, 'Org default record switches SES on');
        }
    }

    // ------------------------------------------------------------------ student portal (PFS) login journeys

    @IsTest
    static void studentLogsInWithOtpSentByAmazonSes() {
        System.runAs(apiUser()) {
            useAmazonSes();
            SesMock mock = acceptedMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            prepareRequest('/PFSOtp/send', new Map<String, String>{ 'contact' => DSU_EMAIL, 'isNoncontactBased' => 'true' });
            PFSOneTimePasswordServiceRestApi.sendOtp();
            Integer salesforceEmails = Limits.getEmailInvocations();
            Matcher emailedOtp = OTP_IN_EMAIL.matcher(mock.lastBody);
            Assert.isTrue(emailedOtp.find(), 'The SES email must contain the OTP');

            prepareRequest('/PFSOtp/verify', new Map<String, String>{ 'contact' => DSU_EMAIL, 'otpentered' => emailedOtp.group(1) });
            PFSOneTimePasswordServiceRestApi.verifyOtp();
            Test.stopTest();

            Assert.areEqual(1, mock.callCount, 'Exactly one Amazon SES call');
            Assert.areEqual(0, salesforceEmails, 'Salesforce email limit not used');
            Map<String, Object> login = responseBody();
            Assert.areEqual(true, login.get('success'), 'Student logs in with the emailed OTP');
            Assert.isNotNull(login.get('sessionId'), 'Portal session created');
        }
    }

    @IsTest
    static void studentGetsSalesforceEmailWhenSesFails() {
        System.runAs(apiUser()) {
            useAmazonSes();
            Test.setMock(HttpCalloutMock.class, new SesMock(500, 'Internal failure'));
            prepareRequest('/PFSOtp/send', new Map<String, String>{ 'contact' => DSU_EMAIL, 'isNoncontactBased' => 'true' });

            Test.startTest();
            Boolean orgEmailLimitUsedUp = false;
            try {
                PFSOneTimePasswordServiceRestApi.sendOtp();
            } catch (EmailException e) {
                // Production often has no single-email capacity left (the reason for Amazon SES). The failed send
                // still proves the original Salesforce email ran as the fallback.
                Assert.isTrue(e.getMessage().contains('SINGLE_EMAIL_LIMIT_EXCEEDED'), 'Only the org email limit may stop the fallback: ' + e.getMessage());
                orgEmailLimitUsedUp = true;
            }
            Integer salesforceEmails = Limits.getEmailInvocations();
            Test.stopTest();

            if (!orgEmailLimitUsedUp) {
                Assert.areEqual(200, RestContext.response.statusCode, 'OTP request still succeeds');
                Assert.areEqual(1, salesforceEmails, 'Original Salesforce email sent as fallback');
            }
            Assert.areEqual(1, [SELECT COUNT() FROM One_Time_Password__c WITH SYSTEM_MODE], 'OTP saved');
        }
    }

    @IsTest
    static void studentContactBasedOtpIsUnchanged() {
        System.runAs(apiUser()) {
            Test.startTest();
            prepareRequest('/PFSOtp/send', new Map<String, String>{ 'contact' => STUDENT_EMAIL });
            PFSOneTimePasswordServiceRestApi.sendOtp();
            Test.stopTest();

            Assert.areEqual(true, responseBody().get('success'), 'Contact-based OTP request works as before');
            Assert.isNotNull(responseBody().get('OTP'), 'OTP returned in the response as before');
        }
    }

    @IsTest
    static void studentRequestsRejectUnknownOrIncompleteAffiliations() {
        System.runAs(apiUser()) {
            insert new hed__Affiliation__c(DSU_Email__c = 'orphan@dsu.example.com', Is_DSU_Email_Active__c = true);

            Test.startTest();
            prepareRequest('/PFSOtp/send', new Map<String, String>{ 'contact' => UNKNOWN_EMAIL, 'isNoncontactBased' => 'true' });
            PFSOneTimePasswordServiceRestApi.sendOtp();
            String unknownError = String.valueOf(responseBody().get('errorMessage'));
            prepareRequest('/PFSOtp/send', new Map<String, String>{ 'contact' => 'orphan@dsu.example.com', 'isNoncontactBased' => 'true' });
            PFSOneTimePasswordServiceRestApi.sendOtp();
            String orphanError = String.valueOf(responseBody().get('errorMessage'));
            Test.stopTest();

            Assert.isTrue(unknownError.contains('not found'), 'Unknown DSU email rejected');
            Assert.isTrue(orphanError.contains('associated Contact'), 'Affiliation without contact rejected');
        }
    }

    /**
     * @description Documents existing behaviour of the unused legacy method PFSOneTimePasswordServiceRestApi.sendEmail
     *              (its only call is commented out): it has no recipient, so Salesforce rejects it. Left unchanged.
     */
    @IsTest
    static void legacyStudentEmailMethodHasNoRecipient() {
        System.runAs(apiUser()) {
            Contact student = [SELECT Id, Email, Phone FROM Contact WHERE Email = :STUDENT_EMAIL WITH SYSTEM_MODE LIMIT 1];
            Id otpId = PFSOneTimePasswordServiceRestApi.saveOtpInformation(student, OTP);
            Boolean rejected = false;

            Test.startTest();
            try {
                PFSOneTimePasswordServiceRestApi.sendEmail(student, OTP, otpId);
            } catch (EmailException expected) {
                rejected = expected.getMessage().contains('recipient');
            }
            Test.stopTest();

            Assert.isTrue(rejected, 'Legacy method has no recipient');
        }
    }

    // ------------------------------------------------------------------ admin portal (OTP email switched off)

    @IsTest
    static void adminGetsNoEmailButCanStillLogIn() {
        System.runAs(apiUser()) {
            useAmazonSes();
            SesMock mock = acceptedMock();
            Test.setMock(HttpCalloutMock.class, mock);

            Test.startTest();
            prepareRequest('/AdminOtp/send', new Map<String, String>{ 'contact' => ADMIN_EMAIL });
            AdminOneTimePasswordServiceRestApi.sendOtp();
            Integer salesforceEmails = Limits.getEmailInvocations();
            String issuedOtp = String.valueOf(responseBody().get('OTP'));
            prepareRequest('/AdminOtp/verify', new Map<String, String>{ 'contact' => ADMIN_EMAIL, 'otpentered' => issuedOtp });
            AdminOneTimePasswordServiceRestApi.verifyOtp();
            Test.stopTest();

            Assert.areEqual(0, mock.callCount, 'Admin OTP email is off: no Amazon SES call');
            Assert.areEqual(0, salesforceEmails, 'Admin OTP email is off: no Salesforce email');
            Assert.areEqual(true, responseBody().get('success'), 'Admin still logs in with the OTP from the response');
        }
    }

    @IsTest
    static void adminVerifyRejectsWrongOrMissingOtp() {
        System.runAs(apiUser()) {
            Test.startTest();
            prepareRequest('/AdminOtp/send', new Map<String, String>{ 'contact' => ADMIN_EMAIL });
            AdminOneTimePasswordServiceRestApi.sendOtp();
            String issuedOtp = String.valueOf(responseBody().get('OTP'));
            prepareRequest('/AdminOtp/verify', new Map<String, String>{ 'contact' => ADMIN_EMAIL, 'otpentered' => issuedOtp == '1000' ? '1001' : '1000' });
            AdminOneTimePasswordServiceRestApi.verifyOtp();
            String wrongOtpError = String.valueOf(responseBody().get('errorMessage'));
            prepareRequest('/AdminOtp/verify', new Map<String, String>{ 'contact' => UNKNOWN_EMAIL, 'otpentered' => issuedOtp });
            AdminOneTimePasswordServiceRestApi.verifyOtp();
            String missingOtpError = String.valueOf(responseBody().get('errorMessage'));
            Test.stopTest();

            Assert.areEqual('Invalid OTP.', wrongOtpError, 'Wrong OTP rejected');
            Assert.areEqual('OTP expired.', missingOtpError, 'No OTP for unknown contact');
        }
    }

    @IsTest
    static void adminSendRejectsUnknownUser() {
        System.runAs(apiUser()) {
            Test.startTest();
            prepareRequest('/AdminOtp/send', new Map<String, String>{ 'contact' => UNKNOWN_EMAIL });
            AdminOneTimePasswordServiceRestApi.sendOtp();
            Test.stopTest();

            Assert.areEqual(400, RestContext.response.statusCode, 'Unknown admin gets HTTP 400');
            Assert.areEqual('User not found', responseBody().get('errorMessage'), 'Error message unchanged');
        }
    }

    @IsTest
    static void adminLegacyEmailMethodHandlesIncompleteContacts() {
        System.runAs(apiUser()) {
            Contact admin = [SELECT Id FROM Contact WHERE Email = :ADMIN_EMAIL WITH SYSTEM_MODE LIMIT 1];

            Test.startTest();
            AdminOneTimePasswordServiceRestApi.sendEmail(new Contact(LastName = 'No Id'), OTP, null);
            AdminOneTimePasswordServiceRestApi.sendEmail(new Contact(Id = admin.Id), OTP, null);
            Integer salesforceEmails = Limits.getEmailInvocations();
            Test.stopTest();

            Assert.areEqual(0, salesforceEmails, 'No email for incomplete contacts');
        }
    }

    // ------------------------------------------------------------------ Amazon SES mock

    /**
     * @description Mock for an accepted email: HTTP 200 with a MessageId, like real Amazon SES.
     * @return Mock that accepts the email.
     */
    private static SesMock acceptedMock() {
        return new SesMock(200, '{"MessageId":"' + MESSAGE_ID + '"}');
    }

    /**
     * @description Mock for a callout that times out.
     * @return Mock that throws a CalloutException.
     */
    private static SesMock timingOutMock() {
        SesMock mock = new SesMock(0, null);
        mock.failure = 'Read timed out';
        return mock;
    }

    /**
     * @description Answers the Amazon SES callout in tests and records what was sent.
     */
    private class SesMock implements HttpCalloutMock {
        private final Integer statusCode;
        private final String body;
        public String failure;
        public Integer callCount = 0;
        public String lastBody;

        SesMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        /**
         * @description Records the request and returns the configured response (or throws the configured failure).
         * @param request Outgoing Amazon SES request.
         * @return Mocked response.
         */
        public HttpResponse respond(HttpRequest request) {
            this.callCount++;
            this.lastBody = request.getBody();
            if (this.failure != null) {
                throw new CalloutException(this.failure);
            }
            HttpResponse response = new HttpResponse();
            response.setStatusCode(this.statusCode);
            response.setBody(this.body);
            return response;
        }
    }
}