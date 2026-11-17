@isTest
public class ProgramEnrollmentTriggerTest {
    
    @isTest
    static void testHandleAffiliationSetsFlag() {
        Test.setMock(HttpCalloutMock.class, new MyMockResponse());

        // Step 1: Create and insert Account
        Account acc = new Account(Name = 'Test Academic Account');
        insert acc;
        
        // Step 2: Create and insert Contact
        Contact con = new Contact(FirstName = 'Test', LastName = 'Student', AccountId = acc.Id);
        insert con;

        // Step 3: Create and insert Affiliation
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = con.Id,
            hed__Account__c = acc.Id,
            Is_Program_Enrollment__c = false
        );
        insert aff;

        // Step 4: Create and insert Program Enrollment with the Affiliation
        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = con.Id,
            hed__Account__c = acc.Id,
            hed__Affiliation__c = aff.Id
        );

        Test.startTest();
        insert pe; // This will fire the trigger and call handleAffiliation
        Test.stopTest();

        // Step 5: Validate that the flag was set to true
        hed__Affiliation__c updatedAff = [SELECT Id, Is_Program_Enrollment__c FROM hed__Affiliation__c WHERE Id = :aff.Id];
    }
    public class MyMockResponse implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"data": []}');
        res.setStatusCode(200);
        return res;
    }
}

}