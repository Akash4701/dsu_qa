@isTest
private class TestCaseQueueReassignment {
    
  
    @testSetup
    static void setup() {
                Test.setMock(HttpCalloutMock.class, null);

        // Create test users
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        List<User> users = new List<User>();
        for (Integer i = 0; i < 2; i++) {
            users.add(new User(
                FirstName = 'Test',
                LastName = 'User' + i,
                Alias = 'tuser' + i,
                Email = 'testuser' + i + '@test.com',
                Username = 'testuser' + i + '@test.com.' + System.currentTimeMillis(),
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id
            ));
        }
        insert users;
        
        // Create a queue (Group) for Case object
        Group queue = new Group(
            Name = 'Case Pipeline Queue',
            Type = 'Queue'
        );
        insert queue;
        
        GroupMember member = new GroupMember(
            GroupId = queue.Id,
            UserOrGroupId = users[0].Id
        );
        insert member;
        
        // Link the queue to Case object
        QueueSobject qs = new QueueSobject(
            QueueId = queue.Id,
            SObjectType = 'Case'
        );
        insert qs;
        
        // Use System.runAs to separate setup and non-setup DML operations
        System.runAs(users[0]) {
            // Disable triggers/flows for test data creation
            Test.startTest();
            
            // Create a test account first (if Cases require Account)
            Account testAccount = new Account(Name = 'Test Account');
            insert testAccount;
            
            // Create a test contact (if Cases require Contact)
            Contact testContact = new Contact(
                FirstName = 'Test',
                LastName = 'Contact',
                Email = 'testcontact@test.com',
                AccountId = testAccount.Id
            );
            insert testContact;
            
            Test.stopTest();
            
            // Create closed cases owned by users with all required fields
            List<Case> closedCases = new List<Case>();
            for (User u : users) {
                closedCases.add(new Case(
                    Status = 'Closed',
                    Subject = 'Closed case',
                    OwnerId = u.Id,
                    Origin = 'Web',
                    ContactId = testContact.Id,
                    AccountId = testAccount.Id
                ));
            }
            insert closedCases;
            
            // Create open cases to assign to queue with all required fields
            List<Case> queuedCases = new List<Case>();
            for (Integer i = 0; i < 5; i++) {
                queuedCases.add(new Case(
                    Status = 'New',
                    Subject = 'Queued Case ' + i,
                    OwnerId = queue.Id,
                    Origin = 'Web',
                    ContactId = testContact.Id,
                    AccountId = testAccount.Id
                ));
            }
            insert queuedCases;
        }
    }
    
    @isTest
    static void testAssign() {
        // Get closed case IDs
        List<Id> closedIds = new List<Id>();
        for (Case c : [SELECT Id FROM Case WHERE Status = 'Closed']) {
            closedIds.add(c.Id);
        }
        
        // Call the method
        Test.startTest();
        CaseQueueReassignment.assign(closedIds);
        Test.stopTest();
        
        // Verify reassignment happened
        List<Case> reassignedCases = [SELECT Id, OwnerId FROM Case WHERE Status = 'New'];
        System.assertNotEquals(0, reassignedCases.size(), 'Cases should be reassigned to users');
        
        // Additional verification: Check that some cases were actually reassigned from queue to users
        Group queue = [SELECT Id FROM Group WHERE Name = 'Case Pipeline Queue' LIMIT 1];
        List<Case> stillInQueue = [SELECT Id FROM Case WHERE OwnerId = :queue.Id AND Status = 'New'];
        List<Case> assignedToUsers = [SELECT Id FROM Case WHERE OwnerId != :queue.Id AND Status = 'New'];
        
        System.assert(assignedToUsers.size() > 0, 'Some cases should be assigned to users');
    }
}