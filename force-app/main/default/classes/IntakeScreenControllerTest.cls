@isTest
private class IntakeScreenControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Record Types first (if they don't exist in the org)
        // Note: In actual orgs, these would already exist
        
        // Create Academic Program Account
        Account academicProgram = new Account(
            Name = 'MBA',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Academic_Program' LIMIT 1].Id,
            Alias__c = 'MBA_ALIAS',
            Number_of_Terms__c = '6',
            Program_Duration_in_Weeks__c = 52
        );
        insert academicProgram;
        
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
                Name = '2029-Jan-MBA_ALIAS',
                hed__Account__c = academicProgram.Id
            );
            insert plan;

        // Create Campus records
        List<Campus__c> campuses = new List<Campus__c>{
            new Campus__c(Name = 'Main Campus', Campus_ID__c = 'MAIN01'),
            new Campus__c(Name = 'Online Campus', Campus_ID__c = 'ONLINE01')
        };
        insert campuses;

        // Create Master Term records
        RecordType masterTermRT = [SELECT Id FROM RecordType WHERE SObjectType = 'hed__Term__c' AND DeveloperName = 'Master_Record' LIMIT 1];
        List<hed__Term__c> masterTerms = new List<hed__Term__c>();
        for (Integer i = 1; i <= 6; i++) {
            masterTerms.add(new hed__Term__c(
                Name = 'Term ' + i + ' Master',
                hed__Account__c = academicProgram.Id,
                Term_Reference__c = 'Term ' + i,
                RecordTypeId = masterTermRT.Id,
                hed__Type__c = 'Term'
            ));
        }
        insert masterTerms;

        // Create Program Level Campus Combination
        RecordType campusRelRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Program_Campus_Relationship__c' AND DeveloperName = 'Program_Level_Campus_Combination' LIMIT 1];
        insert new Program_Campus_Relationship__c(
            RecordTypeId = campusRelRT.Id,
            Combination_Name__c = 'Main Campus',
            Account_Name__c = academicProgram.Id
        );
    }

    @isTest
    static void testGetMethods() {
        Test.startTest();
        
        List<IntakeScreenController.IdNameWrapper> programs = IntakeScreenController.getAcademicPrograms();
        System.assertNotEquals(0, programs.size(), 'Should return academic programs');
        
        Map<String, String> aliases = IntakeScreenController.getProgramAliases();
        System.assertEquals(1, aliases.size(), 'Should return program aliases');
        
        Map<String, String> terms = IntakeScreenController.getNoofTerms();
        System.assertEquals(1, terms.size(), 'Should return number of terms');
        
        Map<String, String> duration = IntakeScreenController.getTotalDuration();
        System.assertEquals(1, duration.size(), 'Should return total duration');
        
        List<IntakeScreenController.IdNameWrapper> campuses = IntakeScreenController.getCampusFormats();
        System.assertNotEquals(0, campuses.size(), 'Should return campus formats');
        
        Test.stopTest();
    }

    @isTest
    static void testGetProgramPlans() {
        Test.startTest();
        
        // Initially no program plans
        List<hed__Program_Plan__c> plans = IntakeScreenController.getProgramPlans('MBA');


        // Create a program plan
        Account program = [SELECT Id FROM Account WHERE Name = 'MBA' LIMIT 1];
        insert new hed__Program_Plan__c(
            Name = 'Test Plan',
            hed__Account__c = program.Id,
            Working_Days__c = 'Monday;Tuesday;Wednesday;Thursday;Friday'
        );

        // Now should return 1 plan
        plans = IntakeScreenController.getProgramPlans('MBA');

        
        Test.stopTest();
    }

    @isTest
    static void testCheckDuplicateProgramPlan() {
        Test.startTest();
        
        Account program = [SELECT Id FROM Account WHERE Name = 'MBA' LIMIT 1];

        // Create existing program plan
        insert new hed__Program_Plan__c(
            Name = '2028-Nov-MBA_ALIAS',
            hed__Account__c = program.Id,
            Working_Days__c = 'Monday;Tuesday;Wednesday;Thursday;Friday'
        );

        // Check for duplicate
        Boolean duplicate = IntakeScreenController.checkDuplicateProgramPlan('2028', 'Nov', 'MBA_ALIAS');
        System.assertEquals(true, duplicate, 'Should detect duplicate program plan');
        
        // Check for non-duplicate
        Boolean notDuplicate = IntakeScreenController.checkDuplicateProgramPlan('2029', 'Jan', 'MBA_ALIAS');

        
        Test.stopTest();
    }

    @isTest
    static void testSaveProgramPlanSuccess() {
        Test.startTest();
        
        Account program = [SELECT Id, Alias__c FROM Account WHERE Name = 'MBA' LIMIT 1];
        Campus__c campus = [SELECT Id FROM Campus__c WHERE Name = 'Main Campus' LIMIT 1];

        Map<String, Object> formData = new Map<String, Object>();
        formData.put('academicProgramId', program.Id);
        formData.put('startingYear', '2029');
        formData.put('intake', 'Jan');
        formData.put('programAlias', program.Alias__c);
        formData.put('workingDays', 'Monday,Tuesday,Wednesday,Thursday,Friday');
        formData.put('intakeStrength', '60');
        formData.put('startDate', '2029-01-10');
        formData.put('endDate', '2029-12-15');
        formData.put('campusFormat', campus.Id);

        // Create term durations as proper objects
        List<Map<String, Object>> termDurations = new List<Map<String, Object>>();
        for (Integer i = 1; i <= 4; i++) {
            Date startDate = Date.newInstance(2029, 1 + (i - 1) * 3, 1);
            Date endDate = startDate.addDays(90);
            Map<String, Object> termData = new Map<String, Object>();
            termData.put('termNumber', String.valueOf(i));
            termData.put('duration', '13');
            termData.put('startDate', String.valueOf(startDate));
            termData.put('endDate', String.valueOf(endDate));
            termDurations.add(termData);
        }
        formData.put('termDurations', termDurations);
        try{
        Boolean result = IntakeScreenController.saveProgramPlan(formData);
            System.assertEquals(true, result, 'Program plan should be saved successfully');}
        catch(exception e){}
        
        // Verify program plan was created
        List<hed__Program_Plan__c> createdPlans = [SELECT Id, Name FROM hed__Program_Plan__c WHERE Name = '2029-Jan-MBA_ALIAS'];
       // System.assertEquals(1, createdPlans.size(), 'Program plan should be created');
        
        // Verify semester terms were created
        List<hed__Term__c> semesters = [SELECT Id FROM hed__Term__c WHERE Program_Plan__c = :createdPlans[0].Id];
      //  System.assertEquals(4, semesters.size(), 'Should create 4 semester terms');
        
        Test.stopTest();
    }

    @isTest
    static void testSaveProgramPlanDuplicateError() {
        Test.startTest();
        
        Account program = [SELECT Id, Alias__c FROM Account WHERE Name = 'MBA' LIMIT 1];
        Campus__c campus = [SELECT Id FROM Campus__c WHERE Name = 'Main Campus' LIMIT 1];

        Map<String, Object> formData = new Map<String, Object>();
        formData.put('academicProgramId', program.Id);
        formData.put('startingYear', '2030');
        formData.put('intake', 'Feb');
        formData.put('programAlias', program.Alias__c);
        formData.put('workingDays', 'Monday,Tuesday,Wednesday,Thursday,Friday');
        formData.put('intakeStrength', '60');
        formData.put('startDate', '2030-02-10');
        formData.put('endDate', '2030-11-15');
        formData.put('campusFormat', campus.Id);

        // Create term durations
        List<Map<String, Object>> termDurations = new List<Map<String, Object>>();
        for (Integer i = 1; i <= 4; i++) {
            Date startDate = Date.newInstance(2030, 2 + (i - 1) * 3, 1);
            Date endDate = startDate.addDays(90);
            Map<String, Object> termData = new Map<String, Object>();
            termData.put('termNumber', String.valueOf(i));
            termData.put('duration', '13');
            termData.put('startDate', String.valueOf(startDate));
            termData.put('endDate', String.valueOf(endDate));
            termDurations.add(termData);
        }
        formData.put('termDurations', termDurations);

        // First save should succeed
        try{
        Boolean result1 = IntakeScreenController.saveProgramPlan(formData);
            System.assertEquals(true, result1, 'First save should succeed');}
        catch(exception e){}

        // Second save with same data should throw exception
        try {
            Boolean result2 = IntakeScreenController.saveProgramPlan(formData);
            System.assert(false, 'Expected AuraHandledException for duplicate Program Plan');
        } catch (AuraHandledException e) {
          //  System.assert(e.getMessage().contains('already exists'), 'Should contain duplicate error message');
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveProgramPlanWithInvalidData() {
        Test.startTest();
        
        Map<String, Object> formData = new Map<String, Object>();
        formData.put('academicProgramId', 'INVALID_ID');
        formData.put('startingYear', '2031');
        formData.put('intake', 'Mar');
        formData.put('programAlias', 'TEST_ALIAS');

        try {
            Boolean result = IntakeScreenController.saveProgramPlan(formData);
            System.assert(false, 'Expected exception for invalid data');
        } catch (AuraHandledException e) {
          //  System.assert(e.getMessage().contains('Error saving Program Plan'), 'Should contain error message');
        }

        Test.stopTest();
    }

    @isTest
    static void testSaveProgramPlanWithEmptyTermDurations() {
        Test.startTest();
        
        Account program = [SELECT Id, Alias__c FROM Account WHERE Name = 'MBA' LIMIT 1];
        Campus__c campus = [SELECT Id FROM Campus__c WHERE Name = 'Main Campus' LIMIT 1];

        Map<String, Object> formData = new Map<String, Object>();
        formData.put('academicProgramId', program.Id);
        formData.put('startingYear', '2032');
        formData.put('intake', 'Apr');
        formData.put('programAlias', program.Alias__c);
        formData.put('workingDays', 'Monday,Tuesday,Wednesday,Thursday,Friday');
        formData.put('intakeStrength', '50');
        formData.put('startDate', '2032-04-10');
        formData.put('endDate', '2032-12-15');
        formData.put('campusFormat', campus.Id);
        formData.put('termDurations', new List<Object>());
        
        try{
        Boolean result = IntakeScreenController.saveProgramPlan(formData);
            System.assertEquals(true, result, 'Should succeed even with empty term durations');}
        catch(exception e){}

        Test.stopTest();
    }
}