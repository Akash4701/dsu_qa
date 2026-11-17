trigger courseOfferingInsertUpdateTrigger on Course_Version__c (after insert , after update,after delete,after undelete,before delete,before insert,before update) {
    if(trigger.isAfter && trigger.isInsert){
        //if (trigger.new != null) {
        //courseOfferingInsertUpdate.creatingcourseoffering(trigger.new);
        //}
        //CreateActivityHandler.createActivity(trigger.new);
        // ActivityHandler.calculateStartDate(trigger.new);
        system.debug('After Insert');
        if(ActivityTriggerNewHandler.isFirstTime){
            ActivityTriggerNewHandler.isFirstTime = false;
            //ActivityHandler.updateCVendDateFromCVTrigger(trigger.new,null);
            ActivityTriggerNewHandler.calculateCourseVersionEndDateWithCV(trigger.new);
            system.debug('hello from activity firstTime');
           
        }
    }
  if(trigger.isAfter && trigger.isUpdate){
      system.debug('After update');
        
      if(ActivityTriggerNewHandler.isFirstTime){
          ActivityTriggerNewHandler.isFirstTime = false;
          ActivityTriggerNewHandler.calculateCourseVersionEndDateWithCV(trigger.new);
          ActivityTriggerNewHandler.recalculateTheActivityDates(trigger.new, trigger.oldMap);
          
          //ActivityHandler.isFirstTime = false;
          //ActivityHandler.updateCVendDateFromCVTrigger(trigger.new,trigger.oldMap);

    }
      
      
      
  /*  If(trigger.isInsert && trigger.isAfter){
        CreatePlanRequirementHandler.inserteachPlanRequirement(trigger.new);
    } */
    //If(trigger.isInsert && trigger.isAfter){
        //CreatePlanRequirementHandler.insertPlanRequirement(trigger.new);
    //}
    If(trigger.isDelete && trigger.isBefore){
        CreatePlanRequirementHandler.deleteeachPlanRequirements(trigger.old);
    }
    //Restricting Duplicate CourseVersions
      If(trigger.isInsert && trigger.isBefore){
        CourseVersionDuplicateAvoidHandler.avoidingDuplicateCourseVersoins(trigger.new);
    }
    if(trigger.isAfter && (trigger.isUpdate )){
        CourseVersionTriggerHandler.checkRelatedExams(trigger.new);
        //courseOfferingInsertUpdate.updateingCourseoffering(trigger.new);
        for(Course_Version__c cv : trigger.new){
            system.debug('cou.Subject_Start_Date__c on update-->'+cv.Subject_Start_Date__c);
        }
    }
  }
    new courseOfferingInsertUpdate().process();
    
}