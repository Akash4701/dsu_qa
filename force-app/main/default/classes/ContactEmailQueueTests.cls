@IsTest
private class ContactEmailQueueTests {

    private static List<Contact> makeContacts(Integer n, Boolean withEmail, Boolean optedOut) {
        List<Contact> out = new List<Contact>();
        for (Integer i = 0; i < n; i++) {
            out.add(new Contact(
                LastName = (withEmail ? 'C_WithEmail_' : 'C_NoEmail_') + i,
                Email    = withEmail ? 'user' + i + '@example.com' : null,
                HasOptedOutOfEmail = optedOut
            ));
        }
        insert out;
        return out;
    }

    private static Id makeFile(String title, String contents, String ext) {
        ContentVersion cv = new ContentVersion(
            Title        = title,
            PathOnClient = title + (String.isBlank(ext) ? '' : '.' + ext),
            VersionData  = Blob.valueOf(contents)
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id]
               .ContentDocumentId;
    }


    @IsTest
    static void fullFlow_withFiles_optedOut_and_skip() {
        List<Contact> recips   = makeContacts(5, true,  false); 
        List<Contact> optedOut = makeContacts(1, true,  true ); 
        List<Contact> skipped  = makeContacts(1, false, false);

        List<Id> allIds = new List<Id>();
        allIds.addAll(new Map<Id,Contact>(recips).keySet());
        allIds.addAll(new Map<Id,Contact>(optedOut).keySet());
        allIds.addAll(new Map<Id,Contact>(skipped).keySet());

        Map<Id, List<String>> affMap = new Map<Id, List<String>>();
        affMap.put(optedOut[0].Id, new List<String>{ 'aff+opted@example.com' });

        Id docId = makeFile('utfile', 'hello', 'txt');

        Test.startTest();
        System.enqueueJob(new ContactEmailQueue(
            allIds,
            affMap,
            new List<Id>{ docId },
            'UT Subject',
            'UT Body',
            UserInfo.getUserId()
        ));
        Test.stopTest(); 

        List<Task> optedTasks = [
            SELECT Id, WhoId, Subject, Status
            FROM Task
            WHERE WhoId = :optedOut[0].Id
              AND Subject LIKE 'Email sent to affiliation%'
        ];
        System.assertEquals(1, optedTasks.size(), 'Opted-out contact must get a Task');

        System.assert(
            [SELECT count() FROM ContentDocumentLink WHERE LinkedEntityId = :optedTasks[0].Id] > 0,
            'File must be linked to the opted-out Task'
        );

        System.assertEquals(0,
            [SELECT count() FROM Task
             WHERE WhoId = :skipped[0].Id
               AND (Subject LIKE 'UT Subject%' OR Subject LIKE 'Email sent to affiliation%')],
            'Skip contact must have no activity'
        );
    }

    @IsTest
    static void noFiles_allHaveEmail() {
        List<Contact> recips = makeContacts(3, true, false);
        List<Id> ids = new List<Id>(new Map<Id,Contact>(recips).keySet());

        Test.startTest();
        System.enqueueJob(new ContactEmailQueue(
            ids,
            new Map<Id, List<String>>(), 
            new List<Id>(),
            'UT NoFiles',
            'Body',
            UserInfo.getUserId()
        ));
        Test.stopTest();

        System.assertEquals(0,
            [SELECT count() FROM Task WHERE Subject LIKE 'Email sent to affiliation%'],
            'No affiliation tasks expected when everyone has email'
        );
    }

    @IsTest
    static void emptyInput_earlyReturn() {
        Test.startTest();
        System.enqueueJob(new ContactEmailQueue(
            new List<Id>(),
            new Map<Id, List<String>>(),
            new List<Id>(),
            'UT Empty',
            'Body',
            UserInfo.getUserId()
        ));
        Test.stopTest();
    }
}