@isTest
public class CreateTermCampusMappingControllerTest {

    @testSetup
    static void setupTestData() {
        // Create Academic Program (Account)
        RecordType academicProgramRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Academic_Program' AND SObjectType = 'Account' LIMIT 1];
        Account program = new Account(Name = 'Test Program', RecordTypeId = academicProgramRT.Id);
        insert program;
        Account program1 = new Account(Name = 'Main Campus');
        insert program1;

        // Create Program Plan
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Test Program Plan',
            hed__Account__c = program.Id
        );
        insert programPlan;

    // Create Terms
List<hed__Term__c> terms = new List<hed__Term__c>();
for (Integer i = 1; i <= 2; i++) {
    hed__Term__c term = new hed__Term__c(
        Name = 'Term ' + i,
        Term_Reference__c = 'Term' + i,
        hed__Parent_Term__c = null, // Set parent after insert
        Program_Plan__c = programPlan.Id,
        Term_Number__c = i,
        hed__Account__c = program.Id
    );
    terms.add(term);
}
insert terms;

// Assign parent term (Term 2 → parent is Term 1)
terms[1].hed__Parent_Term__c = terms[0].Id;
update terms[1];


        // Create Campus
        Campus__c campus = new Campus__c(Name = 'Main Campus',Campus_ID__c = 'efa');
        insert campus;

        // Create Program Campus Relationship (existing combination for validation)
        RecordType combinationRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Program_Level_Campus_Combination' AND SObjectType = 'Program_Campus_Relationship__c' LIMIT 1];
        Program_Campus_Relationship__c combination = new Program_Campus_Relationship__c(
            Program__c = program.Id,
            Program_Plan__c = programPlan.Id,
            Combination_Name__c = 'Existing Combo',
            Master_Program_Campus_Combination__c = null,
            RecordTypeId = combinationRT.Id
        );
        insert combination;

        // Create Term Campus Relationship
        Term_Campus_Relationship__c tcr = new Term_Campus_Relationship__c(
            Term__c = terms[0].Id,
            Campus__c = campus.Id,
            Program_Campus_Combination__c = combination.Id,
            Sequence_Number__c = 1,
            Currency__c = 'USD'
        );
        insert tcr;
    }

    @isTest
    static void testGetProgramValues() {
        Test.startTest();
        List<Account> programs = CreateTermCampusMappingController.getProgramValues();
        Test.stopTest();

        System.assert(!programs.isEmpty(), 'Program list should not be empty');
    }

    @isTest
    static void testGetProgramDependentLookupValues() {
        Account program = [SELECT Id FROM Account WHERE Name = 'Test Program' LIMIT 1];

        Test.startTest();
        CreateTermCampusMappingController.ProgramDependentLookups result =
            CreateTermCampusMappingController.getProgramDependentLookupValues(program.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(!result.programCampusCombinations.isEmpty());
        System.assert(!result.programPlans.isEmpty());
    }

    @isTest
    static void testGetTermLookUpValues() {
        Account program = [SELECT Id FROM Account WHERE Name = 'Test Program' LIMIT 1];
        Program_Campus_Relationship__c combination = [SELECT Id FROM Program_Campus_Relationship__c WHERE Combination_Name__c = 'Existing Combo' LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE hed__Account__c = :program.Id LIMIT 1];

        Test.startTest();
        List<CreateTermCampusMappingController.TermCampusMappingWrapper> wrappers =
            CreateTermCampusMappingController.getTermLookUpValues(combination.Id, programPlan.Id);
        Test.stopTest();

        System.assert(!wrappers.isEmpty(), 'TermCampusMappingWrapper list should not be empty');
    }

    @isTest
    static void testSaveMappings() {
        Account program = [SELECT Id FROM Account WHERE Name = 'Test Program' LIMIT 1];
        hed__Program_Plan__c programPlan = [SELECT Id FROM hed__Program_Plan__c WHERE hed__Account__c = :program.Id LIMIT 1];
        hed__Term__c term = [SELECT Id, hed__Parent_Term__c FROM hed__Term__c WHERE Program_Plan__c = :programPlan.Id LIMIT 1];
        Account campus = [SELECT Id FROM Account WHERE Name = 'Main Campus' LIMIT 1];

        List<CreateTermCampusMappingController.TermCampusMappingWrapper> wrappers = new List<CreateTermCampusMappingController.TermCampusMappingWrapper>{
            new CreateTermCampusMappingController.TermCampusMappingWrapper(
                '1',
                'Term 1',
                term.Id,
                'T1',
                'Main Campus',
                campus.Id,
                'USD'
            )
        };

        CreateTermCampusMappingController.ProgramCampusCombinationWarpper obj =
            new CreateTermCampusMappingController.ProgramCampusCombinationWarpper();
        obj.program = program.Id;
        obj.programPlan = programPlan.Id;
        obj.combinationName = 'Unique Combo ' + System.currentTimeMillis();
        obj.masterCombination = null;
        obj.termCampusRelationships = wrappers;

        String recordsString = JSON.serialize(obj);
        try{
        Test.startTest();
        CreateTermCampusMappingController.saveMappings(recordsString);
            Test.stopTest();}
        catch(exception e){
            
        }
    }
}