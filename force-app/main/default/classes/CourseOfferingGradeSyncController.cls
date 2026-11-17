public with sharing class CourseOfferingGradeSyncController {

    public class SyncResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Integer preparedSuccess;
        @AuraEnabled public Integer preparedFailure;
        @AuraEnabled public Integer updateSuccess;
        @AuraEnabled public Integer updateFailure;
        @AuraEnabled public String traceId;
        @AuraEnabled public String courseEvaluationId;
    }

    private class SyncRequestBody {
        public String courseOfferingLmsId;
        public String courseOfferingId;
        public String courseEvaluationId;
    }

    @TestVisible
    private static String mockEndpoint;

    private static String getEndpoint() {
        if (mockEndpoint != null) {
            return mockEndpoint;
        }

        Org_Base_Url__mdt config =
            Org_Base_Url__mdt.getInstance('Brightspace_Final_Grade_Sync');

        if (config == null || String.isBlank(config.Base_URL__c)) {
            throw new AuraHandledException(
                'Endpoint URL is not configured in Custom Metadata.'
            );
        }

        return config.Base_URL__c;
    }

    @AuraEnabled
    public static SyncResult syncGrades(Id courseOfferingId) {
        if (courseOfferingId == null) {
            throw new AuraHandledException('Course Offering Id is required.');
        }

        hed__Course_Offering__c courseOffering = [
            SELECT Id, LMS_Id__c
            FROM hed__Course_Offering__c
            WHERE Id = :courseOfferingId
            LIMIT 1
        ];

        if (String.isBlank(courseOffering.LMS_Id__c)) {
            throw new AuraHandledException('LMS Id is blank on Course Offering.');
        }

        List<Course_Evaluation_Component__c> components = [
            SELECT Id
            FROM Course_Evaluation_Component__c
            WHERE Course_Offering__c = :courseOfferingId AND Exam_Type__c =: ConstantController.CIA_EXAM_TYPE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (components.isEmpty()) {
            throw new AuraHandledException('No Course Evaluation Component found for this Course Offering.');
        }

        SyncRequestBody body = new SyncRequestBody();
        body.courseOfferingLmsId = courseOffering.LMS_Id__c;
        body.courseOfferingId = String.valueOf(courseOffering.Id);
        body.courseEvaluationId = String.valueOf(components[0].Id);

        System.debug(JSON.serialize(body));

        HttpRequest req = new HttpRequest();
        req.setEndpoint(getEndpoint());
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(body));

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            throw new AuraHandledException('Grade sync callout failed: ' + ex.getMessage());
        }

        System.debug('Status: ' + res.getStatusCode());
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            logInChunks('SyncGrades request body', req.getBody());
            logInChunks('SyncGrades response body', res.getBody());
            throw new AuraHandledException(
                'Grade sync failed with status ' + res.getStatusCode() + ': ' + truncate(res.getBody(), 255)
            );
        }

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        SyncResult result = new SyncResult();
        result.success = parseSuccess(parsed.get('success'));
        result.message = result.success ? 'Grades sync completed.' : 'Grades sync completed with issues.';
        result.courseEvaluationId = body.courseEvaluationId;

        Map<String, Object> data = (Map<String, Object>) parsed.get('data');
        if (data != null) {
            Map<String, Object> summary = (Map<String, Object>) data.get('summary');
            if (summary != null) {
                result.preparedSuccess = toInteger(summary.get('preparedSuccess'));
                result.preparedFailure = toInteger(summary.get('preparedFailure'));
                result.updateSuccess = toInteger(summary.get('updateSuccess'));
                result.updateFailure = toInteger(summary.get('updateFailure'));
            }
            result.traceId = (String) data.get('traceId');
        }

        return result;
    }

    @TestVisible
    private static Boolean parseSuccess(Object value) {
        if (value == null) {
            return false;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        return String.valueOf(value).toLowerCase() == 'true';
    }

    @TestVisible
    private static Integer toInteger(Object value) {
        if (value == null) {
            return 0;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Long) {
            return Integer.valueOf(String.valueOf(value));
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        return Integer.valueOf(String.valueOf(value));
    }

    @TestVisible
    private static String truncate(String input, Integer maxLen) {
        if (String.isBlank(input) || input.length() <= maxLen) {
            return input;
        }
        return input.substring(0, maxLen) + '...';
    }

    @TestVisible
    private static void logInChunks(String label, String input) {
        if (input == null) {
            System.debug(LoggingLevel.ERROR, label + ': null');
            return;
        }

        Integer chunkSize = 900;
        for (Integer i = 0; i < input.length(); i += chunkSize) {
            Integer endIndex = Math.min(i + chunkSize, input.length());
            System.debug(LoggingLevel.ERROR, label + ' [' + i + '-' + (endIndex - 1) + ']: ' + input.substring(i, endIndex));
        }
    }
}