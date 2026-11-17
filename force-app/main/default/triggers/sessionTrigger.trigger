trigger sessionTrigger on Session__c (before insert, before update, after insert, after update, after delete) {
    if(trigger.isBefore){
        if(trigger.isInsert){
            system.debug('Hello from before update');
            SessionTriggerHandler.restrictDuplicateSessions(trigger.new);
            //SessionTriggerHandler.sessions(trigger.new,null);
        }  
    }
    if(trigger.isAfter){
        if(trigger.isInsert){
            system.debug('Hello from after insert');
            //SessionTriggerHandler.sessions(trigger.new,null);
        }  
        if(trigger.isUpdate){
            //SessionTriggerHandler.sessions(trigger.new,trigger.oldMap);
            //SessionTriggerHandler.sendEmail(trigger.new,trigger.oldMap);
        }
    
    }
     
}