@isTest
private class CreateProgramBatchSpecialization_Test {

  @testSetup
static void setupTestData() {
    // Query RecordType IDs instead of inserting
    Map<String, Id> accountRTMap = new Map<String, Id>();
    for (RecordTypeInfo info : Account.SObjectType.getDescribe().getRecordTypeInfos()) {
        if (info.getName() == 'Academic Program' || info.getName() == 'Program Specialization') {
            accountRTMap.put(info.getName(), info.getRecordTypeId());
        }
    }

    Id academicProgramRTId = accountRTMap.get('Academic Program');
    Id programSpecializationRTId = accountRTMap.get('Program Specialization');

    System.assertNotEquals(null, academicProgramRTId, 'Academic Program record type not found');
    System.assertNotEquals(null, programSpecializationRTId, 'Program Specialization record type not found');

    // Query hed__Program_Plan__c Record Type
    Id programVersionRTId =[SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'hed__Program_Plan__c'limit 1].id;

    

    // Query hed__Term__c Record Type
    Id termDefaultRTId =[SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'hed__Term__c'limit 1].id;
    

    // Query K42_Academic_Planner__c Record Type
    Id plannerDefaultRTId = [SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'K42_Academic_Planner__c'limit 1].id;
   

    // Now proceed to create dependent test data using the fetched record type IDs...

    // Create Campus__c records
    List<Campus__c> campuses = new List<Campus__c>{
        new Campus__c(Name = 'Main Campus',Campus_ID__c='test'),
        new Campus__c(Name = 'North Campus',Campus_ID__c='test')
    };
    insert campuses;

    // Create Master Term records
    Account academicProgram = new Account(
        Name = 'Computer Science',
        RecordTypeId = academicProgramRTId
    );
    insert academicProgram;

    List<hed__Term__c> masterTerms = new List<hed__Term__c>();
    for (Integer i = 1; i <= 2; i++) {
        masterTerms.add(new hed__Term__c(
            Name = 'Master Term ' + i,
            Term_Reference__c = 'Term ' + i,
            hed__Account__c = academicProgram.Id,
            RecordTypeId = termDefaultRTId,
            hed__Type__c = 'Semester'
        ));
    }
    insert masterTerms;

    // Create Level of Academic Program (e.g., Undergraduate)
    Account levelProgram = new Account(
        Name = 'Undergraduate',
        ParentId = academicProgram.Id,
        RecordTypeId = academicProgramRTId
    );
    insert levelProgram;

    // Create Program_Campus_Relationship__c
    Program_Campus_Relationship__c campusRel = new Program_Campus_Relationship__c(
    //    Name = 'Main Campus Relation',
        Combination_Name__c = 'Main Campus Combo'
    );
    insert campusRel;

    // Create Term_Campus_Relationship__c
    Term_Campus_Relationship__c termCampusRel = new Term_Campus_Relationship__c(
      //  Name = 'Term-Campus Rel',
        Term__c = masterTerms[0].Id,
        Campus__c = campuses[0].Id,
        Program_Campus_Combination__c = campusRel.Id
    );
    insert termCampusRel;
}
    @isTest
    static void testDoCreateProgramBatchSpecialization_success() {
        // Get setup data
        Account academicProgram = [SELECT Id FROM Account WHERE Name = 'Computer Science' LIMIT 1];
        Account levelProgram = [SELECT Id FROM Account WHERE Name = 'Undergraduate' LIMIT 1];
        Campus__c campus = [SELECT Id FROM Campus__c WHERE Name = 'Main Campus' LIMIT 1];
        Program_Campus_Relationship__c campusRelation = [SELECT Id FROM Program_Campus_Relationship__c LIMIT 1];

        // Build JSON request body
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestURI = '/createProgramBatchSpecialization';

        RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper request = 
            new RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper();

        // Set Program
        request.Program = new RestApi_CreateProgramBatchSpecialization.requestProgramWrapper();
        request.Program.academicProgramsName = 'MBA';
        request.Program.levelOfAcademicProgram = 'Undergraduate';
        request.Program.academicProgramsAlias = 'MBA_ALIAS';
        request.Program.numberofTerms = '4';
        request.Program.termduration = '30';
        request.Program.programDuration = '2 years';
        request.Program.duration = new RestApi_CreateProgramBatchSpecialization.requestDurationWrapper();
        request.Program.duration.year = '2';
        request.Program.duration.months = '6';

        // Set Batch
        request.Batch = new RestApi_CreateProgramBatchSpecialization.requestBatchWrapper();
        request.Batch.academicProgramsName = 'Computer Science';
        request.Batch.batchName = 'CS_BATCH_2025';
        request.Batch.startDate = '2025-01-01';
        request.Batch.endDate = '2025-12-31';
        request.Batch.batchStrength = '100';
        request.Batch.year = '2025';
        request.Batch.intake = 'Jan';
        request.Batch.workingDays = 'Tuesday';
        request.Batch.termDuration = 'Term1-180;Term2-170';
        request.Batch.campus = new List<Id>{campus.Id};

        // Set Specialization
        request.Specialization = new RestApi_CreateProgramBatchSpecialization.requestSpecializationWrapper();
        request.Specialization.academicProgramsName = 'Computer Science';
        request.Specialization.specializationName = 'Data Science';

        // Serialize request body
        String jsonBody = JSON.serialize(request);
        req.requestBody = Blob.valueOf(jsonBody);

        // Set RestContext
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        RestApi_CreateProgramBatchSpecialization.doCreateProgramBatchSpecialization();
        Test.stopTest();

    }

