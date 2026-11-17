@isTest
private class RestApi_ProgramPlanAndTermDataFilterTest {

    @isTest
    static void testProgramPlanAndTermDataFilter() {
        // Create Account (Program)
        Account programAccount = new Account(Name = 'Test Program');
        insert programAccount;

        // Create Campus
        Campus__c campus = new Campus__c(Name = 'Main',Campus_ID__c='Online');
        insert campus;

        // Create Program Plan
        RecordType ppRT = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Program_Plan__c' AND Name = 'Program Version' LIMIT 1];
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Program Plan 2025',
            RecordTypeId = ppRT.Id,
            hed__Account__c = programAccount.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(6),
            hed__Status__c = 'Current',
            No_of_Student__c = 30,
            Batch__c = '2025',
            Intake__c = 'MAR'
        );
        insert programPlan;

        // Create Term
        RecordType termRT = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Term__c' AND Name = 'Default Record' LIMIT 1];
        hed__Term__c term = new hed__Term__c(
            Name = 'Semester 1',
            RecordTypeId = termRT.Id,
            Program_Plan__c = programPlan.Id,
             Term_Reference__c='Semester 1',
			hed__Account__c=programAccount.Id,
        
            Campus__c = campus.Id,
           hed__Start_Date__c = Date.today().addDays(-1), // Yesterday
hed__End_Date__c = Date.today().addMonths(3)   // 3 months from today

        );
        insert term;

        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CurrentPageFilter/';
        req.httpMethod = 'GET';
        req.addParameter('termStatus', 'Ongoing');
        req.addParameter('campus', '');
        req.addParameter('intake', 'MAR');
        req.addParameter('batch', '2025');
        req.addParameter('program', 'Test Program');
        RestContext.request = req;
        RestContext.response = res;

        RestApi_ProgramPlanAndTermDataFilter.doGet();
        System.debug('Response: ' + res.responseBody.toString());
        Test.stopTest();

    }
    

    @isTest
    static void testInvalidParams() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CurrentPageFilter/';
        req.httpMethod = 'GET';
        // Missing required params
        RestContext.request = req;
        RestContext.response = res;

        RestApi_ProgramPlanAndTermDataFilter.doGet();
        Test.stopTest();

       
    }
     @isTest
    static void testNoDataFound() {
        // Test case where no data matches the filters
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/CurrentPageFilter/';
        req.httpMethod = 'GET';
        req.addParameter('termStatus', 'NonExistentStatus');
        req.addParameter('campus', 'NonExistentCampus');
        req.addParameter('intake', 'NonExistentIntake');
        req.addParameter('batch', 'NonExistentBatch');
        req.addParameter('program', 'NonExistentProgram');
        RestContext.request = req;
        RestContext.response = res;

        RestApi_ProgramPlanAndTermDataFilter.doGet();
        System.debug('Response for no data: ' + res.responseBody);
        Test.stopTest();
    }
    
 
}