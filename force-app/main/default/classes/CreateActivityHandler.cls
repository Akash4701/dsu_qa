public class CreateActivityHandler {
    public static void createActivity(List<Course_Version__c> records){
        List<Course_Version__c> couVersionRecordsList = [Select Id,Term__c,Term__r.Id,Start_Date__c,End_Date__c from Course_Version__c where Id IN: records];
        Set<Id> termIds = new Set<Id>();
        for(Course_Version__c couVer:couVersionRecordsList){
            termIds.add(couVer.Term__r.Id);
        }
        system.debug('Hello');
        List<K42_Academic_Planner__c> academicPlannerList = [Select Id,Term__r.Id from K42_Academic_Planner__c where Term__c IN: termIds];
        Map<Id,K42_Academic_Planner__c> mapOfAcademicPlannerAndTerm = new Map<Id,K42_Academic_Planner__c>();
        for(K42_Academic_Planner__c acaPlan:academicPlannerList){
            mapOfAcademicPlannerAndTerm.put(acaPlan.Term__r.Id,acaPlan);
        }
        List<Activity__c> activitiesList = new List<Activity__c>();
        for(Course_Version__c couVerObj:couVersionRecordsList){
            Activity__c actObj = new Activity__c();
            actObj.Subject__c = couVerObj.Id;
            actObj.Activity_type__c = 'Teaching';
            actObj.Start_date__c = couVerObj.Start_Date__c;
            actObj.End_date__c = couVerObj.End_Date__c;
            //actObj.Academic_Planner__c = mapOfAcademicPlannerAndTerm.containsKey(couVerObj.Term__r.Id)?mapOfAcademicPlannerAndTerm.get(couVerObj.Term__r.Id).Id:null;
            activitiesList.add(actObj);
        }
        
        if(!activitiesList.isEmpty()){
            insert activitiesList;
        }
    }
}