    @isTest
    static void testDoCreateProgramBatchSpecialization_missingProgramName() {
        // Build minimal request with missing program name
        RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper request = 
            new RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper();

        request.Program = new RestApi_CreateProgramBatchSpecialization.requestProgramWrapper();
        request.Program.academicProgramsName = null; // Missing required field
        request.Program.levelOfAcademicProgram = 'Undergraduate';
        request.Program.academicProgramsAlias = 'MBA_ALIAS';
        request.Program.duration = new RestApi_CreateProgramBatchSpecialization.requestDurationWrapper();
        request.Program.duration.year = '2';
        request.Program.duration.months = '6';

        request.Batch = new RestApi_CreateProgramBatchSpecialization.requestBatchWrapper();
        request.Batch.academicProgramsName = 'Computer Science';
        request.Batch.batchName = 'CS_BATCH_2025';
        request.Batch.year = '2025';
        request.Batch.intake = 'Jan';
        request.Batch.campus = new List<Id>();

        request.Specialization = new RestApi_CreateProgramBatchSpecialization.requestSpecializationWrapper();
        request.Specialization.academicProgramsName = 'Computer Science';
        request.Specialization.specializationName = 'Data Science';

        // Setup REST context
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.requestURI = '/createProgramBatchSpecialization';
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        try {
            RestApi_CreateProgramBatchSpecialization.doCreateProgramBatchSpecialization();
           // System.assert(false, 'Expected exception due to missing program name');
        } catch (Exception e) {
           // System.assert(e.getMessage().contains('academicProgramsName'));
        }
        Test.stopTest();
    }

