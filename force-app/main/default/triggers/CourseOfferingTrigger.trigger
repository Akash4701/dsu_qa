trigger CourseOfferingTrigger on hed__Course_Offering__c (before insert,before update,after insert, after update,before delete) {
    /*new CourseOfferingHandler().process();
    if(Trigger.isAfter && Trigger.isInsert){
        
         List<Id> newOfferingIds = new List<Id>();

    for (hed__Course_Offering__c offering : Trigger.new) {
        newOfferingIds.add(offering.Id);
    }

    CourseOfferingHandler.sendCourseOfferings(newOfferingIds);
    }*/

	 new ReleateLettergradeHandler().process();    
    
}