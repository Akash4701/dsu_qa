@isTest
private class RestApi_studentListByCourseOfferingTest {

    @isTest
        static void testValidCourseOfferingId() {
            LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
            Test.setMock(HttpCalloutMock.class, new SessionMockCallout());

            Test.startTest();
        
            // Create Institution
            Account institution = new Account(Name = 'Test Institution');
            insert institution;
        
            // Create Department
            Account department = new Account(Name = 'Test Department', ParentId = institution.Id);
            insert department;
        
            // Create Course
            hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = department.Id);
            insert course;
        
            // Create Term
            hed__Term__c term = new hed__Term__c(Name = 'Test Term', hed__Account__c = institution.id, Term_Reference__c='Semester 1');
            insert term;
        
            // Create Course Offering
            hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
                Name = 'Test Course Offering',
                hed__Course__c = course.Id,
                hed__Term__c = term.Id
            );
            insert courseOffering;
        
            // Create Student Contact
            Contact student = new Contact(FirstName = 'Test', LastName = 'Student', Email = 'test@student.com', Registration_Number__c = 'STU123');
            insert student;
        
            // Get Student RecordType ID
            Id studentRTId = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Course_Enrollment__c' AND Name = 'Student' LIMIT 1].Id;
            
            // Create Course Enrollment (Ensuring it appears in courseConnectionList)
            hed__Course_Enrollment__c enrollment = new hed__Course_Enrollment__c(
                hed__Contact__c = student.Id,
                hed__Course_Offering__c = courseOffering.Id,
                Enrollment_Status__c = 'Enrolled',
                RecordTypeId = studentRTId,
                No_Of_Classes_Attended__c = 10
            );
            insert enrollment;
        
            // Mock Request
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/studentsByCourseOffering';
            req.httpMethod = 'GET';
            req.addParameter('CourseOfferingId', courseOffering.Id);
        
            RestContext.request = req;
            RestContext.response = res;
        
            // Call API
            RestApi_studentListByCourseOffering.doGet();
        
            // Validate Response
            String responseBody = res.responseBody.toString();
            System.assert(responseBody.contains('"success": "true"'), 'API response should indicate success');
            System.assert(responseBody.contains('Test Student'), 'Student name should be in the response');
            System.assert(responseBody.contains('STU123'), 'Registration number should be in the response');
        
            Test.stopTest();
        }

    
    
        @isTest
        static void testExceptionHandling() {
            LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/studentsByCourseOffering';
            req.httpMethod = 'GET';
    
            RestContext.request = req;
            RestContext.response = res;
    
            RestApi_studentListByCourseOffering.doGet();
    
            String responseBody = res.responseBody.toString();
        }
    
        private static String createTestData() {
            hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(Name = 'Test Course Offering');
            insert courseOffering;
    
            Contact contact = new Contact(LastName = 'Doe', Email = 'test@example.com', Registration_Number__c = 'REG123');
            insert contact;
    
            RecordType studentRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Course_Enrollment__c' AND Name = 'Student' LIMIT 1];
            hed__Course_Enrollment__c courseEnrollment = new hed__Course_Enrollment__c(
                hed__Contact__c = contact.Id,
                hed__Course_Offering__c = courseOffering.Id,
                hed__Status__c = 'Current',
                RecordTypeId = studentRecordType.Id,
                No_Of_Classes_Attended__c = 10
            );
            insert courseEnrollment;
    
            return courseOffering.Id;
        }
        @isTest
        static void testValidCourseOfferingIdd() {
            LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
            Test.setMock(HttpCalloutMock.class, new SessionMockCallout());

            Test.startTest();
        
            // Create required data
            Account institution = new Account(Name = 'Test Institution');
            insert institution;
        
            Account department = new Account(Name = 'Test Department', ParentId = institution.Id);
            insert department;
        
            hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = department.Id);
            insert course;
        
            hed__Term__c term = new hed__Term__c(Name = 'Test Term',hed__Account__c = institution.id,Term_Reference__c='Semester 1');
            insert term;
        
            hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
                Name = 'Test Course Offering',
                hed__Course__c = course.Id,
                hed__Term__c = term.Id
            );
            insert courseOffering;
        
            Contact student = new Contact(FirstName = 'Test', LastName = 'Student', Email = 'test@student.com');
            insert student;
        
            Id studentRTId = [SELECT Id FROM RecordType WHERE Name = 'Student' LIMIT 1].Id;
        
            hed__Course_Enrollment__c enrollment = new hed__Course_Enrollment__c(
                hed__Contact__c = student.Id,
                hed__Course_Offering__c = courseOffering.Id,
                Enrollment_Status__c = 'Enrolled'
                //RecordTypeId = 'Faculty'
            );
            insert enrollment;
        
            // Mock Request
            RestRequest req = new RestRequest();
            RestResponse res = new RestResponse();
            req.requestURI = '/services/apexrest/studentsByCourseOffering';
            req.httpMethod = 'GET';
            req.addParameter('CourseOfferingId', courseOffering.Id);
        
            RestContext.request = req;
            RestContext.response = res;
        
            // Call API
            RestApi_studentListByCourseOffering.doGet();
        
            // Validate Response
            String responseBody = res.responseBody.toString();
            
        
            Test.stopTest();
    }

}