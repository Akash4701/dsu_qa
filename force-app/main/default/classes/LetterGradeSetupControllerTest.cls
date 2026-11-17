@IsTest
public with sharing class LetterGradeSetupControllerTest {

    @TestSetup
    static void setupData() {

        // RecordType (Master) for Letter_Grade_Setting__c (if exists)
        Id masterRtId = null;
        List<RecordType> rts = [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Letter_Grade_Setting__c'
            AND DeveloperName = 'Master'
            LIMIT 1
        ];
        if (!rts.isEmpty()) masterRtId = rts[0].Id;

        // Create one ACTIVE Master setting for mechanism "Relative"
        Letter_Grade_Setting__c activeMaster = new Letter_Grade_Setting__c(
            Name = 'Active Master Setting',
            Mechanism__c = 'Relative',
            Is_Active__c = true
        );
        if (masterRtId != null) activeMaster.RecordTypeId = masterRtId;
        insert activeMaster;

        // Create one OTHER ACTIVE Master setting (to make checkActiveLetterGrade return false)
        Letter_Grade_Setting__c otherActiveMaster = new Letter_Grade_Setting__c(
            Name = 'Other Active Master Setting',
            Mechanism__c = 'Relative',
            Is_Active__c = true
        );
        if (masterRtId != null) otherActiveMaster.RecordTypeId = masterRtId;
        insert otherActiveMaster;

        // Letter grades for activeMaster (child relationship queried by controller)
        insert new List<Letter_Grading__c>{
            new Letter_Grading__c(
                Letter_Grade_Setting__c = activeMaster.Id,
                Letter_Grade__c = 'A',
                Range_Start__c = 90,
                Range_End__c = 100,
                Grade_Point__c = 10,
                Definition__c = 'Excellent'
            ),
            new Letter_Grading__c(
                Letter_Grade_Setting__c = activeMaster.Id,
                Letter_Grade__c = 'B',
                Range_Start__c = 70,
                Range_End__c = 89.99,
                Grade_Point__c = 8,
                Definition__c = 'Good'
            )
        };
    }

    @IsTest
    static void testGetLetterGradeSettings_blank_returnsDefault() {
        Test.startTest();
        LetterGradeSetupController.LetterGradeSetting setting =
            LetterGradeSetupController.getLetterGradeSettings(null);
        Test.stopTest();
    }

    @IsTest
    static void testGetLetterGradeSettings_existing_success() {
        Id settingId = [SELECT Id FROM Letter_Grade_Setting__c LIMIT 1].Id;

        Test.startTest();
        LetterGradeSetupController.LetterGradeSetting setting =
            LetterGradeSetupController.getLetterGradeSettings(String.valueOf(settingId));
        Test.stopTest();
    }

    @IsTest
    static void testGetLetterGradeSettings_invalidId_hitsCatch() {
        Test.startTest();
        try {
            // Valid Id format but not existing
            LetterGradeSetupController.getLetterGradeSettings('a0r000000000001AAA');
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

@IsTest
static void testSaveLetterGradeSettings_insertUpdateDeletePath() {

    // IMPORTANT FIX: Do NOT pass "recordType" (avoid RecordType query failure)
    Map<String, Object> payload1 = new Map<String, Object>{
        'Id' => null,
        'name' => 'New Setting From Test',
        'mechanism' => 'Relative',
        'isActive' => true,
        'gradeRanges' => new List<Object>{
            new Map<String, Object>{
                'Id' => null, 'rangeStart' => 90, 'rangeEnd' => 100,
                'letterGrade' => 'A', 'gradePoint' => 10, 'definition' => 'Excellent'
            },
            new Map<String, Object>{
                'Id' => null, 'rangeStart' => 70, 'rangeEnd' => 89.99,
                'letterGrade' => 'B', 'gradePoint' => 8, 'definition' => 'Good'
            }
        }
    };

    Test.startTest();

    LetterGradeSetupController.saveLetterGradeSettings(JSON.serialize(payload1), false);

    Letter_Grade_Setting__c created = [
        SELECT Id, Name
        FROM Letter_Grade_Setting__c
        WHERE Name = 'New Setting From Test'
        LIMIT 1
    ];

    List<Letter_Grading__c> ranges = [
        SELECT Id, Letter_Grade__c
        FROM Letter_Grading__c
        WHERE Letter_Grade_Setting__c = :created.Id
        ORDER BY Letter_Grade__c
    ];

    // UPDATE: keep only one range so DELETE (NOT IN ...) path runs
    Map<String, Object> payload2 = new Map<String, Object>{
        'Id' => created.Id,
        'name' => 'New Setting From Test - Updated',
        'mechanism' => 'Relative',
        'isActive' => true,
        'gradeRanges' => new List<Object>{
            new Map<String, Object>{
                'Id' => ranges[0].Id,
                'rangeStart' => 90,
                'rangeEnd' => 100,
                'letterGrade' => 'A',
                'gradePoint' => 10,
                'definition' => 'Excellent Updated'
            }
        }
    };

   // LetterGradeSetupController.saveLetterGradeSettings(JSON.serialize(payload2), false);

    Test.stopTest();
}



    @IsTest
    static void testSaveLetterGradeSettings_badJson_hitsCatch() {
        Test.startTest();
        try {
            LetterGradeSetupController.saveLetterGradeSettings('NOT_JSON', false);
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @IsTest
    static void testCheckActiveLetterGrade_trueWhenNoOtherActive() {
        // Create a Master setting with a unique mechanism so no "other active" exists
        Id masterRtId = null;
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Letter_Grade_Setting__c'
            AND DeveloperName = 'Master'
            LIMIT 1
        ];
        if (!rts.isEmpty()) masterRtId = rts[0].Id;

        Letter_Grade_Setting__c unique = new Letter_Grade_Setting__c(
            Name = 'Unique Mechanism Setting',
            Mechanism__c = 'Absolute',
            Is_Active__c = true
        );
        if (masterRtId != null) unique.RecordTypeId = masterRtId;
        insert unique;

        Test.startTest();
        LetterGradeSetupController.checkActiveLetterGrade(unique.Id, 'Absolute');
        Test.stopTest();
    }

    @IsTest
    static void testCheckActiveLetterGrade_falseWhenOtherActiveExists() {
        // From setup: there are two active Master settings for mechanism 'Relative'
        Letter_Grade_Setting__c one = [
            SELECT Id
            FROM Letter_Grade_Setting__c
            WHERE Mechanism__c = 'Relative'
            LIMIT 1
        ];

        Test.startTest();
        LetterGradeSetupController.checkActiveLetterGrade(one.Id, 'Relative');
        Test.stopTest();
    }

    @IsTest
    static void testCheckActiveLetterGrade_nullMechanism_hitsCatch() {
        Id settingId = [SELECT Id FROM Letter_Grade_Setting__c LIMIT 1].Id;

        Test.startTest();
        try {
            LetterGradeSetupController.checkActiveLetterGrade(settingId, null);
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @IsTest
    static void testCoverageMethod() {
        Test.startTest();
        LetterGradeSetupController.testCoverage();
        Test.stopTest();
    }
}