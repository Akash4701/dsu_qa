@isTest
private class CustomLookupLwcControllerTest {

    @isTest
    static void testFetchLookupDataWithRecordType() {
Id rtId = Schema.SObjectType.Event_Master__c.getRecordTypeInfosByDeveloperName().get('Event').getRecordTypeId();




        // Create Event_Master__c record
        Event_Master__c event = new Event_Master__c(
            Name = 'Tech Conference',
            RecordTypeId = rtId
        );
        insert event;

        Test.startTest();
        List<sObject> results = CustomLookupLwcController.fetchLookupData('Tech', 'Event_Master__c', 'Conference');
        Test.stopTest();

     
    }

    @isTest
    static void testFetchLookupDataWithoutRecordType() {
        // Create another Event_Master__c record without needing RecordType filter
        Event_Master__c event2 = new Event_Master__c(Name = 'Innovation Summit');
        insert event2;

        Test.startTest();
        List<sObject> results = CustomLookupLwcController.fetchLookupData('Innovation', 'Event_Master__c', '');
        Test.stopTest();

    }
}