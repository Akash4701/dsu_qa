trigger FeeAssignmentTrigger on Fee_Assignment__c (
    before insert, before update, after insert, after update
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            List<Fee_Assignment__c> changedRecords = new List<Fee_Assignment__c>();
            
            if (Trigger.isInsert) {
                changedRecords.addAll(Trigger.new);
            } else {
                for (Fee_Assignment__c newRec : Trigger.new) {
                    Fee_Assignment__c oldRec = Trigger.oldMap.get(newRec.Id);
                    if (newRec.Scholarship__c != oldRec.Scholarship__c) {
                        changedRecords.add(newRec);
                    }
                }
            }
            
            if (!changedRecords.isEmpty()) {
                FeeAssignmentHandler.calculateScholarship(changedRecords, Trigger.oldMap);
            }
        }
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            List<Fee_Assignment__c> changedRecords = new List<Fee_Assignment__c>();
            
            if (Trigger.isInsert) {
                changedRecords.addAll(Trigger.new);
            } else {
                for (Fee_Assignment__c newRec : Trigger.new) {
                    Fee_Assignment__c oldRec = Trigger.oldMap.get(newRec.Id);
                    if (newRec.Scholarship__c != oldRec.Scholarship__c) {
                        changedRecords.add(newRec);
                    }
                }
            }
            
            if (!changedRecords.isEmpty()) {
                FeeAssignmentHandler.updateInstallments(changedRecords);
            }
        }
    }
}