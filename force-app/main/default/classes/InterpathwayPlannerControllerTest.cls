@IsTest
private class InterpathwayPlannerControllerTest {

@TestSetup
static void setupData() {

    // Department / Academic Unit (required for hed__Course__c)
    Account academicDept = new Account(Name = 'Dept of Science');
    insert academicDept;

    // Required: hed__Term__c (Standard EDA Term)
    hed__Term__c hedTerm = new hed__Term__c(
        Name = 'Spring 2025 Term',
        hed__Account__c = academicDept.Id, 
        Term_Reference__c = 'Term 1'
    );
    insert hedTerm;

    // Custom Academic Term
    Academic_Term__c term = new Academic_Term__c(
        Name = 'Spring 2025'
    );
    insert term;

    // CEM
    Course_Enrollment_Management__c cem = new Course_Enrollment_Management__c(
        Academic_Term__c = term.Id
    );
    insert cem;

    // Courses
    hed__Course__c course1 = new hed__Course__c(
        Name = 'Math 101',
        hed__Course_ID__c = 'MATH-101',
        hed__Account__c = academicDept.Id
    );
    insert course1;

    hed__Course__c course2 = new hed__Course__c(
        Name = 'Physics 102',
        hed__Course_ID__c = 'PHYS-102',
        hed__Account__c = academicDept.Id
    );
    insert course2;

    // Course Offering WITHOUT ICP
    hed__Course_Offering__c offering1 = new hed__Course_Offering__c(
        Name = 'Math 101 - Section A',
        hed__Course__c = course1.Id,
        hed__Term__c = hedTerm.Id,            // REQUIRED
        Academic_Term__c = term.Id
    );
    insert offering1;

    // Existing ICP
    Interpathway_Capacity_Planner__c icpExisting = new Interpathway_Capacity_Planner__c(
        Academic_Term__c = term.Id,
        Capacity__c = 50,
        Active__c = true
    );
    insert icpExisting;

    // Course Offering WITH ICP (should be skipped in getInitialData)
    hed__Course_Offering__c offering2 = new hed__Course_Offering__c(
        Name = 'Physics 102 - Section A',
        hed__Course__c = course2.Id,
        hed__Term__c = hedTerm.Id,            // REQUIRED
        Academic_Term__c = term.Id,
        Interpathway_Capacity_Planner__c = icpExisting.Id
    );
    insert offering2;
}




    // ---------------------------------------------------------------------------
    // TEST getInitialData()
    // ---------------------------------------------------------------------------
    @IsTest
    static void testGetInitialData() {
        Course_Enrollment_Management__c cem = [
            SELECT Id FROM Course_Enrollment_Management__c LIMIT 1
        ];

        Test.startTest();
        Map<String, Object> result = InterpathwayPlannerController.getInitialData(cem.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Expected returned data.');
        System.assertEquals(cem.Id, result.get('selectedCemId'), 'CEM ID mismatch.');
        System.assert(result.containsKey('courseOfferings'), 'Expected course offerings in result.');

        List<Object> offerings = (List<Object>) result.get('courseOfferings');

        // Only 1 offering should appear (the one not assigned to ICP)
        System.assertEquals(1, offerings.size(), 'Offerings list should exclude ICP-assigned records.');
    }


    // ---------------------------------------------------------------------------
    // TEST createInterpathwayCapacityPlanner() — Individual Capacity
    // ---------------------------------------------------------------------------
    @IsTest
    static void testCreateICPIndividual() {
        List<hed__Course_Offering__c> cos = [
            SELECT Id, hed__Course__c
            FROM hed__Course_Offering__c
            WHERE Interpathway_Capacity_Planner__c = null
            LIMIT 1
        ];

        Course_Enrollment_Management__c cem = [
            SELECT Id, Academic_Term__c
            FROM Course_Enrollment_Management__c LIMIT 1
        ];

        Test.startTest();
        String result = InterpathwayPlannerController.createInterpathwayCapacityPlanner(
            new List<Id>{ cos[0].Id },
            cem.Id,
            cem.Academic_Term__c,
            30
        );
        Test.stopTest();
    }



    

    // ---------------------------------------------------------------------------
    // TEST createInterpathwayCapacityPlanner() — Conflict Scenario
    // ---------------------------------------------------------------------------
    @IsTest
    static void testCreateICPConflict() {
        // Pick an offering that already has an ICP assigned
        hed__Course_Offering__c existing = [
            SELECT Id
            FROM hed__Course_Offering__c
            WHERE Interpathway_Capacity_Planner__c != null
            LIMIT 1
        ];

        Course_Enrollment_Management__c cem = [
            SELECT Id, Academic_Term__c FROM Course_Enrollment_Management__c LIMIT 1
        ];

        Test.startTest();
        String result = InterpathwayPlannerController.createInterpathwayCapacityPlanner(
            new List<Id>{ existing.Id },
            cem.Id,
            cem.Academic_Term__c,
            50
        );
        Test.stopTest();
    }
}