@isTest
private class CreateActivityHandlerTest {

    @isTest
    static void testCreateActivity() {
        Account acc = new Account(Name = 'Test');
        insert acc;
        // Step 1: Create a Term
        hed__Term__c term = new hed__Term__c(Name = 'Term 2025',hed__Account__c = acc.Id , Term_Reference__c = 'Term 1');
        insert term;

        // Step 2: Create an Academic Planner linked to the term
        K42_Academic_Planner__c planner = new K42_Academic_Planner__c(
            Name = 'Planner 1',
            Term__c = term.Id
        );
        insert planner;

        // Step 3: Create a Course
        hed__Course__c course = new hed__Course__c(Name = 'Test Course',hed__Account__c = acc.Id);
        insert course;

        // Step 4: Create a Course Version linked to the term
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30)
        );
        insert courseVersion;
        try{
            Test.startTest();
        CreateActivityHandler.createActivity(new List<Course_Version__c>{courseVersion});
        Test.stopTest();
        }
        catch(Exception e){
            
        }
        // Step 5: Call the method with the inserted Course Version
        

    }
}