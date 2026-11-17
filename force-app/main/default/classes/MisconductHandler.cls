public with sharing class MisconductHandler {

    public static void populateFromExamConnection(
        List<Misconduct__c> newRecords,
        Map<Id, Misconduct__c> oldMap
    ) {
        // Collect Exam Connection Ids that actually need processing
        Set<Id> examConnectionIds = new Set<Id>();

        for (Misconduct__c rec : newRecords) {
            if (rec.Exam_Connection__c == null) {
                continue;
            }

            // oldMap is null  always process
            // process only if Exam Connection changed
            if (oldMap == null) {
                examConnectionIds.add(rec.Exam_Connection__c);
            } else {
                Misconduct__c oldRec = oldMap.get(rec.Id);
                if (oldRec == null || oldRec.Exam_Connection__c != rec.Exam_Connection__c) {
                    examConnectionIds.add(rec.Exam_Connection__c);
                }
            }
        }

        if (examConnectionIds.isEmpty()) {
            return; 
        }

        // Single SOQL query  bulkified
        Map<Id,Exam_Connections__c> examConnMap =
            new Map<Id, Exam_Connections__c>([
                SELECT  Id,
                        Course_Evaluation_Component__r.Name,
                        Course_Connection_ID__c,
                        Student_Name__c
                FROM    Exam_Connections__c
                WHERE   Id IN :examConnectionIds
            ]);

        // Populate Misconduct fields
        for (Misconduct__c rec : newRecords) {
            if (rec.Exam_Connection__c == null) continue;

            Exam_Connections__c exam = examConnMap.get(rec.Exam_Connection__c);
            if (exam == null) continue; 

           
            rec.Component_Name__c   = exam.Course_Evaluation_Component__r != null
                                      ? exam.Course_Evaluation_Component__r.Name
                                      : null;
            rec.Course_Connection__c = exam.Course_Connection_ID__c;
            rec.Contact__c           = exam.Student_Name__c;
        }
    }
}