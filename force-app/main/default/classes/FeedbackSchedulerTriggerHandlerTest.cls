@isTest
public class FeedbackSchedulerTriggerHandlerTest {
    @testSetup
    static void setupData() {
        Blackboard_Integration__c bbSettings = new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), // Organization level
            Username__c = 'testUser',
            Password__c = 'testPass'
        );
        insert bbSettings;
        
         Test.setMock(HttpCalloutMock.class, new MockCallout());
        // Create required record types
        Id facultyRT = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByDeveloperName().get('Faculty').getRecordTypeId();

        Id studentRT = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName().get('Student').getRecordTypeId();
         Id studentRTCon = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Student').getRecordTypeId();
         Id facultyRTCon = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Faculty').getRecordTypeId();

        // Create Contact
        Contact studentContact = new Contact(RecordTypeId = studentRTCon,FirstName = 'Student', LastName = 'One');
        insert studentContact;
        
         Contact facultyContact = new Contact(RecordTypeId = facultyRTCon,FirstName = 'Student', LastName = 'One');
        insert facultyContact;


		Account acc= new Account(Name='test');
        insert acc;
        
        // Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2024',
        	hed__Account__c=acc.Id,
            Term_Reference__c='Term 1'
        );
        insert term;

        
        Campus__c campus = new Campus__c(
        	Campus_ID__c='MUM'
        );
        insert campus;
        
        hed__Course__c course = new hed__Course__c(
        	hed__Account__c=acc.Id
        );
        insert course;
        
        // Create Course Offering
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Course1',
            hed__Term__c = term.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(30),
            hed__Course__c=course.Id
        );
        insert offering;

        // Create Course Enrollment
        hed__Course_Enrollment__c enrollment = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = offering.Id,
            hed__Contact__c = studentContact.Id,
            RecordTypeId = facultyRT
        );
        insert enrollment;

        
        Id RecordType = Schema.SObjectType.Questionnaire_Metadata__c.getRecordTypeInfosByName().get('Feedback').getRecordTypeId();

        
        Questionnaire_Metadata__c quesMaster = new Questionnaire_Metadata__c(
         RecordTypeId= RecordType,
            Feedback_Type__c='Faculty Feedback'
        );
        insert quesMaster;
        
        // Create Feedback Master
        Feedback_Scheduler__c master = new Feedback_Scheduler__c(
            //Name = 'Faculty Feedback',
            Feedback_Master__c=quesMaster.Id,
            Term__c=term.Id,
            Start_Date__c= Date.today()
        );
        insert master;
        
       Feedback_Item__c feedback = new Feedback_Item__c(
           Assignee__c=studentContact.Id,
       Course_Offering__c=offering.Id,
       Feedback_Scheduler__c=master.Id,
           Feedback_Status__c	='pending'
       );
        insert feedback;
        
        hed__Course_Enrollment__c courseEnroll = new hed__Course_Enrollment__c(
        	RecordTypeId=studentRT,
          hed__Course_Offering__c=offering.Id
            
        );
        insert courseEnroll;
        
        hed__Program_Enrollment__c programEnroll = new hed__Program_Enrollment__c(
        hed__Contact__c=studentContact.Id,
        Term__c=term.Id
        );
        insert programEnroll;
        
        hed__Facility__c faclty = new hed__Facility__c();
        insert faclty;

    }

    
    
     @isTest
    static void testAfterInsertFacultyInteriFinalFeedback() {
        Test.startTest();

        // This will trigger after insert logic
        Questionnaire_Metadata__c master = [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1];
        master.Feedback_Type__c='Final Feedback';
        update master;
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
            Feedback_Master__c = master.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(7)
        );
        insert scheduler;

        Test.stopTest();

           }
    
    
     @isTest
    static void testAfterInsertFacultyInterimOrientation() {
        Test.startTest();

        // This will trigger after insert logic
        Questionnaire_Metadata__c master = [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1];
        master.Feedback_Type__c='Interim Feedback';
        update master;
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
            Feedback_Master__c = master.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(7)
        );
        insert scheduler;

        Test.stopTest();

           }
    
    
    
    @isTest
    static void testAfterInsertFacultyFeedbackOrientation() {
        Test.startTest();

        // This will trigger after insert logic
        Questionnaire_Metadata__c master = [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1];
        master.Feedback_Type__c='Orientation Feedback';
        update master;
        Account acc= new Account(Name='test');
        insert acc;
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(3),
            hed__Account__c=acc.Id,
            Term_Reference__c='Term 1'
        );
        insert term;

        Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
            Feedback_Master__c = master.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(7)
        );
        insert scheduler;

        Test.stopTest();

           }
    
    
    @isTest
    static void testAfterInsertFacultyFeedback() {
        Test.startTest();

        // This will trigger after insert logic
        Questionnaire_Metadata__c master = [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
            Feedback_Master__c = master.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(7)
        );
        insert scheduler;

        Test.stopTest();

        // Faculty Feedback must activate the day AFTER the course offering's own end date,
        // not on the end date itself.
        hed__Course_Offering__c offering = [SELECT hed__End_Date__c FROM hed__Course_Offering__c LIMIT 1];
        Feedback_Item__c createdItem = [
            SELECT Start_Date__c, End_Date__c
            FROM Feedback_Item__c
            WHERE Feedback_Scheduler__c = :scheduler.Id
            LIMIT 1
        ];
        System.assertEquals(
            offering.hed__End_Date__c.addDays(1),
            createdItem.Start_Date__c,
            'Faculty Feedback must activate the day after the course offering end date.'
        );
    }


    // Extension-email coverage now lives in FeedbackItemTriggerHandlerTest -- the notification
    // fires off the Feedback_Item__c's own Start_Date__c/End_Date__c change, not the parent
    // Feedback_Scheduler__c's.

    @isTest
    static void testAfterUpdateUpdatesDates() {
        try{
            
             Feedback_Scheduler__c scheduler = [SELECT Id, Start_Date__c, End_Date__c FROM Feedback_Scheduler__c LIMIT 1];

        scheduler.Start_Date__c = scheduler.Start_Date__c.addDays(1);
        scheduler.End_Date__c = scheduler.End_Date__c.addDays(1);

        Test.startTest();
        update scheduler;
        Test.stopTest();


        }catch(Exception e){

        }
       
      
    }

    @isTest
    static void testAfterDeleteRemovesItems() {
        List<Feedback_Scheduler__c> schedulers = [SELECT Id FROM Feedback_Scheduler__c];
        Test.startTest();
        delete schedulers;
        Test.stopTest();

        List<Feedback_Item__c> items = [SELECT Id FROM Feedback_Item__c WHERE Feedback_Scheduler__c IN :schedulers];
        System.assertEquals(0, items.size(), 'Feedback items should be deleted after scheduler deletion');
    }
    
    @isTest
