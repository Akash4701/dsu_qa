@isTest
public class AffiliationHandlerTest {
    
    @TestSetup
    static void makeData() {
        // Create Institute (Parent of Parent)
        Account institute = new Account(
            Name = 'Test Institute',
            Institute_Code__c = '1AB'
        );
        insert institute;
        
        // Create Department (Parent)
        Account department = new Account(
            Name = 'Computer Science Department',
            ParentId = institute.Id
        );
        insert department;
        
        // Create Program (Account)
        Account program = new Account(
            Name = 'Bachelor of Computer Application',
            Alias__c = 'CS',
            ParentId = department.Id
        );
        insert program;
        
        // Create Program Plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'BCA-JUL-2025',
            hed__Account__c = program.Id,
            Batch__c = '2025',
            Intake_Number__c = 2,
            Sequence_Number__c = 1
        );
        insert programPlan;
        
        // Create another Program Plan for different scenarios
        hed__Program_Plan__c programPlan2 = new hed__Program_Plan__c(
            Name = 'MBA-DEC-2025',
            hed__Account__c = program.Id,
            Batch__c = '2025',
            Intake_Number__c = 1,
            Sequence_Number__c = null
        );
        insert programPlan2;
        
        // Create Terms
        hed__Term__c term1 = new hed__Term__c(
            Name = 'Semester 1',
            hed__Account__c = program.Id,
            Term_Reference__c = 'Semester 1',
            Program_Plan__c = programPlan.Id,
            hed__Start_Date__c = Date.newInstance(2025, 8, 1),
            hed__End_Date__c = Date.newInstance(2026, 1, 29)
        );
        insert term1;
        
        hed__Term__c term2 = new hed__Term__c(
            Name = 'Semester 2',
            hed__Account__c = program.Id,
            Term_Reference__c = 'Semester 2',
            Program_Plan__c = programPlan2.Id,
            hed__Start_Date__c = Date.newInstance(2025, 8, 1),
            hed__End_Date__c = Date.newInstance(2026, 1, 29)
        );
        insert term2;
        
        // Create Contacts
        Contact contact1 = new Contact(
            FirstName = 'John',
            LastName = 'Doe'
        );
        insert contact1;
        
