@IsTest
private class CreateClassControllerTest {

    @TestSetup
    static void setupData() {

        //
        // 1. Academic Unit (required by hed__Course__c)
        //
        Account academicDept = new Account(
            Name = 'Dept of Engineering'
        );
        insert academicDept;

        //
        // 2. EDA Term (hed__Term__c) — required for Course Offering
        //
        hed__Term__c hedTerm = new hed__Term__c(
            Name = 'Fall 2025',
            hed__Account__c = academicDept.Id, 
            Term_Reference__c = 'Term 1'
        );
        insert hedTerm;

        //
        // 3. Academic Term (custom field used by your org)
        //
        Academic_Term__c term = new Academic_Term__c(
            Name = 'Fall 2025'
        );
        insert term;

        //
        // 4. Create a Course
        //
        hed__Course__c course = new hed__Course__c(
            Name = 'Computer Science 101',
            hed__Course_ID__c = 'CS101',
            hed__Account__c = academicDept.Id
        );
        insert course;

        //
        // 5. Create an ICP
        //
        Interpathway_Capacity_Planner__c icp = new Interpathway_Capacity_Planner__c(
            Academic_Term__c = term.Id,
            Capacity__c = 100,
            Active__c = true
        );
        insert icp;

        //
        // 6. Create Course Offering linked to ICP
        //
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'CS101 - Section A',
            hed__Course__c = course.Id,
            Academic_Term__c = term.Id,
            hed__Term__c = hedTerm.Id,              // required
            Interpathway_Capacity_Planner__c = icp.Id
        );
        insert offering;

        //
        // 7. Create Contact for enrollment
        //
        Contact con = new Contact(
            LastName = 'StudentA'
        );
        insert con;

        //
        // 8. Create Enrollments (3 students)
        //
        List<hed__Course_Enrollment__c> enrollments = new List<hed__Course_Enrollment__c>();
        for (Integer i = 0; i < 3; i++) {
            enrollments.add(new hed__Course_Enrollment__c(
                hed__Contact__c = con.Id,
                hed__Course_Offering__c = offering.Id
            ));
        }
        insert enrollments;
    }

    // --------------------------------------------------------------------------
    // TEST getCourseConnectionCount
    // --------------------------------------------------------------------------
    @IsTest
    static void testGetCourseConnectionCount() {
        Interpathway_Capacity_Planner__c icp = [
            SELECT Id FROM Interpathway_Capacity_Planner__c LIMIT 1
        ];

        Test.startTest();
        Integer count = CreateClassController.getCourseConnectionCount(icp.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetCourseConnectionCountNull() {
        Test.startTest();
        Integer count = CreateClassController.getCourseConnectionCount(null);
        Test.stopTest();

    }

    // --------------------------------------------------------------------------
    // TEST createClassAllocationsAndAssignEnrollments — SUCCESS
    // --------------------------------------------------------------------------
    @IsTest
    static void testCreateClassAllocationsSuccess() {

        Interpathway_Capacity_Planner__c icp = [
            SELECT Id FROM Interpathway_Capacity_Planner__c LIMIT 1
        ];

        Test.startTest();
        CreateClassController.createClassAllocationsAndAssignEnrollments(
            icp.Id,
            2,   // num classes
            2    // students per class -> TOTAL CAPACITY = 4 > 3 students
        );
        Test.stopTest();
    }

    // --------------------------------------------------------------------------
    // TEST createClassAllocationsAndAssignEnrollments — SHORTAGE ERROR
    // --------------------------------------------------------------------------
    @IsTest
    static void testCreateClassAllocationsShortage() {

        Interpathway_Capacity_Planner__c icp = [
            SELECT Id FROM Interpathway_Capacity_Planner__c LIMIT 1
        ];

        Boolean didThrow = false;

        try {
            Test.startTest();
            CreateClassController.createClassAllocationsAndAssignEnrollments(
                icp.Id,
                1,  // 1 class
                2   // capacity = 2 < 3 enrollments
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            didThrow = true;
        }
    }

    // --------------------------------------------------------------------------
    // TEST createClassAllocationsAndAssignEnrollments — INVALID INPUT
    // --------------------------------------------------------------------------
    @IsTest
    static void testCreateClassAllocationsInvalid() {

        Boolean didThrow = false;

        try {
            Test.startTest();
            CreateClassController.createClassAllocationsAndAssignEnrollments(
                null,
                0,
                0
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            didThrow = true;
         
        }
    }
}