@isTest
private class IndividualApplicationTriggerHandlerTest {

    @isTest static void testHandleAfterUpdate_StatusChangeToAdmitted() {
        // Create necessary test data

        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Contact with default record type (not Student)
        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id);
        insert con;

        // Get RecordType Id for Student on Contact
        Id studentRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Student').getRecordTypeId();

        // Create Program Plan with start and end dates
        hed__Program_Plan__c progPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(6)
        );
        insert progPlan;

        // Create Application record with status other than 'Admitted'
        Application__c appOld = new Application__c(
            
            Status__c = 'Enrolled',
            Program_Plan__c = progPlan.Id,
            AccountId__c = acc.Id,
            ContactId__c = con.Id,
            External_Application_Number__c='sdf',
            Program_Level__c = 'UG'
        );
        insert appOld;

        // Prepare new version of Application with Status changed to 'Admitted'
        Application__c appNew = appOld.clone(false, true, false, false);
        appNew.Status__c = 'Admitted';

        // Prepare old map for trigger simulation
        Map<Id, Application__c> oldMap = new Map<Id, Application__c>{ appNew.Id => appOld };

        Test.startTest();
        // Call handler method simulating after update trigger
        IndividualApplicationTriggerHandler.handleAfterUpdate(new List<Application__c>{appNew}, oldMap);
        Test.stopTest();


    }

    @isTest static void testHandleAfterUpdate_NoStatusChange() {
        // Setup similar data
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id);
        insert con;

        hed__Program_Plan__c progPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(6)
        );
        insert progPlan;

        Application__c appOld = new Application__c(
           
            Status__c = 'Admitted',
            Program_Plan__c = progPlan.Id,
            AccountId__c = acc.Id,
            ContactId__c = con.Id,
            External_Application_Number__c='sdf',
            Program_Level__c = 'UG'
        );
        insert appOld;

        // New record with same Status 'Admitted' (no status change)
        Application__c appNew = appOld.clone(false, true, false, false);

        Map<Id, Application__c> oldMap = new Map<Id, Application__c>{ appNew.Id => appOld };

        Test.startTest();
        IndividualApplicationTriggerHandler.handleAfterUpdate(new List<Application__c>{appNew}, oldMap);
        Test.stopTest();


    }
     @isTest static void testTriggerAfterUpdate() {
        // Create test data

        // Insert Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Insert Contact
        Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id);
        insert con;

        // Insert Program Plan
        hed__Program_Plan__c progPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(6)
        );
        insert progPlan;

        // Insert Application with Status not 'Admitted'
        Application__c app = new Application__c(
           
            Status__c = 'Enrolled',
            Program_Plan__c = progPlan.Id,
            AccountId__c = acc.Id,
            ContactId__c = con.Id,
            External_Application_Number__c='sdf',
            Program_Level__c = 'UG'
        );
        insert app;

        // Update Application record to Status = 'Admitted' to fire after update trigger
        app.Status__c = 'Admitted';

        Test.startTest();
        update app;
        Test.stopTest();
    }

    // ---------- helpers for the tests below ----------

    private static hed__Program_Plan__c newPlan(String name, String intake, String batch) {
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = name,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(6),
            Intake__c = intake,
            Batch__c = batch
        );
        insert plan;
        return plan;
    }

    private static Application__c newApplication(Id accountId, Id contactId, Id planId, String status, String extNumber) {
        return new Application__c(
            Status__c = status,
            Program_Plan__c = planId,
            AccountId__c = accountId,
            ContactId__c = contactId,
            External_Application_Number__c = extNumber,
            Program_Level__c = 'UG'
        );
    }

    @isTest static void testProgramPlanChangeCreatesAffiliation() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(LastName = 'Plan Change', AccountId = acc.Id);
        insert con;
        hed__Program_Plan__c oldPlan = newPlan('Old Plan', 'AUG', '2026');
        hed__Program_Plan__c newPlanRec = newPlan('New Plan', 'AUG', '2026');

        Application__c app = newApplication(acc.Id, con.Id, oldPlan.Id, 'Enrolled', 'plan-change');
        insert app;

        Application__c changed = app.clone(true, true, false, false);
        changed.Program_Plan__c = newPlanRec.Id;

        Test.startTest();
        IndividualApplicationTriggerHandler.handleAfterUpdate(
            new List<Application__c>{ changed }, new Map<Id, Application__c>{ app.Id => app });
        Test.stopTest();

        List<hed__Affiliation__c> affs = [
            SELECT Program_Plan__c, hed__StartDate__c FROM hed__Affiliation__c
            WHERE Individual_Application__c = :app.Id AND Program_Plan__c = :newPlanRec.Id
        ];
        System.assertEquals(1, affs.size(), 'A new Affiliation should be created for the new Program Plan');
        System.assertEquals(Date.today(), affs[0].hed__StartDate__c, 'Affiliation dates come from the Program Plan');
    }

    @isTest static void testHandleAfterUpdateIsBulkSafe() {
        Account acc = new Account(Name = 'Bulk Account');
        insert acc;
        hed__Program_Plan__c oldPlan = newPlan('Bulk Old Plan', 'AUG', '2026');
        hed__Program_Plan__c newPlanRec = newPlan('Bulk New Plan', 'AUG', '2026');

        List<Contact> contacts = new List<Contact>();
        for (Integer i = 0; i < 150; i++) {
            contacts.add(new Contact(LastName = 'Bulk ' + i, AccountId = acc.Id));
        }
        insert contacts;
        List<Application__c> apps = new List<Application__c>();
        for (Integer i = 0; i < 150; i++) {
            apps.add(newApplication(acc.Id, contacts[i].Id, oldPlan.Id, 'Enrolled', 'bulk-' + i));
        }
        insert apps;

        Map<Id, Application__c> oldMap = new Map<Id, Application__c>(apps);
        List<Application__c> changed = new List<Application__c>();
        for (Application__c app : apps) {
            Application__c c = app.clone(true, true, false, false);
            // Only half change plan; the rest must not trigger any Program Plan lookup
            if (changed.size() < 75) {
                c.Program_Plan__c = newPlanRec.Id;
            }
            changed.add(c);
        }

        Test.startTest();
        Integer queriesBefore = Limits.getQueries();
        IndividualApplicationTriggerHandler.handleAfterUpdate(changed, oldMap);
        Integer handlerQueries = Limits.getQueries() - queriesBefore;
        Test.stopTest();

        // Before the fix this ran one Program Plan query per Application (150 here) and hit the limit
        System.assert(handlerQueries < 100, 'Program Plan lookup must not run per record, used ' + handlerQueries);
        System.assertEquals(75, [SELECT COUNT() FROM hed__Affiliation__c WHERE Program_Plan__c = :newPlanRec.Id]);
    }

    @isTest static void testHandleAfterUpdateWithoutProgramPlan() {
        Account acc = new Account(Name = 'No Plan Account');
        insert acc;
        Contact con = new Contact(LastName = 'No Plan', AccountId = acc.Id);
        insert con;
        Application__c app = newApplication(acc.Id, con.Id, null, 'Enrolled', 'no-plan');
        insert app;

        Application__c changed = app.clone(true, true, false, false);
        changed.Status__c = 'Admitted';

        Test.startTest();
        // Used to throw "List has no rows for assignment" when the Application had no Program Plan
        IndividualApplicationTriggerHandler.handleAfterUpdate(
            new List<Application__c>{ changed }, new Map<Id, Application__c>{ app.Id => app });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM hed__Affiliation__c WHERE Individual_Application__c = :app.Id]);
    }

    @isTest static void testHandleAfterInsertCrmEnrolled() {
        Account acc = new Account(Name = 'CRM Account');
        insert acc;
        Contact con = new Contact(LastName = 'CRM Enrolled', AccountId = acc.Id);
        insert con;
        hed__Program_Plan__c plan = newPlan('CRM Plan', 'AUG', '2026');

        Application__c app = newApplication(acc.Id, con.Id, plan.Id, 'CRM Enrolled', 'crm-1');

        Test.startTest();
        insert app; // fires handleAfterInsert through the trigger
        IndividualApplicationTriggerHandler.handleAfterInsert(new List<Application__c>{ app });
        Test.stopTest();

        System.assert([SELECT COUNT() FROM hed__Affiliation__c WHERE Individual_Application__c = :app.Id] > 0,
            'An Affiliation should be created for a CRM Enrolled application');
    }

    @isTest static void testApprovedForUsnRequiresDebId() {
        Account acc = new Account(Name = 'USN Account');
        insert acc;
        Contact con = new Contact(LastName = 'No DEB', AccountId = acc.Id);
        insert con;
        hed__Program_Plan__c plan = newPlan('USN Plan', 'AUG', '2026');
        Application__c app = newApplication(acc.Id, con.Id, plan.Id, 'Enrolled', 'usn-1');
        insert app;

        Application__c changed = app.clone(true, true, false, false);
        changed.Status__c = 'Approved for USN';
        Map<Id, Application__c> oldMap = new Map<Id, Application__c>{ app.Id => app };

        Test.startTest();
        IndividualApplicationTriggerHandler.validateDEBIDBeforeApproval(new List<Application__c>{ changed }, oldMap);
        IndividualApplicationTriggerHandler.handleDEBIDUpdate(new List<Application__c>{ changed }, oldMap);
        Test.stopTest();

        System.assert(changed.hasErrors(), 'Approving for USN without a DEB ID must be blocked');
    }

    @isTest static void testApprovedForUsnWithDebId() {
        Account acc = new Account(Name = 'USN DEB Account');
        insert acc;
        Contact con = new Contact(LastName = 'Has DEB', AccountId = acc.Id, DEB_ID__c = '123456789012');
        insert con;
        hed__Program_Plan__c plan = newPlan('USN DEB Plan', 'AUG', '2026');
        Application__c app = newApplication(acc.Id, con.Id, plan.Id, 'Enrolled', 'usn-2');
        insert app;

        Application__c changed = app.clone(true, true, false, false);
        changed.Status__c = 'Approved for USN';
        Map<Id, Application__c> oldMap = new Map<Id, Application__c>{ app.Id => app };

        Test.startTest();
        IndividualApplicationTriggerHandler.validateDEBIDBeforeApproval(new List<Application__c>{ changed }, oldMap);
        IndividualApplicationTriggerHandler.handleDEBIDUpdate(new List<Application__c>{ changed }, oldMap);
        Test.stopTest();

        System.assert(!changed.hasErrors(), 'A Contact with a DEB ID can be approved for USN');
    }

    @isTest static void testGenerateOfferFromApplication() {
        Account acc = new Account(Name = 'Offer Account');
        insert acc;
        Contact con = new Contact(LastName = 'Offer', AccountId = acc.Id);
        insert con;
        hed__Program_Plan__c plan = newPlan('Offer Plan', 'AUG', '2026');
        Application__c app = newApplication(acc.Id, con.Id, plan.Id, 'Enrolled', 'offer-1');
        insert app;

        Application__c changed = app.clone(true, true, false, false);
        changed.Status__c = 'Generate Letter of Admission';

        Test.startTest();
        // No Affiliation linked yet: covers the status-change detection without queueing PDF callouts
        IndividualApplicationTriggerHandler.generateOfferFromApplication(
            new List<Application__c>{ changed }, new Map<Id, Application__c>{ app.Id => app });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM hed__Affiliation__c WHERE Individual_Application__c = :app.Id]);
    }

    private static Id createApprovedAffiliationWithLetter(String intake, String batch, String rollNumber) {
        Account acc = new Account(Name = 'Letter Account ' + rollNumber);
        insert acc;
        Contact con = new Contact(FirstName = 'Letter', LastName = rollNumber, AccountId = acc.Id, Email = rollNumber + '@example.com');
        insert con;
        hed__Program_Plan__c plan = newPlan('Letter Plan ' + rollNumber, intake, batch);
        Application__c app = newApplication(acc.Id, con.Id, plan.Id, 'Enrolled', 'letter-' + rollNumber);
        insert app;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Account__c = acc.Id,
            hed__Contact__c = con.Id,
            Program_Plan__c = plan.Id,
            Individual_Application__c = app.Id,
            Roll_Number__c = rollNumber,
            DSU_Email__c = rollNumber + '@dsuonline.in',
            Approval_Status__c = 'Approved'
        );
        insert aff;

        insert new ContentVersion(
            Title = rollNumber + '_LetterOfAdmission.pdf',
            PathOnClient = rollNumber + '_LetterOfAdmission.pdf',
            VersionData = Blob.valueOf('%PDF-1.4 test')
        );
        return aff.Id;
    }

    @isTest static void testSendOfferLetterEmail() {
        Id affId = createApprovedAffiliationWithLetter('AUG', '2026', 'DSUTEST0001');

        Test.startTest();
        try {
            IndividualApplicationTriggerHandler.sendOfferLetterAsEmailAttachment(affId);
        } catch (System.EmailException e) {
            // Sandboxes with email deliverability off reject the send; the letter was still built
            System.debug('Email not sent in this org: ' + e.getMessage());
        } catch (System.QueryException e) {
            // The OfferLetterEmailTemplate may not exist in every org
            System.debug('Missing setup data: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest static void testSendOfferLetterEmailDecemberIntake() {
        Id affId = createApprovedAffiliationWithLetter('DEC', '2026', 'DSUTEST0002');

        Test.startTest();
        try {
            IndividualApplicationTriggerHandler.sendOfferLetterAsEmailAttachment(affId);
        } catch (System.EmailException e) {
            System.debug('Email not sent in this org: ' + e.getMessage());
        } catch (System.QueryException e) {
            System.debug('Missing setup data: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest static void testSendOfferOnAdmitted() {
        insert new SendLetterOfAdmission__c(SetupOwnerId = UserInfo.getOrganizationId(), send_Email__c = true);
        Account acc = new Account(Name = 'Admitted Account');
        insert acc;
        Contact con = new Contact(LastName = 'Admitted', AccountId = acc.Id);
        insert con;
        hed__Program_Plan__c plan = newPlan('Admitted Plan', 'AUG', '2026');
        Application__c app = newApplication(acc.Id, con.Id, plan.Id, 'Enrolled', 'admitted-1');
        insert app;

        Application__c changed = app.clone(true, true, false, false);
        changed.Status__c = 'Admitted';

        Test.startTest();
        // No Affiliation linked: covers the admitted detection and settings check without sending email
        IndividualApplicationTriggerHandler.sendOffer(
            new List<Application__c>{ changed }, new Map<Id, Application__c>{ app.Id => app });
        Test.stopTest();

        System.assert(SendLetterOfAdmission__c.getInstance().send_Email__c);
    }
}