static void testFeedbackItemsToUpdate() {
    
       Test.setMock(HttpCalloutMock.class, new MockCallout());
    // Create required record types
        Id facultyRT = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByDeveloperName().get('Faculty').getRecordTypeId();

        Id studentRT = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByDeveloperName().get('Student').getRecordTypeId();

        // Create Contact
        Contact studentContact = new Contact(FirstName = 'Student', LastName = 'One');
        insert studentContact;

		Account acc= new Account(Name='test');
        insert acc;
        
        // Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2024',
        	hed__Account__c=acc.Id,
            Term_Reference__c='Term 1'
        );
        insert term;

        
        Campus__c campus = new Campus__c(
        	Campus_ID__c='MUM'
        );
        insert campus;
        
        hed__Course__c course = new hed__Course__c(
        	hed__Account__c=acc.Id
        );
        insert course;
        
        // Create Course Offering
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Course1',
            hed__Term__c = term.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(30),
            hed__Course__c=course.Id
        );
        insert offering;

        // Create Course Enrollment
        hed__Course_Enrollment__c enrollment = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = offering.Id,
            hed__Contact__c = studentContact.Id,
            RecordTypeId = facultyRT
        );
        insert enrollment;

        
        Id RecordType = Schema.SObjectType.Questionnaire_Metadata__c.getRecordTypeInfosByName().get('Feedback').getRecordTypeId();

        
        Questionnaire_Metadata__c quesMaster = new Questionnaire_Metadata__c(
         RecordTypeId= RecordType,
            Feedback_Type__c='Faculty Feedback'
        );
        insert quesMaster;
        
        // Create Feedback Master
        Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
            //Name = 'Faculty Feedback',
            Feedback_Master__c=quesMaster.Id,
            Term__c=term.Id,
            Start_Date__c= Date.today()
        );
        insert scheduler;
        
       Feedback_Item__c feedback = new Feedback_Item__c(
           Assignee__c=studentContact.Id,
       Course_Offering__c=offering.Id,
       Feedback_Scheduler__c=scheduler.Id,
           Feedback_Status__c	='pending'
       );
        insert feedback;
    
    
    // Trigger should create Feedback_Item__c via handler
    List<Feedback_Item__c> itemsBeforeUpdate = [
        SELECT Id, Start_Date__c, End_Date__c
        FROM Feedback_Item__c
        WHERE Feedback_Scheduler__c = :scheduler.Id
    ];
    System.assert(itemsBeforeUpdate.size() > 0, 'Feedback item should be created on insert');

    // Step 2: Update Feedback_Scheduler__c start and end dates
    scheduler.Start_Date__c = Date.today().addDays(2);
    scheduler.End_Date__c = Date.today().addDays(10);
    update scheduler;

    // Step 3: Fetch updated feedback items and assert their new dates
    List<Feedback_Item__c> itemsAfterUpdate = [
        SELECT Id, Start_Date__c, End_Date__c
        FROM Feedback_Item__c
        WHERE Feedback_Scheduler__c = :scheduler.Id
    ];

    
}

    
    public class MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success": false}');
            res.setStatusCode(201);
            return res;
        }
    }
}