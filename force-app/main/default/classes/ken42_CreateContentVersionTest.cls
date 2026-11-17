@isTest
public class ken42_CreateContentVersionTest {

    // A small, valid base64 payload
    private static final String SAMPLE_BASE64 =
        'iVBORw0KGgoAAAANSUhEUgAAAoAAAAHgCAQAAAD//1UBAAAAGXRFWHRTb2Z0d2FyZQBNYXRwbG90bGliIHZlcnNpb24xLjAgNjguMAp0cmFpbGVyRjgyMjItY291cmlkYQ==';

    @isTest
    public static void testCreateContentVersion() {
        Test.startTest();
        String publicUrl = ken42_CreateContentVersion.createContentVersion('TestImage', SAMPLE_BASE64);
        Test.stopTest();

        // The file itself must always be stored, whatever happens to the public delivery
        List<ContentVersion> stored = [SELECT Id, Title FROM ContentVersion WHERE Title = 'TestImage'];
        System.assertEquals(1, stored.size(), 'The document should have been stored');

        // A URL is optional - publishing can fail on org limits - but it must never be an error message
        if (publicUrl != null) {
            System.assert(publicUrl.startsWith('http'),
                'A returned value must be a URL, never an error message: ' + publicUrl);
        }
    }

    // PKDSU-243: the document is attached to the record it belongs to.
    @isTest
    public static void testCreateContentVersionLinksToRecord() {
        Contact c = new Contact(FirstName = 'Link', LastName = 'Target');
        insert c;

        Test.startTest();
        ken42_CreateContentVersion.createContentVersion('LinkedDoc', SAMPLE_BASE64, c.Id);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :c.Id
        ];
        System.assertEquals(1, links.size(), 'The stored document should be attached to the contact');
    }

    // PKDSU-243: re-running an import must not publish the same document again, because every
    // publication is charged against the org's content publication limit - the limit this
    // ticket is about.
    @isTest
    public static void testRepublishIsReused() {
        Contact c = new Contact(FirstName = 'Reuse', LastName = 'Target');
        insert c;

        Test.startTest();
        ken42_CreateContentVersion.createContentVersion('ReusedDoc', SAMPLE_BASE64, c.Id);
        Integer afterFirst = [SELECT COUNT() FROM ContentVersion WHERE Title = 'ReusedDoc'];

        // Same title, same record - the second call should not store or publish another copy
        ken42_CreateContentVersion.createContentVersion('ReusedDoc', SAMPLE_BASE64, c.Id);
        Test.stopTest();

        Integer afterSecond = [SELECT COUNT() FROM ContentVersion WHERE Title = 'ReusedDoc'];
        System.assertEquals(afterFirst, afterSecond,
            'Re-importing the same document must not create another copy');
    }

    // PKDSU-243: the whole point of the fix - a call that cannot produce a URL returns null, so
    // callers never write an error message into a URL field and break their own transaction.
    @isTest
    public static void testNoUsableInputReturnsNull() {
        Test.startTest();
        System.assertEquals(null, ken42_CreateContentVersion.createContentVersion('TestImage', ''),
            'An empty document must return null');
        System.assertEquals(null, ken42_CreateContentVersion.createContentVersion('TestImage', null),
            'A null document must return null');
        System.assertEquals(null, ken42_CreateContentVersion.createContentVersion('', SAMPLE_BASE64),
            'A blank title must return null');
        System.assertEquals(null, ken42_CreateContentVersion.createContentVersion('BadData', 'not-base64!!'),
            'An undecodable document must return null rather than an error message');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentVersion WHERE Title = 'BadData'],
            'Nothing should have been stored for an undecodable document');
    }
}