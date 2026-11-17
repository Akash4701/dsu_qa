/**
 * @description       : 
 * @author            : Ken42
 * @group             : 
 * @last modified on  : 31-10-2025
 * @last modified by  : Ken42
**/
trigger ProgramEnrollmentTrigger on hed__Program_Enrollment__c (before insert, before update,after insert) {
    
     if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            ProgramEnrollmentTriggerHandler.handleEndDateStatusUpdate(Trigger.new);
        }
    }
    
    if (Trigger.isAfter && Trigger.isInsert) {
        //ProgramEnrollmentTriggerHandler.handleAfterInsert(Trigger.new);
        ProgramEnrollmentTriggerHandler.handleAffiliation(Trigger.new);
		FeeAssignmentHandler.prepareAndCreateFeeAssignments(Trigger.new);
    }
    
    }