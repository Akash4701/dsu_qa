trigger IndividualApplicationTrigger on Application__c (after update, after insert) {
    if(Trigger.isAfter && Trigger.isInsert){
        IndividualApplicationTriggerHandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        IndividualApplicationTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
                IndividualApplicationTriggerHandler.handleDEBIDUpdate(Trigger.new, Trigger.oldMap);
         IndividualApplicationTriggerHandler.validateDEBIDBeforeApproval(Trigger.new, Trigger.oldMap);
        IndividualApplicationTriggerHandler.generateOfferFromApplication(Trigger.new, Trigger.oldMap);
        IndividualApplicationTriggerHandler.sendOffer(Trigger.new,Trigger.oldMap);
    }
  
}