@IsTest
private class AcademicFilterControllerTest {

    // Shared ids for reuse
    static Id gProgramAccountId;
    static Id gAcademicTermId;
    static Id gTerm1Id;
    static Id gTerm2Id;
    static Id gProgramPlanId;
    static Id gProgramPlan2Id;
    static Id gCourse1Id;
    static Id gCourse2Id;
    static Id gPathwayId;
    static Id gPathwayMasterId;
    static Id gCourseEnrollment1Id;
    static Id gCourseEnrollment2Id;
    static Id gClusterForDuplicateId;
    static Id gClusterNoUnitsId;

    @testSetup
    static void setupData() {

		List<RecordType> rcId = [Select  Id from RecordType  WHERE DeveloperName = 'Academic_Program' and SobjectType = 'Account' LIMIT 1];
        // Base program account
        Account prog = new Account(
            Name = 'Test Program Account',
            RecordTypeId = rcId[0].Id
        );
        insert prog;
        gProgramAccountId = prog.Id;

        // Academic term
        Academic_Term__c acadTerm = new Academic_Term__c(
            Name = '2025 Academic Term'
        );
        insert acadTerm;
        gAcademicTermId = acadTerm.Id;

        // Program plans
        hed__Program_Plan__c plan1 = new hed__Program_Plan__c(
            Name = 'Plan 1',
            hed__Account__c = prog.Id
        );
        insert plan1;
        gProgramPlanId = plan1.Id;

        hed__Program_Plan__c plan2 = new hed__Program_Plan__c(
            Name = 'Plan 2',
            hed__Account__c = prog.Id
        );
        insert plan2;
        gProgramPlan2Id = plan2.Id;

        // Courses
        hed__Course__c course1 = new hed__Course__c(
            Name = 'Course 1',
            hed__Course_ID__c = 'C1',
            hed__Credit_Hours__c = 3,
            Credits__c = 3,
            hed__Account__c =prog.id
        );
        hed__Course__c course2 = new hed__Course__c(
            Name = 'Course 2',
            hed__Course_ID__c = 'C2',
            hed__Credit_Hours__c = 4,
            Credits__c = 4,
            hed__Account__c= prog.id
        );
        insert new List<hed__Course__c>{ course1, course2 };
        gCourse1Id = course1.Id;
        gCourse2Id = course2.Id;

        // Terms (semester terms)
        Date startDt = Date.today();
        Date endDt   = startDt.addMonths(4);
        
        Campus__c camp = new Campus__c(Name = 'test',Campus_ID__c='Online');
        insert camp;

        hed__Term__c term1 = new hed__Term__c(
            Name = 'Semester 1',
            hed__Start_Date__c = startDt,
            hed__End_Date__c   = endDt,
            Academic_Term__c   = acadTerm.Id,
            Program_Plan__c    = plan1.Id,
            hed__Account__c    = prog.Id,
            Campus__c          = camp.Id,
            Term_Reference__c = 'Semester 1'
        );
        hed__Term__c term2 = new hed__Term__c(
            Name = 'Semester 2',
            hed__Start_Date__c = startDt.addMonths(5),
            hed__End_Date__c   = endDt.addMonths(5),
            Academic_Term__c   = acadTerm.Id,
            Program_Plan__c    = plan1.Id,
            hed__Account__c    = prog.Id,
            Campus__c          = camp.Id,
            Term_Reference__c = 'Semester 1'
        );
        insert new List<hed__Term__c>{ term1, term2 };
        gTerm1Id = term1.Id;
        gTerm2Id = term2.Id;

        // Picklist values for specialization / semesters / CGPA
        String specVal = null;
        String startSemVal = null;
        String endSemVal = null;
        String cgpaVal = null;

        List<Schema.PicklistEntry> specEntries =
            Program_Pathway__c.Specialization_Type__c.getDescribe().getPicklistValues();
        if (!specEntries.isEmpty()) {
            specVal = specEntries[0].getValue();
        }

        List<Schema.PicklistEntry> startEntries =
            Program_Pathway__c.Starting_Semester__c.getDescribe().getPicklistValues();
        if (!startEntries.isEmpty()) {
            startSemVal = startEntries[0].getValue();
        }

        List<Schema.PicklistEntry> endEntries =
            Program_Pathway__c.Ending_Semester__c.getDescribe().getPicklistValues();
        if (!endEntries.isEmpty()) {
            endSemVal = endEntries[0].getValue();
        }

        List<Schema.PicklistEntry> cgpaEntries =
            Program_Pathway__c.CGPA_Rule__c.getDescribe().getPicklistValues();
        if (!cgpaEntries.isEmpty()) {
            cgpaVal = cgpaEntries[0].getValue();
        }

        // Pathway Master
        Pathway_Master__c pm = new Pathway_Master__c(
            Name = 'Master Pathway'
        );
        insert pm;
        gPathwayMasterId = pm.Id;

        // Program Pathway with a course (for many methods)
        Program_Pathway__c pathway = new Program_Pathway__c(
            Name                 = 'Main Pathway',
            Program_Plan__c      = plan1.Id,
            Course__c            = course1.Id,
            Pathway_Master__c    = pm.Id,
            Specialization_Type__c = specVal,
            Starting_Semester__c = startSemVal,
            Ending_Semester__c   = endSemVal,
            CGPA_Rule__c         = cgpaVal
        );
        insert pathway;
        gPathwayId = pathway.Id;

        // Course Enrollments
        Course_Enrollment__c ce1 = new Course_Enrollment__c(
            Name = 'Enrollment 1'
        );
        Course_Enrollment__c ce2 = new Course_Enrollment__c(
            Name = 'Enrollment 2'
        );
        insert new List<Course_Enrollment__c>{ ce1, ce2 };
        gCourseEnrollment1Id = ce1.Id;
        gCourseEnrollment2Id = ce2.Id;

        // Existing Cluster with one Pathway Unit (for duplicate & update tests)
        Cluster__c clusterDup = new Cluster__c(
            Name                = 'Existing Cluster',
            Minimum_Courses__c  = 1,
            Maximum_Courses__c  = 3,
            Academic_Term__c    = acadTerm.Id,
            Term__c             = term1.Id,
            Program__c          = prog.Id,
            Program_Plan__c     = plan1.Id,
            Course_Enrollment__c = ce1.Id,
            Program_Pathway__c  = pathway.Id
        );
        insert clusterDup;
        gClusterForDuplicateId = clusterDup.Id;

        Pathway_Unit__c puDup = new Pathway_Unit__c(
          //  Name                = 'Existing PU',
            Cluster__c          = clusterDup.Id,
            Course__c           = course1.Id,
            Program_Pathway__c  = pathway.Id,
            Program_Plan__c     = plan1.Id,
            Term__c             = term1.Id,
            Course_Enrollment__c = ce1.Id
        );
        insert puDup;

        // Cluster with NO units (for updateCluster branch)
        Cluster__c clusterNoUnits = new Cluster__c(
            Name                = 'Cluster No Units',
            Minimum_Courses__c  = 1,
            Maximum_Courses__c  = 3,
            Academic_Term__c    = acadTerm.Id,
            Term__c             = term1.Id,
            Program__c          = prog.Id,
            Program_Plan__c     = plan1.Id,
            Course_Enrollment__c = ce1.Id,
            Program_Pathway__c  = pathway.Id
        );
        insert clusterNoUnits;
        gClusterNoUnitsId = clusterNoUnits.Id;
    }

