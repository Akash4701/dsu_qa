public with sharing class CourseEvaluationComponentHandler {

    public static void handleAfterInsert(List<Course_Evaluation_Component__c> newComponents) {
        if (newComponents == null || newComponents.isEmpty()) return;

        List<Exam__c> examsToInsert = new List<Exam__c>();
        List<Course_Evaluation_Component__c> compsForExam = new List<Course_Evaluation_Component__c>();

        // Only process components where Exam_Required__c == true
        for (Course_Evaluation_Component__c comp : newComponents) {
            if (comp == null) continue;
            if (comp.Course_Offering__c == null) continue;
            if (comp.Exam_Required__c != true) continue;

            examsToInsert.add(new Exam__c(
                Exam_Name__c = comp.Exam_Type__c,
                Course_Evaluation_Component__c = comp.Id  // keep as-is (if field exists)
            ));
            compsForExam.add(comp);
        }

        if (examsToInsert.isEmpty()) return;

        insert examsToInsert;

        // Build junctions and component → exam map
        List<Course_Offering_Exam_Connection__c> junctionsToInsert = new List<Course_Offering_Exam_Connection__c>();
        Map<Id, Id> componentIdToExamId = new Map<Id, Id>();

        for (Integer i = 0; i < examsToInsert.size(); i++) {
            Exam__c exam = examsToInsert[i];
            Course_Evaluation_Component__c comp = compsForExam[i];

            junctionsToInsert.add(new Course_Offering_Exam_Connection__c(
                Course_Evaluation_Component__c = comp.Id,
                Course_Offering__c = comp.Course_Offering__c,
                Exam__c = exam.Id
            ));

            componentIdToExamId.put(comp.Id, exam.Id);
        }

        insert junctionsToInsert;

        // IMPORTANT: pass only "true" comps
        createExamConnections(compsForExam, componentIdToExamId);
    }

    public static void handleAfterUpdate(
        List<Course_Evaluation_Component__c> newComponents,
        Map<Id, Course_Evaluation_Component__c> oldMap
    ) {
        if (newComponents == null || newComponents.isEmpty()) return;
        if (oldMap == null || oldMap.isEmpty()) return;

        List<Course_Evaluation_Component__c> componentsToProcess = new List<Course_Evaluation_Component__c>();
        Set<Id> componentsToCleanUp = new Set<Id>();

        for (Course_Evaluation_Component__c newComp : newComponents) {
            if (newComp == null) continue;

            Course_Evaluation_Component__c oldComp = oldMap.get(newComp.Id);
            if (oldComp == null) continue;

            Boolean courseOfferingChanged = (newComp.Course_Offering__c != oldComp.Course_Offering__c);
            Boolean examRequiredChanged  = (newComp.Exam_Required__c != oldComp.Exam_Required__c);

            if (courseOfferingChanged || examRequiredChanged) {
                // Became eligible (or moved while eligible)
                if (newComp.Course_Offering__c != null && newComp.Exam_Required__c == true) {
                    componentsToProcess.add(newComp);
                }
                // Became ineligible (or removed while eligible before)
                else if (oldComp.Course_Offering__c != null && oldComp.Exam_Required__c == true) {
                    componentsToCleanUp.add(newComp.Id);
                }
            }
        }

        if (!componentsToProcess.isEmpty()) {
            processComponentsForExams(componentsToProcess);
        }

        if (!componentsToCleanUp.isEmpty()) {
            cleanupExamRecords(new List<Id>(componentsToCleanUp));
        }
    }

    private static void processComponentsForExams(List<Course_Evaluation_Component__c> components) {
        if (components == null || components.isEmpty()) return;

        List<Exam__c> examsToInsert = new List<Exam__c>();
        List<Course_Evaluation_Component__c> compsForExam = new List<Course_Evaluation_Component__c>();

        // Only process components where Exam_Required__c == true
        for (Course_Evaluation_Component__c comp : components) {
            if (comp == null) continue;
            if (comp.Course_Offering__c == null) continue;
            if (comp.Exam_Required__c != true) continue;

            examsToInsert.add(new Exam__c(
                Exam_Name__c = comp.Exam_Type__c,
                Course_Evaluation_Component__c = comp.Id  // keep as-is (if field exists)
            ));

            compsForExam.add(comp);
        }

        if (examsToInsert.isEmpty()) return;

        insert examsToInsert;

        List<Course_Offering_Exam_Connection__c> junctionsToInsert = new List<Course_Offering_Exam_Connection__c>();
        Map<Id, Id> componentIdToExamId = new Map<Id, Id>();

        for (Integer i = 0; i < examsToInsert.size(); i++) {
            Exam__c exam = examsToInsert[i];
            Course_Evaluation_Component__c comp = compsForExam[i];

            junctionsToInsert.add(new Course_Offering_Exam_Connection__c(
                Course_Evaluation_Component__c = comp.Id,
                Course_Offering__c = comp.Course_Offering__c,
                Exam__c = exam.Id
            ));

            componentIdToExamId.put(comp.Id, exam.Id);
        }

        insert junctionsToInsert;

        // IMPORTANT: pass only "true" comps
        createExamConnections(compsForExam, componentIdToExamId);
    }

    private static void cleanupExamRecords(List<Id> componentIds) {
        if (componentIds == null || componentIds.isEmpty()) return;

        // Step 1: Get junction records linked to these components
        List<Course_Offering_Exam_Connection__c> junctions = [
            SELECT Id, Exam__c
            FROM Course_Offering_Exam_Connection__c
            WHERE Course_Evaluation_Component__c IN :componentIds
        ];

        if (junctions.isEmpty()) return;

        Set<Id> examIds = new Set<Id>();
        for (Course_Offering_Exam_Connection__c j : junctions) {
            if (j.Exam__c != null) examIds.add(j.Exam__c);
        }

        // Step 2: Delete Exam_Connections__c
        List<Exam_Connections__c> connectionsToDelete = [
            SELECT Id
            FROM Exam_Connections__c
            WHERE Exam_Name__c IN :examIds
        ];
        if (!connectionsToDelete.isEmpty()) {
            delete connectionsToDelete;
        }

        // Step 3: Delete junctions
        delete junctions;

        // Step 4: Delete exams (safe now that junctions are gone)
        if (!examIds.isEmpty()) {
            delete [SELECT Id FROM Exam__c WHERE Id IN :examIds];
        }
    }

    private static void createExamConnections(
        List<Course_Evaluation_Component__c> components,
        Map<Id, Id> componentIdToExamId
    ) {
        if (components == null || components.isEmpty()) return;
        if (componentIdToExamId == null || componentIdToExamId.isEmpty()) return;

        // Build offering → exam mapping (existing approach kept)
        Map<Id, Id> offeringIdToExamId = new Map<Id, Id>();
        Set<Id> offeringIds = new Set<Id>();

        for (Course_Evaluation_Component__c comp : components) {
            if (comp == null) continue;

            // HARD GUARD: never create exam connections when Exam_Required__c is false
            if (comp.Exam_Required__c != true) continue;

            if (comp.Course_Offering__c != null && componentIdToExamId.containsKey(comp.Id)) {
                Id examId = componentIdToExamId.get(comp.Id);
                if (examId == null) continue;

                offeringIds.add(comp.Course_Offering__c);
                offeringIdToExamId.put(comp.Course_Offering__c, examId);
            }
        }

        if (offeringIds.isEmpty()) return;

        // Bulk query enrollments
        List<hed__Course_Enrollment__c> enrollments = [
            SELECT Id, hed__Contact__c, hed__Course_Offering__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :offeringIds
              AND hed__Contact__c != null
              AND Exam_Eligibility__c = 'Eligible'
        ];

        if (enrollments.isEmpty()) return;

        // Create Exam_Connections__c
        List<Exam_Connections__c> connectionsToInsert = new List<Exam_Connections__c>();

        for (hed__Course_Enrollment__c enr : enrollments) {
            Id examId = offeringIdToExamId.get(enr.hed__Course_Offering__c);
            if (examId == null) continue;

            // Find the matching component (same as your existing logic)
            Id compId = null;
            for (Course_Evaluation_Component__c comp : components) {
                if (comp == null) continue;
                if (comp.Exam_Required__c != true) continue;

                if (componentIdToExamId.get(comp.Id) == examId &&
                    comp.Course_Offering__c == enr.hed__Course_Offering__c) {
                    compId = comp.Id;
                    break;
                }
            }

            connectionsToInsert.add(new Exam_Connections__c(
                Student_Name__c = enr.hed__Contact__c,
                Course_Connection_ID__c = enr.Id,
                Exam_Name__c = examId,
                Course_Evaluation_Component__c = compId // keep as-is (if field required)
            ));
        }

        if (!connectionsToInsert.isEmpty()) {
            insert connectionsToInsert;
        }
    }
}