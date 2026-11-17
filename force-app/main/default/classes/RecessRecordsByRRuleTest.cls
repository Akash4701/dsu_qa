@isTest
private class RecessRecordsByRRuleTest {

    @testSetup
    static void setupData() {
         // Create Academic Program (assuming it's Account or custom object)
        Account academicProgram = new Account(Name = 'Test Academic Program');
        insert academicProgram;
        // Create Program Plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Plan',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(5)
        );
        insert programPlan;

        // Create Term record (dummy object if needed)
        hed__Term__c term = new hed__Term__c(Name = 'Term 1',Term_Reference__c='Term 1',hed__Account__c=academicProgram.Id );
        insert term;

       
    }

    @isTest
    static void testValidateOperation() {
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Account program = [SELECT Id FROM Account LIMIT 1];

        RecessRecordsByRRule.mainWrapper wrapper = new RecessRecordsByRRule.mainWrapper();
        wrapper.operation = 'validate';
        RecessRecordsByRRule.requestWrapper req = new RecessRecordsByRRule.requestWrapper();
        req.name = 'Break 1';
        req.startDateTime = DateTime.now();
        req.endDateTime = DateTime.now().addHours(1);
        req.selectedDays = 'MO';
        req.frequency = 'Weekly';
        req.rRuleString = 'FREQ=WEEKLY;BYDAY=MO';
        req.typeOfSession = 'Break';
        req.termId = term.Id;
        req.programPlanId = plan.Id;
        req.academicProgramId = program.Id;

        wrapper.sessions = new List<RecessRecordsByRRule.requestWrapper>{ req };

        RestContext.request = new RestRequest();
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(wrapper));
        RestContext.response = new RestResponse();

        Test.startTest();
        RecessRecordsByRRule.createRecessRecords();
        Test.stopTest();

    }

    @isTest
    static void testCreateOperation() {
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Account program = [SELECT Id FROM Account LIMIT 1];

        RecessRecordsByRRule.mainWrapper wrapper = new RecessRecordsByRRule.mainWrapper();
        wrapper.operation = 'create';

        RecessRecordsByRRule.requestWrapper req = new RecessRecordsByRRule.requestWrapper();
        req.name = 'Break 2';
        req.startDateTime = DateTime.now().addDays(1);
        req.endDateTime = DateTime.now().addDays(1).addHours(1);
        req.selectedDays = 'MONDAY';
        req.frequency = 'Weekly';
        req.rRuleString = 'FREQ=WEEKLY;BYDAY=TU';
        req.typeOfSession = 'Break';
        req.termId = term.Id;
        req.programPlanId = plan.Id;
        req.academicProgramId = program.Id;

        wrapper.sessions = new List<RecessRecordsByRRule.requestWrapper>{ req };

        RestContext.request = new RestRequest();
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(wrapper));
        RestContext.response = new RestResponse();

        Test.startTest();
        RecessRecordsByRRule.createRecessRecords();
        Test.stopTest();

    }

    @isTest
    static void testInvalidOperation() {
        RecessRecordsByRRule.mainWrapper wrapper = new RecessRecordsByRRule.mainWrapper();
        wrapper.operation = 'unknown';

        RestContext.request = new RestRequest();
        RestContext.request.requestBody = Blob.valueOf(JSON.serialize(wrapper));
        RestContext.response = new RestResponse();

        Test.startTest();
        RecessRecordsByRRule.createRecessRecords();
        Test.stopTest();

    }
}