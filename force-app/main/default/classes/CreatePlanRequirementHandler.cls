public class CreatePlanRequirementHandler {
   public static void inserteachPlanRequirement(List<Course_Version__c> courseVersionList) {
    Set<Id> courseIds = new Set<Id>();
    for (Course_Version__c cv : courseVersionList) {
        courseIds.add(cv.Course__c);
    }
    
    List<hed__Plan_Requirement__c> insertingList = new List<hed__Plan_Requirement__c>();

    for (hed__Plan_Requirement__c eachPlanRequirement : [SELECT hed__Course__c, hed__Course__r.Name,
                                     Id, Name, Pre_Requisites_1__c, Pre_Requisites_2__c, Pre_Requisites_3__c,Offset__c,
                                            Number_of_Sessions__c, Duration__c, hed__Category__c, Term__c, Term__r.Name
                                     FROM hed__Plan_Requirement__c
                                 WHERE hed__Course__c IN :courseIds AND RecordType.Name != 'Unit']) {
        
            hed__Plan_Requirement__c plan = new hed__Plan_Requirement__c();
            plan.RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
            plan.hed__Course__c = eachPlanRequirement.hed__Course__c;
            plan.Term__c = eachPlanRequirement.Term__c; 
            plan.Name = eachPlanRequirement.Term__r.Name + '-' + eachPlanRequirement.hed__Course__r.Name; 
            // Populate additional fields from the queried plan requirement
            plan.Pre_Requisites_1__c = eachPlanRequirement.Pre_Requisites_1__c;
            plan.Pre_Requisites_2__c = eachPlanRequirement.Pre_Requisites_2__c;
            plan.Pre_Requisites_3__c = eachPlanRequirement.Pre_Requisites_3__c;
            plan.Number_of_Sessions__c = eachPlanRequirement.Number_of_Sessions__c;
            plan.Offset__c = eachPlanRequirement.Offset__c;
            plan.Duration__c = eachPlanRequirement.Duration__c;
            plan.hed__Category__c = eachPlanRequirement.hed__Category__c;

            insertingList.add(plan);
        }
    

    // Insert the records only if the list is not empty
    if (!insertingList.isEmpty()) {
        insert insertingList;
    }
}
    public static void deleteeachPlanRequirements(List<Course_Version__c> courseVersionDeletedList){
        set<id> courseVersionIds = new Set<id>();
        for(Course_Version__c courseVersion : courseVersionDeletedList){
           // if(courseVersion.Course_Version_Id__c != null){
                courseVersionIds.add(courseVersion.id);
           // }
        }
        List<hed__Plan_Requirement__c> eachPlanRequirementList = [Select id,CourseVersionId__c from hed__Plan_Requirement__c where CourseVersionId__c =:courseVersionIds];
        List<hed__Plan_Requirement__c> listToDelete = new List<hed__Plan_Requirement__c>();
        for(hed__Plan_Requirement__c planReq :eachPlanRequirementList){
            listToDelete.add(planReq);
        } 
        if(!listToDelete.isEmpty()){
            Delete listToDelete;   
        }
    }
    
    public static void restrictDuplicatesPlanRequirments(List<hed__Plan_Requirement__c> planReqRecords){
        Set<Id> courseIds = new Set<Id>();
        for(hed__Plan_Requirement__c planReqObj:planReqRecords){
            courseIds.add(planReqObj.hed__Course__c);
        }
        
        Map<String,hed__Plan_Requirement__c> mapOfPlanReq = new Map<String,hed__Plan_Requirement__c>();
        for(hed__Plan_Requirement__c planReqObj:[Select Id,Name,hed__Course__c,Term__c,RecordTypeId from hed__Plan_Requirement__c where hed__Course__c IN:courseIds]){
            mapOfPlanReq.put(planReqObj.hed__Course__c+'_'+planReqObj.Term__c+'_'+planReqObj.RecordTypeId,planReqObj);
        }
        

    }
}