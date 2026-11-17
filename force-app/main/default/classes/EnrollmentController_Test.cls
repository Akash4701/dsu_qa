@IsTest
public class EnrollmentController_Test {

    // STATIC IDs reused across tests (top-level only)
    static Id instAccountId;
    static Id deptAccountId;
    static Id programAccountId;
    static Id progPlanId;
    static Id academicTermId;
    static Id termId;
    static Id courseId;
    static Id courseOfferingId;
    static Id student1Id;
    static Id student2Id;
    static Id facultyId;

    // -------------------------------
    // STATIC: Init common data
    // -------------------------------
    static void initCommonData() {
        if (progPlanId != null) return;

        // 1. Account Hierarchy
        Account inst = new Account(Name = 'Institute A');
        insert inst;
        instAccountId = inst.Id;

        Account dept = new Account(Name = 'Department A', ParentId = inst.Id);
        insert dept;
        deptAccountId = dept.Id;

        Account program = new Account(Name = 'Program A', ParentId = dept.Id);
        insert program;
        programAccountId = program.Id;

        // Program Specialization RT
        Id progSpecRT = Schema.SObjectType.Account
            .getRecordTypeInfosByName().get('Program Specialization').getRecordTypeId();

        insert new Account(
            Name = 'Program Specialization A',
            ParentId = program.Id,
            RecordTypeId = progSpecRT
        );

        // 2. Program Plan
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Plan A',
            hed__Account__c = program.Id
        );
        insert plan;
        progPlanId = plan.Id;

        // 3. Academic Term + hed__Term
        Academic_Term__c at = new Academic_Term__c(Name = 'AT 2025');
        insert at;
        academicTermId = at.Id;

        hed__Term__c term = new hed__Term__c(
            Name = 'Term A',
            hed__Start_Date__c = Date.today().addDays(-5),
            hed__End_Date__c = Date.today().addDays(30),
            hed__Account__c = dept.Id, 
            Term_Reference__c = 'Term 1',
            Program_Plan__c = plan.Id,
            Academic_Term__c = at.Id
        );
        insert term;
        termId = term.Id;

        // 4. Course + Offering
        hed__Course__c course = new hed__Course__c(
            Name = 'Course A',
            hed__Course_ID__c = 'C001',
            Credits__c = 3,
            hed__Account__c = program.Id
        );
        insert course;
        courseId = course.Id;

        Course_Enrollment_Management__c cem =
            new Course_Enrollment_Management__c(Academic_Term__c = at.Id);
        insert cem;

        hed__Course_Offering__c co = new hed__Course_Offering__c(
            Name = 'Course Offering A',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            Academic_Term__c = at.Id,
            Course_Enrollment_Management__c = cem.Id
        );
        insert co;
        courseOfferingId = co.Id;

        // Plan requirement
        insert new hed__Plan_Requirement__c(
            hed__Course__c = course.Id,
            hed__Category__c = 'Major',
            Term__c = term.Id
        );

        // 5. Students
        Contact student1 = new Contact(LastName = 'Student One');
        insert student1;
        student1Id = student1.Id;

        Contact student2 = new Contact(LastName = 'Student Two');
        insert student2;
        student2Id = student2.Id;

        // Faculty contact (RecordType = Faculty)
        Id facultyRT = [
            SELECT Id FROM RecordType
            WHERE DeveloperName = 'Faculty' AND SobjectType = 'Contact'
            LIMIT 1
        ].Id;

        Contact fac = new Contact(
            LastName = 'Faculty One',
            RecordTypeId = facultyRT
        );
        insert fac;
        facultyId = fac.Id;