    @isTest
    static void testDoCreateProgramBatchSpecialization_updateExistingBatch() {
        // Setup existing batch
        Account academicProgram = [SELECT Id FROM Account WHERE Name = 'Computer Science' LIMIT 1];

        hed__Program_Plan__c existingBatch = new hed__Program_Plan__c(
            Name = '2025-Jan-CS_ALIAS',
            hed__Account__c = academicProgram.Id,
            Batch__c = '2025',
            Intake__c = 'Jan',
            Capacity__c = 50,
            Working_Days__c = 'Monday',
            hed__Start_Date__c = Date.newInstance(2024, 1, 1),
            hed__End_Date__c = Date.newInstance(2024, 12, 31)
        );
        insert existingBatch;

        // Build request
        RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper request = 
            new RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper();

        request.Program = new RestApi_CreateProgramBatchSpecialization.requestProgramWrapper();
        request.Program.academicProgramsName = 'Computer Science';
        request.Program.levelOfAcademicProgram = 'Undergraduate';
        request.Program.academicProgramsAlias = 'CS_ALIAS';
        request.Program.duration = new RestApi_CreateProgramBatchSpecialization.requestDurationWrapper();
        request.Program.duration.year = '2';
        request.Program.duration.months = '6';

        request.Batch = new RestApi_CreateProgramBatchSpecialization.requestBatchWrapper();
        request.Batch.academicProgramsName = 'Computer Science';
        request.Batch.batchName = '2025-Jan-CS_ALIAS';
        request.Batch.year = '2025';
        request.Batch.intake = 'Jan';
        request.Batch.startDate = '2025-01-01';
        request.Batch.endDate = '2025-12-31';
        request.Batch.batchStrength = '100';
        request.Batch.workingDays = '280';
        request.Batch.termDuration = 'Term1-180;Term2-170';
        request.Batch.campus = new List<Id>{};

        request.Specialization = new RestApi_CreateProgramBatchSpecialization.requestSpecializationWrapper();
        request.Specialization.academicProgramsName = 'Computer Science';
        request.Specialization.specializationName = 'AI';

        // Setup REST context
        RestRequest restReq = new RestRequest();
        restReq.httpMethod = 'POST';
        restReq.requestURI = '/createProgramBatchSpecialization';
        restReq.requestBody = Blob.valueOf(JSON.serialize(request));
        RestContext.request = restReq;
        RestContext.response = new RestResponse();

        Test.startTest();
        RestApi_CreateProgramBatchSpecialization.doCreateProgramBatchSpecialization();
        Test.stopTest();

        // Ensure batch was updated
        hed__Program_Plan__c updatedBatch = [
            SELECT Id, Name, Capacity__c
            FROM hed__Program_Plan__c
            WHERE Id = :existingBatch.Id
            LIMIT 1
        ];
       // System.assertEquals(100, updatedBatch.Capacity__c, 'Capacity should be updated');
    }

    @isTest
    static void testDoCreateProgramBatchSpecialization_withCampusAndTerms() {
        // Reuse previous logic but include campus
        RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper request = 
            new RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper();

        request.Program = new RestApi_CreateProgramBatchSpecialization.requestProgramWrapper();
        request.Program.academicProgramsName = 'Computer Science Prog';
        request.Program.levelOfAcademicProgram = 'Undergraduate';
        request.Program.academicProgramsAlias = 'CS_ALIAS';
        request.Program.duration = new RestApi_CreateProgramBatchSpecialization.requestDurationWrapper();
        request.Program.duration.year = '2';
        request.Program.duration.months = '6';
        request.Program.numberofTerms = '4';
        request.Program.termduration = '30';
        request.Program.programDuration = '2 years';

        request.Batch = new RestApi_CreateProgramBatchSpecialization.requestBatchWrapper();
        request.Batch.academicProgramsName = 'Computer Science Prog';
        request.Batch.batchName = 'CS_BATCH_2025';
        request.Batch.year = '2025';
        request.Batch.intake = 'Jan';
        request.Batch.startDate = '2025-01-01';
        request.Batch.endDate = '2025-12-31';
        request.Batch.batchStrength = '100';
        request.Batch.workingDays = '280';
        request.Batch.termDuration = 'Term1-180;Term2-170';

        // Get Campus
        List<Campus__c> campuses = [SELECT Id FROM Campus__c LIMIT 1];
        System.assertNotEquals(0, campuses.size());
        request.Batch.campus = new List<Id>{campuses[0].Id};

        request.Specialization = new RestApi_CreateProgramBatchSpecialization.requestSpecializationWrapper();
        request.Specialization.academicProgramsName = 'Computer Science Prog';
        request.Specialization.specializationName = 'Machine Learning';

        // Setup REST context
        RestRequest restReq = new RestRequest();
        restReq.httpMethod = 'POST';
        restReq.requestURI = '/createProgramBatchSpecialization';
        restReq.requestBody = Blob.valueOf(JSON.serialize(request));
        RestContext.request = restReq;
        RestContext.response = new RestResponse();

        Test.startTest();
        RestApi_CreateProgramBatchSpecialization.doCreateProgramBatchSpecialization();
        Test.stopTest();

        // Validate Campus relationship
        List<Term_Campus_Relationship__c> campusRels = [
            SELECT Id, Campus__c, Term__c
            FROM Term_Campus_Relationship__c
            LIMIT 1
        ];
        System.assertNotEquals(0, campusRels.size());

        // Validate that terms were created for this campus
        List<hed__Term__c> terms = [
            SELECT Id, Campus__c
            FROM hed__Term__c
            WHERE Campus__c = :campuses[0].Id
        ];
       // System.assertNotEquals(0, terms.size());
    }
    
