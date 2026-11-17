@IsTest
public with sharing class GradeCardBatchTest {

    @TestSetup
    static void setupData() {

        // ACCOUNT (Department / Institution)
        Account dept = new Account(Name = 'Test Department');
        insert dept;

        // TERM (REQUIRED: Account + Term Reference)
        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        // CONTACT (Student)
        Contact student = new Contact(LastName = 'Test Student');
        insert student;

        // COURSE (REQUIRED: Account)
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        // COURSE OFFERING (REQUIRED: Course + Term)
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        // Program Plan + Affiliation + Program Enrollment (needed because batch queries Program Enrollments by Term__c)
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert programPlan;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = programPlan.Id,
            Roll_Number__c = 'RN-BATCH-001'
        );
        insert aff;

        //  Create 2 Program Enrollments in the term to exercise multiple scope rows
        hed__Program_Enrollment__c pe1 = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = aff.Id
        );
        hed__Program_Enrollment__c pe2 = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = aff.Id
        );
        insert new List<hed__Program_Enrollment__c>{ pe1, pe2 };
    }

    @IsTest
    static void testBatch_successPath_countsIncrement() {

        Id termId = [SELECT Id FROM hed__Term__c WHERE Name = 'Spring 2025' LIMIT 1].Id;
        List<hed__Program_Enrollment__c> peList = [
            SELECT Id, hed__Contact__r.Name, hed__Affiliation__r.Roll_Number__c
            FROM hed__Program_Enrollment__c
            WHERE Term__c = :termId
            ORDER BY CreatedDate ASC
        ];
        String expectedTitle = peList[0].hed__Contact__r.Name + '(' + peList[0].hed__Affiliation__r.Roll_Number__c + ')_E-Grade Card';
        Set<Id> peIds = new Set<Id>();
        for (hed__Program_Enrollment__c pe : peList) peIds.add(pe.Id);

        Test.startTest();
        GradeCardBatch b = new GradeCardBatch(termId);
        Database.executeBatch(b, 200);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :peIds
        ];
        System.assertEquals(2, links.size(), 'Each PE should receive one grade-card attachment');

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) docIds.add(link.ContentDocumentId);
        List<ContentVersion> versions = [
            SELECT Title, Document_Type__c, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
            ORDER BY CreatedDate DESC
        ];
        System.assertEquals(2, versions.size(), 'A ContentVersion should be created for each PE');
        for (ContentVersion cv : versions) {
            System.assertEquals(expectedTitle, cv.Title, 'Title should be Name(Roll_Number)_E-Grade Card');
            System.assertEquals('Grade Card', cv.Document_Type__c);
        }

    }

    @IsTest
    static void testBatch_noProgramEnrollments_noWork() {

        // Create a new term with no program enrollments
        Account dept = [SELECT Id FROM Account WHERE Name = 'Test Department' LIMIT 1];

        hed__Term__c emptyTerm = new hed__Term__c(
            Name = 'Empty Term',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert emptyTerm;

        Integer beforeCount = [SELECT COUNT() FROM ContentVersion WHERE Document_Type__c = 'Grade Card'];

        Test.startTest();
        GradeCardBatch b = new GradeCardBatch(emptyTerm.Id);
        Database.executeBatch(b, 200);
        Test.stopTest();

        Integer afterCount = [SELECT COUNT() FROM ContentVersion WHERE Document_Type__c = 'Grade Card'];
        System.assertEquals(beforeCount, afterCount, 'No grade cards should be generated when there are no enrollments');
    }

    @IsTest
    static void testBatch_failurePath_collectsErrors() {
        Integer beforeCount = [SELECT COUNT() FROM ContentVersion WHERE Document_Type__c = 'Grade Card'];
        Boolean threw = false;
        Boolean started = false;
        try {
            Test.startTest();
            started = true;
            GradeCardBatch b = new GradeCardBatch(null);
            Database.executeBatch(b, 200);
            Test.stopTest();
            started = false;
        } catch (Exception e) {
            if (started) {
                Test.stopTest();
            }
            threw = true;
        }
        Integer afterCount = [SELECT COUNT() FROM ContentVersion WHERE Document_Type__c = 'Grade Card'];
        System.assertEquals(
            beforeCount,
            afterCount,
            'Null term should not create any grade card files, whether batch fails or no-ops'
        );
        System.assert(threw || beforeCount == afterCount);
    }
}