        // Applications + affiliations
        createApplicationsAndAffiliations();
    }

    // -------------------------------
    // STATIC helper
    // -------------------------------
    static void createApplicationsAndAffiliations() {
        Application__c app1 = new Application__c(
            ContactId__c = student1Id,
            Program_Plan__c = progPlanId,
            Status__c = 'Admitted',
            External_Application_Number__c = 'HBCJN647', Program_Level__c = 'UG'
        );
        Application__c app2 = new Application__c(
            ContactId__c = student2Id,
            Program_Plan__c = progPlanId,
            Status__c = 'Admitted',
            External_Application_Number__c = 'YGTFCVV333', Program_Level__c = 'PG'
        );
        insert new List<Application__c>{ app1, app2 };

        insert new hed__Affiliation__c(
            hed__Contact__c = student1Id,
            hed__Account__c = programAccountId,
            Individual_Application__c = app1.Id,
            Is_DSU_Email_Active__c = true,
            Roll_Number__c = 'R001'
        );

        insert new hed__Program_Enrollment__c(
            hed__Contact__c = student1Id,
            hed__Program_Plan__c = progPlanId,
            Term__c = termId,
            hed__Account__c = programAccountId,
            hed__Enrollment_Status__c = 'Active'
        );
    }

    // -------------------------------
    // STATIC add default faculty CE
    // ------------------------------- 
    static void createDefaultFacultyEnrollment() {
        Id defaultRT = Schema.SObjectType.hed__Course_Enrollment__c
            .getRecordTypeInfosByName().get('Default').getRecordTypeId();

        insert new hed__Course_Enrollment__c(
            hed__Contact__c = facultyId,
            hed__Course_Offering__c = courseOfferingId,
            RecordTypeId = defaultRT,
            Is_Active__c = true
        );
    }

    // -------------------------------
    // STATIC: create pathway
    // -------------------------------
    static Id createProgramPathway() {
        Program_Pathway__c pp = new Program_Pathway__c(
            Name = 'Pathway A',
            Program_Plan__c = progPlanId,
            Specialization_Type__c = 'Major'
        );
        insert pp;
        return pp.Id;
    }

    // -------------------------------------------------------------
    // SETUP
    // -------------------------------------------------------------
    @TestSetup
    static void setupAll() {
        initCommonData();
    }

    // -------------------------------------------------------------
    // TESTS (unchanged logic)
    // -------------------------------------------------------------
    @IsTest
    static void testGetFilterOptions() {
        EnrollmentController.Filters f = EnrollmentController.getFilterOptions();
    }

    @IsTest
    static void testGetProgramPathwaysByPlan() {
        Id pathId = createProgramPathway();
        List<EnrollmentController.FilterOption> res =
            EnrollmentController.getProgramPathwaysByPlan(progPlanId);
    }

    @IsTest
    static void testSearchApplicationsNewAndExisting() {
        EnrollmentController.ApplicationWrapper wNew =
            EnrollmentController.searchApplications(
                String.valueOf(progPlanId),
                String.valueOf(termId),
                null,
                'new'
            );

        EnrollmentController.ApplicationWrapper wExisting =
            EnrollmentController.searchApplications(
                String.valueOf(progPlanId),
                String.valueOf(termId),
                null,
                'existing'
            );
    }



    @IsTest
    static void testCreateFacultyEnrollments() {
        createDefaultFacultyEnrollment();

        EnrollmentController.FacultyDetail fd =
            new EnrollmentController.FacultyDetail();
        fd.facultyId = String.valueOf(facultyId);
        fd.isPrimary = true;

        EnrollmentController.FacultyEnrollmentDetail fed =
            new EnrollmentController.FacultyEnrollmentDetail();
        fed.courseOfferingId = String.valueOf(courseOfferingId);
        fed.faculties = new List<EnrollmentController.FacultyDetail>{ fd };

        EnrollmentController.createFacultyEnrollments(
            new List<EnrollmentController.FacultyEnrollmentDetail>{ fed },
            String.valueOf(termId),
            String.valueOf(progPlanId),
            String.valueOf(programAccountId),
            null,
            String.valueOf(academicTermId)
        );

        Integer ceCount = [
            SELECT COUNT()
            FROM hed__Course_Enrollment__c
            WHERE hed__Contact__c = :facultyId
        ];
    }

}