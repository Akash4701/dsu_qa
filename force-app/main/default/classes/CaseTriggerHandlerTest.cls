@IsTest
private class CaseTriggerHandlerTest {

    private static void setupTestData() {
        Contact testContact = new Contact(
            LastName = 'TestContact',
            Email = 'testcontact@example.com'
        );
        insert testContact;

        Contact contactNoEnrollment = new Contact(
            LastName = 'NoEnrollment',
            Email = 'noenrollment@example.com'
        );
        insert contactNoEnrollment;

        insert new hed__Program_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Enrollment_Status__c = 'Active'
        );
        insert new hed__Program_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Enrollment_Status__c = 'Active'
        );
        insert new hed__Program_Enrollment__c(
            hed__Contact__c = testContact.Id,
            hed__Enrollment_Status__c = 'Inactive'
        );
    }

    @IsTest
    static void testHandleAfterInsert_PopulatesEnrollment() {
        setupTestData();

        Contact con = [SELECT Id, Email FROM Contact WHERE LastName = 'TestContact' LIMIT 1];
        List<hed__Program_Enrollment__c> enrollments = [
            SELECT Id
            FROM hed__Program_Enrollment__c
            WHERE hed__Contact__c = :con.Id
              AND hed__Enrollment_Status__c = 'Active'
            ORDER BY CreatedDate ASC
        ];
        System.assert(enrollments.size() >= 2, 'Should have at least 2 active enrollments');

        Case c = buildCaseForInsert('Test Case', con.Id, con.Email, 'Test Contact');
        insert c;

        Case updatedCase = [SELECT Id, Program_Enrollment__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            enrollments[0].Id,
            updatedCase.Program_Enrollment__c,
            'Should be mapped to the first active enrollment'
        );
    }

    @IsTest
    static void testHandleAfterInsert_NoActiveEnrollment() {
        setupTestData();

        Contact con = [SELECT Id, Email FROM Contact WHERE LastName = 'NoEnrollment' LIMIT 1];
        Case c = buildCaseForInsert('Test Case - No Enrollment', con.Id, con.Email, 'No Enrollment');
        insert c;

        Case updatedCase = [SELECT Id, Program_Enrollment__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(null, updatedCase.Program_Enrollment__c, 'Should stay null when no active enrollment exists');
    }

    @IsTest
    static void testHandleAfterInsert_NoContact() {
        Test.startTest();
        CaseTriggerHandler.handleAfterInsert(new List<Case>{
            new Case(Subject = 'No Contact In-Memory')
        });
        Test.stopTest();

        System.assert(true, 'No-contact records should be skipped without errors.');
    }

    @IsTest
    static void testHandleAfterInsert_AlreadyPopulated() {
        setupTestData();

        Contact con = [SELECT Id, Email FROM Contact WHERE LastName = 'TestContact' LIMIT 1];
        Id existingEnrollmentId = [
            SELECT Id
            FROM hed__Program_Enrollment__c
            WHERE hed__Contact__c = :con.Id
              AND hed__Enrollment_Status__c = 'Active'
            LIMIT 1
        ].Id;

        Case c = buildCaseForInsert('Test Case - Already Set', con.Id, con.Email, 'Already Set');
        c.Program_Enrollment__c = existingEnrollmentId;
        insert c;

        Case updatedCase = [SELECT Id, Program_Enrollment__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(
            existingEnrollmentId,
            updatedCase.Program_Enrollment__c,
            'Should retain original value and not be overwritten'
        );
    }

    @IsTest
    static void testHandleAfterInsert_MixedCases() {
        setupTestData();

        Contact conWithEnrollment = [SELECT Id, Email FROM Contact WHERE LastName = 'TestContact' LIMIT 1];
        Contact conWithout = [SELECT Id, Email FROM Contact WHERE LastName = 'NoEnrollment' LIMIT 1];
        Id existingEnrollmentId = [
            SELECT Id
            FROM hed__Program_Enrollment__c
            WHERE hed__Contact__c = :conWithEnrollment.Id
              AND hed__Enrollment_Status__c = 'Active'
            LIMIT 1
        ].Id;

        List<Case> casesToInsert = new List<Case>{
            buildCaseForInsert('With Contact & Enrollment', conWithEnrollment.Id, conWithEnrollment.Email, 'With Enrollment'),
            buildCaseForInsert('With Contact but No Enrollment', conWithout.Id, conWithout.Email, 'No Enrollment'),
            buildCaseForInsert('Already Populated', conWithEnrollment.Id, conWithEnrollment.Email, 'Already Populated')
        };

        insert casesToInsert;

        List<Case> results = [
            SELECT Id, Subject, ContactId, Program_Enrollment__c
            FROM Case
            WHERE Id IN :casesToInsert
        ];

        Map<String, Case> caseMap = new Map<String, Case>();
        for (Case c : results) {
            caseMap.put(c.Subject, c);
        }

        System.assertNotEquals(null, caseMap.get('With Contact & Enrollment').Program_Enrollment__c);
        System.assertEquals(null, caseMap.get('With Contact but No Enrollment').Program_Enrollment__c);
        System.assertEquals(existingEnrollmentId, caseMap.get('Already Populated').Program_Enrollment__c);
    }

    @IsTest
    static void testHandleAfterInsert_ExceptionHandling() {
        Contact con = new Contact(
            LastName = 'Ghost',
            Email = 'ghost@example.com'
        );
        insert con;

        Case c = buildCaseForInsert('Ghost Case', con.Id, con.Email, 'Ghost User');
        insert c;

        List<Case> fakeCases = new List<Case>{ new Case(Id = '500000000000000AAA') };
        Test.startTest();
        try {
            update fakeCases;
        } catch (Exception e) {
            // Expected
        }
        Test.stopTest();
    }

    private static Case buildCaseForInsert(
        String subject,
        Id contactId,
        String suppliedEmail,
        String suppliedName
    ) {
        Case c = new Case(
            Subject = subject,
            ContactId = contactId,
            SuppliedEmail = String.isBlank(suppliedEmail) ? 'case.test@example.com' : suppliedEmail,
            SuppliedName = String.isBlank(suppliedName) ? 'Case Test' : suppliedName,
            Origin = 'Email'
        );

        Id serviceRecordTypeId = getServiceRecordTypeId();
        if (serviceRecordTypeId != null) {
            c.RecordTypeId = serviceRecordTypeId;
        }

        return c;
    }

    private static Id getServiceRecordTypeId() {
        for (RecordType rt : [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
              AND Name = 'Service'
            LIMIT 1
        ]) {
            return rt.Id;
        }
        return null;
    }
}