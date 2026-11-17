trigger CourseTrigger on hed__Course__c (after insert) {
    
    /*if(Trigger.isAfter && Trigger.isInsert){
        
        List<Id> courseIds = new List<Id>();
        for (hed__Course__c course : Trigger.new) {
           
            courseIds.add(course.Id);
        }
        if (!courseIds.isEmpty()) {
            CourseCalloutHandler.sendCourses(courseIds);
        }
        
    }*/

}