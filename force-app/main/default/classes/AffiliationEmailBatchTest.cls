@isTest
private class AffiliationEmailBatchTest {

    @testSetup
    static void setup() {
        Contact c = new Contact(
            FirstName = 'Batch',
            LastName = 'User',
            Email = 'batchuser@example.com',
            HasOptedOutOfEmail = false
        );
        insert c;

        List<hed__Affiliation__c> affs = new List<hed__Affiliation__c>{ 
            new hed__Affiliation__c(
                hed__Contact__c = c.Id,
                DSU_Email__c = 'batch1@example.com'
            ),
            new hed__Affiliation__c(
                hed__Contact__c = c.Id,
                DSU_Email__c = 'batch2@example.com'
            )
        };
        insert affs;
    }

    @isTest
    static void testBatchExecutes() {
        List<Id> affilIds = new List<Id>();
        for (hed__Affiliation__c a : [
            SELECT Id
            FROM hed__Affiliation__c
            WHERE DSU_Email__c != null
        ]) {
            affilIds.add(a.Id);
        }
        System.assertEquals(2, affilIds.size());

        Test.startTest();
        Database.executeBatch(
            new AffiliationEmailBatch(affilIds, 'Batch Subject', 'Batch Body', null),
            200
        );
        Test.stopTest();

        System.assertEquals(2, [SELECT count() FROM EmailMessage WHERE Subject = 'Batch Subject']);
    }

    @isTest
    static void testBatchWithNullList() {
        Test.startTest();
        Database.executeBatch(
            new AffiliationEmailBatch(null, 'Empty Subject', 'Empty Body', null),
            200
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT count() FROM EmailMessage WHERE Subject = 'Empty Subject']);
    }
}