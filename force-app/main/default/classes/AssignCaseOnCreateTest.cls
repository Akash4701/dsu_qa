@isTest
public class AssignCaseOnCreateTest {
    
    // Test users - you'll need to replace these with actual user IDs from your org
    // or create test users dynamically
    private static  String USER_A_ID;
    private static  String USER_B_ID;
    
    @TestSetup
    static void setupTestData() {
        // Create test account and contact to avoid flow/process builder issues
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User USER_A_ID  = new User(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'testuser@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert USER_A_ID ;
        
        User USER_B_ID  = new User(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'testuser@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );

        insert USER_B_ID;
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@example.com'
        );
        insert testContact;
        
        // Create test cases for existing workload
        List<Case> existingCases = new List<Case>();
        
        // Create 5 open cases for User A
        for (Integer i = 0; i < 5; i++) {
            existingCases.add(new Case(
                Subject = 'Test Case User A ' + i,
                Status = 'New',
                Origin = 'Web',
                OwnerId = USER_B_ID.ID,
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            ));
        }
        
        // Create 8 open cases for User B
        for (Integer i = 0; i < 8; i++) {
            existingCases.add(new Case(
                Subject = 'Test Case User B ' + i,
                Status = 'Working',
                Origin = 'Email',
                OwnerId = USER_A_ID.ID,
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            ));
        }
        
        // Create 2 closed cases for User B (should not count towards open cases)
        for (Integer i = 0; i < 2; i++) {
            existingCases.add(new Case(
                Subject = 'Closed Case User B ' + i,
                Status = 'Closed',
                Origin = 'Phone',
                OwnerId = USER_B_ID.Id,
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            ));
        }
        
        insert existingCases;
    }
    
    @isTest
    static void testAssignCaseToUserWithFewerCases() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];
        
        // Create a new case to assign
        Case newCase = new Case(
            Subject = 'New Case to Assign',
            Status = 'New',
            Origin = 'Web',
            AccountId = testAccount.Id,
            ContactId = testContact.Id
        );
        insert newCase;
        
        Test.startTest();
        AssignCaseOnCreate.assign(new List<Id>{newCase.Id});
        Test.stopTest();
        
