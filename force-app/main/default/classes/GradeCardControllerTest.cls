@IsTest
public with sharing class GradeCardControllerTest {

    @TestSetup
    static void setupData() {

        // ==============================
        // Base data (same reference style)
        // ==============================

        Account dept = new Account(Name = 'Test Department');
        insert dept;

        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        Contact student = new Contact(
            LastName = 'Test Student',
            Registration_Number__c = 'REG-001',
            Passport_Size_Photo__c = 'https://example.com/photo.png'
        );
        insert student;

        // Affiliation for roll number + also used by other flows
        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Roll_Number__c = 'RN-001',
            DSU_Email__c = 'teststudent@dsuonline.com'
        );
        insert aff;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4,
            hed__Course_ID__c = 'CSE101'
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        // Program plan / enrollment
        hed__Program_Plan__c pp = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert pp;

        // Program Enrollment (the controller queries by Term__c)
        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            SGPA__c = 8.25,
            hed__Affiliation__c = aff.Id
        );
        insert pe;

        // Course Enrollment under PE (used to populate courseRows)
        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            hed__Program_Enrollment__c = pe.Id,
          	Letter_Grade__c = 'A',
            Grade_Point__c = 8,
            Component_Final_Score__c = 75,
            Exam_Result_Status__c = 'Pass',
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert ce;

        // Component definition (needed for Component_Scores__c joins)
        Course_Evaluation_Component__c cecCIA = new Course_Evaluation_Component__c(
            Name = 'CIA Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        Course_Evaluation_Component__c cecSEE = new Course_Evaluation_Component__c(
            Name = 'SEE Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'SEE',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert new List<Course_Evaluation_Component__c>{ cecCIA, cecSEE };

        // Active component scores (CIA + SEE) for the Course Enrollment
        // Ensure Is_Active__c = true to be picked up
        Component_Scores__c ciaScore = new Component_Scores__c(
            Course_Connection__c = ce.Id,
            Exam_Type__c = 'CIA',
            Component_Name__c = cecCIA.Id,
            Marks_Obtained__c = 80,
            Component_Score_Result__c = 'Pass',
            Is_Active__c = true
        );
        Component_Scores__c seeScore = new Component_Scores__c(
            Course_Connection__c = ce.Id,
            Exam_Type__c = 'SEE',
            Component_Name__c = cecSEE.Id,
            Marks_Obtained__c = 70,
            Component_Score_Result__c = 'Pass',
            Is_Active__c = true
        );
        insert new List<Component_Scores__c>{ ciaScore, seeScore };

        // OPTIONAL: also create an older CIA score to prove "latest record only" logic
        Component_Scores__c oldCia = new Component_Scores__c(
            Course_Connection__c = ce.Id,
            Exam_Type__c = 'CIA',
            Component_Name__c = cecCIA.Id,
            Marks_Obtained__c = 50,
            Component_Score_Result__c = 'Fail',
            Is_Active__c = true
        );
        insert oldCia;
    }

    private static String expectedTitle(Id peId) {
        hed__Program_Enrollment__c pe = [
            SELECT hed__Contact__r.Name, hed__Affiliation__r.Roll_Number__c
            FROM hed__Program_Enrollment__c
            WHERE Id = :peId
            LIMIT 1
        ];
        return pe.hed__Contact__r.Name + '(' + pe.hed__Affiliation__r.Roll_Number__c + ')_E-Grade Card';
    }

    @IsTest
    static void testGenerateGradeCards_success_createsContentAndLinks() {
        Id termId = [SELECT Id FROM hed__Term__c WHERE Name = 'Spring 2025' LIMIT 1].Id;
        Id peId = [SELECT Id FROM hed__Program_Enrollment__c WHERE Term__c = :termId LIMIT 1].Id;
        String expected = expectedTitle(peId);

        Test.startTest();
        GradeCardController.GenerateResponse resp = GradeCardController.generateGradeCards(termId);
        Test.stopTest();

        System.assertEquals(1, resp.successCount, 'One PE in setup -> should generate 1 grade card');
        System.assertEquals(0, resp.failCount, 'No failures expected');
        System.assertEquals(0, resp.errors.size(), 'No errors expected');

        // Assert ContentDocumentLink created against Program Enrollment
        Integer links = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :peId
        ];
        System.assertEquals(1, links, 'PDF should be attached to Program Enrollment via ContentDocumentLink');

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :peId
            LIMIT 1
        ];
        ContentVersion cv = [
            SELECT Title, Document_Type__c
            FROM ContentVersion
            WHERE ContentDocumentId = :cdl.ContentDocumentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(expected, cv.Title, 'Title should be Name(Roll_Number)_E-Grade Card');
        System.assertEquals('Grade Card', cv.Document_Type__c, 'Document type should be Grade Card');
    }

    @IsTest
    static void testGenerateGradeCards_throwsWhenTermNull() {
        Test.startTest();
        try {
            GradeCardController.generateGradeCards(null);
            System.assert(false, 'Expected AuraHandledException for null termId');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'AuraHandledException should be thrown for null termId');
        }
        Test.stopTest();
    }

    @IsTest
    static void testGenerateGradeCards_noProgramEnrollments_returnsZeroCounts() {
        Account dept = [SELECT Id FROM Account WHERE Name = 'Test Department' LIMIT 1];

        hed__Term__c emptyTerm = new hed__Term__c(
            Name = 'Empty Term',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert emptyTerm;

        Test.startTest();
        GradeCardController.GenerateResponse resp = GradeCardController.generateGradeCards(emptyTerm.Id);
        Test.stopTest();

        System.assertEquals(0, resp.successCount);
        System.assertEquals(0, resp.failCount);
        System.assertEquals(0, resp.errors.size());
    }

    @IsTest
    static void testVfConstructor_buildsPdfData_andCourseRows() {
        Id termId = [SELECT Id FROM hed__Term__c WHERE Name = 'Spring 2025' LIMIT 1].Id;
        Id peId = [SELECT Id FROM hed__Program_Enrollment__c WHERE Term__c = :termId LIMIT 1].Id;

        // Simulate VF page params
        ApexPages.currentPage().getParameters().put('termId', String.valueOf(termId));
        ApexPages.currentPage().getParameters().put('peId', String.valueOf(peId));

        GradeCardController ctrl = new GradeCardController();
        System.assertEquals('Test Student', ctrl.studentName);
        System.assertEquals('RN-001', ctrl.rollNumber);
        System.assertEquals('Test Department', ctrl.programName, 'Program name should be fetched from Account');
        System.assert(!ctrl.courseRows.isEmpty(), 'Course rows should be populated for the PE');
        GradeCardController.CourseRow row = ctrl.courseRows[0];
        System.assertEquals('CSE101', row.courseCode);
        System.assertEquals(false, ctrl.isCompact, 'isCompact should be false with 5 or fewer courses (PKDSU-213)');

    }

    @IsTest
    static void testIsCompact_trueWhenMoreThanFiveCourses() {
        Id termId = [SELECT Id FROM hed__Term__c WHERE Name = 'Spring 2025' LIMIT 1].Id;
        hed__Program_Enrollment__c pe = [SELECT Id, hed__Contact__c FROM hed__Program_Enrollment__c WHERE Term__c = :termId LIMIT 1];
        Account dept = [SELECT Id FROM Account WHERE Name = 'Test Department' LIMIT 1];

        // Setup already has 1 course enrollment (CSE101) for this PE; add 5 more
        // distinct courses so the total (6) crosses the "more than 5" threshold
        // that drives the compact PDF layout (PKDSU-213).
        List<hed__Course__c> extraCourses = new List<hed__Course__c>();
        for (Integer i = 1; i <= 5; i++) {
            extraCourses.add(new hed__Course__c(
                Name = 'Extra Course ' + i,
                hed__Account__c = dept.Id,
                Credits__c = 3,
                hed__Course_ID__c = 'CSE2' + String.valueOf(i).leftPad(2, '0')
            ));
        }
        insert extraCourses;

        List<hed__Course_Offering__c> extraOfferings = new List<hed__Course_Offering__c>();
        for (hed__Course__c c : extraCourses) {
            extraOfferings.add(new hed__Course_Offering__c(
                Name = 'Offering ' + c.Name,
                hed__Course__c = c.Id,
                hed__Term__c = termId
            ));
        }
        insert extraOfferings;

        List<hed__Course_Enrollment__c> extraEnrollments = new List<hed__Course_Enrollment__c>();
        for (hed__Course_Offering__c o : extraOfferings) {
            extraEnrollments.add(new hed__Course_Enrollment__c(
                hed__Contact__c = pe.hed__Contact__c,
                hed__Course_Offering__c = o.Id,
                hed__Program_Enrollment__c = pe.Id,
                Letter_Grade__c = 'A',
                Grade_Point__c = 8,
                Exam_Result_Status__c = 'Pass',
                Enrollment_Status__c = 'Enrolled',
                Exam_Eligibility__c = 'Eligible'
            ));
        }
        insert extraEnrollments;

        ApexPages.currentPage().getParameters().put('termId', String.valueOf(termId));
        ApexPages.currentPage().getParameters().put('peId', String.valueOf(pe.Id));

        GradeCardController ctrl = new GradeCardController();
        System.assertEquals(6, ctrl.courseRows.size(), 'Should have 6 course rows (1 from setup + 5 extra)');
        System.assertEquals(true, ctrl.isCompact, 'isCompact should be true with more than 5 courses (PKDSU-213)');
    }

    @IsTest
    static void testVfConstructor_programNameHandlesNullAccount() {
        // Term's Account is a required master-detail, so it must have a valid name.
        Account dept = new Account(Name = 'Dept For Null PE Account');
        insert dept;

        hed__Term__c termNoName = new hed__Term__c(
            Name = 'Empty Program Term',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 2',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert termNoName;

        Contact student = [SELECT Id FROM Contact WHERE LastName = 'Test Student' LIMIT 1];
        // hed__Account__c is intentionally left null to exercise the null-account branch
        // in the controller, where programName defaults to an empty string.
        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            Term__c = termNoName.Id,
            SGPA__c = 7.5
        );
        insert pe;

        ApexPages.currentPage().getParameters().put('termId', String.valueOf(termNoName.Id));
        ApexPages.currentPage().getParameters().put('peId', String.valueOf(pe.Id));

        GradeCardController ctrl = new GradeCardController();
        System.assertEquals('', ctrl.programName, 'Program name should default to empty string when the Program Enrollment has no Account');
    }

    @IsTest
    static void testVfConstructor_noSeeComponentScore_showsInCompleteAndRealMaxMin() {
        Id termId = [SELECT Id FROM hed__Term__c WHERE Name = 'Spring 2025' LIMIT 1].Id;
        hed__Program_Enrollment__c pe = [SELECT Id, hed__Contact__c FROM hed__Program_Enrollment__c WHERE Term__c = :termId LIMIT 1];
        Account dept = [SELECT Id FROM Account WHERE Name = 'Test Department' LIMIT 1];

        hed__Course__c course2 = new hed__Course__c(
            Name = 'No SEE Course',
            hed__Account__c = dept.Id,
            Credits__c = 3,
            hed__Course_ID__c = 'CSE102'
        );
        insert course2;

        hed__Course_Offering__c offering2 = new hed__Course_Offering__c(
            Name = 'No SEE Offering',
            hed__Course__c = course2.Id,
            hed__Term__c = termId
        );
        insert offering2;

        // Student attempted CIA (and failed it) but never attempted SEE at all,
        // so no Component_Scores__c record exists for the SEE exam type.
        hed__Course_Enrollment__c ce2 = new hed__Course_Enrollment__c(
            hed__Contact__c = pe.hed__Contact__c,
            hed__Course_Offering__c = offering2.Id,
            hed__Program_Enrollment__c = pe.Id,
            Letter_Grade__c = 'IC',
            Exam_Result_Status__c = 'In Complete',
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible'
        );
        insert ce2;

        // Both CIA and SEE components are configured for this offering (Max 100 / Pass 40%),
        // even though the student only has a Component_Scores__c record for CIA.
        Course_Evaluation_Component__c cecCIA2 = new Course_Evaluation_Component__c(
            Name = 'CIA Component 2',
            Course_Offering__c = offering2.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        Course_Evaluation_Component__c cecSEE2 = new Course_Evaluation_Component__c(
            Name = 'SEE Component 2',
            Course_Offering__c = offering2.Id,
            Exam_Type__c = 'SEE',
            Maximum_Marks_for_the_Component__c = 70,
            Pass_Weightage__c = 40
        );
        insert new List<Course_Evaluation_Component__c>{ cecCIA2, cecSEE2 };

        Component_Scores__c ciaScore2 = new Component_Scores__c(
            Course_Connection__c = ce2.Id,
            Exam_Type__c = 'CIA',
            Component_Name__c = cecCIA2.Id,
            Marks_Obtained__c = 0,
            Component_Score_Result__c = 'Fail',
            Is_Active__c = true
        );
        insert ciaScore2;

        ApexPages.currentPage().getParameters().put('termId', String.valueOf(termId));
        ApexPages.currentPage().getParameters().put('peId', String.valueOf(pe.Id));

        GradeCardController ctrl = new GradeCardController();

        GradeCardController.CourseRow row2;
        for (GradeCardController.CourseRow r : ctrl.courseRows) {
            if (r.courseCode == 'CSE102') {
                row2 = r;
            }
        }

        System.assertNotEquals(null, row2, 'Row for the SEE-less course should be present');
        System.assertEquals('Fail', row2.ciaResult, 'CIA result should still reflect the actual component score result');
        System.assertEquals('In Complete', row2.seeResult, 'SEE result should show In Complete when no component score record exists for SEE');
        System.assertEquals(0, row2.seeScored, 'SEE scored should default to 0 when no component score record exists');
        System.assertEquals('70/28', row2.seeMax, 'SEE Max/Min should show the configured component values (70 max, 40% pass -> 28), not 0/0, even with no attempt');
        System.assertEquals('100/40', row2.ciaMax, 'CIA Max/Min should show the configured component values unaffected by this change');
    }

    @IsTest
    static void testStartGradeCardBatch_returnsJobId() {
        Id termId = [SELECT Id FROM hed__Term__c WHERE Name = 'Spring 2025' LIMIT 1].Id;

        Test.startTest();
        String jobId = GradeCardController.startGradeCardBatch(termId);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Batch job id should be returned');
        System.assert(jobId.startsWith('707'), 'Batch job id should be an AsyncApexJob id');
    }

    @IsTest
    static void testStorePdfFromBatch_createsContentAndLink() {
        Id peId = [SELECT Id FROM hed__Program_Enrollment__c LIMIT 1].Id;
        String expected = expectedTitle(peId);

        Test.startTest();
        GradeCardController.storePdfFromBatch(peId, Blob.valueOf('TEST_PDF'), 'E-Grade Card');
        Test.stopTest();

        Integer links = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :peId
        ];
        System.assertEquals(1, links, 'storePdfFromBatch should attach a PDF to the Program Enrollment');

        ContentDocumentLink cdl = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :peId
            LIMIT 1
        ];
        ContentVersion cv = [
            SELECT Title, Document_Type__c
            FROM ContentVersion
            WHERE ContentDocumentId = :cdl.ContentDocumentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(expected, cv.Title, 'Title should be Name(Roll_Number)_E-Grade Card');
        System.assertEquals('Grade Card', cv.Document_Type__c);
    }
}