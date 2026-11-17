@IsTest
private class CourseConnectionRestAPITest {

    @TestSetup
    static void setupData() {

        //
        // 1. Required: Academic Department
        //
        Account dept = new Account(Name = 'Dept');
        insert dept;
        
         Academic_Term__c acTerm = new Academic_Term__c(
            Name = 'Fall 2024'
        );
        insert acTerm;

        //
        // 2. EDA Term (hed__Term__c)
        //
        hed__Term__c term = new hed__Term__c(
            Name = 'Term A',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'REF1'
        );
        insert term;

        //
        // 3. Contact
        //
        Contact con = new Contact(LastName = 'Student');
        insert con;

        //
        // 4. Program Enrollment (hed__Program_Enrollment__c)
        //
        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = con.Id,
            Term__c = term.Id
        );
        insert pe;

        //
        // 5. Course
        //
        hed__Course__c course = new hed__Course__c(
            Name = 'Math101',
            hed__Course_ID__c = 'M101',
            hed__Account__c = dept.Id,
            Credits__c = 3
        );
        insert course;

        //
        // 6. Course Enrollment Management (optional)
        //
        Course_Enrollment_Management__c cem = new Course_Enrollment_Management__c(
            Academic_Term__c = acTerm.Id
        );
        insert cem;

        //
        // 7. Course Offering (required)
        //
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Math101 - A',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            Academic_Term__c = acTerm.Id
        );
        insert offering;

        //
        // 8. Custom Course_Enrollment__c parent record
        //
        Course_Enrollment__c ceParent = new Course_Enrollment__c(
            Name = 'ParentCE'
        );
        insert ceParent;
    }


    // =========================================================================
    // TEST 1: Invalid Payload (missing fields)
    // =========================================================================
    @IsTest
    static void testInvalidPayload() {

        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/courseconnections';
        req.requestBody = Blob.valueOf('{}'); // invalid (missing required)

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        CourseConnectionRestAPI.doPost();
        Test.stopTest();
    }


    // =========================================================================
    // TEST 2: Valid Payload (happy path)
    // =========================================================================
    @IsTest
    static void testValidPayload() {

        Contact con = [SELECT Id FROM Contact LIMIT 1];
        hed__Program_Enrollment__c pe = [SELECT Id FROM hed__Program_Enrollment__c LIMIT 1];
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        Course_Enrollment__c ceParent = [SELECT Id FROM Course_Enrollment__c LIMIT 1];
        Course_Enrollment_Management__c cem = [SELECT Id FROM Course_Enrollment_Management__c LIMIT 1];

        // Build JSON payload for POST
        String jsonBody = JSON.serialize(new Map<String, Object>{
            'ProgramEnrollmentId' => pe.Id,
            'ContactId'           => con.Id,
            'connections'         => new List<Object>{
                new Map<String, Object>{
                    'CourseEnrollmentId'          => ceParent.Id,
                    'CourseOfferingId'            => offering.Id,
                    'CourseEnrollmentManagementId'=> cem.Id,
                    'creditsAttempted'            => 3
                }
            }
        });

        // Configure REST request
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/courseconnections';
        req.requestBody = Blob.valueOf(jsonBody);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        CourseConnectionRestAPI.doPost();
        Test.stopTest();
    }
}