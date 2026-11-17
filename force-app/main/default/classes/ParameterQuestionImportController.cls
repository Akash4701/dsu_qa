/**
 * Imports question rows as Question_Metadata__c records for the Questionnaire the quick action was opened on.
 *
 * Runs synchronously: one request, one bulk insert (user mode), no query or DML inside a loop. Nothing runs
 * on Question_Metadata__c on insert (no trigger, flow or validation rule), so the cost of an import is the
 * insert itself. The import is all-or-nothing: if any row is rejected, nothing is saved.
 *
 * Limits that bound one import:
 *   - MAX_ROWS rows per call. Well under the 10,000-row DML limit, so a bigger file gets a clear message
 *     instead of an uncatchable limit error, and it keeps the request and heap small (Section Points can be
 *     very long text).
 *   - Errors name the CSV row, so a person can fix the file without guessing.
 */
public with sharing class ParameterQuestionImportController {

    @TestVisible private static final Integer MAX_ROWS = 2000;
    private static final Integer MAX_REPORTED_ROW_ERRORS = 5;

    private static final Set<String> ALLOWED_TYPES = new Set<String>{
        'Graded',
        'Yes/No',
        'Comment',
        'Multiple Choice',
        'Rating',
        'Dropdown',
        'Likert Scale'
    };

    // Types answered by picking from a list: the list (Answers, semicolon-separated) is mandatory.
    private static final Set<String> CHOICE_TYPES = new Set<String>{
        'Multiple Choice',
        'Dropdown',
        'Likert Scale'
    };
    private static final Integer MIN_LIKERT_CHOICES = 2;

    private static final Set<String> TRUE_VALUES =
        new Set<String>{'true', 'yes', '1'};

    private static final Set<String> FALSE_VALUES =
        new Set<String>{'false', 'no', '0'};

    // Raised by the parsing and validation helpers. Turned into an AuraHandledException (with a readable
    // message) only at the edge, in saveQuestions.
    private class ImportException extends Exception {}

    /**
     * Creates Question_Metadata__c records under the Questionnaire identified by questionnaireId.
     *
     * @param questionnaireId Questionnaire record ID from the LWC.
     * @param rowsJson JSON array of CSV rows. Each row may carry "_row", its line number in the CSV, which is
     *                 used in error messages; without it the position in the list is used.
     * @return Number of records created.
     */
    @AuraEnabled
    public static Integer saveQuestions(
        Id questionnaireId,
        String rowsJson
    ) {
        try {
            return importQuestions(questionnaireId, rowsJson);
        } catch (ImportException importError) {
            throw auraError(importError.getMessage());
        }
    }

    private static Integer importQuestions(Id questionnaireId, String rowsJson) {
        if (questionnaireId == null) {
            throw new ImportException('The current Questionnaire record was not identified.');
        }
        if (String.isBlank(rowsJson)) {
            throw new ImportException('No CSV rows were provided.');
        }
        requireQuestionnaire(questionnaireId);

        List<Object> decodedRows = deserializeRows(rowsJson);
        if (decodedRows.isEmpty()) {
            throw new ImportException('No question records were provided.');
        }
        if (decodedRows.size() > MAX_ROWS) {
            throw new ImportException(
                'One import can contain at most ' + MAX_ROWS + ' questions. This file has '
                + decodedRows.size() + '. Split it into smaller files.'
            );
        }

        List<Question_Metadata__c> recordsToInsert = new List<Question_Metadata__c>();
        List<Integer> rowNumbers = new List<Integer>();
        for (Integer i = 0; i < decodedRows.size(); i++) {
            Integer rowNumber = rowNumber(decodedRows[i], i);
            try {
                recordsToInsert.add(buildQuestion(decodedRows[i], questionnaireId));
            } catch (ImportException rowError) {
                throw new ImportException('Row ' + rowNumber + ': ' + rowError.getMessage());
            }
            rowNumbers.add(rowNumber);
        }

        try {
            insert as user recordsToInsert;
        } catch (DmlException dmlError) {
            throw new ImportException(describeDmlFailure(dmlError, rowNumbers));
        } catch (NoAccessException accessError) {
            throw new ImportException(
                'You do not have permission to create questions, or to set one of the imported columns.'
            );
        }

        return recordsToInsert.size();
    }

    // The action is only meant for a Questionnaire. Refuses any other record, and a Questionnaire the user
    // cannot see, with a clear message instead of attaching questions to the wrong place.
    private static void requireQuestionnaire(Id questionnaireId) {
        if (questionnaireId.getSObjectType() != Questionnaire_Metadata__c.SObjectType) {
            throw new ImportException('Questions can only be imported into a Questionnaire.');
        }
        List<Questionnaire_Metadata__c> found = [
            SELECT Id
            FROM Questionnaire_Metadata__c
            WHERE Id = :questionnaireId
            WITH USER_MODE
            LIMIT 1
        ];
        if (found.isEmpty()) {
            throw new ImportException('The Questionnaire was not found, or you do not have access to it.');
        }
    }

    private static AuraHandledException auraError(String message) {
        // Without setMessage the exception reads as "Script-thrown exception" everywhere except the
        // browser, which makes it impossible to assert on in tests.
        AuraHandledException error = new AuraHandledException(message);
        error.setMessage(message);
        return error;
    }

    // Name the CSV row of each rejected record (the first few), so the file can be corrected.
    private static String describeDmlFailure(DmlException dmlError, List<Integer> rowNumbers) {
        List<String> lines = new List<String>();
        Integer failures = dmlError.getNumDml();
        Integer shown = Math.min(failures, MAX_REPORTED_ROW_ERRORS);
        for (Integer i = 0; i < shown; i++) {
            Integer index = dmlError.getDmlIndex(i);
            String rowPrefix = (index != null && index < rowNumbers.size()) ? 'Row ' + rowNumbers[index] + ': ' : '';
            lines.add(rowPrefix + dmlError.getDmlMessage(i));
        }
        String summary = 'Nothing was imported. ' + String.join(lines, ' ');
        if (failures > shown) {
            summary += ' (and ' + (failures - shown) + ' more rows with errors)';
        }
        return summary;
    }

    /**
     * Converts the JSON payload into a list of CSV rows.
     */
    private static List<Object> deserializeRows(String rowsJson) {
        Object decodedValue;
        try {
            decodedValue = JSON.deserializeUntyped(rowsJson);
        } catch (JSONException jsonError) {
            throw new ImportException('Unable to read the imported CSV data.');
        }
        if (!(decodedValue instanceof List<Object>)) {
            throw new ImportException('Imported CSV data must be a list of rows.');
        }
        return (List<Object>) decodedValue;
    }

    // The CSV line the row came from ("_row", sent by the screen). Falls back to the position in the list,
    // counting the header as line 1.
    private static Integer rowNumber(Object decodedRow, Integer index) {
        if (decodedRow instanceof Map<String, Object>) {
            Object sent = ((Map<String, Object>) decodedRow).get('_row');
            if (sent instanceof Integer) {
                return (Integer) sent;
            }
            if (sent instanceof Decimal) {
                return ((Decimal) sent).intValue();
            }
        }
        return index + 2;
    }

    /**
     * Creates one Question_Metadata__c record.
     * questionnaireId is assigned directly to Questionnaire__c.
     */
    private static Question_Metadata__c buildQuestion(
        Object decodedRow,
        Id questionnaireId
    ) {
        if (!(decodedRow instanceof Map<String, Object>)) {
            throw new ImportException('Each imported row must contain CSV column values.');
        }

        Map<String, Object> row = (Map<String, Object>) decodedRow;

        String questionLabel = stringValue(row.get('Question Label'));
        String questionType = stringValue(row.get('Question Type'));

        if (String.isBlank(questionLabel)) {
            throw new ImportException('Question Label is required.');
        }
        if (!ALLOWED_TYPES.contains(questionType)) {
            throw new ImportException('Invalid Question Type: ' + questionType);
        }

        Question_Metadata__c question = new Question_Metadata__c(
            Questionnaire__c = questionnaireId,
            Question_Label__c = questionLabel,
            Question_Type__c = questionType
        );

        setOptionalFields(question, row);
        applyAnswerChoices(question, stringValue(row.get('Answers')));

        return question;
    }

    // Normalises the semicolon-separated choices (trim, drop blanks) and enforces them for choice types.
    private static void applyAnswerChoices(Question_Metadata__c question, String rawAnswers) {
        List<String> choices = new List<String>();
        Set<String> seen = new Set<String>();
        for (String choice : (rawAnswers == null ? '' : rawAnswers).split(';')) {
            String trimmed = choice.trim();
            if (String.isNotBlank(trimmed) && seen.add(trimmed.toLowerCase())) {
                choices.add(trimmed);
            }
        }
        if (CHOICE_TYPES.contains(question.Question_Type__c) && choices.isEmpty()) {
            throw new ImportException(question.Question_Type__c + ' needs its choices in Answers, separated by semicolons.');
        }
        if (question.Question_Type__c == 'Likert Scale' && choices.size() < MIN_LIKERT_CHOICES) {
            throw new ImportException('Likert Scale needs at least ' + MIN_LIKERT_CHOICES + ' choices in Answers.');
        }
        if (!choices.isEmpty()) {
            question.Answers__c = String.join(choices, ';');
        }
    }

    /**
     * Maps optional CSV columns to Salesforce fields.
     */
    private static void setOptionalFields(
        Question_Metadata__c question,
        Map<String, Object> row
    ) {
        Boolean active = parseBoolean(row.get('Active'));
        if (active != null) {
            question.Active__c = active;
        }

        Boolean mandatory = parseBoolean(row.get('Mandatory'));
        if (mandatory != null) {
            question.Mandatory__c = mandatory;
        }

        String sectionPoints = stringValue(row.get('Section Points'));
        if (sectionPoints != null) {
            question.Section_Points__c = sectionPoints;
        }

        Decimal maxGrade = parseDecimal(row.get('Max Grade'));
        if (maxGrade != null) {
            question.Max_Grade__c = maxGrade;
        }

        String sectionLabel = stringValue(row.get('Section Label'));
        if (sectionLabel != null) {
            question.Section_Label__c = sectionLabel;
        }

        Decimal orderValue = parseDecimal(row.get('Order'));
        if (orderValue != null) {
            question.Order__c = orderValue;
        }

        String subLabel = stringValue(row.get('Sub Label'));
        if (subLabel != null) {
            question.Label__c = subLabel;
        }
    }

    /**
     * Converts CSV values into strings.
     */
    private static String stringValue(Object value) {
        if (value == null) {
            return null;
        }
        if (!(value instanceof String)) {
            throw new ImportException('Imported CSV values must be text.');
        }
        return ((String) value).trim();
    }

    /**
     * Parses Boolean values from the CSV.
     */
    private static Boolean parseBoolean(Object value) {
        String normalized = stringValue(value);

        if (String.isBlank(normalized)) {
            return null;
        }

        normalized = normalized.toLowerCase();

        if (TRUE_VALUES.contains(normalized)) {
            return true;
        }
        if (FALSE_VALUES.contains(normalized)) {
            return false;
        }

        throw new ImportException('Boolean values must be true/false, yes/no, or 1/0.');
    }

    /**
     * Parses whole-number values from the CSV.
     */
    private static Decimal parseDecimal(Object value) {
        String normalized = stringValue(value);

        if (String.isBlank(normalized)) {
            return null;
        }

        Decimal parsedValue;
        try {
            parsedValue = Decimal.valueOf(normalized);
        } catch (TypeException typeError) {
            throw new ImportException('Max Grade and Order must be numeric.');
        }

        if (parsedValue != parsedValue.setScale(0, RoundingMode.DOWN)) {
            throw new ImportException('Max Grade and Order must be whole numbers.');
        }

        return parsedValue;
    }
}