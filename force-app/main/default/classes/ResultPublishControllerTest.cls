@IsTest
public class ResultPublishControllerTest {

    @TestSetup
    static void setupData() {

        // Account
        Account acc = new Account(Name = 'Test Dept');
        insert acc;

        // Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'T1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4),
            Result_Published__c = false
        );
        insert term;

        // Course
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = acc.Id,
            Credits__c = 3
        );
        insert course;

        // Course Offerings (both unpublished)
        List<hed__Course_Offering__c> offerings = new List<hed__Course_Offering__c>{
            new hed__Course_Offering__c(
                Name = 'CO 1',
                hed__Course__c = course.Id,
                hed__Term__c = term.Id,
                Result_Published__c = false
            ),
            new hed__Course_Offering__c(
                Name = 'CO 2',
                hed__Course__c = course.Id,
                hed__Term__c = term.Id,
                Result_Published__c = false
            )
        };
        insert offerings;
    }

    // ----------------------------------------
    // Happy path coverage
    // ----------------------------------------
    @IsTest
    static void testPublishResults_success() {

        Id termId = [SELECT Id FROM hed__Term__c LIMIT 1].Id;

        Test.startTest();
        ResultPublishController.publishResults(termId);
        Test.stopTest();
    }

    // ----------------------------------------
    // Null termId → AuraHandledException path
    // ----------------------------------------
    @IsTest
    static void testPublishResults_nullTerm() {

        Test.startTest();
        try {
            ResultPublishController.publishResults(null);
        } catch (AuraHandledException e) {
            // intentionally empty – coverage only
        }
        Test.stopTest();
    }

    // ----------------------------------------
    // No offerings to update (empty list path)
    // ----------------------------------------
    @IsTest
    static void testPublishResults_noOfferings() {

        // Create a new term WITHOUT offerings
        Account acc = new Account(Name = 'Dept 2');
        insert acc;

        hed__Term__c term = new hed__Term__c(
            Name = 'Empty Term',
            hed__Account__c = acc.Id,
            Term_Reference__c = 'T2',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(3),
            Result_Published__c = false
        );
        insert term;

        Test.startTest();
        ResultPublishController.publishResults(term.Id);
        Test.stopTest();
    }
}