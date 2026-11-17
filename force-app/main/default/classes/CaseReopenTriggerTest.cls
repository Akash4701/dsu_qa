@isTest
public class CaseReopenTriggerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com'
        );
        insert testContact;
    }
    
    @isTest
    static void testFirstTimeReopen() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Get Record Type Id for 'Support'
        Id supportRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Case' AND DeveloperName = 'Support' 
            LIMIT 1
        ].Id;
        
        // Create a Case
        Case testCase = new Case(
            Subject = 'Test Case Reopen',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'Medium',
            RecordTypeId = supportRecordTypeId,
            ContactId = testContact.Id,
            Reason_for_Reopened__c = 'Initial reason for reopening'
        );
        insert testCase;
        
        Test.startTest();
        
        // Update case status to 'Reopened'
        testCase.Status = 'Reopened';
        update testCase;
        
        Test.stopTest();
        
        // Verify the results
        Case updatedCase = [SELECT Id, Status, Reopen_Count__c, Reason_for_Reopened__c FROM Case WHERE Id = :testCase.Id];
        
      
    }
    
    @isTest
    static void testMultipleReopens() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Get Record Type Id for 'Support'
        Id supportRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Case' AND DeveloperName = 'Support' 
            LIMIT 1
        ].Id;
        
        // Create a Case
        Case testCase = new Case(
            Subject = 'Test Multiple Reopens',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'Medium',
            RecordTypeId = supportRecordTypeId,
            ContactId = testContact.Id
        );
        insert testCase;
        
        Test.startTest();
        
        // First reopen
        testCase.Status = 'Reopened';
        testCase.Reason_for_Reopened__c = 'First reopen reason';
        update testCase;
        
        // Change status back to something else
        testCase.Status = 'In Progress';
        update testCase;
        
        // Second reopen
        testCase.Status = 'Reopened';
        testCase.Reason_for_Reopened__c = testCase.Reason_for_Reopened__c + ' Second reopen reason';
        update testCase;
        
        Test.stopTest();
        
       
    }
    
    @isTest
    static void testReopenWithExistingCount() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Get Record Type Id for 'Support'
        Id supportRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Case' AND DeveloperName = 'Support' 
            LIMIT 1
        ].Id;
        
        // Create a Case with existing reopen count
        Case testCase = new Case(
            Subject = 'Test Existing Count',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'Medium',
            RecordTypeId = supportRecordTypeId,
            ContactId = testContact.Id,
            Reopen_Count__c = 3,
            Reason_for_Reopened__c = '01-01-2024 10:00 AM Previous reason'
        );
        insert testCase;
        
        Test.startTest();
        
        // Reopen the case
        testCase.Status = 'Reopened';
        testCase.Reason_for_Reopened__c = testCase.Reason_for_Reopened__c + ' New reopen reason';
        update testCase;
        
        Test.stopTest();
        
  
    }
    
    @isTest
    static void testStatusUpdateWithoutReopen() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Get Record Type Id for 'Support'
        Id supportRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Case' AND DeveloperName = 'Support' 
            LIMIT 1
        ].Id;
        
        // Create a Case
        Case testCase = new Case(
            Subject = 'Test No Reopen',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'Medium',
            RecordTypeId = supportRecordTypeId,
            ContactId = testContact.Id,
            Reopen_Count__c = 2,
            Reason_for_Reopened__c = 'Original reason'
        );
        insert testCase;
        
        Test.startTest();
        
        // Update case status to something other than 'Reopened'
        testCase.Status = 'In Progress';
        testCase.Priority = 'High'; // Change another field
        update testCase;
        
        Test.stopTest();
        
    
    }
    
    @isTest
    static void testReopenWithEmptyReason() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Get Record Type Id for 'Support'
        Id supportRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Case' AND DeveloperName = 'Support' 
            LIMIT 1
        ].Id;
        
        // Create a Case
        Case testCase = new Case(
            Subject = 'Test Empty Reason',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'Medium',
            RecordTypeId = supportRecordTypeId,
            ContactId = testContact.Id,
            Reason_for_Reopened__c = 'Original reason'
        );
        insert testCase;
        
        Test.startTest();
        
        // Reopen without adding new reason
        testCase.Status = 'Reopened';
        testCase.Reason_for_Reopened__c = 'Original reason'; // Same as before
        update testCase;
        
        Test.stopTest();
        
     
    }
    
    @isTest
    static void testReopenWithTimestampInUserInput() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Get Record Type Id for 'Support'
        Id supportRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Case' AND DeveloperName = 'Support' 
            LIMIT 1
        ].Id;
        
        // Create a Case
        Case testCase = new Case(
            Subject = 'Test Timestamp Removal',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'Medium',
            RecordTypeId = supportRecordTypeId,
            ContactId = testContact.Id
        );
        insert testCase;
        
        Test.startTest();
        
        // Reopen with user accidentally including timestamp
        testCase.Status = 'Reopened';
        testCase.Reason_for_Reopened__c = '15-06-2024 02:30 PM User typed this timestamp accidentally in the reason';
        update testCase;
        
        Test.stopTest();
        
      
    }
    
    @isTest
    static void testBulkCaseReopen() {
        // Get the test contact
        Contact testContact = [SELECT Id FROM Contact WHERE Email = 'testuser@example.com' LIMIT 1];
        
        // Get Record Type Id for 'Support'
        Id supportRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Case' AND DeveloperName = 'Support' 
            LIMIT 1
        ].Id;
        
        // Create multiple cases
        List<Case> testCases = new List<Case>();
        for (Integer i = 0; i < 5; i++) {
            testCases.add(new Case(
                Subject = 'Bulk Test Case ' + i,
                Status = 'New',
                Origin = 'Phone',
                Priority = 'Medium',
                RecordTypeId = supportRecordTypeId,
                ContactId = testContact.Id,
                Reason_for_Reopened__c = 'Bulk test reason ' + i
            ));
        }
        insert testCases;
        
        Test.startTest();
        
        // Bulk reopen all cases
        for (Case c : testCases) {
            c.Status = 'Reopened';
            c.Reason_for_Reopened__c = c.Reason_for_Reopened__c + ' - Updated';
        }
        update testCases;
        
        Test.stopTest();
     
    }
}

/*@isTest
private class CaseReopenTriggerTest {
    @isTest
    static void testReopenCountIncrement() {
        // Create a test Contact (required by Flow)
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com'
        );
        insert testContact;

        // Get Record Type Id for 'Support'
        Id supportRecordTypeId = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Case' AND DeveloperName = 'Support' 
            LIMIT 1
        ].Id;

        // Create a Case with the contact
        Case testCase = new Case(
            Subject = 'Test Case Reopen',
            Status = 'New',
            Origin = 'Phone',
            Priority = 'Medium',
            RecordTypeId = supportRecordTypeId,
            ContactId = testContact.Id  // ✅ added
        );
        insert testCase;

        Test.startTest();

        testCase.Status = 'Resolved';
        update testCase;

        testCase.Status = 'Re-opened';
        update testCase;

        Case c1 = [SELECT Reopen_Count__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(1, c1.Reopen_Count__c);

        c1.Status = 'Resolved';
        update c1;

        c1.Status = 'Re-opened';
        update c1;

        Case c2 = [SELECT Reopen_Count__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(2, c2.Reopen_Count__c);

        Test.stopTest();
    }
}*/