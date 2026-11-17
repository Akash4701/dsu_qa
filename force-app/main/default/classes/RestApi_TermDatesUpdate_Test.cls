@isTest
private class RestApi_TermDatesUpdate_Test {
    
    private static hed__Term__c setupTestData() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Start_Date__c = Date.newInstance(2022, 1, 1),
            hed__End_Date__c = Date.newInstance(2022, 12, 31),
            hed__Account__c = testAccount.Id, 
            Term_Reference__c = 'TR-1234' 
        );
        insert term;

        return term;
    }

    @isTest
    static void testUpdatingTerms_Success() {
        hed__Term__c term = setupTestData();

        Course_Version__c courseVersion = new Course_Version__c(
            Term__c = term.Id
        );
        insert courseVersion;

        String requestBody = '[{"termId": "' + term.Id + '","startDate": "2023-01-01","endDate": "2023-12-31","termDuration": "30"}]';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/TermDatesUpdate/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_TermDatesUpdate.updatingTerms();
        Test.stopTest();

          hed__Term__c updatedTerm = [SELECT Id, hed__Start_Date__c, hed__End_Date__c, Term_Duration__c FROM hed__Term__c WHERE Id = :term.Id];
         }

    @isTest
    static void testUpdatingTerms_InvalidTermId() {
        String requestBody = '[{"termId": "InvalidId","startDate": "2023-01-01","endDate": "2023-12-31","termDuration": "30"}]';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/TermDatesUpdate/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_TermDatesUpdate.updatingTerms();
        Test.stopTest();

        }

    @isTest
    static void testUpdatingTerms_NullValues() {
        hed__Term__c term = setupTestData();

        String requestBody = '[{"termId": "' + term.Id + '","startDate": null,"endDate": null,"termDuration": "45"}]';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/TermDatesUpdate/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_TermDatesUpdate.updatingTerms();
        Test.stopTest();

            hed__Term__c updatedTerm = [SELECT Id, hed__Start_Date__c, hed__End_Date__c, Term_Duration__c FROM hed__Term__c WHERE Id = :term.Id];

        }
     @isTest
    static void testUpdatingTerms_PlannedSubjects() {
        hed__Term__c term = setupTestData();

        // Insert a Course Version linked to the term
        Course_Version__c courseVersion = new Course_Version__c(
            Term__c = term.Id
        );
        insert courseVersion;

        // Send an update request where startDate is NULL (which should fail due to planned subjects)
        String requestBody = '[{"termId": "' + term.Id + '","startDate": null,"endDate": "2023-12-31","termDuration": "30"}]';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/TermDatesUpdate/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_TermDatesUpdate.updatingTerms();
        Test.stopTest();

          }
}