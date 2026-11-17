global class SlotAndExamExpireBatch implements Database.Batchable<SObject> {

    private String objectName;
    private Id examIndividualRtId;
    private Id examRecurringRtId;

    // Constructor with parameter (used when we call executeBatch)
    global SlotAndExamExpireBatch(String objectName) {
        this.objectName = objectName;

        if (objectName == 'Exam_Slot_Setup__c') {
            Map<String, Id> rtMap = new Map<String, Id>();

            for (RecordType rt : [
                SELECT Id, DeveloperName
                FROM RecordType
                WHERE SobjectType = 'Exam_Slot_Setup__c'
                AND DeveloperName IN ('Individual', 'Recurring')
            ]) {
                rtMap.put(rt.DeveloperName, rt.Id);
            }

            examIndividualRtId = rtMap.get('Individual');
            examRecurringRtId  = rtMap.get('Recurring');
        }
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {

        if (objectName == 'Slot_scheduled__c') {
            return Database.getQueryLocator([
                SELECT Id, End_Date_Time__c, Is_Expired__c
                FROM Slot_scheduled__c
                WHERE Is_Expired__c = FALSE
            ]);

        } else if (objectName == 'Exam_Slot_Setup__c') {

            List<Id> rtIds = new List<Id>();
            if (examIndividualRtId != null) rtIds.add(examIndividualRtId);
            if (examRecurringRtId != null)  rtIds.add(examRecurringRtId);

            if (rtIds.isEmpty()) {
                return Database.getQueryLocator('SELECT Id FROM Exam_Slot_Setup__c WHERE Id = null');
            }

            return Database.getQueryLocator([
                SELECT Id,
                       RecordTypeId,
                       Start_Date__c,
                       End_Date__c,
                       End_Time__c,
                       Is_Expired__c
                FROM Exam_Slot_Setup__c
                WHERE Is_Expired__c = FALSE
                AND RecordTypeId IN :rtIds
            ]);
        }

        return Database.getQueryLocator('SELECT Id FROM Account WHERE Id = null');
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {

        if (scope.isEmpty()) return;

        Datetime nowDt = System.now();
        List<SObject> toUpdate = new List<SObject>();

        if (objectName == 'Slot_scheduled__c') {

            for (Slot_scheduled__c s : (List<Slot_scheduled__c>)scope) {
                if (s.End_Date_Time__c != null && s.End_Date_Time__c <= nowDt) {
                    s.Is_Expired__c = true;
                    toUpdate.add(s);
                }
            }

        } else if (objectName == 'Exam_Slot_Setup__c') {

            for (Exam_Slot_Setup__c rec : (List<Exam_Slot_Setup__c>)scope) {
                Datetime endDt;

                // Individual → Start_Date__c + End_Time__c
                if (rec.RecordTypeId == examIndividualRtId) {
                    if (rec.Start_Date__c != null && rec.End_Time__c != null) {
                        endDt = Datetime.newInstance(rec.Start_Date__c, rec.End_Time__c);
                    }

                // Recurring → End_Date__c + End_Time__c
                } else if (rec.RecordTypeId == examRecurringRtId) {
                    if (rec.End_Date__c != null && rec.End_Time__c != null) {
                        endDt = Datetime.newInstance(rec.End_Date__c, rec.End_Time__c);
                    }
                }

                if (endDt != null && endDt <= nowDt) {
                    rec.Is_Expired__c = true;
                    toUpdate.add(rec);
                }
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    global void finish(Database.BatchableContext bc) {
        // optional
    }
}