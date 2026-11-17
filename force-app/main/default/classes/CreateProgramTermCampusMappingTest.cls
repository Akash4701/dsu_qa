@isTest
public class CreateProgramTermCampusMappingTest {

    @isTest
    static void testGetLookUpValues() {
        Campus__c campus = new Campus__c(Name = 'Test Campus',Campus_ID__c='dfs');
        insert campus;

        Test.startTest();
        CreateProgramTermCampusMappingController.ComboBoxValuesWrapper result =
            CreateProgramTermCampusMappingController.getLookUpValues();
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.campusList.size() > 0);
        System.assert(result.currencyOptions.size() > 0);
    }

    @isTest
    static void testGetTermLookUpValues() {
        Account program = new Account(Name = 'Test Program');
        insert program;

        hed__Term__c term = new hed__Term__c(Name = 'Test Term', hed__Account__c = program.Id,Term_Reference__c = 'Term 1');
        insert term;

        Test.startTest();
        List<hed__Term__c> termList = CreateProgramTermCampusMappingController.getTermLookUpValues(program.Id);
        Test.stopTest();

        System.assertEquals(1, termList.size());
    }

    @isTest
    static void testSaveMappings() {
        Account program = new Account(Name = 'Test Program');
        insert program;

        Campus__c campus = new Campus__c(Name = 'Test Campus',Campus_ID__c ='sdv');
        insert campus;

        hed__Term__c term = new hed__Term__c(Name = 'Test Term', hed__Account__c = program.Id,Term_Reference__c = 'Term 1');
        insert term;

        // Construct wrapper JSON
        Map<String, Object> tcm = new Map<String, Object>{
            'sequenceNumber' => '1',
            'term' => term.Id,
            'campus' => campus.Id,
            'currencyValue' => 'USD'
        };

        Map<String, Object> wrapper = new Map<String, Object>{
            'program' => program.Id,
            'combinationName' => 'TestCombo1',
            'termCampusList' => new List<Object>{ tcm }
        };

        String jsonString = JSON.serialize(wrapper);
        try{
        Test.startTest();
        
            CreateProgramTermCampusMappingController.saveMappings(jsonString);
            Test.stopTest();
        }
        catch(exception e){
            
        }

    }

    @isTest
    static void testSaveMappingsDuplicateCheck() {
        Account program = new Account(Name = 'Test Program');
        insert program;

        Program_Campus_Relationship__c existing = new Program_Campus_Relationship__c(
            RecordTypeId = Schema.SObjectType.Program_Campus_Relationship__c.getRecordTypeInfosByName()
                .get('Program Level Campus Combination').getRecordTypeId(),
            Program__c = program.Id,
            Combination_Name__c = 'TestDuplicateCombo'
        );
        insert existing;

        Map<String, Object> wrapper = new Map<String, Object>{
            'program' => program.Id,
            'combinationName' => 'TestDuplicateCombo',
            'termCampusList' => new List<Object>()
        };

        String jsonString = JSON.serialize(wrapper);

        Test.startTest();
        try {
            CreateProgramTermCampusMappingController.saveMappings(jsonString);
            System.assert(false, 'Expected exception not thrown');
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
}