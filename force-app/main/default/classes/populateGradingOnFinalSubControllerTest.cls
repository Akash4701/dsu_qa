@IsTest
public with sharing class populateGradingOnFinalSubControllerTest {

    @TestSetup
    static void setupData() {

        // ==============================
        // Base data (your standard pattern)
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

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        // ------------------------------
        // Grade Scheme (for formula Grade_Scheme_RecordType_Name__c)
        // Grade_Scheme_RecordType_Name__c = Grade_Scheme__r.RecordType.DeveloperName (formula)
        // So we set Grade_Scheme__c with RecordType DeveloperName = 'Course' if it exists.
        // ------------------------------
        Id gradeSchemeRtId = null;
        List<RecordType> gsRT = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Grade_Scheme__c'
              AND DeveloperName = 'Course'
            LIMIT 1
        ];
        if (!gsRT.isEmpty()) gradeSchemeRtId = gsRT[0].Id;

        Grade_Scheme__c scheme = new Grade_Scheme__c(Name = 'Test Scheme');
        if (gradeSchemeRtId != null) scheme.RecordTypeId = gradeSchemeRtId;
        insert scheme;

        // ------------------------------
        // Letter Grade Setting (Relative)
        // populateGradingOnFinalSubController checks Mechanism__c on setting via Letter_Grade_Setting__r
        // ------------------------------
        Letter_Grade_Setting__c lgs = new Letter_Grade_Setting__c(
            Name = 'Relative LGS',
            Mechanism__c = 'Relative',
            Is_Active__c = true
        );
        insert lgs;

        // ------------------------------
        // Course Offering (uses Grade_Scheme_RecordType_Name__c formula)
        // ------------------------------
        hed__Course_Offering__c offering1 = new hed__Course_Offering__c(
            Name = 'Offering 1',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            Grade_Scheme__c = scheme.Id,
            Letter_Grade_Setting__c = lgs.Id
        );
        insert offering1;

        // Create a 2nd offering with same term+course so that if Grade_Scheme_RecordType_Name__c='Course'
        // the controller branch that adds related offerings gets data too.
        hed__Course_Offering__c offering2 = new hed__Course_Offering__c(
            Name = 'Offering 2',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            Grade_Scheme__c = scheme.Id,
            Letter_Grade_Setting__c = lgs.Id
        );
        insert offering2;

        // ------------------------------
        // Letter Grading ranges (RELATIVE uses percentile)
        // We add one "non-matching" range to force CONTINUE
        // and one matching range to hit assignment+break.
        // ------------------------------
        insert new List<Letter_Grading__c>{
            // Non-matching range (forces continue)
            new Letter_Grading__c(
                Letter_Grade_Setting__c = lgs.Id,
                Course_Offering__c = offering1.Id,
                Letter_Grade__c = 'X',
                Range_Start__c = 0,
                Range_End__c = 5,
                Grade_Point__c = 0
            ),
            // Matching ranges
            new Letter_Grading__c(
                Letter_Grade_Setting__c = lgs.Id,
                Course_Offering__c = offering1.Id,
                Letter_Grade__c = 'A',
                Range_Start__c = 80,
                Range_End__c = 100,
                Grade_Point__c = 10
            ),
            new Letter_Grading__c(
                Letter_Grade_Setting__c = lgs.Id,
                Course_Offering__c = offering1.Id,
                Letter_Grade__c = 'B',
                Range_Start__c = 50,
                Range_End__c = 79.99,
                Grade_Point__c = 8
            ),
            new Letter_Grading__c(
                Letter_Grade_Setting__c = lgs.Id,
                Course_Offering__c = offering1.Id,
                Letter_Grade__c = 'C',
                Range_Start__c = 20,
                Range_End__c = 49.99,
                Grade_Point__c = 6
            ),
            new Letter_Grading__c(
                Letter_Grade_Setting__c = lgs.Id,
                Course_Offering__c = offering1.Id,
                Letter_Grade__c = 'D',
                Range_Start__c = 0,
                Range_End__c = 19.99,
                Grade_Point__c = 4
            )
        };

        // ------------------------------
        // Students + Program Enrollment (kept consistent with your pattern)
        // ------------------------------
        List<Contact> students = new List<Contact>();
        for (Integer i = 0; i < 5; i++) {
            students.add(new Contact(LastName = 'Student ' + i));
        }
        insert students;

        hed__Program_Plan__c pp = new hed__Program_Plan__c(Name = 'Test PP');
        insert pp;

        List<hed__Affiliation__c> affs = new List<hed__Affiliation__c>();
        for (Contact c : students) {
            affs.add(new hed__Affiliation__c(
                hed__Contact__c = c.Id,
                hed__Account__c = dept.Id,
                Program_Plan__c = pp.Id
            ));
        }
        insert affs;

        List<hed__Program_Enrollment__c> pes = new List<hed__Program_Enrollment__c>();
        for (Integer i = 0; i < students.size(); i++) {
            pes.add(new hed__Program_Enrollment__c(
                hed__Contact__c = students[i].Id,
                hed__Account__c = dept.Id,
                Term__c = term.Id,
                hed__Affiliation__c = affs[i].Id
            ));
        }
        insert pes;

        // ------------------------------
        // Course Enrollment RecordType = Student (controller query filters this)
        // ------------------------------
        Id ceStudentRtId = null;
        List<RecordType> ceRT = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'hed__Course_Enrollment__c'
              AND DeveloperName = 'Student'
            LIMIT 1
        ];
        if (!ceRT.isEmpty()) ceStudentRtId = ceRT[0].Id;

        // 5 Course Enrollments on offering1 (we will compute statuses by handler)
        List<hed__Course_Enrollment__c> ces = new List<hed__Course_Enrollment__c>();
        for (Integer i = 0; i < 5; i++) {
            hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
                hed__Course_Offering__c = offering1.Id,
                hed__Program_Enrollment__c = pes[i].Id
            );
            if (ceStudentRtId != null) ce.RecordTypeId = ceStudentRtId;
            ces.add(ce);
        }
        insert ces;

        // ------------------------------
        // Components needed by ComponentScoresHandler pass/fail calc
        // ------------------------------
        Course_Evaluation_Component__c ciaComp = new Course_Evaluation_Component__c(
            Name = 'CIA Comp',
            Course_Offering__c = offering1.Id,
            Exam_Type__c = 'CIA',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        Course_Evaluation_Component__c seeComp = new Course_Evaluation_Component__c(
            Name = 'SEE Comp',
            Course_Offering__c = offering1.Id,
            Exam_Type__c = 'SEE',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert new List<Course_Evaluation_Component__c>{ ciaComp, seeComp };

        // ------------------------------
        // Create Component_Scores__c so HANDLER computes:
        // - Component_Final_Score__c
        // - Exam_Result_Status__c
        //
        // PASS: CIA Pass + SEE Pass (3 records, two duplicate totals to hit commonScore== branch)
        // FAIL: CIA Pass + SEE Fail
        // IN COMPLETE: only CIA present (SEE missing -> defaults IC)
        // ------------------------------
        List<Component_Scores__c> scores = new List<Component_Scores__c>();

        // CE[0] PASS total 95 (50+45)
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[0].Id,
            Component_Name__c = ciaComp.Id,
            Exam_Type__c = 'CIA',
            Marks_Obtained__c = 50,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[0].Id,
            Component_Name__c = seeComp.Id,
            Exam_Type__c = 'SEE',
            Marks_Obtained__c = 45,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));

        // CE[1] PASS total 95 (50+45) -> duplicate score to hit commonScoreCount++
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[1].Id,
            Component_Name__c = ciaComp.Id,
            Exam_Type__c = 'CIA',
            Marks_Obtained__c = 50,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[1].Id,
            Component_Name__c = seeComp.Id,
            Exam_Type__c = 'SEE',
            Marks_Obtained__c = 45,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));

        // CE[2] PASS total 60 (30+30)
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[2].Id,
            Component_Name__c = ciaComp.Id,
            Exam_Type__c = 'CIA',
            Marks_Obtained__c = 30,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Fail' // below 40 -> fail at component level
        ));
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[2].Id,
            Component_Name__c = seeComp.Id,
            Exam_Type__c = 'SEE',
            Marks_Obtained__c = 30,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Fail'
        ));
        // NOTE: This would make final status FAIL by handler (Fail+Fail).
        // We want a PASS record here for controller PASS bucket.
        // So adjust to marks >=40.
        scores.remove(scores.size()-1);
        scores.remove(scores.size()-1);
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[2].Id,
            Component_Name__c = ciaComp.Id,
            Exam_Type__c = 'CIA',
            Marks_Obtained__c = 40,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[2].Id,
            Component_Name__c = seeComp.Id,
            Exam_Type__c = 'SEE',
            Marks_Obtained__c = 20,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Fail'
        ));
        // That makes final FAIL, not PASS. We need PASS.
        // So instead set PASS marks:
        scores.remove(scores.size()-1);
        scores.remove(scores.size()-1);
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[2].Id,
            Component_Name__c = ciaComp.Id,
            Exam_Type__c = 'CIA',
            Marks_Obtained__c = 30,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[2].Id,
            Component_Name__c = seeComp.Id,
            Exam_Type__c = 'SEE',
            Marks_Obtained__c = 30,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));
        // With your handler, result depends on Component_Score_Result__c values (not marks) in calculateAndUpdateFinalScore.
        // So PASS+PASS => final Pass. Total score becomes 60.

        // CE[3] FAIL: CIA Pass + SEE Fail
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[3].Id,
            Component_Name__c = ciaComp.Id,
            Exam_Type__c = 'CIA',
            Marks_Obtained__c = 50,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[3].Id,
            Component_Name__c = seeComp.Id,
            Exam_Type__c = 'SEE',
            Marks_Obtained__c = 10,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Fail'
        ));

        // CE[4] IN COMPLETE: only CIA exists -> SEE defaults In Complete
        scores.add(new Component_Scores__c(
            Course_Connection__c = ces[4].Id,
            Component_Name__c = ciaComp.Id,
            Exam_Type__c = 'CIA',
            Marks_Obtained__c = 50,
            Is_Active__c = true,
            Exam_Status__c = 'Present',
            Component_Score_Result__c = 'Pass'
        ));

        insert scores;

        // IMPORTANT:
        // Call the handler AFTER insert to compute:
        // - Component_Final_Score__c
        // - Exam_Result_Status__c
        ComponentScoresHandler.onAfterInsert(scores);
    }

    @IsTest
    static void testPopulateGrade_fullCoverage() {
        Id offeringId = [SELECT Id FROM hed__Course_Offering__c WHERE Name = 'Offering 1' LIMIT 1].Id;

        Test.startTest();
        populateGradingOnFinalSubController.populateGrade(offeringId);
        Test.stopTest();
    }
}