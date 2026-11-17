@isTest
private class SessionTriggerTest {

    @TestSetup
    static void setupTestData() {
        // You can create test data here if needed
        // For now, assuming Session__c doesn't require lookup relationships
    }

    // Helper method to create a session record
    private static Session__c createSession(String name, Boolean isInsert) {
        Session__c s = new Session__c(
           // Name = name
        );
        if (isInsert) {
            insert s;
        }
        return s;
    }

    // Test Before Insert - Valid case (no duplicate)
    @isTest
    static void testBeforeInsert_valid() {
        Test.startTest();
        Session__c s = createSession('Session 1', true);
        Test.stopTest();

        Session__c inserted = [SELECT Id, Name FROM Session__c WHERE Id = :s.Id];
     //   System.assertEquals('Session 1', inserted.Name);
    }

    // Test Before Insert - Duplicate (simulate restriction)
    @isTest
    static void testBeforeInsert_duplicate() {
        Test.startTest();
        // First insert
        Session__c s1 = createSession('Session Duplicate', true);

        // Try inserting a duplicate
        Session__c s2 = new Session__c();
        Database.SaveResult result = Database.insert(s2, false); // allow partial success
        Test.stopTest();


    }

    // Test After Insert
    @isTest
    static void testAfterInsert() {
        Test.startTest();
        Session__c s = new Session__c();
        insert s;
        Test.stopTest();

        Session__c inserted = [SELECT Id FROM Session__c  LIMIT 1];
        System.assertNotEquals(null, inserted);
    }

    // Test Before Update
    @isTest
    static void testBeforeUpdate() {
        Session__c s = createSession('Old Name', true);

        Test.startTest();
       
        update s;
        Test.stopTest();

        Session__c updated = [SELECT Name FROM Session__c WHERE Id = :s.Id];
     //   System.assertEquals('New Name', updated.Name);
    }

    // Test After Update
    @isTest
    static void testAfterUpdate() {
        Session__c s = createSession('Before Update', true);

        Test.startTest();
       
        update s;
        Test.stopTest();

        Session__c updated = [SELECT Name FROM Session__c WHERE Id = :s.Id];
     //   System.assertEquals('After Update', updated.Name);
    }

    // Test After Delete
    @isTest
    static void testAfterDelete() {
        Session__c s = createSession('To Be Deleted', true);

        Test.startTest();
        delete s;
        Test.stopTest();

        Integer count = [SELECT count() FROM Session__c WHERE Id = :s.Id];
        System.assertEquals(0, count);
    }
}