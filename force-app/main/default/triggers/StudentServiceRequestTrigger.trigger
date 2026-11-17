trigger StudentServiceRequestTrigger on Student_Service_Request__c (after insert, after update) {
    if (Trigger.isAfter && Trigger.isInsert) {
        StudentServiceRequestTriggerHandler.handleAfterInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        StudentServiceRequestTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}