        Contact contact2 = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith'
        );
        insert contact2;
        
        // Create Applications
        // Program_Plan__c is set (as it always is on real Applications - see
        // ApplicantServiceV3.cls) so that updating these records in tests doesn't hit the
        // unguarded "WHERE Id = :programPlanID" query in
        // IndividualApplicationTriggerHandler.handleAfterUpdate when Program_Plan__c is null.
        Application__c app1 = new Application__c(
            Status__c = 'Approved for USN',
            Fee_Preference__c = 'Semester-wise fee',
            External_Application_Number__c = 'RD62FG',
            Program_Level__c = 'UG',
            Program_Plan__c = programPlan.Id
        );
        insert app1;

        Application__c app2 = new Application__c(
            Status__c = 'Approved for USN',
            Fee_Preference__c = 'Total program fee',
            External_Application_Number__c = 'RD632FG',
            Program_Level__c = 'UG',
            Program_Plan__c = programPlan.Id
        );
        insert app2;

        Application__c app3 = new Application__c(
            Status__c = 'Approved for USN',
            Fee_Preference__c = 'Year-wise fee',
            External_Application_Number__c = 'RD72FG',
            Program_Level__c = 'UG',
            Program_Plan__c = programPlan.Id
        );
        insert app3;
        
        // Create Fee Types
        Fee_Type__c feeType1 = new Fee_Type__c(
            Fee_head__c = 'Semester Fee',
            Program__c = program.Id,
            Semester__c = term1.Id,
            Amount__c = 50000,
            Fee_Preference__c = 'Semester-wise fee'
        );
        insert feeType1;
        
        Fee_Type__c feeType2 = new Fee_Type__c(
            Fee_head__c = 'Semester Fee',
            Program__c = program.Id,
            Semester__c = term1.Id,
            Amount__c = 200000,
            Fee_Preference__c = 'Total program fee'
        );
        insert feeType2;
        
        Fee_Type__c feeType3 = new Fee_Type__c(
            Fee_head__c = 'Semester Fee',
            Program__c = program.Id,
            Semester__c = term1.Id,
            Amount__c = 100000,
            Fee_Preference__c = 'Year-wise fee'
        );
        insert feeType3;
    }
    
    @isTest
    static void testGenerateRollNumbersSuccess() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Application__c app = [SELECT Id FROM Application__c WHERE Status__c = 'Approved for USN' LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id
        );
        
        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        
        Test.startTest();
        AffiliationHandler.generateRollNumbers(affiliations);
        Test.stopTest();
    }
    
    @isTest
    static void testGenerateRollNumbersWithNullSequence() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'MBA-DEC-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'Jane' LIMIT 1];
        Application__c app = [SELECT Id FROM Application__c WHERE Status__c = 'Approved for USN' LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id
        );
        
        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        
        Test.startTest();
        AffiliationHandler.generateRollNumbers(affiliations);
        Test.stopTest();
    }
    
    @isTest
    static void testGenerateRollNumbersWithExistingRollNumber() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Application__c app = [SELECT Id FROM Application__c WHERE Status__c = 'Approved for USN' LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id,
            Roll_Number__c = 'EXISTING123'
        );
        
        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        
        Test.startTest();
        AffiliationHandler.generateRollNumbers(affiliations);
        Test.stopTest();
    }
    
    @isTest
    static void testGenerateRollNumbersWithoutDEBID() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Application__c app = [SELECT Id FROM Application__c WHERE Status__c = 'Approved for USN' LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id
        );
        
        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        
        Test.startTest();
        AffiliationHandler.generateRollNumbers(affiliations);
        Test.stopTest();
    }
    
    @isTest
    static void testGenerateRollNumbersMultipleAffiliations() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        List<Contact> contacts = [SELECT Id FROM Contact];
        List<Application__c> apps = [SELECT Id FROM Application__c WHERE Status__c = 'Approved for USN'];
        
        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>();
        
        for (Integer i = 0; i < contacts.size() && i < apps.size(); i++) {
            hed__Affiliation__c aff = new hed__Affiliation__c(
                hed__Contact__c = contacts[i].Id,
                Program_Plan__c = programPlan.Id,
                Individual_Application__c = apps[i].Id
            );
            affiliations.add(aff);
        }
        
        Test.startTest();
        AffiliationHandler.generateRollNumbers(affiliations);
        Test.stopTest();
    }
    
    @isTest
    static void testMarkPrimaryAffiliationSuccess() {
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Is_Primary__c = false
        );
        insert aff;
        
        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        
        Test.startTest();
        AffiliationHandler.MarkPrimaryAffiliation(affiliations);
        Test.stopTest();
    }
    
    @isTest
    static void testMarkPrimaryAffiliationWithSiblings() {
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        
        // Create existing affiliation
        hed__Affiliation__c existingAff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Is_Primary__c = false
        );
        insert existingAff;
        
        // Create program enrollment for existing affiliation
        hed__Program_Enrollment__c enrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = contact.Id,
            hed__Affiliation__c = existingAff.Id,
            hed__Program_Plan__c = programPlan.Id
        );
        insert enrollment;
        
        // Create new affiliation
        hed__Affiliation__c newAff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Is_Primary__c = false
        );
        insert newAff;
        
        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{newAff};
        
        Test.startTest();
        AffiliationHandler.MarkPrimaryAffiliation(affiliations);
        Test.stopTest();
    }
    
    @isTest
    static void testMarkPrimaryAffiliationWithoutContact() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            Program_Plan__c = programPlan.Id,
            Is_Primary__c = false
        );
        insert aff;
        
        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        
        Test.startTest();
        AffiliationHandler.MarkPrimaryAffiliation(affiliations);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateApplicationSubstatusEmailActive() {
        Application__c app = [SELECT Id FROM Application__c WHERE External_Application_Number__c = 'RD62FG' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id,
            Is_DSU_Email_Active__c = true,
            Approval_Status__c = 'Approved'
        );
        insert aff;

        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        Map<Id, hed__Affiliation__c> oldMap = new Map<Id, hed__Affiliation__c>();

        Test.startTest();
        AffiliationHandler.UpdateApplicationSubstatus(affiliations, oldMap);
        Test.stopTest();

        Application__c updatedApp = [SELECT Status__c, Sub_Status__c FROM Application__c WHERE Id = :app.Id];
        // Sub_Status__c's picklist value is 'Email Id Active' (lowercase d) - the org accepts the
        // code's 'Email ID Active' literal via case-insensitive picklist matching and normalizes it,
        // so this asserts what actually gets stored, not the code's literal casing.
        System.assertEquals('Email Id Active', updatedApp.Sub_Status__c,
            'Approved + DSU Email active should set Sub_Status to Email Id Active');
        System.assertEquals('Approved for USN', updatedApp.Status__c,
            'Status__c is a manual process and must never be touched by Affiliation approval');
    }

    @isTest
    static void testUpdateApplicationSubstatusEmailActiveNotApproved() {
        Application__c app = [SELECT Id FROM Application__c WHERE External_Application_Number__c = 'RD632FG' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id,
            Is_DSU_Email_Active__c = true,
            Approval_Status__c = 'Pending'
        );

        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        Map<Id, hed__Affiliation__c> oldMap = new Map<Id, hed__Affiliation__c>();

        Test.startTest();
        AffiliationHandler.UpdateApplicationSubstatus(affiliations, oldMap);
        Test.stopTest();

        // addError() registers immediately on the in-memory sObject, no DML needed to observe it.
        System.assert(aff.hasErrors(),
            'DSU Email active without Registrar approval should be blocked with a validation error');

        Application__c unchangedApp = [SELECT Status__c, Sub_Status__c FROM Application__c WHERE Id = :app.Id];
        System.assertEquals(null, unchangedApp.Sub_Status__c,
            'Sub_Status should stay unset when the Affiliation is not yet approved');
        System.assertEquals('Approved for USN', unchangedApp.Status__c,
            'Status should stay unchanged when the Affiliation is not yet approved');
    }

    @isTest
    static void testUpdateApplicationSubstatusApprovedOnly() {
        Application__c app = [SELECT Id FROM Application__c WHERE External_Application_Number__c = 'RD72FG' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id,
            Is_DSU_Email_Active__c = false,
            Approval_Status__c = 'Approved'
        );
        insert aff;

        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        Map<Id, hed__Affiliation__c> oldMap = new Map<Id, hed__Affiliation__c>();

        Test.startTest();
        AffiliationHandler.UpdateApplicationSubstatus(affiliations, oldMap);
        Test.stopTest();

        Application__c updatedApp = [SELECT Status__c, Sub_Status__c FROM Application__c WHERE Id = :app.Id];
        System.assertEquals('Registrar Approved', updatedApp.Sub_Status__c,
            'Approved without DSU Email active should set Sub_Status to Registrar Approved');
        System.assertEquals('Approved for USN', updatedApp.Status__c,
            'Status__c is a manual process and must never be touched by Affiliation approval');
    }

    @isTest
    static void testUpdateApplicationSubstatusWithoutApplication() {
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Is_DSU_Email_Active__c = true,
            Approval_Status__c = 'Approved'
        );
        insert aff;

        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        Map<Id, hed__Affiliation__c> oldMap = new Map<Id, hed__Affiliation__c>();

        Test.startTest();
        AffiliationHandler.UpdateApplicationSubstatus(affiliations, oldMap);
        Test.stopTest();

        // No Individual_Application__c on the Affiliation - method must no-op, not throw.
        System.assert(!aff.hasErrors(), 'An Affiliation without a linked Application should not be touched at all');
    }

    @isTest
    static void testUpdateApplicationSubstatusNeverTouchesStatus() {
        // Status__c is a manual process owned by staff - Registrar approval on the Affiliation
        // must only ever move Sub_Status__c, regardless of where Status__c currently sits.
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];

        Application__c app = new Application__c(
            Status__c = 'Admitted',
            External_Application_Number__c = 'GUARD001',
            Program_Level__c = 'UG',
            Program_Plan__c = programPlan.Id
        );
        insert app;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id,
            Is_DSU_Email_Active__c = false,
            Approval_Status__c = 'Approved'
        );
        insert aff;

        List<hed__Affiliation__c> affiliations = new List<hed__Affiliation__c>{aff};
        Map<Id, hed__Affiliation__c> oldMap = new Map<Id, hed__Affiliation__c>();

        Test.startTest();
        AffiliationHandler.UpdateApplicationSubstatus(affiliations, oldMap);
        Test.stopTest();

        Application__c unchangedApp = [SELECT Status__c, Sub_Status__c FROM Application__c WHERE Id = :app.Id];
        System.assertEquals('Admitted', unchangedApp.Status__c,
            'Status__c must never be changed by Affiliation approval - it is a manual process');
        System.assertEquals('Registrar Approved', unchangedApp.Sub_Status__c,
            'Sub_Status should still update independently of Status__c');
    }
    
    @isTest
    static void testCreateFeeAssignmentsSemesterWise() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Application__c app = [SELECT Id FROM Application__c WHERE Fee_Preference__c = 'Semester-wise fee' LIMIT 1];
        Account program = [SELECT Id FROM Account WHERE Name = 'Bachelor of Computer Application' LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id,
            hed__Account__c = program.Id
        );
        insert aff;
        
        List<Id> affiliationIds = new List<Id>{aff.Id};
        
        Test.startTest();
        AffiliationHandler.createFeeAssignmentsFromAffiliations(affiliationIds);
        Test.stopTest();
    }
    
    @isTest
    static void testCreateFeeAssignmentsTotalProgramFee() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Application__c app = [SELECT Id FROM Application__c WHERE Fee_Preference__c = 'Total program fee' LIMIT 1];
        Account program = [SELECT Id FROM Account WHERE Name = 'Bachelor of Computer Application' LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id,
            hed__Account__c = program.Id
        );
        insert aff;
        
        List<Id> affiliationIds = new List<Id>{aff.Id};
        
        Test.startTest();
        AffiliationHandler.createFeeAssignmentsFromAffiliations(affiliationIds);
        Test.stopTest();
    }
    
    @isTest
    static void testCreateFeeAssignmentsYearWise() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Application__c app = [SELECT Id FROM Application__c WHERE Fee_Preference__c = 'Year-wise fee' LIMIT 1];
        Account program = [SELECT Id FROM Account WHERE Name = 'Bachelor of Computer Application' LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id,
            hed__Account__c = program.Id
        );
        insert aff;
        
        List<Id> affiliationIds = new List<Id>{aff.Id};
        
        Test.startTest();
        AffiliationHandler.createFeeAssignmentsFromAffiliations(affiliationIds);
        Test.stopTest();
    }
    
    @isTest
    static void testCreateFeeAssignmentsEmptyList() {
        List<Id> affiliationIds = new List<Id>();
        
        Test.startTest();
        AffiliationHandler.createFeeAssignmentsFromAffiliations(affiliationIds);
        Test.stopTest();
    }
    
    @isTest
    static void testCreateFeeAssignmentsNullList() {
        Test.startTest();
        AffiliationHandler.createFeeAssignmentsFromAffiliations(null);
        Test.stopTest();
    }
    
    @isTest
    static void testCreateFeeAssignmentsWithoutFeePreference() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Account program = [SELECT Id FROM Account WHERE Name = 'Bachelor of Computer Application' LIMIT 1];
        
        Application__c appWithoutPref = new Application__c(
            Status__c = 'Approved for USN',
            External_Application_Number__c = 'RRD62FG',
            Program_Level__c = 'UG'
        );
        insert appWithoutPref;
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = appWithoutPref.Id,
            hed__Account__c = program.Id
        );
        insert aff;
        
        List<Id> affiliationIds = new List<Id>{aff.Id};
        
        Test.startTest();
        AffiliationHandler.createFeeAssignmentsFromAffiliations(affiliationIds);
        Test.stopTest();
    }
    
    @isTest
    static void testCreateFeeAssignmentsWithoutAccount() {
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE Name = 'BCA-JUL-2025' LIMIT 1];
        Contact contact = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Application__c app = [SELECT Id FROM Application__c WHERE Fee_Preference__c = 'Semester-wise fee' LIMIT 1];
        
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = contact.Id,
            Program_Plan__c = programPlan.Id,
            Individual_Application__c = app.Id
        );
        insert aff;
        
        List<Id> affiliationIds = new List<Id>{aff.Id};
        
        Test.startTest();
        AffiliationHandler.createFeeAssignmentsFromAffiliations(affiliationIds);
        Test.stopTest();
    }
    
    
    @isTest
    static void testEmailInnerClass() {
        Test.startTest();
        AffiliationHandler.email emailObj = new AffiliationHandler.email();
        String dsuemail = emailObj.dsuemail;
        Test.stopTest();
    }
}