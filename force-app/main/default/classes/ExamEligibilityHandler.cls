public class ExamEligibilityHandler {

    public static void handleCourseEnrollmentUpdate(
        Map<Id, hed__Course_Enrollment__c> newMap,
        Map<Id, hed__Course_Enrollment__c> oldMap
    ) {
        // Based on rule:
        // IF Exam_Eligibility__c = 'Eligible' AND Enrollment_Status__c = 'Enrolled'
        //    => Exam_Connections__c.Eligibility__c = 'Eligible'
        // ELSE
        //    => Exam_Connections__c.Eligibility__c = 'Not Eligible'

        Set<Id> ceIdsNowEligible    = new Set<Id>();
        Set<Id> ceIdsNowNotEligible = new Set<Id>();

        for (Id ceId : newMap.keySet()) {
            hed__Course_Enrollment__c newRec = newMap.get(ceId);
            hed__Course_Enrollment__c oldRec = oldMap.get(ceId);

            // Only react if either Exam_Eligibility__c OR Enrollment_Status__c changed
            Boolean eligibilityChanged  = (newRec.Exam_Eligibility__c != oldRec.Exam_Eligibility__c);
            Boolean statusChanged       = (newRec.Enrollment_Status__c != oldRec.Enrollment_Status__c);

            if (!eligibilityChanged && !statusChanged) {
                continue;
            }

            // Evaluate final eligibility condition
            Boolean isEligibleNow =
                (newRec.Exam_Eligibility__c == 'Eligible' &&
                 newRec.Enrollment_Status__c == 'Enrolled');

            if (isEligibleNow) {
                ceIdsNowEligible.add(ceId);
            } else {
                ceIdsNowNotEligible.add(ceId);
            }
        }

        // First mark Not Eligible (covers any "else" scenario)
        if (!ceIdsNowNotEligible.isEmpty()) {
            handleNotEligible(ceIdsNowNotEligible);
        }

        // Then set Eligible / create missing eligible connections
        if (!ceIdsNowEligible.isEmpty()) {
            handleEligible(newMap, ceIdsNowEligible);
        }
    }

    // When NOT eligible => mark related Exam_Connections__c Not Eligible
    private static void handleNotEligible(Set<Id> ceIdsNowNotEligible) {
        List<Exam_Connections__c> examConnectionsToUpdate = [
            SELECT Id, Eligibility__c, Course_Connection_ID__c
            FROM Exam_Connections__c
            WHERE Course_Connection_ID__c IN :ceIdsNowNotEligible
        ];

        List<Exam_Connections__c> updates = new List<Exam_Connections__c>();

        for (Exam_Connections__c ec : examConnectionsToUpdate) {
            if (ec.Eligibility__c != 'Not Eligible') {
                ec.Eligibility__c = 'Not Eligible';
                updates.add(ec);
            }
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    // When eligible => create/update Exam_Connections__c with Eligibility__c = Eligible
    private static void handleEligible(
        Map<Id, hed__Course_Enrollment__c> newMap,
        Set<Id> ceIdsNowEligible
    ) {
        // Map Course Enrollment → Course Offering & Student
        Map<Id, Id> ceIdToOfferingId = new Map<Id, Id>();
        Map<Id, Id> ceIdToStudentId  = new Map<Id, Id>();

        for (Id ceId : ceIdsNowEligible) {
            hed__Course_Enrollment__c ce = newMap.get(ceId);
            if (ce == null) continue;

            if (ce.hed__Course_Offering__c != null) {
                ceIdToOfferingId.put(ceId, ce.hed__Course_Offering__c);
            }
            if (ce.hed__Contact__c != null) {
                ceIdToStudentId.put(ceId, ce.hed__Contact__c);
            }
        }

        if (ceIdToOfferingId.isEmpty()) {
            return;
        }

        Set<Id> offeringIds = new Set<Id>(ceIdToOfferingId.values());

        // Get all Course Evaluation Components for these Course Offerings.
        // Only components that actually require an exam (SEE) get an Exam_Connections__c —
        // CIA components never have an Exam__c, so including them here only produces
        // orphan connections with a blank Exam_Name__c.
        List<Course_Evaluation_Component__c> allComponents = [
            SELECT Id, Course_Offering__c
            FROM Course_Evaluation_Component__c
            WHERE Course_Offering__c IN :offeringIds
              AND Exam_Required__c = true
        ];

        if (allComponents.isEmpty()) {
            return;
        }

        // Map Offering → its Course Evaluation Components
        Map<Id, List<Course_Evaluation_Component__c>> offeringIdToComponents =
            new Map<Id, List<Course_Evaluation_Component__c>>();

        Set<Id> componentIds = new Set<Id>();

        for (Course_Evaluation_Component__c cec : allComponents) {
            componentIds.add(cec.Id);

            if (!offeringIdToComponents.containsKey(cec.Course_Offering__c)) {
                offeringIdToComponents.put(
                    cec.Course_Offering__c,
                    new List<Course_Evaluation_Component__c>()
                );
            }
            offeringIdToComponents.get(cec.Course_Offering__c).add(cec);
        }

        // Get existing Exam_Connections__c for (Course_Connection, Component) combinations
        List<Exam_Connections__c> existingExConns = [
            SELECT Id, Eligibility__c, Course_Connection_ID__c, Course_Evaluation_Component__c
            FROM Exam_Connections__c
            WHERE Course_Connection_ID__c IN :ceIdsNowEligible
              AND Course_Evaluation_Component__c IN :componentIds
        ];

        Map<String, Exam_Connections__c> existingMap = new Map<String, Exam_Connections__c>();
        for (Exam_Connections__c ec : existingExConns) {
            String key = ec.Course_Connection_ID__c + '-' + ec.Course_Evaluation_Component__c;
            existingMap.put(key, ec);
        }

        // Get Exam__c records per Course_Evaluation_Component__c
        Map<Id, Id> componentIdToExamId = new Map<Id, Id>();

        List<Exam__c> exams = [
            SELECT Id, Course_Evaluation_Component__c
            FROM Exam__c
            WHERE Course_Evaluation_Component__c IN :componentIds
        ];

        for (Exam__c ex : exams) {
            // If multiple Exams per component, last one wins; adjust if needed
            componentIdToExamId.put(ex.Course_Evaluation_Component__c, ex.Id);
        }

        // Create or update Exam_Connections__c
        List<Exam_Connections__c> toUpdate = new List<Exam_Connections__c>();
        List<Exam_Connections__c> toInsert = new List<Exam_Connections__c>();

        for (Id ceId : ceIdsNowEligible) {
            Id offeringId = ceIdToOfferingId.get(ceId);
            if (offeringId == null) continue;

            List<Course_Evaluation_Component__c> comps = offeringIdToComponents.get(offeringId);
            if (comps == null || comps.isEmpty()) continue;

            Id studentId = ceIdToStudentId.get(ceId);

            for (Course_Evaluation_Component__c comp : comps) {
                String key = ceId + '-' + comp.Id;
                Exam_Connections__c existing = existingMap.get(key);

                if (existing != null) {
                    if (existing.Eligibility__c != 'Eligible') {
                        existing.Eligibility__c = 'Eligible';
                        toUpdate.add(existing);
                    }
                } else {
                    Exam_Connections__c newEc = new Exam_Connections__c();
                    newEc.Course_Connection_ID__c        = ceId;
                    newEc.Course_Evaluation_Component__c = comp.Id;
                    newEc.Eligibility__c                 = 'Eligible';

                    Id examId = componentIdToExamId.get(comp.Id);
                    if (examId != null) {
                        newEc.Exam_Name__c = examId;
                    }

                    if (studentId != null) {
                        newEc.Student_Name__c = studentId;
                    }

                    toInsert.add(newEc);
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }
     public static void handleCourseEnrollmentBefore(
        List<hed__Course_Enrollment__c> newList,
        Map<Id, hed__Course_Enrollment__c> oldMap
    ) {
        // 1) Credits Attempted should be set when Course Offering is inserted/changed
        applyCreditsAttemptedFromOffering(newList, oldMap);

        // 2) Credits Earned should be calculated when Component_Final_Score__c is inserted/changed
        applyCreditsEarnedFromScore(newList, oldMap);
    }

   
    private static void applyCreditsAttemptedFromOffering(
        List<hed__Course_Enrollment__c> newList,
        Map<Id, hed__Course_Enrollment__c> oldMap
    ) {
        Set<Id> offeringIdsToQuery = new Set<Id>();

        for (hed__Course_Enrollment__c ce : newList) {
            // Only when inserted OR Course Offering changed
            Boolean isInsert = (oldMap == null);
            Boolean offeringChanged = !isInsert
                && ce.hed__Course_Offering__c != oldMap.get(ce.Id).hed__Course_Offering__c;

            if ((isInsert || offeringChanged) && ce.hed__Course_Offering__c != null) {
                offeringIdsToQuery.add(ce.hed__Course_Offering__c);
            }
        }

        if (offeringIdsToQuery.isEmpty()) return;

        // Query Offering -> Course -> Credits
        Map<Id, hed__Course_Offering__c> offeringMap = new Map<Id, hed__Course_Offering__c>([
            SELECT Id, hed__Course__r.Credits__c
            FROM hed__Course_Offering__c
            WHERE Id IN :offeringIdsToQuery
        ]);

        for (hed__Course_Enrollment__c ce : newList) {
            if (ce.hed__Course_Offering__c == null) continue;

            Boolean isInsert = (oldMap == null);
            Boolean offeringChanged = !isInsert
                && ce.hed__Course_Offering__c != oldMap.get(ce.Id).hed__Course_Offering__c;

            if (isInsert || offeringChanged) {
                hed__Course_Offering__c off = offeringMap.get(ce.hed__Course_Offering__c);
                if (off != null) {
                    // Store credits into Credits Attempted
                    ce.hed__Credits_Attempted__c = off.hed__Course__r.Credits__c;
                }
            }
        }
    }

    
    private static void applyCreditsEarnedFromScore(
        List<hed__Course_Enrollment__c> newList,
        Map<Id, hed__Course_Enrollment__c> oldMap
    ) {
        for (hed__Course_Enrollment__c ce : newList) {
            Boolean isInsert = (oldMap == null);
            hed__Course_Enrollment__c oldCe = isInsert ? null : oldMap.get(ce.Id);

            Boolean scoreChanged = isInsert
                ? (ce.Component_Final_Score__c != null)
                : (ce.Component_Final_Score__c != oldCe.Component_Final_Score__c);
            Boolean attemptedChanged = !isInsert
                && ce.hed__Credits_Attempted__c != oldCe.hed__Credits_Attempted__c;
            Boolean gradeChanged = !isInsert
                && ce.Final_Grade__c != oldCe.Final_Grade__c;

            if (!(scoreChanged || attemptedChanged || gradeChanged)) continue;

            // If score is blank, you can decide to null out earned credits
            if (
                ce.Component_Final_Score__c == null ||
                ce.hed__Credits_Attempted__c == null ||
                String.isBlank(ce.Final_Grade__c)
            ) {
                ce.hed__Credits_Earned__c = null;
                continue;
            }

            String finalGrade = ce.Final_Grade__c.trim().toUpperCase();
            if (finalGrade == 'F' || finalGrade == 'IC') {
                ce.hed__Credits_Earned__c = 0;
            } else {
                ce.hed__Credits_Earned__c = ce.hed__Credits_Attempted__c;
            }
           
        }
    }
}