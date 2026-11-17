/**
 * Parameter bulk import: happy paths, every validation branch (including the Likert Scale / choice rules),
 * all-or-nothing behaviour, the row cap and a bulk volume.
 */
@IsTest
private class ParameterQuestionImport_Test {

    @TestSetup
    static void setup() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        insert new Questionnaire_Metadata__c(Name = 'Import Test Questionnaire', Feedback_Type__c = 'Faculty Feedback', Active__c = true);
            }
    }

    private static Id sectionId() {
        return [SELECT Id FROM Questionnaire_Metadata__c LIMIT 1].Id;
    }

    private static Integer questionCount() {
        return [SELECT COUNT() FROM Question_Metadata__c];
    }

    private static Map<String, Object> row(String label, String type) {
        return new Map<String, Object>{ 'Question Label' => label, 'Question Type' => type };
    }

    private static String json(List<Map<String, Object>> rows) {
        return JSON.serialize(rows);
    }

    private static String failure(Id questionnaireId, String rowsJson) {
        try {
            ParameterQuestionImportController.saveQuestions(questionnaireId, rowsJson);
        } catch (AuraHandledException e) {
            return e.getMessage();
        }
        return null;
    }

    @IsTest
    static void importsQuestionsWithAllOptionalColumns() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Map<String, Object> full = row('Teaching quality', 'Rating');
        full.putAll(new Map<String, Object>{
            'Active' => 'yes', 'Mandatory' => '1', 'Max Grade' => '10', 'Order' => '3',
            'Section Label' => 'Course', 'Sub Label' => 'Delivery', 'Section Points' => 'a;b' });

        Integer created = ParameterQuestionImportController.saveQuestions(sectionId(), json(new List<Map<String, Object>>{ full }));

        System.assertEquals(1, created);
        Question_Metadata__c saved = [SELECT Question_Type__c, Active__c, Mandatory__c, Max_Grade__c, Order__c, Section_Label__c, Label__c
                                      FROM Question_Metadata__c LIMIT 1];
        System.assertEquals('Rating', saved.Question_Type__c);
        System.assertEquals(true, saved.Active__c);
        System.assertEquals(true, saved.Mandatory__c);
        System.assertEquals(10, saved.Max_Grade__c);
        System.assertEquals('Delivery', saved.Label__c);
            }
    }

    @IsTest
    static void likertScaleKeepsItsChoicesTrimmedAndDeduplicated() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Map<String, Object> likert = row('The faculty explains clearly', 'Likert Scale');
        likert.put('Answers', ' Strongly Disagree ;Disagree;;Neutral;agree;Agree;Strongly Agree');

        ParameterQuestionImportController.saveQuestions(sectionId(), json(new List<Map<String, Object>>{ likert }));

        System.assertEquals('Strongly Disagree;Disagree;Neutral;agree;Strongly Agree',
            [SELECT Answers__c FROM Question_Metadata__c LIMIT 1].Answers__c, 'Blank and duplicate choices are removed');
            }
    }

    @IsTest
    static void choiceTypesRequireAnswers() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        for (String type : new List<String>{ 'Likert Scale', 'Multiple Choice', 'Dropdown' }) {
            String message = failure(sectionId(), json(new List<Map<String, Object>>{ row('Q', type) }));
            System.assert(message != null && message.contains('Answers'), type + ' without choices must be rejected: ' + message);
        }
        System.assertEquals(0, questionCount());
            }
    }

    @IsTest
    static void likertScaleNeedsAtLeastTwoChoices() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        Map<String, Object> one = row('Q', 'Likert Scale');
        one.put('Answers', 'Agree');

        String message = failure(sectionId(), json(new List<Map<String, Object>>{ one }));

        System.assert(message != null && message.contains('at least 2'), message);
            }
    }

    @IsTest
    static void invalidRowsAreRejectedAndNothingIsSaved() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            row('Good', 'Comment'), row('', 'Comment'), row('Bad type', 'Nonsense') };
        String message = failure(sectionId(), json(rows));

        System.assert(message != null && message.contains('Row 3'), 'The first bad row is named: ' + message);
        System.assertEquals(0, questionCount(), 'All-or-nothing');

        Map<String, Object> badBool = row('Q', 'Comment');
        badBool.put('Active', 'maybe');
        System.assert(failure(sectionId(), json(new List<Map<String, Object>>{ badBool })).contains('true/false'));

        Map<String, Object> badNumber = row('Q', 'Comment');
        badNumber.put('Order', '1.5');
        System.assert(failure(sectionId(), json(new List<Map<String, Object>>{ badNumber })).contains('whole numbers'));
            }
    }

    @IsTest
    static void guardsAgainstBadInput() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        System.assert(failure(null, '[]').contains('not identified'));
        System.assert(failure(sectionId(), '').contains('No CSV rows'));
        System.assert(failure(sectionId(), '{').contains('Unable to read'));
        System.assert(failure(sectionId(), '{"a":1}').contains('list of rows'));
        System.assert(failure(sectionId(), '[]').contains('No question records'));
        System.assert(failure(UserInfo.getUserId(), '[]').contains('only be imported into a Questionnaire'));
            }
    }

    @IsTest
    static void rowCapIsEnforced() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Integer i = 0; i < ParameterQuestionImportController.MAX_ROWS + 1; i++) {
            rows.add(row('Q' + i, 'Comment'));
        }
        System.assert(failure(sectionId(), json(rows)).contains('at most'));
            }
    }

    @IsTest
    static void importsAFullBatchInOneCall() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Integer i = 0; i < 500; i++) {
            rows.add(row('Question ' + i, 'Rating'));
        }

        Test.startTest();
        Integer created = ParameterQuestionImportController.saveQuestions(sectionId(), json(rows));
        Test.stopTest();

        System.assertEquals(500, created);
        System.assertEquals(500, questionCount());
            }
    }
}