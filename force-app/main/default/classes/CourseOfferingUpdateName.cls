public class CourseOfferingUpdateName {
    public CourseOfferingUpdateName(){
        List<hed__Course_Offering__c> listOfCourseOffering = new List<hed__Course_Offering__c>();
        for(hed__Course_Offering__c courseOffering: [SELECT Id, Name,hed__Course__r.Name, hed__Term__r.Name FROM hed__Course_Offering__c LIMIT 1]){  
            if(courseOffering.hed__Term__r.Name.contains('2022')){
                hed__Course_Offering__c courseOff = new hed__Course_Offering__c();
                courseOff.Id = courseOffering.Id;
                courseOff.Name =  courseOffering.hed__Term__r.Name.split('-')[0]+'-'+courseOffering.hed__Course__r.Name.split('-')[0]+'-'+courseOffering.hed__Term__r.Name;  
                listOfCourseOffering.add(courseOff);
            }
        }
        if(listOfCourseOffering.size()>0){
            update listOfCourseOffering;
        }
    }
}