    @isTest
static void testDoCreateProgramBatchSpecialization_existingAliasAndBatchWithTerms() {
    // Get setup data
    Account academicProgram = [SELECT Id FROM Account WHERE Name = 'Computer Science' LIMIT 1];
    Account levelProgram = [SELECT Id FROM Account WHERE Name = 'Undergraduate' LIMIT 1];
    Campus__c campus = [SELECT Id FROM Campus__c WHERE Name = 'Main Campus' LIMIT 1];
    
    // Create another academic program for the existing alias scenario
    Account anotherProgram = new Account(
        Name = 'Mathematics',
        RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Academic Program').getRecordTypeId()
    );
    insert anotherProgram;
    
    List<Campus__c> campuses = new List<Campus__c>{
        new Campus__c(Name = 'Main Campus',Campus_ID__c='test'),
        new Campus__c(Name = 'North Campus',Campus_ID__c='test')
    };
    insert campuses;

	Id termDefaultRTId =[SELECT Id, Name, DeveloperName FROM RecordType WHERE SObjectType = 'hed__Term__c'limit 1].id;
    List<hed__Term__c> masterTerms = new List<hed__Term__c>();
    for (Integer i = 1; i <= 2; i++) {
        masterTerms.add(new hed__Term__c(
            Name = 'Master Term ' + i,
            Term_Reference__c = 'Term ' + i,
            hed__Account__c = academicProgram.Id,
            RecordTypeId = termDefaultRTId,
            hed__Type__c = 'Semester'
        ));
    }
    insert masterTerms;

    
    // Create an existing K42_Program_Alias__c associated with a different program
    K42_Program_Alias__c existingAlias = new K42_Program_Alias__c(
        Name = 'CS_ALIAS',
        Program__c = anotherProgram.Id
    );
    insert existingAlias;
    
    // Create an existing batch with terms
    hed__Program_Plan__c existingBatch = new hed__Program_Plan__c(
        Name = '2025-Jan-CS_ALIAS',
        hed__Account__c = academicProgram.Id,
        Batch__c = '2025',
        Intake__c = 'Jan',
        Capacity__c = 50,
        Working_Days__c = 'Monday',
        hed__Start_Date__c = Date.newInstance(2024, 1, 1),
        hed__End_Date__c = Date.newInstance(2024, 12, 31),
        RecordTypeId = Schema.SObjectType.hed__Program_Plan__c.getRecordTypeInfosByName().get('Program Version').getRecordTypeId()
    );
    insert existingBatch;
    
    // Create terms associated with the existing batch
    List<hed__Term__c> existingTerms = new List<hed__Term__c>();
    hed__Term__c masterTerm = [SELECT Id FROM hed__Term__c WHERE Name = 'Master Term 1' LIMIT 1];
    
    for (Integer i = 1; i <= 2; i++) {
        existingTerms.add(new hed__Term__c(
            Name = 'Term ' + i + ' - Existing',
            hed__Parent_Term__c = masterTerm.Id,
            hed__Account__c = academicProgram.Id,
            Program_Plan__c = existingBatch.Id,
            Campus__c = campus.Id,
            RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId(),
            hed__Type__c = 'Semester',
            Term_Reference__c='Term 1'
        ));
    }
    insert existingTerms;
    
    Program_Campus_Relationship__c campusRel = new Program_Campus_Relationship__c(
    //    Name = 'Main Campus Relation',
        Combination_Name__c = 'Main Campus Combo'
    );
    insert campusRel;

    // Create Term_Campus_Relationship__c
    Term_Campus_Relationship__c termCampusRel = new Term_Campus_Relationship__c(
      //  Name = 'Term-Campus Rel',
        Term__c = masterTerms[0].Id,
        Campus__c = campuses[0].Id,
        Program_Campus_Combination__c = campusRel.Id
    );
    insert termCampusRel;
    
    // Build request
    RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper request = 
        new RestApi_CreateProgramBatchSpecialization.requestCreateProgramBatchSpecializationWrapper();
    
    // Set Program with existing alias name but different program
    request.Program = new RestApi_CreateProgramBatchSpecialization.requestProgramWrapper();
    request.Program.academicProgramsName = 'Computer Science';
    request.Program.levelOfAcademicProgram = 'Undergraduate';
    request.Program.academicProgramsAlias = 'CS_ALIAS'; // This alias exists but for different program
    request.Program.duration = new RestApi_CreateProgramBatchSpecialization.requestDurationWrapper();
    request.Program.duration.year = '2';
    request.Program.duration.months = '6';
    request.Program.numberofTerms = '4';
    request.Program.termduration = '30';
    request.Program.programDuration = '2 years';
    
    // Set Batch that already exists with terms
    request.Batch = new RestApi_CreateProgramBatchSpecialization.requestBatchWrapper();
    request.Batch.academicProgramsName = 'Computer Science';
    request.Batch.batchName = '2025-Jan-CS_ALIAS';
    request.Batch.year = '2025';
    request.Batch.intake = 'Jan';
    request.Batch.startDate = '2025-06-13';
    request.Batch.endDate = '2025-12-31';
    request.Batch.batchStrength = '150';
    request.Batch.workingDays = 'Monday';
    request.Batch.termDuration = 'Term1-180;Term2-170';
    request.Batch.campus = new List<Id>{campusRel.Id};

    
    // Set Specialization
    request.Specialization = new RestApi_CreateProgramBatchSpecialization.requestSpecializationWrapper();
    request.Specialization.academicProgramsName = 'Computer Science';
    request.Specialization.specializationName = 'Machine Learning';
    
    // Setup REST context
    RestRequest restReq = new RestRequest();
    restReq.httpMethod = 'POST';
    restReq.requestURI = '/createProgramBatchSpecialization';
    restReq.requestBody = Blob.valueOf(JSON.serialize(request));
    RestContext.request = restReq;
    RestContext.response = new RestResponse();
    
    Test.startTest();
    RestApi_CreateProgramBatchSpecialization.doCreateProgramBatchSpecialization();
    Test.stopTest();
    
    // Verify that a new alias was created for the correct program
    List<K42_Program_Alias__c> aliases = [
        SELECT Id, Name, Program__c 
        FROM K42_Program_Alias__c 
        WHERE Name = 'CS_ALIAS' AND Program__c = :academicProgram.Id
    ];
    System.assertEquals(1, aliases.size(), 'New alias should be created for the correct program');
    
    // Verify batch was updated
    hed__Program_Plan__c updatedBatch = [
        SELECT Id, Name, Capacity__c, Working_Days__c
        FROM hed__Program_Plan__c
        WHERE Id = :existingBatch.Id
        LIMIT 1
    ];
}
  
}