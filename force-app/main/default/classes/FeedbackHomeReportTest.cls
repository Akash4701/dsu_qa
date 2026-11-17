/**
 * The Reports tab: collected answers joined with the student's USN (from Affiliation), filtered and paged
 * on the server. Reads run as a Feedback_Management user so the new Affiliation/Program Plan access is proven.
 */
@isTest
private class FeedbackHomeReportTest {

    private static final String USN_ONE = 'DSUOE252MBA0001';
    private static final String USN_OTHER_PLAN = 'DSUOE252MCA0099';
    private static final String USN_TWO = 'DSUOE252MBA0002';

    @testSetup
    static void setup() {
        Account institute = new Account(Name = 'Report Institute', Institute_Code__c = 'RPT');
        insert institute;
        Account dept = new Account(Name = 'Report Department', ParentId = institute.Id);
        insert dept;
        Account program = new Account(Name = 'Master of Business Administration', Alias__c = 'MBA', ParentId = dept.Id);
        insert program;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            hed__Account__c = program.Id, Batch__c = '2026', Intake_Number__c = 1, Sequence_Number__c = 1);
        insert plan;
        hed__Program_Plan__c otherPlan = new hed__Program_Plan__c(
            hed__Account__c = program.Id, Batch__c = '2027', Intake_Number__c = 2, Sequence_Number__c = 2);
        insert otherPlan;

        hed__Term__c term = new hed__Term__c(
            Name = '2026-FEB-MBA-Sem 2-ONLINE', hed__Account__c = program.Id, Term_Reference__c = 'Semester 2',
            Program_Plan__c = plan.Id);
        insert term;
        hed__Term__c laterTerm = new hed__Term__c(
            Name = '2026-AUG-MBA-Sem 3-ONLINE', hed__Account__c = program.Id, Term_Reference__c = 'Semester 3',
            Program_Plan__c = plan.Id);
        insert laterTerm;

        List<Contact> students = FeedbackTestFactory.createStudents(2);
        students[0].FirstName = 'Asha';
        students[0].LastName = 'Reportstudent';
        students[1].FirstName = 'Bala';
        students[1].LastName = 'Reportstudent';
        update students;

        // Asha has two affiliations; the one in the answer's program plan must win.
        insert new List<hed__Affiliation__c>{
            new hed__Affiliation__c(hed__Contact__c = students[0].Id, Program_Plan__c = otherPlan.Id, Roll_Number__c = USN_OTHER_PLAN),
            new hed__Affiliation__c(hed__Contact__c = students[0].Id, Program_Plan__c = plan.Id, Roll_Number__c = USN_ONE),
            new hed__Affiliation__c(hed__Contact__c = students[1].Id, Program_Plan__c = plan.Id, Roll_Number__c = USN_TWO)
        };

        Questionnaire_Metadata__c admissions = FeedbackTestFactory.createSection('Admissions Feedback');
        Questionnaire_Metadata__c exam = FeedbackTestFactory.createSection('Exam Feedback');
        admissions.Program__c = program.Id;
        exam.Program__c = program.Id;
        update new List<Questionnaire_Metadata__c>{ admissions, exam };
        // Question type and number on an answer are formulas over its parameter, so the parameters carry them.
        Question_Metadata__c contactQuestion = FeedbackHomeTestData.makeParameter('Contact', admissions.Id, true);
        contactQuestion.Question_Type__c = 'Multiple Choice';
        contactQuestion.Order__c = 1;
        Question_Metadata__c feeQuestion = FeedbackHomeTestData.makeParameter('Fee', admissions.Id, true);
        feeQuestion.Question_Type__c = 'Yes/No';
        feeQuestion.Order__c = 2;
        Question_Metadata__c examQuestion = FeedbackHomeTestData.makeParameter('Exam', exam.Id, true);
        examQuestion.Question_Type__c = 'Yes/No';
        examQuestion.Order__c = 1;
        insert new List<Question_Metadata__c>{ contactQuestion, feeQuestion, examQuestion };

        Feedback_Scheduler__c scheduler = FeedbackTestFactory.createScheduler(
            admissions.Id, term.Id, Date.today().addDays(-5), Date.today().addDays(5));
        Feedback_Item__c itemOne = new Feedback_Item__c(
            Feedback_Scheduler__c = scheduler.Id, Assignee__c = students[0].Id, Feedback_Status__c = 'Submitted',
            Start_Date__c = Date.today().addDays(-5), End_Date__c = Date.today().addDays(5));
        Feedback_Item__c itemTwo = new Feedback_Item__c(
            Feedback_Scheduler__c = scheduler.Id, Assignee__c = students[1].Id, Feedback_Status__c = 'Submitted',
            Start_Date__c = Date.today().addDays(-5), End_Date__c = Date.today().addDays(5));
        insert new List<Feedback_Item__c>{ itemOne, itemTwo };