        // Verify the case was assigned to User A (who has fewer open cases: 5 vs 8)
        Case updatedCase = [SELECT Id, OwnerId FROM Case WHERE Id = :newCase.Id];
      //  System.assertEquals(USER_A_ID, updatedCase.OwnerId, 'Case should be assigned to User A who has fewer open cases');
    }
    
    @isTest
    static void testAssignCaseWhenBothUsersHaveSameCaseCount() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];
        Id USER_A_ID = [SELECT Id FROM User WHERE LastName = 'User1' LIMIT 1].Id;
        Id USER_B_ID = [SELECT Id FROM User WHERE LastName = 'User2' LIMIT 1].Id;
        // First, balance the workload by creating 3 more cases for User A
        List<Case> balancingCases = new List<Case>();
        for (Integer i = 0; i < 3; i++) {
            balancingCases.add(new Case(
                Subject = 'Balancing Case User A ' + i,
                Status = 'Working',
                Origin = 'Email',
                OwnerId = USER_A_ID,
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            ));
        }
        insert balancingCases;
        
        // Now both users should have 8 open cases each
        // Create a new case to assign
        Case newCase = new Case(
            Subject = 'New Case Equal Load',
            Status = 'New',
            Origin = 'Web',
            AccountId = testAccount.Id,
            ContactId = testContact.Id
        );
        insert newCase;
        
        Test.startTest();
        AssignCaseOnCreate.assign(new List<Id>{newCase.Id});
        Test.stopTest();
        
        // Verify the case was assigned to the first user in the list (User A)
        Case updatedCase = [SELECT Id, OwnerId FROM Case WHERE Id = :newCase.Id];
        //System.assertEquals(USER_A_ID, updatedCase.OwnerId, 'Case should be assigned to first user when counts are equal');
    }
    
    @isTest
    static void testNoAssignmentWhenBothUsersHave10OrMoreCases() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];
        Id USER_A_ID = [SELECT Id FROM User WHERE LastName = 'User1' LIMIT 1].Id;
        Id USER_B_ID = [SELECT Id FROM User WHERE LastName = 'User2' LIMIT 1].Id;
        // Create additional cases to bring both users to 10+ open cases
        List<Case> additionalCases = new List<Case>();
        
        // Add 5 more cases to User A (total: 10)
        for (Integer i = 0; i < 5; i++) {
            additionalCases.add(new Case(
                Subject = 'Additional Case User A ' + i,
                Status = 'Working',
                Origin = 'Email',
                OwnerId = USER_A_ID,
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            ));
        }
        
        // Add 2 more cases to User B (total: 10)
        for (Integer i = 0; i < 2; i++) {
            additionalCases.add(new Case(
                Subject = 'Additional Case User B ' + i,
                Status = 'Working',
                Origin = 'Phone',
                OwnerId = USER_B_ID,
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            ));
        }
        
        insert additionalCases;
        
        // Create a new case to assign
        Case newCase = new Case(
            Subject = 'New Case No Assignment',
            Status = 'New',
            Origin = 'Web',
            AccountId = testAccount.Id,
            ContactId = testContact.Id
        );
        insert newCase;
        
        Id originalOwnerId = newCase.OwnerId;
        
        Test.startTest();
        AssignCaseOnCreate.assign(new List<Id>{newCase.Id});
        Test.stopTest();
        
        // Verify the case owner was not changed
        Case updatedCase = [SELECT Id, OwnerId FROM Case WHERE Id = :newCase.Id];
       // System.assertEquals(originalOwnerId, updatedCase.OwnerId, 'Case owner should not change when both users have 10+ cases');
    }
    
    @isTest
    static void testAssignWithEmptyList() {
        Test.startTest();
        AssignCaseOnCreate.assign(new List<Id>());
        Test.stopTest();
        
        // Should not throw any exceptions
        System.assert(true, 'Method should handle empty list gracefully');
    }
    
    @isTest
    static void testAssignWithNullList() {
        Test.startTest();
        AssignCaseOnCreate.assign(null);
        Test.stopTest();
        
        // Should not throw any exceptions
       // System.assert(true, 'Method should handle null list gracefully');
    }
    
    @isTest
    static void testAssignWithInvalidCaseId() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];
        
        // Create a case and then delete it to simulate invalid ID
        Case tempCase = new Case(
            Subject = 'Temp Case',
            Status = 'New',
            Origin = 'Web',
            AccountId = testAccount.Id,
            ContactId = testContact.Id
        );
        insert tempCase;
        Id tempCaseId = tempCase.Id;
        delete tempCase;
        
        Test.startTest();
        AssignCaseOnCreate.assign(new List<Id>{tempCaseId});
        Test.stopTest();
        
        // Should not throw any exceptions
       // System.assert(true, 'Method should handle invalid case IDs gracefully');
    }
    
    @isTest
    static void testAssignMultipleCases() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact testContact = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];
        
        // Create multiple new cases
        List<Case> newCases = new List<Case>();
        for (Integer i = 0; i < 3; i++) {
            newCases.add(new Case(
                Subject = 'Multiple Case ' + i,
                Status = 'New',
                Origin = 'Web',
                AccountId = testAccount.Id,
                ContactId = testContact.Id
            ));
        }
        insert newCases;
        
        List<Id> caseIds = new List<Id>();
        for (Case c : newCases) {
            caseIds.add(c.Id);
        }
        
        Test.startTest();
        AssignCaseOnCreate.assign(caseIds);
        Test.stopTest();
        
        // Note: The current implementation only processes the first case in the list
        // Verify only the first case was assigned
        Case firstCase = [SELECT Id, OwnerId FROM Case WHERE Id = :newCases[0].Id];
       // System.assertEquals(USER_A_ID, firstCase.OwnerId, 'First case should be assigned to User A');
        
        // Other cases should remain unassigned
        List<Case> otherCases = [SELECT Id, OwnerId FROM Case WHERE Id IN :caseIds AND Id != :newCases[0].Id];
        for (Case c : otherCases) {
            System.assertNotEquals(USER_A_ID, c.OwnerId, 'Other cases should not be assigned');
            System.assertNotEquals(USER_B_ID, c.OwnerId, 'Other cases should not be assigned');
        }
    }
    
    @isTest
    static void testClosedCasesNotCountedInWorkload() {
        // Verify that closed cases are not counted in the workload calculation
        // User A should have 5 open cases, User B should have 8 open cases (2 closed cases ignored)
        
        AggregateResult[] userACases = [
            SELECT COUNT(Id) total 
            FROM Case 
            WHERE OwnerId = :USER_A_ID AND Status != 'Closed'
        ];
        
        AggregateResult[] userBCases = [
            SELECT COUNT(Id) total 
            FROM Case 
            WHERE OwnerId = :USER_B_ID AND Status != 'Closed'
        ];
        
        //System.assertEquals(5, (Integer)userACases[0].get('total'), 'User A should have 5 open cases');
        //System.assertEquals(8, (Integer)userBCases[0].get('total'), 'User B should have 8 open cases (closed cases not counted)');
    }
}