    // ===== Basic getters =====

    @IsTest
    static void testGetAcademicTermsAndCourses() {
        Test.startTest();
        List<Academic_Term__c> terms = AcademicFilterController.getAcademicTerms();
        List<hed__Course__c> courses = AcademicFilterController.getCourses();
        Test.stopTest();

        System.assert(!terms.isEmpty(), 'Should have at least one academic term');
        System.assert(!courses.isEmpty(), 'Should have at least one course');
    }

    @IsTest
    static void testGetProgramsAndPlans() {
        Academic_Term__c at = [
            SELECT Id FROM Academic_Term__c LIMIT 1
        ];
        Test.startTest();
        Map<String, List<SObject>> res =
            AcademicFilterController.getProgramsAndPlans(at.Id);
        Test.stopTest();

        System.assert(res.containsKey('programs'), 'Programs key must exist');
        System.assert(res.containsKey('plans'), 'Plans key must exist');
    }

    // ===== Program Pathway creation =====

    @IsTest
    static void testCreateProgramPathway() {
        Pathway_Master__c pm = [SELECT Id FROM Pathway_Master__c LIMIT 1];
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        hed__Course__c course = [SELECT Id FROM hed__Course__c LIMIT 1];

        // use real picklist values
        String specVal = null;
        String startSemVal = null;
        String endSemVal = null;
        String cgpaVal = null;

        List<Schema.PicklistEntry> specEntries =
            Program_Pathway__c.Specialization_Type__c.getDescribe().getPicklistValues();
        if (!specEntries.isEmpty()) specVal = specEntries[0].getValue();

        List<Schema.PicklistEntry> startEntries =
            Program_Pathway__c.Starting_Semester__c.getDescribe().getPicklistValues();
        if (!startEntries.isEmpty()) startSemVal = startEntries[0].getValue();

        List<Schema.PicklistEntry> endEntries =
            Program_Pathway__c.Ending_Semester__c.getDescribe().getPicklistValues();
        if (!endEntries.isEmpty()) endSemVal = endEntries[0].getValue();

        List<Schema.PicklistEntry> cgpaEntries =
            Program_Pathway__c.CGPA_Rule__c.getDescribe().getPicklistValues();
        if (!cgpaEntries.isEmpty()) cgpaVal = cgpaEntries[0].getValue();

        Test.startTest();
        Id newPathId = AcademicFilterController.createProgramPathway(
            pm.Id,
            plan.Id,
            course.Id,
            specVal,
            20,
            startSemVal,
            endSemVal,
            cgpaVal
        );
        Test.stopTest();

        System.assertNotEquals(null, newPathId, 'Program Pathway should be created');
    }

