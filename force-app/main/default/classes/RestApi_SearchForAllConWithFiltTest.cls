@isTest

public class RestApi_SearchForAllConWithFiltTest {


    @testSetup
    static void setupData() {
        // Create Record Types
        Id contactRt = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Student').getRecordTypeId();

        // Create Department Account
        Account department = new Account(Name = 'Science Department');
        insert department;

        // Create Academic Program Account
        Account acaProgram = new Account(Name = 'B.Sc Physics', ParentId = department.Id);
        insert acaProgram;

        // Create Contact with RecordType and Country
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Phone = '9999999999',
            Email = 'test@example.com',
            Birthdate = Date.newInstance(2000, 1, 1),
            Registration_Number__c = 'REG123',
            hed__Gender__c = 'Male',
            Status__c = 'Active',
            hed__Country_of_Origin__c = 'India',
            RecordTypeId = contactRt
        );
        insert con;

        // Create Program Plan
        hed__Program_Plan__c plan = new hed__Program_Plan__c(Name = 'Physics Plan');
        insert plan;

        // Create Term
        hed__Term__c term = new hed__Term__c(Name = 'Term 1',
                                             hed__Start_Date__c = Date.today().addDays(1), 
                                             hed__End_Date__c = Date.today().addMonths(3),
                                             Term_Reference__c='Semester 2',
                                             hed__Account__c=acaProgram.Id
                                            );
        insert term;

        // Create Program Enrollment for the Contact
        hed__Program_Enrollment__c enrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = con.Id,
            hed__Account__c = acaProgram.Id,
            Term__c = term.Id,
            hed__Program_Plan__c = plan.Id
        );
        insert enrollment;
    }

    @isTest
    static void testGetWithoutProgramEnrollmentFilters() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/users';
        req.httpMethod = 'GET';
        req.params.put('name', 'Test');
        req.params.put('type', 'Student');
        req.params.put('country', 'India');
        req.params.put('pageNo', '0');
        req.params.put('count', '10');

        RestContext.request = req;
        RestContext.response = res;

        RestApi_SearchForAllConatcsWithFilters.doGet();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('"success": "true"'));
        Test.stopTest();
    }

    @isTest
    static void testGetWithProgramEnrollmentFilters() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/users';
        req.httpMethod = 'GET';
        req.params.put('department', [SELECT ParentId FROM Account LIMIT 1].ParentId); // ensure it exists
        req.params.put('acaProgram', [SELECT Id FROM Account WHERE ParentId != null LIMIT 1].Id);
        req.params.put('term', [SELECT Id FROM hed__term__c LIMIT 1].Id);
        req.params.put('programPlan', [SELECT Id FROM hed__Program_Plan__c LIMIT 1].Id);
        req.params.put('type', 'Student');
        req.params.put('name', 'Test');
        req.params.put('country', 'India');
        req.params.put('count', '10');
        req.params.put('pageNo', '0');

        RestContext.request = req;
        RestContext.response = res;

        RestApi_SearchForAllConatcsWithFilters.doGet();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('"success": "true"'));
        Test.stopTest();
    }

    @isTest
    static void testGetWithException() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/users';
        req.httpMethod = 'GET';
        // Force exception by passing invalid count
        req.params.put('count', 'invalid_number');
        req.params.put('pageNo', '1');

        RestContext.request = req;
        RestContext.response = res;

        RestApi_SearchForAllConatcsWithFilters.doGet();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('"success" : false'));
        Test.stopTest();
    }
}