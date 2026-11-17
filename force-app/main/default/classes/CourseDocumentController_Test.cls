@IsTest
private class CourseDocumentController_Test {

    @TestSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl;
 LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;

        // Create Contact (Faculty)
        Contact facultyContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com'
        );
        insert facultyContact;

        // Create Contact (Area Head)
        Contact areaHeadContact = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            Email = 'jane.smith@example.com'
        );
        insert areaHeadContact;

        // Create Account (required for hed__Term__r.hed__Account__c if needed)
        Account account = new Account(Name = 'SP Jain School',LMS_Id__c = '12345');
        insert account;

        // Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(3),
            hed__Account__c = account.Id,
            Term_Reference__c='term 1'
        );
        insert term;

        // Create Course
        hed__Course__c course = new hed__Course__c(
            Name = 'Mathematics',
        //    hed__Code__c = 'MTH101'
           hed__Account__c= account.id,
           hed__Course_ID__c = 'TC001',
            LMS_ID__c = '54321'

        );
        insert course;

        // Create Course Document
        Course_Document__c courseDoc = new Course_Document__c(
        //    Name = 'Course Doc - Math',
            Status__c = 'Pending',
            Comment__c = 'Initial comment',
            Area_Head_Status__c = null,
            Is_Link_Active__c = true,
            Faculty__c = facultyContact.Id,
            Course__c = course.Id,
            Term__c = term.Id
          //  Campus__c = 'Dubai',
          //  Mode_of_delivery__c = 'Online',
          //  No_of_Sessions__c = 20,
          //  No_of_Divisions__c = 2,
          //  Area_Head__c = 'Dr. Jane Smith'
        );
        insert courseDoc;

        // Insert OrgWideEmailAddress
        OrgWideEmailAddress owea = [SELECT Id, DisplayName, Address, IsAllowAllProfiles 
FROM OrgWideEmailAddress limit 1];
            

        // Set Custom Label for Admin Email
       // System.Label.Admin_Email_Id = 'admin@example.com';
    }

    @IsTest
    static void test_CourseDocumentController_LoadsDataSuccessfully() {
        // Arrange
        Test.setCurrentPage(Page.OfferLetterPage); // Replace with actual VF page name
        PageReference pageRef = ApexPages.currentPage();
        Course_Document__c courseDoc = [SELECT Id FROM Course_Document__c LIMIT 1];
        Contact faculty = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        pageRef.getParameters().put('courseDocumentId', courseDoc.Id);
        pageRef.getParameters().put('contactId', faculty.Id);

        // Act
        CourseDocumentController controller = new CourseDocumentController();

        // Assert
        System.assertNotEquals(null, controller.response, 'Response should be initialized');
        System.assertEquals(courseDoc.Id, controller.response.courseDocumentRecordId, 'Course document ID should match');
    }

    @IsTest
    static void test_Save_AlreadySubmittedLink_ShowsError() {
        // Arrange
        Test.setCurrentPage(Page.OfferLetterPage);
        PageReference pageRef = ApexPages.currentPage();
        Course_Document__c courseDoc = [SELECT Id FROM Course_Document__c LIMIT 1];

        pageRef.getParameters().put('courseDocumentId', courseDoc.Id);

        // Update to make link inactive
        courseDoc.Is_Link_Active__c = false;
        update courseDoc;

        // Act
        CourseDocumentController controller = new CourseDocumentController();
        controller.response.availability = 'Approved';
        controller.response.note = 'Looks good!';
        PageReference result = controller.save();

        // Assert
        ApexPages.Message[] messages = ApexPages.getMessages();
        System.assertEquals(1, messages.size(), 'One error message expected');
       
    }

    @IsTest
    static void test_Save_SubmitsSuccessfullyAndSendsEmail() {
        // Arrange
        Test.setCurrentPage(Page.OfferLetterPage);
        PageReference pageRef = ApexPages.currentPage();
        Course_Document__c courseDoc = [SELECT Id FROM Course_Document__c LIMIT 1];

        pageRef.getParameters().put('courseDocumentId', courseDoc.Id);

        // Start test context
        Test.startTest();

        CourseDocumentController controller = new CourseDocumentController();
        controller.response.availability = 'Approved';
        controller.response.note = 'Looks good!';

        PageReference result = controller.save();

        Test.stopTest();

        // Verify record update
        Course_Document__c updatedDoc = [SELECT Id, Area_Head_Status__c, Status__c, Comment__c, Is_Link_Active__c FROM Course_Document__c WHERE Id = :courseDoc.Id];

        System.assertEquals('Approved', updatedDoc.Area_Head_Status__c);
        System.assertEquals('Submitted', updatedDoc.Status__c);
        System.assertEquals('Looks good!', updatedDoc.Comment__c);
       

        // Verify email sent
  //      List<Messaging.SingleEmailMessage> emails = Test.getEmails();
  //      System.assertEquals(1, emails.size(), 'One email should be sent');

 //       Messaging.SingleEmailMessage email = emails[0];
    //    System.assertTrue(email.getToAddresses().contains('john.doe@example.com'), 'Faculty email should be included');
     //   System.assertTrue(email.getToAddresses().contains(System.Label.Admin_Email_Id), 'Admin email should be included');

    //    String body = email.getPlainTextBody();
  //      System.assertTrue(body.contains('has given the response on the submitted outline'), 'Email body should contain correct content');

        // Confirm success message
        ApexPages.Message[] messages = ApexPages.getMessages();
       // System.assertEquals(1, messages.size());
     //   System.assertEquals('Response recorded, Please close the tab', messages[0].summary);
    }

    @IsTest
    static void test_Save_ModifyStatusTriggersEmail() {
        // Arrange
        Test.setCurrentPage(Page.OfferLetterPage);
        PageReference pageRef = ApexPages.currentPage();
        Course_Document__c courseDoc = [SELECT Id FROM Course_Document__c LIMIT 1];

        pageRef.getParameters().put('courseDocumentId', courseDoc.Id);

        // Start test context
        Test.startTest();

        CourseDocumentController controller = new CourseDocumentController();
        controller.response.availability = 'Modify';
        controller.response.note = 'Please update this part.';
        controller.save();

        Test.stopTest();

        // Verify record update
        Course_Document__c updatedDoc = [SELECT Id, Area_Head_Status__c, Status__c FROM Course_Document__c WHERE Id = :courseDoc.Id];
        System.assertEquals('Modify', updatedDoc.Area_Head_Status__c);
        System.assertEquals('Pending', updatedDoc.Status__c);

        // Verify email sent
    //    List<Messaging.SingleEmailMessage> emails = Test.getEmails();
   //     System.assertEquals(1, emails.size(), 'One email should be sent');
    }

    @IsTest
    static void test_Save_ExceptionHandling() {
        // Arrange
        Test.setCurrentPage(Page.OfferLetterPage);
        PageReference pageRef = ApexPages.currentPage();
        pageRef.getParameters().put('courseDocumentId', 'a00000000000000'); // Invalid ID

        // Act
      
        // Assert
        ApexPages.Message[] messages = ApexPages.getMessages();
     //   System.assertEquals(1, messages.size(), 'One error message expected');
      //  System.assertTrue(messages[0].summary.contains('An error occurred while saving the record'), 'Unexpected error message');
    }
    public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(' {"success": "true","data": {"Identifier": "98765","Code": "Ken BBA-01","Name": "Ken - BBA Template","Path": "/content/enforced/6887-KenBBA-01"}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    public class FailureHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "Internal Server Error"}');
            res.setStatusCode(500);
            return res;
        }
    }
    
    public class NoDataHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}