        Datetime recent = Datetime.now().addDays(-1);
        Datetime old = Datetime.now().addDays(-20);
        insert new List<Collected_Feedback_Data__c>{
            answer(students[0].Id, term.Id, admissions.Id, itemOne.Id, contactQuestion.Id, 'How did you first contact a counsellor?', 'Referral', recent),
            answer(students[0].Id, term.Id, admissions.Id, itemOne.Id, feeQuestion.Id, 'Was the fee schedule explained?', 'Yes', recent),
            answer(students[1].Id, term.Id, admissions.Id, itemTwo.Id, contactQuestion.Id, 'How did you first contact a counsellor?', 'SMS', old),
            answer(students[1].Id, laterTerm.Id, exam.Id, itemTwo.Id, examQuestion.Id, 'Was the exam schedule clear?', 'No', old)
        };
    }

    private static Collected_Feedback_Data__c answer(
        Id contactId, Id termId, Id sectionId, Id itemId, Id parameterId, String question, String value, Datetime submittedAt
    ) {
        return new Collected_Feedback_Data__c(
            Contact__c = contactId, Term__c = termId, Feedback_Master__c = sectionId, Feedback_Item__c = itemId,
            Feedback_Master_Child__c = parameterId, Question__c = question, Answer__c = value,
            Feedback_DateTime__c = submittedAt);
    }

    private static FeedbackHomeDto.ReportPage page(
        String search, String feedbackType, Id termId, Date fromDate, Date toDate
    ) {
        return FeedbackHomeService.reportPage(search, feedbackType, termId, fromDate, toDate, 25, 1);
    }

    private static Id termNamed(String name) {
        return [SELECT Id FROM hed__Term__c WHERE Name = :name LIMIT 1].Id;
    }

    @isTest
    static void everyAnswerShowsItsStudentUsnProgramAndPlan() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            Test.startTest();
            FeedbackHomeDto.ReportPage result = page(null, null, null, null, null);
            Test.stopTest();

            System.assertEquals(4, result.total);
            System.assertEquals(4, result.rows.size());
            Boolean sawAsha = false;
            for (FeedbackHomeDto.ReportRow row : result.rows) {
                System.assertEquals('Master of Business Administration', row.program);
                System.assertNotEquals(null, row.programPlan, 'Program plan comes from the answer\'s term');
                System.assertEquals('Submitted', row.status);
                System.assertNotEquals(null, row.questionNo, 'Question number comes from the parameter order');
                System.assert(row.questionType == 'Multiple Choice' || row.questionType == 'Yes/No', row.questionType);
                if (row.student == 'Asha Reportstudent') {
                    sawAsha = true;
                    System.assertEquals(USN_ONE, row.usn, 'The affiliation in the answer\'s program plan wins over the other one');
                } else {
                    System.assertEquals(USN_TWO, row.usn);
                }
            }
            System.assert(sawAsha);
        }
    }

    @isTest
    static void answersAreNewestFirst() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            FeedbackHomeDto.ReportPage result = page(null, null, null, null, null);
            for (Integer i = 1; i < result.rows.size(); i++) {
                System.assert(result.rows[i - 1].submittedOn >= result.rows[i].submittedOn, 'Newest submissions first');
            }
        }
    }

    @isTest
    static void searchFindsStudentsByNameUsnAndQuestion() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            System.assertEquals(2, page('Asha', null, null, null, null).total, 'By student name');
            System.assertEquals(2, page(USN_ONE, null, null, null, null).total, 'By USN, which lives on Affiliation');
            System.assertEquals(2, page(USN_TWO.substring(8), null, null, null, null).total, 'By part of a USN');
            System.assertEquals(1, page('exam schedule', null, null, null, null).total, 'By question text');
            System.assertEquals(0, page('no such text', null, null, null, null).total);
            System.assertEquals(0, page('100%_', null, null, null, null).total, 'LIKE wildcards match literally');
        }
    }

    @isTest
    static void filtersByFeedbackTypeAndSemester() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            System.assertEquals(3, page(null, 'Admissions Feedback', null, null, null).total);
            System.assertEquals(1, page(null, 'Exam Feedback', null, null, null).total);
            System.assertEquals(3, page(null, null, termNamed('2026-FEB-MBA-Sem 2-ONLINE'), null, null).total);
            System.assertEquals(1, page(null, 'Exam Feedback', termNamed('2026-AUG-MBA-Sem 3-ONLINE'), null, null).total);
            System.assertEquals(0, page(null, 'Admissions Feedback', termNamed('2026-AUG-MBA-Sem 3-ONLINE'), null, null).total,
                'Filters combine');
        }
    }

    @isTest
    static void filtersBySubmittedDateIncludingTheWholeEndDay() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            Date yesterday = Date.today().addDays(-1);
            System.assertEquals(2, page(null, null, null, Date.today().addDays(-3), null).total, 'From');
            System.assertEquals(2, page(null, null, null, null, Date.today().addDays(-10)).total, 'To');
            System.assertEquals(2, page(null, null, null, yesterday, yesterday).total, 'The end day is inclusive');
            System.assertEquals(0, page(null, null, null, Date.today().addDays(2), null).total);
        }
    }

    @isTest
    static void aFromDateAfterTheToDateIsRejectedWithAReadableMessage() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            try {
                FeedbackHomeController.getReportPage(null, null, null, Date.today(), Date.today().addDays(-1), 25, 1);
                System.assert(false, 'Expected an exception');
            } catch (AuraHandledException e) {
                System.assert(e.getMessage().contains('From date'), e.getMessage());
            }
        }
    }

    @isTest
    static void pagingClampsAndReportsTotals() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            FeedbackHomeDto.ReportPage first = FeedbackHomeService.reportPage(null, null, null, null, null, 3, 1);
            System.assertEquals(3, first.rows.size());
            System.assertEquals(2, first.totalPages);
            FeedbackHomeDto.ReportPage second = FeedbackHomeService.reportPage(null, null, null, null, null, 3, 2);
            System.assertEquals(1, second.rows.size());
            FeedbackHomeDto.ReportPage clamped = FeedbackHomeService.reportPage(null, null, null, null, null, 3, 99);
            System.assertEquals(2, clamped.pageNumber, 'An out-of-range page falls back to the last page');
            System.assertEquals(false, clamped.truncated);
        }
    }

    @isTest
    static void filterOptionsListTypesAndSemestersThatHaveAnswers() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            FeedbackHomeDto.ReportFilters filters = FeedbackHomeController.getReportFilters();
            Set<String> types = new Set<String>();
            for (FeedbackHomeDto.FilterOption option : filters.feedbackTypes) {
                types.add(option.value);
            }
            System.assert(types.contains('Admissions Feedback'));
            System.assert(types.contains('Exam Feedback'));
            System.assertEquals(2, filters.terms.size(), 'Only semesters with answers');
            System.assertEquals('2026-AUG-MBA-Sem 3-ONLINE', filters.terms[0].label, 'Sorted by name');
        }
    }

    @isTest
    static void usnSelectionPrefersTheProgramPlanThenFallsBack() {
        List<hed__Program_Plan__c> plans = [SELECT Id FROM hed__Program_Plan__c ORDER BY Batch__c LIMIT 2];
        hed__Affiliation__c inPlan = new hed__Affiliation__c(Roll_Number__c = 'IN-PLAN', Program_Plan__c = plans[0].Id);
        hed__Affiliation__c recent = new hed__Affiliation__c(Roll_Number__c = 'RECENT');
        System.assertEquals(null, FeedbackHomeService.pickUsn(null, null));
        System.assertEquals(null, FeedbackHomeService.pickUsn(new List<hed__Affiliation__c>(), null));
        System.assertEquals('RECENT', FeedbackHomeService.pickUsn(new List<hed__Affiliation__c>{ recent, inPlan }, null),
            'No plan to match: the most recent USN');
        System.assertEquals('IN-PLAN', FeedbackHomeService.pickUsn(new List<hed__Affiliation__c>{ recent, inPlan }, plans[0].Id));
        System.assertEquals('RECENT', FeedbackHomeService.pickUsn(new List<hed__Affiliation__c>{ recent, inPlan }, plans[1].Id),
            'Plan with no matching affiliation: the most recent USN');
    }

    @isTest
    static void aRatingIsShownWhenThereIsNoTextAnswer() {
        Collected_Feedback_Data__c rated = [SELECT Id FROM Collected_Feedback_Data__c LIMIT 1];
        rated.Answer__c = null;
        rated.Rating__c = '4';
        update rated;
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            Boolean found = false;
            for (FeedbackHomeDto.ReportRow row : page(null, null, null, null, null).rows) {
                if (row.id == rated.Id) {
                    found = true;
                    System.assertEquals('4', row.answer);
                }
            }
            System.assert(found);
        }
    }

    @isTest
    static void studentsWithoutAnAffiliationStillAppearWithoutAUsn() {
        Contact loner = FeedbackTestFactory.createStudents(1)[0];
        Collected_Feedback_Data__c existing = [
            SELECT Term__c, Feedback_Master__c, Feedback_Item__c, Feedback_Master_Child__c FROM Collected_Feedback_Data__c LIMIT 1
        ];
        insert answer(loner.Id, existing.Term__c, existing.Feedback_Master__c, existing.Feedback_Item__c,
            existing.Feedback_Master_Child__c, 'Was the fee schedule explained?', 'Yes', Datetime.now());
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            Boolean found = false;
            for (FeedbackHomeDto.ReportRow row : page(null, null, null, null, null).rows) {
                if (row.contactId == loner.Id) {
                    found = true;
                    System.assertEquals(null, row.usn);
                }
            }
            System.assert(found, 'No USN does not hide the answer');
        }
    }
}