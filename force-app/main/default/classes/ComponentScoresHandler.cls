public with sharing class ComponentScoresHandler {

    // Entry point for before insert
    public static void onBeforeInsert(List<Component_Scores__c> newRecords) {
        populateFieldsFromRelatedSlot(newRecords);
        calculateAndSetResult(newRecords);
        populateExamTypeFromComponent(newRecords); 
    }

    // Entry point for before update
    public static void onBeforeUpdate(
        List<Component_Scores__c> oldRecords,
        List<Component_Scores__c> newRecords
    ) {
        List<Component_Scores__c> recordsToProcess = new List<Component_Scores__c>();
        for (Integer i = 0; i < newRecords.size(); i++) {
            Component_Scores__c newRec = newRecords[i];
            if (newRec.Slot_Scheduled__c != null) {
                recordsToProcess.add(newRec);
            }
        }
    
        if (!recordsToProcess.isEmpty()) {
            populateFieldsFromRelatedSlot(recordsToProcess);
        }
    
        //  ALWAYS call populateExamTypeFromComponent on all newRecords
        // because Component_Name__c may have been set above or already existed
        populateExamTypeFromComponent(newRecords);
    
        // Calculate result for records where Marks_Obtained__c OR Exam_Status__c is being set or changed
        List<Component_Scores__c> recordsForResultCalculation = new List<Component_Scores__c>();
        for (Integer i = 0; i < newRecords.size(); i++) {
            Component_Scores__c newRec = newRecords[i];
            Component_Scores__c oldRec = oldRecords[i];
    
            Boolean marksChanged = (newRec.Marks_Obtained__c != null &&
                                   (oldRec.Marks_Obtained__c != newRec.Marks_Obtained__c || oldRec.Id == null));
    
            Boolean statusChanged = (oldRec.Exam_Status__c != newRec.Exam_Status__c);
    
            if (marksChanged || statusChanged) {
                recordsForResultCalculation.add(newRec);
            }
        }
    
        if (!recordsForResultCalculation.isEmpty()) {
            calculateAndSetResult(recordsForResultCalculation);
        }
    }

    // Accept oldRecords parameter and only process when Exam_Type__c or Course_Connection__c actually changes
    public static void onAfterUpdate(List<Component_Scores__c> oldRecords, List<Component_Scores__c> newRecords) {
        // Process records where Exam_Type__c or Course_Connection__c changed (for ANY exam type)
        List<Component_Scores__c> recordsToProcess = new List<Component_Scores__c>();
        for (Integer i = 0; i < newRecords.size(); i++) {
            Component_Scores__c newRec = newRecords[i];
            Component_Scores__c oldRec = oldRecords[i];
            
            // Trigger deactivation if Exam_Type__c changed OR Course_Connection__c changed
            if (newRec.Exam_Type__c != null && 
                (oldRec.Exam_Type__c != newRec.Exam_Type__c || 
                 oldRec.Course_Connection__c != newRec.Course_Connection__c)) {
                recordsToProcess.add(newRec);
            }
        }
        
        if (!recordsToProcess.isEmpty()) {
            deactivateOlderRecords(recordsToProcess);
        }
        
        // Calculate and update final score - bulkified
        Set<Id> courseEnrollmentIds = new Set<Id>();
        for (Component_Scores__c rec : newRecords) {
            if (rec.Course_Connection__c != null) {
                courseEnrollmentIds.add(rec.Course_Connection__c);
            }
        }
        
        if (!courseEnrollmentIds.isEmpty()) {
            calculateAndUpdateFinalScore(courseEnrollmentIds);
        }
    }
    
    public static void onAfterInsert(List<Component_Scores__c> newRecords) {
        // Deactivate older records for ALL exam types (not just SEE)
        List<Component_Scores__c> recordsToProcess = new List<Component_Scores__c>();
        for (Component_Scores__c rec : newRecords) {
            if (rec.Exam_Type__c != null && rec.Course_Connection__c != null) {
                recordsToProcess.add(rec);
            }
        }
        
        if (!recordsToProcess.isEmpty()) {
            deactivateOlderRecords(recordsToProcess);
        }
        
        // Get course enrollment IDs from new records - bulkified
        Set<Id> courseEnrollmentIds = new Set<Id>();
        for (Component_Scores__c rec : newRecords) {
            if (rec.Course_Connection__c != null) {
                courseEnrollmentIds.add(rec.Course_Connection__c);
            }
        }
        
        // Single call to calculate and update final score - bulkified
        if (!courseEnrollmentIds.isEmpty()) {
            calculateAndUpdateFinalScore(courseEnrollmentIds);
        }
    }
    
    
    private static void populateFieldsFromRelatedSlot(List<Component_Scores__c> records) {
        // Step 1: Collect external ID values from Slot_Scheduled__c (text field)
        Set<String> externalSlotIds = new Set<String>();
        Map<String, List<Component_Scores__c>> externalIdToRecordsMap = new Map<String, List<Component_Scores__c>>();
    
        for (Component_Scores__c rec : records) {
            if (rec.Slot_Scheduled__c != null) {
                externalSlotIds.add(rec.Slot_Scheduled__c);
                if (!externalIdToRecordsMap.containsKey(rec.Slot_Scheduled__c)) {
                    externalIdToRecordsMap.put(rec.Slot_Scheduled__c, new List<Component_Scores__c>());
                }
                externalIdToRecordsMap.get(rec.Slot_Scheduled__c).add(rec);
            }
        }
    
        if (externalSlotIds.isEmpty()) {
            return;
        }
    
        // Step 2: Query Slot_Scheduled__c by external ID
        List<Slot_Scheduled__c> slotRecords = [
            SELECT Id,
                   Slot_Scheduled__c,
                   Exam_Connection__r.Course_Connection_ID__c,
                   Exam_Connection__r.Exam_Name__c,          // This is Exam__c Id
                   Exam_Connection__r.Student_Name__c,
                   Exam_Connection__r.Exam_Name__r.Exam_Name__c  // Exam Type (still on Exam__c)
            FROM Slot_Scheduled__c
            WHERE Slot_Scheduled__c IN :externalSlotIds
              AND Exam_Connection__c != null
              AND Exam_Connection__r.Exam_Name__c != null
        ];
    
        if (slotRecords.isEmpty()) return;
    
        // Step 3: Collect Exam__c IDs to fetch via junction
        Set<Id> examIds = new Set<Id>();
        for (Slot_Scheduled__c slot : slotRecords) {
            examIds.add(slot.Exam_Connection__r.Exam_Name__c);
        }
    
        // Step 4: Query junction object to get Component & Offering
        Map<Id, Course_Offering_Exam_Connection__c> examIdToJunctionMap = new Map<Id, Course_Offering_Exam_Connection__c>();
        for (Course_Offering_Exam_Connection__c junction : [
            SELECT Id, Exam__c, Course_Evaluation_Component__c, Course_Offering__c
            FROM Course_Offering_Exam_Connection__c
            WHERE Exam__c IN :examIds
        ]) {
            examIdToJunctionMap.put(junction.Exam__c, junction);
        }
    
        // Step 5: Populate fields on Component_Scores__c
        for (Slot_Scheduled__c slot : slotRecords) {
            Id examId = slot.Exam_Connection__r.Exam_Name__c;
            Course_Offering_Exam_Connection__c junction = examIdToJunctionMap.get(examId);
    
            List<Component_Scores__c> relatedScoreRecords = externalIdToRecordsMap.get(slot.Slot_Scheduled__c);
            if (relatedScoreRecords != null) {
                for (Component_Scores__c scoreRec : relatedScoreRecords) {
                    // Populate lookup to Slot_Scheduled__c (real lookup field)
                    scoreRec.Slotscheduled__c = slot.Id;
    
                    // Populate related fields
                    scoreRec.Course_Connection__c = slot.Exam_Connection__r.Course_Connection_ID__c;
                    scoreRec.Exam__c = examId;
                    scoreRec.Student_Name__c = slot.Exam_Connection__r.Student_Name__c;
                    scoreRec.Exam_Type__c = slot.Exam_Connection__r.Exam_Name__r.Exam_Name__c; // Exam type
    
                    // Get Component & Offering from junction
                    if (junction != null) {
                        scoreRec.Component_Name__c = junction.Course_Evaluation_Component__c;
                        scoreRec.Course_Offering__c = junction.Course_Offering__c;
                    }
                }
            }
        }
    }    
    
    // method to calculate and set result based on marks AND Exam_Status__c
    private static void calculateAndSetResult(List<Component_Scores__c> records) {
        Set<Id> componentIdsToQuery = new Set<Id>();
        Map<Id, List<Component_Scores__c>> componentIdToRecordsMap = new Map<Id, List<Component_Scores__c>>();

        // Collect component IDs where marks are available
        for (Component_Scores__c rec : records) {

            // NEW: If Exam_Status__c is Absent, ALWAYS set result to In Complete
            // and skip Pass/Fail calculation based on marks
            if (rec.Exam_Status__c == 'Absent') {
                rec.Component_Score_Result__c = 'In Complete'; // make sure this matches your picklist value
                continue;
            }

            if (rec.Marks_Obtained__c != null && rec.Component_Name__c != null) {
                componentIdsToQuery.add(rec.Component_Name__c);
                if (!componentIdToRecordsMap.containsKey(rec.Component_Name__c)) {
                    componentIdToRecordsMap.put(rec.Component_Name__c, new List<Component_Scores__c>());
                }
                componentIdToRecordsMap.get(rec.Component_Name__c).add(rec);
            }
        }
        
        if (componentIdsToQuery.isEmpty()) {
            return;
        }
        
        // Query component details
        List<Course_Evaluation_Component__c> components = [
            SELECT Id, Maximum_Marks_for_the_Component__c, Pass_Weightage__c
            FROM Course_Evaluation_Component__c
            WHERE Id IN :componentIdsToQuery
              AND Maximum_Marks_for_the_Component__c != null
              AND Pass_Weightage__c != null
        ];
        
        // Calculate result for each record — every record sharing the component, not just one
        for (Course_Evaluation_Component__c comp : components) {
            List<Component_Scores__c> scoreRecords = componentIdToRecordsMap.get(comp.Id);
            if (scoreRecords == null || scoreRecords.isEmpty()) {
                continue;
            }

            Decimal maxMarks = comp.Maximum_Marks_for_the_Component__c;
            Decimal passWeightage = comp.Pass_Weightage__c;
            if (maxMarks == null || passWeightage == null) {
                continue;
            }

            Decimal passMarks = (maxMarks * passWeightage) / 100;

            for (Component_Scores__c scoreRec : scoreRecords) {
                Decimal marksObtained = scoreRec.Marks_Obtained__c;
                if (marksObtained == null) {
                    continue;
                }

                if (marksObtained >= passMarks) {
                    scoreRec.Component_Score_Result__c = 'Pass';
                } else {
                    scoreRec.Component_Score_Result__c = 'Fail';
                }
            }
        }
    }
    
    // Method to deactivate older records - excludes newly inserted/updated records
    private static void deactivateOlderRecords(List<Component_Scores__c> newRecords) {
        Set<Id> courseConnectionIds = new Set<Id>();
        Set<Id> newRecordIds = new Set<Id>(); // Track new record IDs
        
        // Collect course connection IDs and new record IDs
        for (Component_Scores__c rec : newRecords) {
            if (rec.Course_Connection__c != null && rec.Exam_Type__c != null) {
                courseConnectionIds.add(rec.Course_Connection__c);
                newRecordIds.add(rec.Id); // Store the new/updated record ID
            }
        }
        
        if (courseConnectionIds.isEmpty()) {
            return;
        }
        
        // Query OLD Component_Scores__c records only (exclude new records)
        List<Component_Scores__c> allRelatedRecords = [
            SELECT Id, Course_Connection__c, Exam_Type__c, Is_Active__c
            FROM Component_Scores__c
            WHERE Course_Connection__c IN :courseConnectionIds
              AND Is_Active__c = true
              AND Id NOT IN :newRecordIds
        ];
        
        // Group existing OLD records by course connection and exam type
        Map<String, List<Component_Scores__c>> keyToExistingRecords = new Map<String, List<Component_Scores__c>>();
        for (Component_Scores__c rec : allRelatedRecords) {
            String key = rec.Course_Connection__c + '_' + rec.Exam_Type__c;
            if (!keyToExistingRecords.containsKey(key)) {
                keyToExistingRecords.put(key, new List<Component_Scores__c>());
            }
            keyToExistingRecords.get(key).add(rec);
        }
        
        // Identify OLD records to deactivate
        List<Component_Scores__c> recordsToDeactivate = new List<Component_Scores__c>();
        
        for (Component_Scores__c newRec : newRecords) {
            if (newRec.Course_Connection__c != null && newRec.Exam_Type__c != null) {
                String key = newRec.Course_Connection__c + '_' + newRec.Exam_Type__c;
                List<Component_Scores__c> existingRecords = keyToExistingRecords.get(key);
                
                if (existingRecords != null) {
                    for (Component_Scores__c existingRec : existingRecords) {
                        // Deactivate ONLY old records (new records already excluded)
                        existingRec.Is_Active__c = false;
                        recordsToDeactivate.add(existingRec);
                    }
                }
            }
        }
        
        // Update the OLD records to deactivate
        if (!recordsToDeactivate.isEmpty()) {
            update recordsToDeactivate;
        }
    }
    
    // Method to calculate and update final score AND exam result status for course enrollment - bulkified
    private static void calculateAndUpdateFinalScore(Set<Id> courseEnrollmentIds) {
        if (courseEnrollmentIds.isEmpty()) {
            return;
        }
        
        try {
            // Query active component scores for the course enrollments - bulkified in single query
            List<Component_Scores__c> activeComponentScores = [
                SELECT Id, Course_Connection__c, Marks_Obtained__c, 
                     /*  Component_Name__r.Weightage__c,*/ Component_Name__r.Maximum_Marks_for_the_Component__c,
                       Exam_Type__c, Component_Score_Result__c
                FROM Component_Scores__c
                WHERE Course_Connection__c IN :courseEnrollmentIds
                  AND Is_Active__c = true
                  AND Marks_Obtained__c != null
               //   AND Component_Name__r.Weightage__c != null
                  AND Component_Name__r.Maximum_Marks_for_the_Component__c != null
            ];
    
            System.debug('activeComponentScores' + activeComponentScores);
            
            // Group component scores by course enrollment and calculate total + collect results
            Map<Id, Decimal> courseEnrollmentToTotalScore = new Map<Id, Decimal>();
            Map<Id, Map<String, String>> courseEnrollmentToExamResults = new Map<Id, Map<String, String>>();
            
            for (Component_Scores__c compScore : activeComponentScores) {
                if (compScore.Component_Name__r.Maximum_Marks_for_the_Component__c != null && 
                    compScore.Component_Name__r.Maximum_Marks_for_the_Component__c > 0) {
                    
                    // Calculate weighted score
                    Decimal componentScore = (/*compScore.Component_Name__r.Weightage__c*/100 / 100) * 
                                           compScore.Marks_Obtained__c;
                    
                    if (componentScore != null) {
                        if (!courseEnrollmentToTotalScore.containsKey(compScore.Course_Connection__c)) {
                            courseEnrollmentToTotalScore.put(compScore.Course_Connection__c, 0);
                        }
                        
                        courseEnrollmentToTotalScore.put(compScore.Course_Connection__c, 
                            courseEnrollmentToTotalScore.get(compScore.Course_Connection__c) + componentScore);
                    }
                    
                    // Store exam type result for final grade calculation
                    if (compScore.Exam_Type__c != null && compScore.Component_Score_Result__c != null) {
                        if (!courseEnrollmentToExamResults.containsKey(compScore.Course_Connection__c)) {
                            courseEnrollmentToExamResults.put(compScore.Course_Connection__c, new Map<String, String>());
                        }
                        courseEnrollmentToExamResults.get(compScore.Course_Connection__c).put(compScore.Exam_Type__c, compScore.Component_Score_Result__c);
                    }
                }
            }
            
            // Prepare course enrollment records to update - bulkified in single DML
            List<hed__Course_Enrollment__c> courseEnrollmentsToUpdate = new List<hed__Course_Enrollment__c>();
            
            for (Id enrollmentId : courseEnrollmentToTotalScore.keySet()) {
                if (courseEnrollmentToTotalScore.get(enrollmentId) != null) {
                    hed__Course_Enrollment__c courseEnrollment = new hed__Course_Enrollment__c();
                    courseEnrollment.Id = enrollmentId;
                    courseEnrollment.Component_Final_Score__c = courseEnrollmentToTotalScore.get(enrollmentId);
                    
                    // Calculate Exam_Result_Status__c based on CIA and SEE results
                    String ciaResult = 'In Complete'; // Default to In Complete
                    String seeResult = 'In Complete'; // Default to In Complete
                    
                    if (courseEnrollmentToExamResults.containsKey(enrollmentId)) {
                        Map<String, String> examResults = courseEnrollmentToExamResults.get(enrollmentId);
                        
                        if (examResults.containsKey('CIA')) {
                            ciaResult = examResults.get('CIA');
                        }
                        if (examResults.containsKey('SEE')) {
                            seeResult = examResults.get('SEE');
                        }
                    }
                    
                    // Apply the logic from your table to determine Final Result Grade
                    String finalResultGrade = calculateFinalResultGrade(ciaResult, seeResult);
                    courseEnrollment.Exam_Result_Status__c = finalResultGrade;
                    
                    courseEnrollmentsToUpdate.add(courseEnrollment);
                }
            }
            
            // Single DML operation - governor limit friendly
            if (!courseEnrollmentsToUpdate.isEmpty()) {
                update courseEnrollmentsToUpdate;
                System.debug('courseEnrollmentsToUpdate' + courseEnrollmentsToUpdate);
            }
            
        } catch (DmlException e) {
            System.debug('Error updating Course Enrollments: ' + e.getMessage());
        } catch (Exception e) {
            System.debug('Unexpected error in calculateAndUpdateFinalScore: ' + e.getMessage());
        }
    }

    // Helper method to calculate final result grade based on CIA and SEE results
    private static String calculateFinalResultGrade(String ciaResult, String seeResult) {
        // If either is missing, return IC (In Complete)
        if (ciaResult == 'In Complete' || seeResult == 'In Complete') {
            return 'In Complete';
        }
        
        if (ciaResult == 'Pass' && seeResult == 'Pass') {
            return 'Pass';
        }
        if (ciaResult == 'Pass' && seeResult == 'Fail') {
            return 'Fail';
        }
        if (ciaResult == 'Fail' && seeResult == 'Pass') {
            return 'Fail';
        }
        if (ciaResult == 'Fail' && seeResult == 'Fail') {
            return 'Fail';
        }
        
        // Default case
        return 'In Complete';
    } 
	private static void populateExamTypeFromComponent(List<Component_Scores__c> records) {
        Set<Id> componentIds = new Set<Id>();
        Map<Id, List<Component_Scores__c>> componentIdToRecordsMap = new Map<Id, List<Component_Scores__c>>();
    
        // Collect Component_Name__c IDs that are non-null
        for (Component_Scores__c rec : records) {
            if (rec.Component_Name__c != null) {
                componentIds.add(rec.Component_Name__c);
                if (!componentIdToRecordsMap.containsKey(rec.Component_Name__c)) {
                    componentIdToRecordsMap.put(rec.Component_Name__c, new List<Component_Scores__c>());
                }
                componentIdToRecordsMap.get(rec.Component_Name__c).add(rec);
            }
        }
    
        if (componentIds.isEmpty()) {
            return;
        }
    
        // Query components to get Exam_Type__c
        Map<Id, Course_Evaluation_Component__c> componentMap = new Map<Id, Course_Evaluation_Component__c>(
            [SELECT Id, Exam_Type__c FROM Course_Evaluation_Component__c WHERE Id IN :componentIds]
        );
    
        // Populate Exam_Type__c from related component
        for (Id compId : componentMap.keySet()) {
            Course_Evaluation_Component__c comp = componentMap.get(compId);
            List<Component_Scores__c> scoreRecords = componentIdToRecordsMap.get(compId);
            if (scoreRecords != null && comp.Exam_Type__c != null) {
                for (Component_Scores__c scoreRec : scoreRecords) {
                    scoreRec.Exam_Type__c = comp.Exam_Type__c;
                }
            }
        }
    }
}