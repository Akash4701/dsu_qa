@isTest
public class RestApi_CampusHolidayTest {
static testMethod void testFetchingCampusHoliday() {
    // Setup data
    Account campus = new Account(Name = 'Test Campus');
    insert campus;

    hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Plan');
    insert programPlan;

    Campus__c camp = new Campus__c(Name = 'Test Campus',Campus_ID__c='Online'); // Set same name
    insert camp;

    hed__Term__c term = new hed__Term__c(
        Name = 'Term 1',
        hed__Start_Date__c = Date.today().addDays(1), 
        hed__End_Date__c = Date.today().addMonths(3),
        Term_Reference__c = 'Semester 2',
        hed__Account__c = campus.Id,
        Program_Plan__c = programPlan.Id
    );
    insert term;

    K42_Holiday__c holiday = new K42_Holiday__c(
        Name = 'Holiday 1',
        K42_Hol_Start_Date__c = Date.today().addDays(2),
        K42_Hol_End_Date__c = Date.today().addDays(3)
    );
    insert holiday;

    K42_Campus_Holiday__c campusHoliday = new K42_Campus_Holiday__c(
        Campus__c = camp.Id,
        Campus_Name__c = campus.Id,
        K42_Holiday__c = holiday.Id
    );
    insert campusHoliday;

    // Setup REST request/response
    Test.startTest();
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestURI = '/CampusHolidayFetching/';
    req.httpMethod = 'GET';
    req.addParameter('campus', 'Test Campus'); // Must match Campus__r.Name
    req.addParameter('programPlanId', programPlan.Id);
    RestContext.request = req;
    RestContext.response = res;

    RestApi_CampusHoliday.fetchingCampusHoliday();
    Test.stopTest();

  
}

    static Id createdCampusHolidayId;

    static testMethod void testDoPost() {
        // Setup campus
        Account campus = new Account(Name = 'Test Campus 2');
        insert campus;

        campus__c camp1 = new Campus__c(Campus_ID__c='Online');
        insert camp1;

        // Prepare wrapper data for POST
        List<RestApi_CampusHoliday.wrapperData> dataList = new List<RestApi_CampusHoliday.wrapperData>();
        RestApi_CampusHoliday.wrapperData data = new RestApi_CampusHoliday.wrapperData();
        data.holidayName = 'Holiday Inserted';
        data.startDate = Date.today().addDays(5);
        data.endDate = Date.today().addDays(6);
        data.campusId = camp1.Id; // using Campus__c from org
        dataList.add(data);

        // Set up REST request/response for POST
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/CampusHolidayFetching/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(dataList));
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CampusHoliday.doPost();
        

        // Get inserted Campus Holiday record to verify
        List<K42_Campus_Holiday__c> insertedCampusHolidays = [
            SELECT Id, K42_Holiday__c FROM K42_Campus_Holiday__c WHERE Campus__c = :camp1.Id
        ];

        createdCampusHolidayId = insertedCampusHolidays[0].Id;

        // POST Update scenario
        dataList[0].campusHolidayId = createdCampusHolidayId;
        dataList[0].holidayName = 'Updated Holiday';
        dataList[0].startDate = Date.today().addDays(7);
        dataList[0].endDate = Date.today().addDays(8);

        req = new RestRequest();
        res = new RestResponse();
        req.requestURI = '/CampusHolidayFetching/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(dataList));
        RestContext.request = req;
        RestContext.response = res;

       
        RestApi_CampusHoliday.doPost();
        Test.stopTest();

       
    }

    static testMethod void testDoDelete() {
        // Prerequisite: You should already have a CampusHoliday inserted from testDoPost
     campus__c camp1 = new Campus__c(Campus_ID__c='Online');
        insert camp1;
          Account campus = new Account(Name = 'Test Campus');
        insert campus;
  K42_Holiday__c holiday = new K42_Holiday__c(
            Name = 'Holiday 1',
            K42_Hol_Start_Date__c = Date.today().addDays(2),
            K42_Hol_End_Date__c = Date.today().addDays(3)
        );
        insert holiday;

        K42_Campus_Holiday__c existingHoliday = new K42_Campus_Holiday__c(
           // Name = 'Campus Holiday 1',
            Campus__c = camp1.Id,
            Campus_Name__c = campus.Id,
            K42_Holiday__c = holiday.Id
        );
        insert existingHoliday;
      

        // Set up REST request/response for DELETE
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/CampusHolidayFetching/';
        req.httpMethod = 'DELETE';
        req.addParameter('campusHolidayId', existingHoliday.Id);
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        RestApi_CampusHoliday.doDelete();
        Test.stopTest();


    }
    
    @isTest
static void testResponseHolidayDataWrapper() {
    RestApi_CampusHoliday.responseHolidayDataWrapper wrapper = new RestApi_CampusHoliday.responseHolidayDataWrapper();
    
    // Set values
    wrapper.holidayId = 'HOL123';
    wrapper.holidayName = 'Republic Day';
    wrapper.campusName = 'Online Campus';
    wrapper.campusId = 'CAMP001';
    wrapper.programId = 'PROG123';
    wrapper.programName = 'MBA Program';
    wrapper.campusHolidayId = 'CH123';
    wrapper.startDate = Date.today();
    wrapper.endDate = Date.today().addDays(1);
    
}

}