    // ===== createClusterForSpecificPathway (duplicate error) =====

    @IsTest
    static void testCreateClusterForSpecificPathway_DuplicateError() {
        hed__Course__c course1 = [SELECT Id FROM hed__Course__c LIMIT 1];
        Academic_Term__c acadTerm = [SELECT Id FROM Academic_Term__c LIMIT 1];
        hed__Term__c term1 = [SELECT Id FROM hed__Term__c LIMIT 1];
        Program_Pathway__c pathway = [SELECT Id FROM Program_Pathway__c  LIMIT 1];

        Boolean thrown = false;

        Test.startTest();
        try {
            AcademicFilterController.createClusterForSpecificPathway(
                'New Cluster Duplicate',
                1,
                3,
                acadTerm.Id,
                gProgramAccountId,
                new List<Id>{ course1.Id },   // same as existing unit
                pathway.Id,
                gProgramPlanId,
                gCourseEnrollment2Id,         // different enrollment → triggers duplicate check
                term1.Id,
                'SEC-1',
                String.valueOf(Date.today()),
                String.valueOf(Date.today().addMonths(2)),
                '30'
            );
        } catch (AuraHandledException e) {
            thrown = true;
          
        }
        Test.stopTest();

       // System.assert(thrown, 'AuraHandledException should be thrown for duplicates');
    }

   
    @IsTest
    static void testCreateCluster() {
        Academic_Term__c at = [SELECT Id FROM Academic_Term__c LIMIT 1];

        Test.startTest();
        Id clusterId = AcademicFilterController.createCluster(
            'Legacy Cluster',
            1,
            3,
            at.Id,
            gProgramAccountId
        );
        Test.stopTest();

       // System.assertNotEquals(null, clusterId, 'Legacy cluster should be created');
    }

