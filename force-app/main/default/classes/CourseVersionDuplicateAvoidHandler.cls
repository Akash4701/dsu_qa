public class CourseVersionDuplicateAvoidHandler {
    public static void avoidingDuplicateCourseVersoins(list<Course_Version__c>newlist){

        List<Course_Version__c> courseVersions = [Select id,Term__c,Term__r.Program_Plan__c,Term__r.Term_Reference__c,Course__c,Campus__c from Course_Version__c where Id=:newlist];
        Map<Id, Id> termByprogramPlan = new Map<Id, Id>();
        Map<Id,String> termByTermRef = new Map<Id,String>();
        Set<Id> termIds = new Set<Id>();
        
        for(Course_Version__c courseVersion : newlist){
            termIds.add(courseVersion.Term__c);
        }
        
        for(hed__Term__c termObj:[Select Id,Program_Plan__c,Term_Reference__c from hed__Term__c where Id IN:termIds]){
            termByTermRef.put(termObj.Id,termObj.Term_Reference__c);
            termByprogramPlan.put(termObj.Id,termObj.Program_Plan__c);
        }
        
        List<Course_Version__c>oldCourseVersionList = [Select id,Term__c,Term__r.Program_Plan__c,Term__r.Term_Reference__c,Course__c,Course__r.Name,Campus__c from Course_Version__c where Term__r.Program_Plan__c IN:termByprogramPlan.values()];
        Map<String,Course_Version__c> oldCVMap = new Map<String,Course_Version__c>();
        Map<String,Course_Version__c> termRefByCampus = new Map<String,Course_Version__c>();
        Map<String,String> courseByTerm = new Map<String,String>();
        for(Course_Version__c oldList :oldCourseVersionList){
            courseByTerm.put(oldList.Course__c,oldList.Term__r.Term_Reference__c+'-'+oldList.Campus__c);
            termRefByCampus.put(oldList.Term__r.Term_Reference__c+' + '+ oldList.Campus__c+' + '+oldList.Course__c,oldList);
            oldCVMap.put(oldList.Term__r.Program_Plan__c+' + '+oldList.Course__c/*+' + '+ oldList.Campus__c*/,oldList);
        }
        List<String> newCourseVersions = new List<String>();
        for(Course_Version__c courseVersion : newlist){
            Boolean verifyingCourseVersion= oldCVMap.Keyset().Contains(termByprogramPlan.get(courseVersion.Term__c)+' + '+courseVersion.Course__c/*+' + '+ courseVersion.Campus__c*/);
            Boolean verify = termRefByCampus.Keyset().Contains(termByTermRef.get(courseVersion.Term__c)+' + '+courseVersion.Campus__c+' + '+courseVersion.Course__c);
            if(courseByTerm.keyset().Contains(courseVersion.Course__c)){
                List<String> str = courseByTerm.get(courseVersion.Course__c).split('-');
                if(str[0] == termByTermRef.get(courseVersion.Term__c)){
                    verifyingCourseVersion = str[1] != courseVersion.Campus__c? false : true;
                }
            }
            if(verifyingCourseVersion == true ){
                courseVersion.addError('You are Unable to create this record because, with the Same Details already Record Existed..');
            }
        }  
        
    }
       
}