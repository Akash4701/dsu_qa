@IsTest
public class EventTargetAudience_Test {
@TestSetup
    static void testData(){
        /*** Insert Event ***/
        Event_Master__c event = new Event_Master__c(Name = 'Test Event');
        insert event;
        
        /*** Insert Contact ***/
        Contact contact = new Contact();
        contact.FirstName = 'Test';
        contact.LastName = 'Contact';
        contact.Event_Reminder_Email_Id__c = 'TestContact@yopmail.com';
        
        insert contact;
    }
    @IsTest
    static void testEventTargetAudience(){
        List<Event_Master__c> event = [SELECT Id, Name FROM Event_Master__c LIMIT 1];
        
        System.assertEquals(1,event.size());
        Event_Target_Audience__c ETA = new Event_Target_Audience__c();
        ETA.Invite_All__c = true;
        ETA.Event_Master__c = event[0].Id;
        insert ETA;
        Event_Target_Audience__c insertedETA = [SELECT Id, Invite_All__c FROM Event_Target_Audience__c WHERE Id = :ETA.Id];
        
        System.assertEquals(true, insertedETA.Invite_All__c, 'The Invite_All field should be true.');
    }
     @isTest
    static void testChunkStringListMethod() {
        // Arrange: create a sample list of 10 email strings
        List<String> emailList = new List<String>();
        for (Integer i = 0; i < 10; i++) {
            emailList.add('test' + i + '@example.com');
        }

        // Act: chunk into size of 3
        List<List<String>> result = EventTargetAudienceHandler.chunkStringList(emailList, 3);

        // Assert
        System.assertEquals(4, result.size(), 'Expected 4 chunks');
        System.assertEquals(3, result[0].size(), 'First chunk should have 3 items');
        System.assertEquals(1, result[3].size(), 'Last chunk should have 1 item');
        System.assertEquals('test0@example.com', result[0][0], 'First email should match');
        System.assertEquals('test9@example.com', result[3][0], 'Last email should match');
    }
}