public class courseOfferingInsertUpdate extends TriggerHandler {
    
    public override void processAfterInsert() {
		creatingcourseoffering();
	}

	public override void processAfterUpdate() {
        updateingCourseoffering();
        
			}
    public static Map<String,hed__Plan_Requirement__c> mapOfTermAndGroup = new Map<String,hed__Plan_Requirement__c>();
    public static void creatingcourseoffering(){
        List<Course_Version__c> courseVersion = [select 
                                                 id,
                                                 course__c,
                                                 course__r.Id,
                                                 Course__r.Name,
                                                 Course__r.hed__Course_ID__c,
                                                 Term__c, 
                                                 Term__r.Name,Credit_hours__c,Subject_Offset__c,Number_of_Sessions__c,
                                                 Term__r.Id,
                                                 Term__r.hed__Parent_Term__c,
                                                 Start_Date__c,
                                                 End_Date__c,Subject_Start_Date__c,Subject_End_Date__c,
                                                 Program_Plan__c from Course_Version__c where id IN: trigger.new];

        
        List<hed__Plan_Requirement__c> groupPlanReqinsertingList = new List<hed__Plan_Requirement__c>();
        Map<String,hed__Plan_Requirement__c> mapOfCourseAndPlanReq = new Map<String,hed__Plan_Requirement__c>();
        for(hed__Plan_Requirement__c masterPlanReqObj:[Select Id,Name,hed__Category__c,Offset__c ,Duration__c ,Number_of_Sessions__c, hed__Course__c,Institute__c,Institute__r.Name,hed__Plan_Requirement__r.Term__c,Pre_Requisites_1__c,Pre_Requisites_2__c,Pre_Requisites_3__c,Co_Requisites_1__c,Co_Requisites_2__c,Co_Requisites_3__c from hed__Plan_Requirement__c where RecordType.Name='Master Unit' and hed__Course__c IN(select course__c from Course_Version__c where Id IN: trigger.new)]){
            mapOfCourseAndPlanReq.put(masterPlanReqObj.hed__Course__c/*+'-'+masterPlanReqObj.hed__Plan_Requirement__r.Term__c*/,masterPlanReqObj);
        }
        system.debug('mapOfCourseAndPlanReq'+mapOfCourseAndPlanReq);
        Set<String> setOfInstituteAndTerm = new Set<String>();
     
        if(!groupPlanReqinsertingList.isEmpty()){
            insert groupPlanReqinsertingList;
        }
        
        for(hed__Term__c termObj:[Select Id,Term_Reference__c,hed__Account__c,(Select id,name, Institute__r.Name,RecordType.Name, hed__Plan_Requirement__r.Name,Term__c FROM Plan_Requirements__r WHERE RecordType.Name = 'Group') from hed__Term__c where Id IN(select Term__c from Course_Version__c where Id IN: trigger.new)]){
            for(hed__Plan_Requirement__c planReq:termObj.Plan_Requirements__r){
                mapOfTermAndGroup.put(planReq.Institute__c+'_'+planReq.Term__c,planReq);
            }
        }
        system.debug(mapOfTermAndGroup);
        
        List<hed__Plan_Requirement__c> planReqinsertingList = new List<hed__Plan_Requirement__c>();
        List<Activity__c> activitiesList = new List<Activity__c>();
        list<hed__Course_Offering__c> courseOfferinginsertinglist=new list<hed__Course_Offering__c>();
        for(Course_Version__c cou :courseVersion){
            if(cou.Course__c != null && cou.Term__c!= null){
                hed__Course_Offering__c couOff=new hed__Course_Offering__c();
                String delimiter = '-';
                String input = cou.Course__r.Name;
                couOff.hed__Course__c = cou.Course__c;
                couOff.hed__Term__c = cou.Term__c;
                couOff.Name = cou.Term__r.Name +'-'+ input.substringBefore(delimiter)+'-'+'A';
                couOff.hed__Section_ID__c='A';
                //couOff.hed__Capacity__c = 100;
                couOff.Course_Version__c = cou.id;
                system.debug('cou.Subject_End_Date__c-->'+cou.Subject_End_Date__c);
                system.debug('cou.Subject_Start_Date__c-->'+cou.Subject_Start_Date__c);
                couOff.hed__End_Date__c  = cou.End_Date__c;
                couOff.hed__Start_Date__c = cou.Start_Date__c;
                if(mapOfCourseAndPlanReq.containsKey(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/)){
                    couOff.Course_Specialisation__c = mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Institute__c!=null? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Institute__c:null;
                }
                
                courseOfferinginsertinglist.add(couOff);
				                
                hed__Plan_Requirement__c plan = new hed__Plan_Requirement__c();
                plan.RecordTypeId =  Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Unit').getRecordTypeId();
                plan.hed__Course__c = cou.Course__c;
                plan.Term__c = cou.Term__r.Id;
                plan.hed__Program_Plan__c = cou.Program_Plan__c;
                plan.Name = cou.Term__r.Name +'-'+cou.Course__r.hed__Course_ID__c;
                plan.CourseVersionId__c = cou.Id;
                //plan.Number_of_Sessions__c  = cou.Number_of_Sessions__c;
                //plan.Offset__c = cou.Subject_Offset__c;
                //plan.Duration__c = cou.Credit_hours__c;
                system.debug(cou.Course__c+'-'+cou.Term__r.hed__Parent_Term__c);
                plan.hed__Category__c = mapOfCourseAndPlanReq.containskey(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/)? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).hed__Category__c:'Mandatory';
               
                if(mapOfCourseAndPlanReq.containsKey(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/)){
                    //plan.hed__Plan_Requirement__c  = mapOfCourseAndPlanReq.get(cou.Course__c).Id;
                    plan.Number_of_Sessions__c  = mapOfCourseAndPlanReq.get(cou.Course__c).Number_of_Sessions__c != null ? mapOfCourseAndPlanReq.get(cou.Course__c).Number_of_Sessions__c : null;
                    plan.Offset__c = mapOfCourseAndPlanReq.get(cou.Course__c).Offset__c != null ? mapOfCourseAndPlanReq.get(cou.Course__c).Offset__c : null;
                    plan.Duration__c = mapOfCourseAndPlanReq.get(cou.Course__c).Duration__c != null ? mapOfCourseAndPlanReq.get(cou.Course__c).Duration__c : null;
                    plan.Institute__c = mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Institute__c!=null? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Institute__c:null;
                    plan.Pre_Requisites_1__c = mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Pre_Requisites_1__c!=null? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Pre_Requisites_1__c:null;
                	plan.Pre_Requisites_2__c = mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Pre_Requisites_2__c!=null? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Pre_Requisites_2__c:null;
                	plan.Pre_Requisites_3__c = mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Pre_Requisites_3__c!=null? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Pre_Requisites_3__c:null;
                	plan.Co_Requisites_1__c = mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Co_Requisites_1__c!=null? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Co_Requisites_1__c:null;
                	plan.Co_Requisites_2__c = mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Co_Requisites_2__c!=null? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Co_Requisites_2__c:null;
                	plan.Co_Requisites_3__c = mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Co_Requisites_3__c!=null? mapOfCourseAndPlanReq.get(cou.Course__c/*+'-'+cou.Term__r.hed__Parent_Term__c*/).Co_Requisites_3__c:null;
                }
             
                planReqinsertingList.add(plan);
            }
        }
        if(courseOfferinginsertinglist.size()>0){
            system.debug('new course offering record'+courseOfferinginsertinglist);
            //insert courseOfferinginsertinglist;
        }
        /*if(!activitiesList.isEmpty()){
            insert activitiesList;
        }*/
       if(!planReqinsertingList.isEmpty()){
           // insert planReqinsertingList;
        } 
    }
    
  /*  public static hed__Plan_Requirement__c CreateGroupPlanReq(Id specializationId, Id termId, String termNumber){
        Account acc = [Select Id,Name from Account where Id=:specializationId limit 1];
        hed__Plan_Requirement__c planReqObj = new hed__Plan_Requirement__c();
        planReqObj.Name = acc.Name+'-'+termNumber;
        planReqObj.Institute__c = specializationId;
        planReqObj.Term__c = termId;
        planReqObj.RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Group').getRecordTypeId();
        insert planReqObj;
        hed__Plan_Requirement__c planReq = [Select Id,Institute__c,Term__c from hed__Plan_Requirement__c where Id=:planReqObj.Id];
        system.debug(planReq);
        mapOfTermAndGroup.put(planReq.Institute__c+'_'+planReq.Term__c,planReq);
        return planReqObj;
    }
    
    /*public static void afterUpdate(List<Course_Version__c> newRecords, Map<Id,Course_Version__c> oldRecords){
        List<Activity__c> activityList = new List<Activity__c>([Select Id,Facility__c from Activity__c where Subject__c IN: newRecords and Activity_type__c='Teaching']);
        List<Activity__c> updateActivitiesList = new List<Activity__c>();
        
        Map<Id,List<Activity__c>> mapOfCVandActivities = new Map<Id,List<Activity__c>>();
        List<Activity__c> activityListforEachCV = new List<Activity__c>();
        for(Activity__c actObj:activityList){
            //facilityNamefromCV.add(actObj.Facility__c);
            if(mapOfCVandActivities.containsKey(actObj.Subject__c)){
                activityListforEachCV = mapOfCVandActivities.get(actObj.Subject__c);
                activityListforEachCV.add(actObj);
                mapOfCVandActivities.put(actObj.Subject__c,activityListforEachCV);
            }else{
                mapOfCVandActivities.put(actObj.Subject__c,new List<Activity__c>{actObj});
            }
        }
        for(Course_Version__c cvObj:newRecords){
            if(cvObj.Facilities__c !=null && oldRecords.get(cvObj.Id).Facilities__c != cvObj.Facilities__c){
                for(Activity__c actObj:mapOfCVandActivities.get(cvObj.Id)){
                    actObj.Facility__c = cvObj.Facilities__c;
                    updateActivitiesList.add(actObj);
                }
            }
        }
        if(!updateActivitiesList.isEmpty()){
            update updateActivitiesList;
        }
    }*/
    
    public static void updateingCourseoffering(){
        
        List<Course_Version__c> courseVersion = [select id,course__c,course__r.Name, term__c, term__r.Name,Subject_End_Date__c,Subject_Start_Date__c,Start_Date__c,
                                                 (SELECT hed__Course__c, hed__Term__c, hed__Capacity__c, hed__End_Date__c, hed__Facility__c, hed__Faculty__c,
                                                  hed__Section_ID__c, hed__Start_Date__c, hed__Time_Block__c, 
                                                   Course_Version__c, Campus__c, Name, Id FROM Course_Offerings__r) 
                                                 from Course_Version__c where id IN:trigger.new];
        
        list<hed__Course_Offering__c>updatingList=new list<hed__Course_Offering__c>();
        for(Course_Version__c cou :courseVersion){
                if(cou.Course_Offerings__r.size()>0){
                    
                    system.debug('cou.Subject_Start_Date__c on update-->'+cou.Start_Date__c);
                    for(hed__Course_Offering__c cof : cou.Course_Offerings__r){
                      	cof.hed__Start_Date__c = cou.Start_Date__c;
                        cof.hed__End_Date__c = cou.Subject_End_Date__c;
                        
                        updatingList.add(cof);
                        
                    }  
                
                
            }
        }
        
        if(updatingList.size()>0){
            system.debug('new course offering record'+updatingList);
            update updatingList;
        }
    }
}