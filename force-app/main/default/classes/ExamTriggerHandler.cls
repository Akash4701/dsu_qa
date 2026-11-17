public class ExamTriggerHandler {

    public static void beforeInsertUpdate(List<Exam__c> newList, Map<Id, Exam__c> oldMap) {

        // Collect all Course Evaluation Component Ids from the incoming Exams
        Set<Id> cecIds = new Set<Id>();
        for (Exam__c ex : newList) {
            if (ex.Course_Evaluation_Component__c != null) {
                cecIds.add(ex.Course_Evaluation_Component__c);
            }
        }

        // If no CEC at all, still block rows that are missing it (since Exam_Cycle must be derived)
        // If your business rule says Exam can be saved without CEC, remove this validation block.
        for (Exam__c ex : newList) {
            if (ex.Course_Evaluation_Component__c == null) {
                ex.Course_Evaluation_Component__c.addError(
                    'Cannot save Exam: Course Evaluation Component is missing. ' +
                    'Exam Cycle cannot be determined without it.'
                );
            }
        }

        if (cecIds.isEmpty()) {
            return; // all rows errored or none to process
        }

        // Query the Course Evaluation Component records (need Term + Exam Type)
        Map<Id, Course_Evaluation_Component__c> cecMap =
            new Map<Id, Course_Evaluation_Component__c>([
                SELECT Id,
                       Exam_Type__c,
                       Course_Offering__c,
                       Course_Offering__r.hed__Term__c
                FROM Course_Evaluation_Component__c
                WHERE Id IN :cecIds
            ]);

        // Collect Term Ids and Exam Types needed to query Exam Cycle Term Connection
        Set<Id> termIds = new Set<Id>();
        Set<String> examTypes = new Set<String>();

        for (Course_Evaluation_Component__c cec : cecMap.values()) {
            Id termId = (cec.Course_Offering__r != null) ? cec.Course_Offering__r.hed__Term__c : null;

            if (termId != null) termIds.add(termId);
            if (!String.isBlank(cec.Exam_Type__c)) examTypes.add(cec.Exam_Type__c);
        }

        // Build map: (TermId|ExamType) -> Exam_Cycle__c
        Map<String, Id> keyToExamCycleId = new Map<String, Id>();
        if (!termIds.isEmpty() && !examTypes.isEmpty()) {
            for (Exam_Cycle_Term_Connection__c ectc : [
                SELECT Id,
                       Exam_Cycle__c,
                       Term__c,
                       Exam_Cycle__r.Exam_Name__c
                FROM Exam_Cycle_Term_Connection__c
                WHERE Term__c IN :termIds
                  AND Exam_Cycle__r.Exam_Name__c IN :examTypes
                  AND Exam_Cycle__c != null
				  AND Exam_Cycle__r.Is_Active__c = true
            ]) {
                String key = ectc.Term__c + '|' + ectc.Exam_Cycle__r.Exam_Name__c;
                if (!keyToExamCycleId.containsKey(key)) {
                    keyToExamCycleId.put(key, ectc.Exam_Cycle__c);
                }
            }
        }

        // Set / Validate Exam_Cycle__c
        for (Exam__c ex : newList) {

            // Optional optimization: on update, only re-evaluate if key inputs changed OR exam cycle blank
            if (oldMap != null && ex.Id != null) {
                Exam__c oldRec = oldMap.get(ex.Id);
                if (oldRec != null) {
                    Boolean cecUnchanged = (ex.Course_Evaluation_Component__c == oldRec.Course_Evaluation_Component__c);
                    Boolean examCycleAlreadySet = (ex.Exam_Cycle__c != null);
                    if (cecUnchanged && examCycleAlreadySet) {
                        continue; // nothing to do
                    }
                }
            }

            // If already set, you can skip validation; but requirement says it must be required if derivation fails.
            // We'll still validate if it's blank.
            if (ex.Exam_Cycle__c != null) {
                continue;
            }

            // Validate CEC existence
            if (ex.Course_Evaluation_Component__c == null) {
                // already addError above
                continue;
            }

            Course_Evaluation_Component__c cec = cecMap.get(ex.Course_Evaluation_Component__c);
            if (cec == null) {
                ex.Course_Evaluation_Component__c.addError(
                    'Cannot save Exam: Course Evaluation Component record was not found. ' +
                    'Exam Cycle cannot be determined.'
                );
                continue;
            }

            // Validate Course Offering and Term
            if (cec.Course_Offering__c == null) {
                ex.Course_Evaluation_Component__c.addError(
                    'Cannot save Exam: Course Offering is missing on the Course Evaluation Component. ' +
                    'Exam Cycle cannot be determined.'
                );
                continue;
            }

            Id termId = (cec.Course_Offering__r != null) ? cec.Course_Offering__r.hed__Term__c : null;
            if (termId == null) {
                ex.Course_Evaluation_Component__c.addError(
                    'Cannot save Exam: Term is missing on the Course Offering linked to the Course Evaluation Component. ' +
                    'Exam Cycle cannot be determined.'
                );
                continue;
            }

            // Validate Exam Type
            String examType = cec.Exam_Type__c;
            if (String.isBlank(examType)) {
                ex.Course_Evaluation_Component__c.addError(
                    'Cannot save Exam: Exam Type is missing on the Course Evaluation Component. ' +
                    'Exam Cycle cannot be determined.'
                );
                continue;
            }

            // Find Exam Cycle via (Term + Exam Type)
            String key = termId + '|' + examType;
            Id examCycleId = keyToExamCycleId.get(key);

            if (examCycleId != null) {
                ex.Exam_Cycle__c = examCycleId;
            } else {
                // Block insert/update with clear message
                ex.Exam_Cycle__c.addError(
                    'Cannot save Exam: Exam Cycle record is missing for Term = ' + termId +
                    ' and Exam Type = "' + examType + '". ' +
                    'Create/maintain the Exam Cycle Term Connection (and related Exam Cycle) for this combination.'
                );
            }
        }
    }
}