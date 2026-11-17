@RestResource(urlMapping='/MasterSubjects/*')
global class RestApi_CreateMasterSubjects {
    public static Map<String,hed__Plan_Requirement__c> mapOfTermAndMasterGroup = new Map<String,hed__Plan_Requirement__c>();
    public static Map<String,hed__Term__c> mapOfmasterTerm = new Map<String,hed__Term__c>();
    @HttpPost
    global static void create(){
        RestResponse res = RestContext.response;
        try{
            Id specId;
            List<requestWrapper> requestList = (List<requestWrapper>) Json.deserialize(RestContext.request.requestBody.toString(), List<requestWrapper>.class);
           
            List<Id> accountList = new List<Id>();
            Set<Id> courseIds = new Set<Id>();
            for(requestWrapper reqObj:requestList){
                accountList.add(reqObj.departmentId);
                courseIds.add(reqObj.courseId);
            }
            Map<Id,K42_Program_Alias__c> mapOfPrgAlias = new Map<Id,K42_Program_Alias__c>();
            for(K42_Program_Alias__c prgAlias:[Select Id,Name,Program__c from K42_Program_Alias__c where Program__c=:accountList]){
                mapOfPrgAlias.put(prgAlias.Program__c, prgAlias);
            }
            Map<Id,hed__Course__c> mapOfCourses = new Map<Id,hed__Course__c>([Select Id,Name,hed__Course_ID__c	from hed__Course__c where Id IN: courseIds]);
            Map<Id,Activity__c> mapOfCourseAndActivity = new Map<Id,Activity__c>();
            for(Activity__c activityObj:[Select Id,Name,Activity_type__c,Activity_Duration__c,Course__c from Activity__c where Course__c IN: courseIds and RecordType.Name='Master Record']){
                mapOfCourseAndActivity.put(activityObj.Course__c,activityObj);
            }
            
            for(hed__Term__c termObj:[Select Id,Term_Reference__c,hed__Account__c from hed__Term__c where hed__Account__c=:accountList and RecordType.Name='Master Record']){
                mapOfmasterTerm.put(termObj.hed__Account__c+'_'+termObj.Term_Reference__c,termObj);
            }
            Map<String,hed__Plan_Requirement__c> mapOfPlanRequirments = new Map<String,hed__Plan_Requirement__c>();
            for(requestWrapper reqObj:requestList){
                if(!mapOfmasterTerm.containsKey(reqObj.departmentId+'_'+reqObj.termNumber))
                    CreateTerm(reqObj.departmentId,reqObj.termNumber);
                //? mapOfmasterTerm.get(reqObj.departmentId+'_'+reqObj.termNumber).Id:;
                
            }
            
            for(hed__Term__c termObj:[Select Id,Term_Reference__c,hed__Account__c,(Select id,name, Institute__r.Name,RecordType.Name, hed__Plan_Requirement__r.Name,Term__c FROM Plan_Requirements__r WHERE RecordType.Name = 'Master Group') from hed__Term__c where hed__Account__c=:accountList and RecordType.Name='Master Record']){
                mapOfmasterTerm.put(termObj.hed__Account__c+'_'+termObj.Term_Reference__c,termObj);
                for(hed__Plan_Requirement__c masterPlanReq:termObj.Plan_Requirements__r){
                    mapOfTermAndMasterGroup.put(masterPlanReq.Institute__c+'_'+masterPlanReq.Term__c,masterPlanReq);
                }
            }
            List<Activity__c> activityList = new List<Activity__c>();
            List<hed__Plan_Requirement__c> planReqList = new List<hed__Plan_Requirement__c>();
            for(requestWrapper reqObj:requestList){
                hed__Plan_Requirement__c planReqObj = new hed__Plan_Requirement__c();
                if(String.isNotBlank(reqObj.masterPlanReqId)){
                    planReqObj.Id = reqObj.masterPlanReqId;
                }
                planReqObj.Name = mapOfPrgAlias.get(reqObj.departmentId).Name+'-'+reqObj.termNumber+'-'+mapOfCourses.get(reqObj.courseId).hed__Course_ID__c;
                planReqObj.hed__Course__c = reqObj.courseId;
                planReqObj.Term__c = mapOfmasterTerm.get(reqObj.departmentId+'_'+reqObj.termNumber).Id;
                if(String.isNotBlank(reqObj.specializationId) && reqObj.specializationId!=null){
                    specId=reqObj.specializationId;
                    planReqObj.Institute__c = reqObj.specializationId;
                }else{
                    List<Account> acc = [Select Id,Name,Parent.Id,RecordType.Name from Account where Parent.Id=:reqObj.departmentId and RecordType.Name='Program Specialization' limit 1];
                    if(acc.isEmpty()){
                        Account accountSpec = new Account();
                        accountSpec.Name = mapOfPrgAlias.get(reqObj.departmentId).Name+' -Core';
                        accountSpec.ParentId = reqObj.departmentId;
                        accountSpec.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Program Specialization').getRecordTypeId();
                        insert accountSpec;
                        specId=accountSpec.Id;
                    }else{
                        specId=acc[0].Id;
                    } 
                }
                planReqObj.hed__Category__c = reqObj.category;
                //if(String.isNotBlank(reqObj.preRequisitesCourseId1))
                    planReqObj.Pre_Requisites_1__c = reqObj.preRequisitesCourseId1;
                //if(String.isNotBlank(reqObj.preRequisitesCourseId2))
                    planReqObj.Pre_Requisites_2__c = reqObj.preRequisitesCourseId2;
                //if(String.isNotBlank(reqObj.preRequisitesCourseId3))
                    planReqObj.Pre_Requisites_3__c = reqObj.preRequisitesCourseId3;
                //if(String.isNotBlank(reqObj.preRequisitesCourseId4))
                    planReqObj.Co_Requisites_1__c = reqObj.preRequisitesCourseId4;
                //if(String.isNotBlank(reqObj.preRequisitesCourseId5))
                    planReqObj.Co_Requisites_2__c = reqObj.preRequisitesCourseId5;
                //if(String.isNotBlank(reqObj.preRequisitesCourseId6))
                    planReqObj.Co_Requisites_3__c = reqObj.preRequisitesCourseId6;
                planReqObj.Offset__c = Decimal.valueOf(reqObj.offset);
                planReqObj.Number_of_Sessions__c=reqObj.numberOfSessions;
                planReqObj.RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Master Unit').getRecordTypeId();
                if(String.isBlank(reqObj.masterPlanReqId)){
                    planReqObj.hed__Plan_Requirement__c = mapOfTermAndMasterGroup.containsKey(specId+'_'+mapOfmasterTerm.get(reqObj.departmentId+'_'+reqObj.termNumber).Id)?mapOfTermAndMasterGroup.get(specId+'_'+mapOfmasterTerm.get(reqObj.departmentId+'_'+reqObj.termNumber).Id).Id:CreateMasterGroupPlanReq(specId,mapOfmasterTerm.get(reqObj.departmentId+'_'+reqObj.termNumber).Id,reqObj.termNumber);
                }
                if(String.isNotBlank(reqObj.duration)){
                    Activity__c act = new Activity__c();

                    act.Id = mapOfCourseAndActivity.containsKey(reqObj.courseId)?mapOfCourseAndActivity.get(reqObj.courseId).Id:null;
                    act.Name = 'Teaching';
                    act.Activity_type__c = 'Teaching';
                    act.Course__c = reqObj.courseId;
                    act.Offset__c = 0;
                    act.Activity_Duration__c = Decimal.valueOf(reqObj.duration);
                    act.RecordTypeId = Schema.SObjectType.Activity__c.getRecordTypeInfosByName().get('Master Record').getRecordTypeId();
                    activityList.add(act);
                }
                planReqList.add(planReqObj);
            }
            if(!activityList.isEmpty()){
                upsert activityList;
            }
            if(!planReqList.isEmpty()){
                upsert planReqList;
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('{"success":"true","message":"Data Inserted"}');
            }
        }Catch(Exception e){
            if(e.getMessage() == 'Upsert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, You are creating a duplicate record: []'){
                res.statusCode = 409;
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Duplicate records found..." }' );
            }else{
                res.statusCode = 400;
                system.debug(e.getMessage()+'at Line Number'+e.getLineNumber());
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
            }
        }
    }
    
    global class requestWrapper{
        public Id departmentId{get;set;}
        public Id courseId{get;set;}
        public String termNumber{get;set;}
        public Id specializationId{get;set;}
        public String category{get;set;}
        public Id preRequisitesCourseId1{get;set;}
        public Id preRequisitesCourseId2{get;set;}
        public Id preRequisitesCourseId3{get;set;}
        public Id preRequisitesCourseId4{get;set;}
        public Id preRequisitesCourseId5{get;set;}
        public Id preRequisitesCourseId6{get;set;}
        public Decimal numberOfSessions{get;set;}
        public String offset{get;set;}
        public String duration{get;set;}
        public Id masterPlanReqId{get;set;}
    }
    
    public static void CreateTerm(Id accountId,String termNumber){
        K42_Program_Alias__c[] prgAlias = [Select Id,Name,Program__c from K42_Program_Alias__c where Program__c=:accountId];
        hed__Term__c termObj = new hed__Term__c();
        termObj.hed__Account__c = accountId;
        termObj.Term_Reference__c = termNumber;
        termObj.Name = prgAlias[0].Name+' '+termNumber+' '+'Master';
        termObj.RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Master Record').getRecordTypeId();
        insert termObj;
        mapOfmasterTerm.put(termObj.hed__Account__c+'_'+termObj.Term_Reference__c,termObj);
    }
    public static Id CreateMasterGroupPlanReq(Id specializationId, Id termId, String termNumber){
        Account acc = [Select Id,Name from Account where Id=:specializationId limit 1];
        hed__Plan_Requirement__c planReqObj = new hed__Plan_Requirement__c();
        planReqObj.Name = acc.Name+'-'+termNumber;
        planReqObj.Institute__c = specializationId;
        planReqObj.Term__c = termId;
        planReqObj.RecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByName().get('Master Group').getRecordTypeId();
        insert planReqObj;
        mapOfTermAndMasterGroup.put(planReqObj.Institute__c+'_'+planReqObj.Term__c,planReqObj);
        return planReqObj.Id;
    }
    
    @HttpDelete
    global static void doDelete(){
        RestResponse res = RestContext.response;
        string recordId = RestContext.request.params.get('recordId');
        try{
            if(String.isNotBlank(recordId)){
                List<hed__Plan_Requirement__c> planReq = [Select Id,hed__Course__c from hed__Plan_Requirement__c where Id=:recordId];
                List<Activity__c> activity = [Select Id,Course__c from Activity__c where Course__c=:planReq[0].hed__Course__c and Activity_type__c='Teaching' and RecordType.Name='Master Record' limit 1];
                if(!activity.isEmpty()){
                    delete activity;
                }
                if(!planReq.isEmpty()){
                    delete planReq;
                    res.statusCode = 202;
                    res.responseBody = Blob.valueof('{"Success": true ,"message":"Record Deleted Successfully.."}');
                }else{
                    res.responseBody = Blob.valueof('{"success": false ,"message":"No data found"}');
                }
            }else{
                res.responseBody = Blob.valueof('{"success": false ,"message":"Invalid Parameter"}');
            }
        }catch(exception ex){
            res.responseBody = Blob.valueof('{"success": false ,"error":"'+ex.getMessage()+' at line number ' +ex.getLineNumber()+ '"}');    
        }
    }
}