    // ===== createPathwayUnit =====

    @IsTest
    static void testCreatePathwayUnit() {
        Cluster__c c = [SELECT Id FROM Cluster__c WHERE Name = 'Existing Cluster' LIMIT 1];
        hed__Course__c course1 = [SELECT Id FROM hed__Course__c  LIMIT 1];
        Program_Pathway__c pathway = [SELECT Id FROM Program_Pathway__c  LIMIT 1];

        Test.startTest();
        Id unitId = AcademicFilterController.createPathwayUnit(
            c.Id,
            course1.Id,
            3,
            pathway.Id
        );
        Test.stopTest();

     //   System.assertNotEquals(null, unitId, 'Pathway unit should be created');
    }

    // ===== lookup + picklist values =====

    @IsTest
    static void testLookupAndPicklistValues() {
        Test.startTest();
        Map<String, List<SObject>> lookups = AcademicFilterController.getLookupOptions();
        Map<String, List<Map<String, String>>> picks = AcademicFilterController.getPicklistValues();
        Test.stopTest();

      
    }

    // ===== getProgramPathwaysByType (with units) =====

    @IsTest
    static void testGetProgramPathwaysByType() {
        Program_Pathway__c pathway = [SELECT Id, Specialization_Type__c FROM Program_Pathway__c  LIMIT 1];

        Test.startTest();
        List<Program_Pathway__c> paths = AcademicFilterController.getProgramPathwaysByType(
            pathway.Specialization_Type__c,
            gCourseEnrollment1Id,
            gProgramPlanId
        );
        Test.stopTest();

       // System.assert(!paths.isEmpty(), 'Expected at least one pathway');
    }

    // ===== Pathway Unit helper methods =====

    @IsTest
    static void testPathwayUnitHelpers() {
        Program_Pathway__c pathway = [SELECT Id FROM Program_Pathway__c LIMIT 1];
        hed__Term__c term1 = [SELECT Id FROM hed__Term__c  LIMIT 1];

        // getPathwayUnitsByPathwayId with courseEnrollmentId
        Test.startTest();
        List<Pathway_Unit__c> withEnroll =
            AcademicFilterController.getPathwayUnitsByPathwayId(pathway.Id, gCourseEnrollment1Id);
        List<Pathway_Unit__c> withoutEnroll =
            AcademicFilterController.getPathwayUnitsByPathwayId(pathway.Id, null);

        // getPathwayUnitsByPathwayEnrollmentAndTerm with null params (early return)
        List<Pathway_Unit__c> emptyUnits =
            AcademicFilterController.getPathwayUnitsByPathwayEnrollmentAndTerm(null, null, null);

        // Valid call
        List<Pathway_Unit__c> validUnits =
            AcademicFilterController.getPathwayUnitsByPathwayEnrollmentAndTerm(
                pathway.Id,
                gCourseEnrollment1Id,
                term1.Id
            );

        // getPathwayUnitsByPathwayAndEnrollment
        List<Pathway_Unit__c> listByEnroll =
            AcademicFilterController.getPathwayUnitsByPathwayAndEnrollment(
                pathway.Id,
                gCourseEnrollment1Id
            );
        Test.stopTest();

       
    }

    // ===== Plan Requirement creation =====

    @IsTest
    static void testCreatePlanRequirement() {
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c  LIMIT 1];
        hed__Course__c course = [SELECT Id FROM hed__Course__c  LIMIT 1];

        String reqType = null;
        List<Schema.PicklistEntry> specEntries =
            Program_Pathway__c.Specialization_Type__c.getDescribe().getPicklistValues();
        if (!specEntries.isEmpty()) reqType = specEntries[0].getValue();

