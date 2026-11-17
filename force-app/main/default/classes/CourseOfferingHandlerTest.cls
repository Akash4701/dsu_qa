@isTest
public class CourseOfferingHandlerTest {
    
    @testSetup
    static void setupData() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        
        hed__Course__c testCourse = new hed__Course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'TC001',
            hed__Account__c = testAccount.Id,
            LMS_ID__c = '54321'
        );
        insert testCourse;
        
        hed__Term__c testTerm = new hed__Term__c(
             Name = 'testTerm',
             hed__Account__c = testAccount.id,
             Term_Reference__c = 'Term 1'
            
             
             );
        insert testTerm;
        
        hed__Course_Offering__c testOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = testCourse.Id,
            hed__Term__c = testTerm.id
        );
        insert testOffering;
    }
    
    @isTest
    static void testSendCourseOfferingsSuccess() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        List<Id> offeringIds = new List<Id>();
        for (hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        CourseOfferingHandler.sendCourseOfferings(OfferingIds);
        Test.stopTest();
        
        hed__Course_Offering__c updatedOffering = [SELECT Id, LMS_Id__c FROM hed__Course_Offering__c WHERE Id = :offerings[0].Id];
        System.assertEquals('98765', updatedOffering.LMS_Id__c);
    }
    
    @isTest
    static void testSendCourseOfferingsSuccess1() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        List<Id> offeringIds = new List<Id>();
        for (hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        Test.startTest();
        //CourseOfferingHandler.createEvaluationPlan();
        Test.stopTest();
    }
    
    @isTest
    static void testSendCourseOfferingsFailure() {
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        List<Id> offeringIds = new List<Id>();
        for (hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        System.enqueueJob(new CourseOfferingCalloutQueueable(offeringIds));
        Test.stopTest();
        
        hed__Course_Offering__c updatedOffering = [SELECT Id, LMS_Id__c FROM hed__Course_Offering__c WHERE Id = :offerings[0].Id];
        System.assertEquals(null, updatedOffering.LMS_Id__c);
    }
    
    @isTest
    static void testSendCourseOfferingsNoDataInResponse() {
        Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        List<Id> offeringIds = new List<Id>();
        for (hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        System.enqueueJob(new CourseOfferingCalloutQueueable(offeringIds));
        Test.stopTest();
        
        hed__Course_Offering__c updatedOffering = [SELECT Id, LMS_Id__c FROM hed__Course_Offering__c WHERE Id = :offerings[0].Id];
        System.assertEquals(null, updatedOffering.LMS_Id__c);
    }
    
    @isTest
    static void testSendCourseOfferingsExistingLmsId() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        offerings[0].LMS_Id__c = '98765';
        update offerings[0];
        
        List<Id> offeringIds = new List<Id>();
        for (hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        System.enqueueJob(new CourseOfferingCalloutQueueable(offeringIds));
        Test.stopTest();
        
        hed__Course_Offering__c updatedOffering = [SELECT Id, LMS_Id__c FROM hed__Course_Offering__c WHERE Id = :offerings[0].Id];
        System.assertEquals('98765', updatedOffering.LMS_Id__c);
    }
    
    public class CourseOfferingCalloutQueueable implements Queueable, Database.AllowsCallouts {
        private List<Id> offeringIds;
        
        public CourseOfferingCalloutQueueable(List<Id> offeringIds) {
            this.offeringIds = offeringIds;
        }
        
        public void execute(QueueableContext context) {
            CourseOfferingHandler.sendCourseOfferings(offeringIds);
        }
    }
    
    public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":"true","data":{"Identifier":"98765","Name":"Ken sample course","Code":"KEN-sample-01","IsActive":true,"CanSelfRegister":false,"Description":{"Text":"This is a new Course Offering","Html":""},"Path":"/content/enforced/6889-KEN-sample-01/","StartDate":null,"EndDate":null,"CourseTemplate":{"Identifier":"6887","Name":"Ken - BBA Template","Code":"Ken BBA-01"},"Semester":null,"Department":null}}');
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
    
   /* @isTest
static void testCreateEvaluationPlan() {
    // Get the existing test data
    hed__Course__c testCourse = [SELECT Id FROM hed__Course__c LIMIT 1];
    hed__Term__c testTerm = [SELECT Id FROM hed__Term__c LIMIT 1];
    
    // Create Evaluation Component Master records
    List<Evaluation_Component_Master__c> masterComponents = new List<Evaluation_Component_Master__c>();
    
    Evaluation_Component_Master__c masterComp1 = new Evaluation_Component_Master__c(
        Course__c = testCourse.Id,
        Component_Name__c = 'Midterm Exam',
        Weightage__c = 30,
        Maximum_Marks__c = 100,
        Exam_Required__c = true
    );
    masterComponents.add(masterComp1);
    
    Evaluation_Component_Master__c masterComp2 = new Evaluation_Component_Master__c(
        Course__c = testCourse.Id,
        Component_Name__c = 'Final Exam',
        Weightage__c = 50,
        Maximum_Marks__c = 100,
        Exam_Required__c = true
    );
    masterComponents.add(masterComp2);
    
    Evaluation_Component_Master__c masterComp3 = new Evaluation_Component_Master__c(
        Course__c = testCourse.Id,
        Component_Name__c = 'Assignment',
        Weightage__c = 20,
        Maximum_Marks__c = 50,
        Exam_Required__c = false
    );
    masterComponents.add(masterComp3);
    
    insert masterComponents;
    
    // Create a new Course Offering to trigger the evaluation plan creation
    hed__Course_Offering__c newOffering = new hed__Course_Offering__c(
        Name = 'Test Course Offering 2',
        hed__Course__c = testCourse.Id,
        hed__Term__c = testTerm.Id
    );
    
    Test.startTest();
    
    // Simulate trigger context by setting up trigger.new
    List<hed__Course_Offering__c> triggerNew = new List<hed__Course_Offering__c>{newOffering};
    
    // Insert the course offering which should trigger evaluation plan creation
    insert newOffering;
    
    // Manually call the method since we can't easily simulate trigger context in test
    // We'll need to modify the method call to work with our test data
    CourseOfferingHandler.createEvaluationPlan();
    
    Test.stopTest();
    
    // Query the created Course Evaluation Component records
    List<Course_Evaluation_Component__c> createdComponents = [
        SELECT Id, Name, Weightage__c, Maximum_Marks_for_the_Component__c, Exam_Required__c, Course_Offering__c
        FROM Course_Evaluation_Component__c 
        WHERE Course_Offering__c = :newOffering.Id
    ];
}*/
}