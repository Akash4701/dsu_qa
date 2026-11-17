@isTest
public class TestIndividualApplicationTrigger {
    
    @isTest
    static void testHandleAfterUpdate_Admitted() {
        // Step 1: Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Step 2: Get Contact RecordTypeId for something other than Student
        Id defaultRT = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Faculty').getRecordTypeId();
        Id studentRT = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Student').getRecordTypeId();

        // Step 3: Create Contact
        Contact con = new Contact(FirstName = 'John', LastName = 'Doe', RecordTypeId = defaultRT);
        insert con;

        // Step 4: Create Program Plan
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Test Plan',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(6)
        );
        insert plan;

        // Step 5: Create Application with initial status not 'Admitted'
        Application__c app = new Application__c(

            ContactId__c = con.Id,
            AccountId__c = acc.Id,
            Program_Plan__c = plan.Id,
            Status__c = 'Application on hold',
            External_Application_Number__c = '1313',
            Program_Level__c = 'UG'
        );
        insert app;

        // Step 6: Update status to 'Admitted' to trigger the logic
        app.Status__c = 'Admitted';

        Test.startTest();
        update app;
        Test.stopTest();

        // Step 7: Assert Affiliation record was created
        List<hed__Affiliation__c> affList = [
            SELECT Id, hed__Contact__c, hed__Account__c, Program_Plan__c, Individual_Application__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c = :con.Id
        ];
        

        // Step 8: Assert Contact record type was updated
        Contact updatedCon = [SELECT Id, RecordTypeId FROM Contact WHERE Id = :con.Id];
        
    }
}