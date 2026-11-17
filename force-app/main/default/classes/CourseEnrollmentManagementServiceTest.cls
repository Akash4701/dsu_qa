@IsTest
private class CourseEnrollmentManagementServiceTest {

    @TestSetup
    static void setupData() {

        //
        // 1. Academic Unit (required for hed__Course__c)
        //
        Account dept = new Account(Name = 'Engineering Department');
        insert dept;

        //
        // 2. hed__Term__c (EDA Standard Term – required for Course Offering)
        //
        hed__Term__c hedTerm = new hed__Term__c(
            Name = 'Spring 2026',
            hed__Account__c = dept.Id, 
            Term_Reference__c = 'Term 1'
        );
        insert hedTerm;

        //
        // 3. AcademicTerm__c (your custom term)
        //
        Academic_Term__c customTerm = new Academic_Term__c(
            Name = 'Spring 2026'
        );
        insert customTerm;

        //
        // 4. Course
        //
        hed__Course__c course = new hed__Course__c(
            Name = 'CS105',
            hed__Course_ID__c = 'CS105',
            hed__Account__c = dept.Id
        );
        insert course;

        //
        // 5. Create CEM (initial insert)
        //
        Course_Enrollment_Management__c cem = new Course_Enrollment_Management__c(
            Academic_Term__c = customTerm.Id
        );
        insert cem;

        //
        // 6. Course Offering (linked to custom term)
        //
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'CS105 - Section A',
            hed__Course__c = course.Id,
            hed__Term__c = hedTerm.Id,
            Academic_Term__c = customTerm.Id,
            Course_Enrollment_Management__c = null     // will be filled by service
        );
        insert offering;

        //
        // 7. Create Course Version record linked to offering
        //
        Course_Version__c cv = new Course_Version__c(
            Course_Offering__c = offering.Id,
            Academic_Term__c = null,
            Course_Enrollment_Management__c = null
        );
        insert cv;

        // Link Course Offering to Course Version (your service logic uses this)
        offering.Course_Version__c = cv.Id;
        update offering;
    }


    // -----------------------------------------------------------------------
    // TEST: afterInsertOrTermSet (triggered during Insert)
    // -----------------------------------------------------------------------
    @IsTest
    static void testAfterInsertPropagation() {

        Course_Enrollment_Management__c cem = [
            SELECT Id, Academic_Term__c
            FROM Course_Enrollment_Management__c
            LIMIT 1
        ];

        List<Course_Enrollment_Management__c> newList = new List<Course_Enrollment_Management__c>{ cem };

        Test.startTest();
        CourseEnrollmentManagementService.afterInsertOrTermSet(newList, null);
        Test.stopTest();

    }


    // -----------------------------------------------------------------------
    // TEST: afterInsertOrTermSet (triggered during UPDATE — term changed)
    // -----------------------------------------------------------------------
    @IsTest
    static void testAfterUpdateTermChangePropagation() {

        //
        // Create brand-new term to simulate "term changed"
        //
        Academic_Term__c newTerm = new Academic_Term__c(
            Name = 'Fall 2026'
        );
        insert newTerm;

        Course_Enrollment_Management__c cem = [
            SELECT Id, Academic_Term__c
            FROM Course_Enrollment_Management__c
            LIMIT 1
        ];

        // Clone old map
        Map<Id, Course_Enrollment_Management__c> oldMap = new Map<Id, Course_Enrollment_Management__c>{
            cem.Id => cem
        };

        // Update CEM to new term
        cem.Academic_Term__c = newTerm.Id;
        update cem;

        List<Course_Enrollment_Management__c> newList = new List<Course_Enrollment_Management__c>{ cem };

        Test.startTest();
        CourseEnrollmentManagementService.afterInsertOrTermSet(newList, oldMap);
        Test.stopTest();
    }
}