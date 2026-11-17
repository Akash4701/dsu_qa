@isTest
private class EventPicklistValuesRestApiTest {

    @isTest
    static void testGetEventPicklistValuesSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/eventpicklistvalues';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        EventPicklistValuesRestApi.getEventPicklistValues();
        Test.stopTest();
    }

    @isTest
    static void testGetPicklistValuesWithInvalidParams() {
        Test.startTest();
        List<EventPicklistValuesRestApi.ValueEntry> result = EventPicklistValuesRestApi.getPicklistValues('', '');
        Test.stopTest();

    }
}