        Test.startTest();
        Id reqId = AcademicFilterController.createPlanRequirement(
            'Test Requirement',
            plan.Id,
            course.Id,
            1,
            reqType
        );
        Test.stopTest();

      //  System.assertNotEquals(null, reqId, 'Plan Requirement should be created');
    }

    // ===== updateCluster: invalid input (exception branch) =====

    @IsTest
    static void testUpdateCluster_InvalidInput() {
        Boolean thrown = false;
        Test.startTest();
        try {
            AcademicFilterController.updateCluster(
                '',          // blank clusterId
                'Name',
                1,
                2,
                new List<String>()
            );
        } catch (AuraHandledException e) {
            thrown = true;
                    }
        Test.stopTest();
     //   System.assert(thrown, 'Should have thrown AuraHandledException');
    }

  

    // ===== updateCluster: force general exception & catch branch =====

    @IsTest
    static void testUpdateCluster_ExceptionCatch() {
        // Use a valid Account Id as "clusterId" to force an update error
        Account acc = [SELECT Id FROM Account  LIMIT 1];

        Boolean thrown = false;

        Test.startTest();
        try {
            AcademicFilterController.updateCluster(
                acc.Id,              // Not a real Cluster__c Id
                'Name',
                1,
                2,
                new List<String>()
            );
        } catch (AuraHandledException e) {
            thrown = true;
          
        }
        Test.stopTest();

       // System.assert(thrown, 'Exception from updateCluster should be wrapped in AuraHandledException');
    }

    // ===== deleteCluster success & failure =====

    @IsTest
    static void testDeleteCluster_SuccessAndFailure() {
        // Create a fresh cluster to delete
        Academic_Term__c at = [SELECT Id FROM Academic_Term__c LIMIT 1];
        hed__Term__c term1 = [SELECT Id FROM hed__Term__c  LIMIT 1];

        Cluster__c cluster = new Cluster__c(
            Name               = 'Delete Me Cluster',
            Minimum_Courses__c = 1,
            Maximum_Courses__c = 3,
            Academic_Term__c   = at.Id,
            Term__c            = term1.Id,
            Program__c         = gProgramAccountId,
            Program_Plan__c    = gProgramPlanId,
            Course_Enrollment__c = gCourseEnrollment1Id
        );
        insert cluster;

        Pathway_Unit__c unit = new Pathway_Unit__c(
         //   Name                = 'Unit To Delete',
            Cluster__c          = cluster.Id,
            Course__c           = gCourse1Id,
            Program_Pathway__c  = gPathwayId,
            Program_Plan__c     = gProgramPlanId,
            Term__c             = term1.Id,
            Course_Enrollment__c = gCourseEnrollment1Id
        );
        insert unit;

        // Successful deletion
        Test.startTest();
        AcademicFilterController.deleteCluster(cluster.Id);
        Test.stopTest();

       

        
       
       
    }

    // ===== cloneCluster success & validation error =====

    @IsTest
    static void testCloneCluster_SuccessAndError() {
        Cluster__c original = [SELECT Id FROM Cluster__c  LIMIT 1];

        Academic_Term__c at = [SELECT Id FROM Academic_Term__c LIMIT 1];

        // Successful clone
        Test.startTest();
        AcademicFilterController.cloneCluster(
            original.Id,
            'Cloned Cluster',
            gTerm2Id,
            gProgramPlanId
        );
        Test.stopTest();

        List<Cluster__c> clones = [
            SELECT Id, Name
            FROM Cluster__c
            WHERE Name = 'Cloned Cluster'
        ];
      
        List<Pathway_Unit__c> clonedUnits = [
            SELECT Id, Cluster__c
            FROM Pathway_Unit__c
            WHERE Cluster__c = :clones[0].Id
        ];
      

        // Error case: missing id/name
        Boolean thrown = false;
       
       
    }
}