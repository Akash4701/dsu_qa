@isTest
public class AcademicTermControllerTest {

    @TestSetup
    static void makeData() {
        Id academicProgramRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Academic_Program').getRecordTypeId();
        
        Account program = new Account(Name = 'Test Program', RecordTypeId = academicProgramRTId);
        insert program;

        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Plan',
            hed__Account__c = program.Id
        );
        insert programPlan;

        Academic_Term__c academicTerm = new Academic_Term__c(
            Name = 'Fall 2024',
            Academic_Year__c = '2024',
            Season__c = 'Fall',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(90),
            IsActive__c = true
        );
        insert academicTerm;

        hed__Term__c term1 = new hed__Term__c(
            Name = 'Test Term 1',
            hed__Account__c = program.Id,
            Term_Reference__c  = 'Term 1',
            Program_Plan__c = programPlan.Id,
            Academic_Term__c = academicTerm.Id
        );
        hed__Term__c term2 = new hed__Term__c(
            Name = 'Test Term 2',
            hed__Account__c = program.Id,
            Term_Reference__c  = 'Term 1',
            Program_Plan__c = programPlan.Id
        );
        insert new List<hed__Term__c>{term1, term2};
    }

    @isTest
    static void testGetAcademicPrograms() {
        AcademicTermController.getAcademicPrograms();
    }

    @isTest
    static void testGetProgramPlans() {
        Account program = [SELECT Id FROM Account LIMIT 1];
        AcademicTermController.getProgramPlans(program.Id);
        AcademicTermController.getProgramPlans(null);
    }

    @isTest
    static void testGetTerms() {
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        AcademicTermController.getterms(plan.Id);
        AcademicTermController.getterms(null);
    }

    @isTest
    static void testGetTermsWithAcademicTerms() {
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        AcademicTermController.getTermsWithAcademicTerms(plan.Id);
        AcademicTermController.getTermsWithAcademicTerms(null);
    }

    @isTest
    static void testGetAcademicTerms() {
        AcademicTermController.getAcademicTerms();
    }

    @isTest
    static void testGetAcademicTermById() {
        Academic_Term__c term = [SELECT Id FROM Academic_Term__c LIMIT 1];
        AcademicTermController.getAcademicTermById(term.Id);
        
        try {
            AcademicTermController.getAcademicTermById(null);
        } catch (Exception e) {}
        
        try {
            AcademicTermController.getAcademicTermById(UserInfo.getUserId());
        } catch (Exception e) {}
    }

    @isTest
    static void testMapAcademicTermToTerm() {
        hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Academic_Term__c = null LIMIT 1];
        Academic_Term__c academicTerm = [SELECT Id FROM Academic_Term__c LIMIT 1];
        
        AcademicTermController.mapAcademicTermToTerm(term.Id, academicTerm.Id);
        
        try {
            AcademicTermController.mapAcademicTermToTerm(null, academicTerm.Id);
        } catch (Exception e) {}
        
        try {
            AcademicTermController.mapAcademicTermToTerm(UserInfo.getUserId(), academicTerm.Id);
        } catch (Exception e) {}
        
        try {
            AcademicTermController.mapAcademicTermToTerm(term.Id, UserInfo.getUserId());
        } catch (Exception e) {}
    }

    @isTest
    static void testRemoveAcademicTermMapping() {
        hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Academic_Term__c != null LIMIT 1];
        
        AcademicTermController.removeAcademicTermMapping(term.Id);
        
        try {
            AcademicTermController.removeAcademicTermMapping(null);
        } catch (Exception e) {}
        
        try {
            AcademicTermController.removeAcademicTermMapping(UserInfo.getUserId());
        } catch (Exception e) {}
    }

    @isTest
    static void testCreateAcademicTerm() {
        try{
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        String termData = '{"Name":"Spring 2025","Academic_Year__c":"2025","Season__c":"Spring",' +
                         '"Start_Date__c":"2025-01-15","End_Date__c":"2025-05-15","IsActive__c":true}';
        
        AcademicTermController.createAcademicTerm(termData, term.Id);
        AcademicTermController.createAcademicTerm(termData, null);
        
        String termDataWithOptional = '{"Name":"Summer 2025","Academic_Year__c":"2025","Season__c":"Summer",' +
                                     '"Start_Date__c":"2025-06-01","End_Date__c":"2025-08-15","IsActive__c":true,' +
                                     '"Registration_Open_Date__c":"2025-05-01","Registration_Close_Date__c":"2025-05-30",' +
                                     '"Last_Modified_Date__c":"2025-05-15","Late_Registration_Date__c":"2025-06-05"}';
        
        AcademicTermController.createAcademicTerm(termDataWithOptional, null);
        
        try {
            AcademicTermController.createAcademicTerm('', null);
        } catch (Exception e) {}
        
        try {
            String invalidData = '{"Name":"Invalid","Season__c":"Fall"}';
            AcademicTermController.createAcademicTerm(invalidData, null);
        } catch (Exception e) {}
        
        try {
            String badDates = '{"Name":"Bad Dates","Academic_Year__c":"2025","Season__c":"Fall",' +
                             '"Start_Date__c":"2025-05-15","End_Date__c":"2025-01-15","IsActive__c":true}';
            AcademicTermController.createAcademicTerm(badDates, null);
        } catch (Exception e) {}
        
        try {
            String duplicate = '{"Name":"Fall 2024","Academic_Year__c":"2024","Season__c":"Fall",' +
                              '"Start_Date__c":"2024-08-15","End_Date__c":"2024-12-15","IsActive__c":true}';
            AcademicTermController.createAcademicTerm(duplicate, null);
        } catch (Exception e) {}}
        catch(exception e){}
    }

    @isTest
    static void testUpdateAcademicTerm() {
        Academic_Term__c term = [SELECT Id FROM Academic_Term__c LIMIT 1];
        
        String termData = '{"Name":"Updated Fall 2024","Academic_Year__c":"2024","Season__c":"Fall",' +
                         '"Start_Date__c":"2024-08-20","End_Date__c":"2024-12-20","IsActive__c":false}';
        
        AcademicTermController.updateAcademicTerm(termData, term.Id);
        
        String termDataWithNulls = '{"Name":"Updated Again","Academic_Year__c":"2024","Season__c":"Fall",' +
                                  '"Start_Date__c":"2024-08-25","End_Date__c":"2024-12-25","IsActive__c":true,' +
                                  '"Registration_Open_Date__c":"","Registration_Close_Date__c":"",' +
                                  '"Last_Modified_Date__c":"","Late_Registration_Date__c":""}';
        
        AcademicTermController.updateAcademicTerm(termDataWithNulls, term.Id);
        
        try {
            AcademicTermController.updateAcademicTerm('', term.Id);
        } catch (Exception e) {}
        
        try {
            AcademicTermController.updateAcademicTerm(termData, null);
        } catch (Exception e) {}
        
        try {
            AcademicTermController.updateAcademicTerm(termData, UserInfo.getUserId());
        } catch (Exception e) {}
        
        try {
            String invalidData = '{"Name":"Invalid"}';
            AcademicTermController.updateAcademicTerm(invalidData, term.Id);
        } catch (Exception e) {}
        
        try {
            String badDates = '{"Name":"Bad Dates","Academic_Year__c":"2024","Season__c":"Fall",' +
                             '"Start_Date__c":"2024-12-15","End_Date__c":"2024-08-15","IsActive__c":true}';
            AcademicTermController.updateAcademicTerm(badDates, term.Id);
        } catch (Exception e) {}
        
        Academic_Term__c anotherTerm = new Academic_Term__c(
            Name = 'Winter 2024',
            Academic_Year__c = '2024',
            Season__c = 'Winter',
            Start_Date__c = Date.today().addDays(200),
            End_Date__c = Date.today().addDays(290),
            IsActive__c = true
        );
        insert anotherTerm;
        
        try {
            String duplicate = '{"Name":"Winter Duplicate","Academic_Year__c":"2024","Season__c":"Winter",' +
                              '"Start_Date__c":"2024-01-15","End_Date__c":"2024-05-15","IsActive__c":true}';
            AcademicTermController.updateAcademicTerm(duplicate, term.Id);
        } catch (Exception e) {}
    }

    @isTest
    static void testGetUnmappedAcademicTerms() {
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        
        AcademicTermController.getUnmappedAcademicTerms(plan.Id);
        AcademicTermController.getUnmappedAcademicTerms(null);
    }
}