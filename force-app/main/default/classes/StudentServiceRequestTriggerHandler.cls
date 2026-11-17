public with sharing class StudentServiceRequestTriggerHandler {
    private static final String REGISTERED_STATUS = 'Fee Paid';
    private static final String RE_EXAM_RECORDTYPE_DEVELOPER_NAME = 'Re_Exam';
    private static final String RE_EXAM_RECORDTYPE_NAME = 'Re Exam';
    private static final String ELIGIBILITY_VALUE = 'Eligible';
    private static final String EXAM_TYPE_VALUE = 'Retest';

    private static Id cachedReExamRecordTypeId;

    public static void handleAfterInsert(List<Student_Service_Request__c> newRequests) {
        System.debug(LoggingLevel.INFO,
            '[SSR_HANDLER] handleAfterInsert called. newRequests size=' +
            (newRequests == null ? 'null' : String.valueOf(newRequests.size()))
        );
        processRequests(newRequests, null);
    }

    public static void handleAfterUpdate(
        List<Student_Service_Request__c> newRequests,
        Map<Id, Student_Service_Request__c> oldMap
    ) {
        System.debug(LoggingLevel.INFO,
            '[SSR_HANDLER] handleAfterUpdate called. newRequests size=' +
            (newRequests == null ? 'null' : String.valueOf(newRequests.size())) +
            ', oldMap size=' + (oldMap == null ? 'null' : String.valueOf(oldMap.size()))
        );
        processRequests(newRequests, oldMap);
    }

    private static void processRequests(
        List<Student_Service_Request__c> newRequests,
        Map<Id, Student_Service_Request__c> oldMap
    ) {
        System.debug(LoggingLevel.INFO, '[SSR_HANDLER] processRequests START');

        if (newRequests == null || newRequests.isEmpty()) {
            System.debug(LoggingLevel.WARN, '[SSR_HANDLER] EXIT: newRequests is null/empty');
            return;
        }

        Id reExamRecordTypeId = getReExamRecordTypeId();
        System.debug(LoggingLevel.INFO, '[SSR_HANDLER] reExamRecordTypeId=' + reExamRecordTypeId);

        if (reExamRecordTypeId == null) {
            System.debug(LoggingLevel.ERROR,
                '[SSR_HANDLER] EXIT: Could not resolve Re Exam record type id. ' +
                'Check developerName=' + RE_EXAM_RECORDTYPE_DEVELOPER_NAME +
                ' or name=' + RE_EXAM_RECORDTYPE_NAME
            );
            return;
        }

        Set<Id> qualifiedRequestIds = new Set<Id>();

        for (Student_Service_Request__c requestRec : newRequests) {
            if (requestRec == null) {
                System.debug(LoggingLevel.WARN, '[SSR_HANDLER] SKIP: requestRec is null');
                continue;
            }
            if (requestRec.Id == null) {
                System.debug(LoggingLevel.WARN, '[SSR_HANDLER] SKIP: requestRec.Id is null (unexpected after trigger?)');
                continue;
            }

            // Log key fields on every record processed
            System.debug(LoggingLevel.DEBUG,
                '[SSR_HANDLER] Evaluating SSR Id=' + requestRec.Id +
                ', RecordTypeId=' + requestRec.RecordTypeId +
                ', Status__c=' + requestRec.Status__c
            );

            if (requestRec.RecordTypeId != reExamRecordTypeId) {
                System.debug(LoggingLevel.INFO,
                    '[SSR_HANDLER] SKIP: RecordTypeId mismatch. SSR Id=' + requestRec.Id +
                    ', expected=' + reExamRecordTypeId + ', actual=' + requestRec.RecordTypeId
                );
                continue;
            }

            if (requestRec.Status__c != REGISTERED_STATUS) {
                System.debug(LoggingLevel.INFO,
                    '[SSR_HANDLER] SKIP: Status not Registered. SSR Id=' + requestRec.Id +
                    ', status=' + requestRec.Status__c
                );
                continue;
            }

            if (oldMap != null) {
                Student_Service_Request__c oldRec = oldMap.get(requestRec.Id);

                if (oldRec == null) {
                    System.debug(LoggingLevel.WARN,
                        '[SSR_HANDLER] NOTE: oldRec not found in oldMap for SSR Id=' + requestRec.Id +
                        '. Proceeding as if status changed.'
                    );
                } else {
                    System.debug(LoggingLevel.DEBUG,
                        '[SSR_HANDLER] old status for SSR Id=' + requestRec.Id + ' was ' + oldRec.Status__c
                    );

                    if (oldRec.Status__c == REGISTERED_STATUS) {
                        System.debug(LoggingLevel.INFO,
                            '[SSR_HANDLER] SKIP: Status already Registered before update. SSR Id=' + requestRec.Id
                        );
                        continue;
                    }
                }
            }

            qualifiedRequestIds.add(requestRec.Id);
            System.debug(LoggingLevel.INFO, '[SSR_HANDLER] QUALIFIED SSR Id=' + requestRec.Id);
        }

        System.debug(LoggingLevel.INFO,
            '[SSR_HANDLER] qualifiedRequestIds size=' + qualifiedRequestIds.size() +
            ', ids=' + qualifiedRequestIds
        );

        if (qualifiedRequestIds.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                '[SSR_HANDLER] EXIT: No qualified SSRs. ' +
                'Most common causes: wrong record type, status not Registered, or old status already Registered.'
            );
            return;
        }

        List<Student_Service_Request__c> qualifiedRequests = [
            SELECT Id, Exam__c, Course_Connection__c, Course_Connection__r.hed__Contact__c
            FROM Student_Service_Request__c
            WHERE Id IN :qualifiedRequestIds
        ];

        System.debug(LoggingLevel.INFO,
            '[SSR_HANDLER] Re-query returned qualifiedRequests size=' + qualifiedRequests.size()
        );

        if (qualifiedRequests.isEmpty()) {
            System.debug(LoggingLevel.WARN, '[SSR_HANDLER] EXIT: Re-query returned 0 records');
            return;
        }

        Map<String, Exam_Connections__c> keyToConnectionToInsert = new Map<String, Exam_Connections__c>();
        Set<Id> examIds = new Set<Id>();
        Set<Id> courseConnectionIds = new Set<Id>();
        Set<Id> studentIds = new Set<Id>();

        for (Student_Service_Request__c requestRec : qualifiedRequests) {
            Id examId = requestRec.Exam__c;
            Id courseConnectionId = requestRec.Course_Connection__c;
            Id studentId = (requestRec.Course_Connection__r != null)
                ? requestRec.Course_Connection__r.hed__Contact__c
                : null;

            System.debug(LoggingLevel.DEBUG,
                '[SSR_HANDLER] SSR Id=' + requestRec.Id +
                ' -> examId=' + examId +
                ', courseConnectionId=' + courseConnectionId +
                ', studentId=' + studentId
            );

            if (examId == null || courseConnectionId == null || studentId == null) {
                System.debug(LoggingLevel.WARN,
                    '[SSR_HANDLER] SKIP: Missing required lookup(s) for SSR Id=' + requestRec.Id +
                    '. examId=' + examId + ', courseConnectionId=' + courseConnectionId + ', studentId=' + studentId +
                    '. (No Exam_Connections will be created for this SSR)'
                );
                continue;
            }

            String candidateKey = buildConnectionKey(
                examId, courseConnectionId, studentId, ELIGIBILITY_VALUE, EXAM_TYPE_VALUE
            );

            if (keyToConnectionToInsert.containsKey(candidateKey)) {
                System.debug(LoggingLevel.INFO,
                    '[SSR_HANDLER] SKIP: Duplicate candidate key within transaction. key=' + candidateKey +
                    ' (Another SSR already produced same Exam_Connections candidate)'
                );
                continue;
            }

            keyToConnectionToInsert.put(
                candidateKey,
                new Exam_Connections__c(
                    Eligibility__c = ELIGIBILITY_VALUE,
                    Exam_Name__c = examId,
                    Course_Connection_ID__c = courseConnectionId,
                    Student_Name__c = studentId,
                    Exam_Type__c = EXAM_TYPE_VALUE
                )
            );

            examIds.add(examId);
            courseConnectionIds.add(courseConnectionId);
            studentIds.add(studentId);

            System.debug(LoggingLevel.INFO,
                '[SSR_HANDLER] Candidate Exam_Connections prepared. key=' + candidateKey
            );
        }

        System.debug(LoggingLevel.INFO,
            '[SSR_HANDLER] keyToConnectionToInsert size=' + keyToConnectionToInsert.size()
        );

        if (keyToConnectionToInsert.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                '[SSR_HANDLER] EXIT: No candidates prepared. Most common cause: missing Exam__c / Course_Connection__c / student contact.'
            );
            return;
        }

        System.debug(LoggingLevel.DEBUG,
            '[SSR_HANDLER] Query existing Exam_Connections with: ' +
            'Eligibility=' + ELIGIBILITY_VALUE + ', ExamType=' + EXAM_TYPE_VALUE +
            ', examIds=' + examIds.size() +
            ', courseConnectionIds=' + courseConnectionIds.size() +
            ', studentIds=' + studentIds.size()
        );

        Set<String> existingConnectionKeys = new Set<String>();
        List<Exam_Connections__c> existingConnections = [
            SELECT Id, Eligibility__c, Exam_Name__c, Course_Connection_ID__c, Student_Name__c, Exam_Type__c
            FROM Exam_Connections__c
            WHERE Eligibility__c = :ELIGIBILITY_VALUE
              AND Exam_Type__c = :EXAM_TYPE_VALUE
              AND Exam_Name__c IN :examIds
              AND Course_Connection_ID__c IN :courseConnectionIds
              AND Student_Name__c IN :studentIds
        ];

        System.debug(LoggingLevel.INFO,
            '[SSR_HANDLER] Existing Exam_Connections found=' + existingConnections.size()
        );

        for (Exam_Connections__c existingConn : existingConnections) {
            String existingKey = buildConnectionKey(
                existingConn.Exam_Name__c,
                existingConn.Course_Connection_ID__c,
                existingConn.Student_Name__c,
                existingConn.Eligibility__c,
                existingConn.Exam_Type__c
            );
            existingConnectionKeys.add(existingKey);

            System.debug(LoggingLevel.DEBUG,
                '[SSR_HANDLER] Existing Exam_Connections Id=' + existingConn.Id + ', key=' + existingKey
            );
        }

        List<Exam_Connections__c> connectionsToInsert = new List<Exam_Connections__c>();
        for (String candidateKey : keyToConnectionToInsert.keySet()) {
            if (existingConnectionKeys.contains(candidateKey)) {
                System.debug(LoggingLevel.INFO,
                    '[SSR_HANDLER] SKIP INSERT: Already exists in DB. key=' + candidateKey
                );
                continue;
            }
            connectionsToInsert.add(keyToConnectionToInsert.get(candidateKey));
        }

        System.debug(LoggingLevel.INFO,
            '[SSR_HANDLER] connectionsToInsert size=' + connectionsToInsert.size()
        );

        if (!connectionsToInsert.isEmpty()) {
            System.debug(LoggingLevel.INFO, '[SSR_HANDLER] Inserting Exam_Connections...');
            try {
                insert connectionsToInsert;
                System.debug(LoggingLevel.INFO,
                    '[SSR_HANDLER] INSERT SUCCESS. Inserted count=' + connectionsToInsert.size()
                );
            } catch (DmlException dmx) {
                System.debug(LoggingLevel.ERROR,
                    '[SSR_HANDLER] INSERT FAILED. Message=' + dmx.getMessage()
                );
                System.debug(LoggingLevel.ERROR,
                    '[SSR_HANDLER] INSERT FAILED. StackTrace=' + dmx.getStackTraceString()
                );
                throw dmx; // rethrow so it surfaces; remove if you prefer silent fail
            }
        } else {
            System.debug(LoggingLevel.WARN,
                '[SSR_HANDLER] EXIT: Nothing to insert (all candidates already existed).'
            );
        }

        System.debug(LoggingLevel.INFO, '[SSR_HANDLER] processRequests END');
    }

    private static Id getReExamRecordTypeId() {
        if (cachedReExamRecordTypeId != null) {
            System.debug(LoggingLevel.DEBUG,
                '[SSR_HANDLER] getReExamRecordTypeId cache hit: ' + cachedReExamRecordTypeId
            );
            return cachedReExamRecordTypeId;
        }

        System.debug(LoggingLevel.DEBUG,
            '[SSR_HANDLER] getReExamRecordTypeId resolving record type id...'
        );

        Map<String, Schema.RecordTypeInfo> byDeveloperName =
            Student_Service_Request__c.SObjectType.getDescribe().getRecordTypeInfosByDeveloperName();

        if (byDeveloperName != null && byDeveloperName.containsKey(RE_EXAM_RECORDTYPE_DEVELOPER_NAME)) {
            cachedReExamRecordTypeId =
                byDeveloperName.get(RE_EXAM_RECORDTYPE_DEVELOPER_NAME).getRecordTypeId();

            System.debug(LoggingLevel.INFO,
                '[SSR_HANDLER] Re Exam record type found by DeveloperName=' +
                RE_EXAM_RECORDTYPE_DEVELOPER_NAME + ' => ' + cachedReExamRecordTypeId
            );
            return cachedReExamRecordTypeId;
        }

        Map<String, Schema.RecordTypeInfo> byName =
            Student_Service_Request__c.SObjectType.getDescribe().getRecordTypeInfosByName();

        if (byName != null && byName.containsKey(RE_EXAM_RECORDTYPE_NAME)) {
            cachedReExamRecordTypeId = byName.get(RE_EXAM_RECORDTYPE_NAME).getRecordTypeId();

            System.debug(LoggingLevel.INFO,
                '[SSR_HANDLER] Re Exam record type found by Name=' +
                RE_EXAM_RECORDTYPE_NAME + ' => ' + cachedReExamRecordTypeId
            );
            return cachedReExamRecordTypeId;
        }

        System.debug(LoggingLevel.ERROR,
            '[SSR_HANDLER] Re Exam record type NOT found by DeveloperName or Name.'
        );
        return null;
    }

    private static String buildConnectionKey(
        Id examId,
        Id courseConnectionId,
        Id studentId,
        String eligibility,
        String examType
    ) {
        String key = String.valueOf(examId) + '|' +
            String.valueOf(courseConnectionId) + '|' +
            String.valueOf(studentId) + '|' +
            String.valueOf(eligibility) + '|' +
            String.valueOf(examType);

        // Keep this DEBUG (not INFO) to avoid log noise
        System.debug(LoggingLevel.DEBUG, '[SSR_HANDLER] buildConnectionKey -> ' + key);
        return key;
    }
}