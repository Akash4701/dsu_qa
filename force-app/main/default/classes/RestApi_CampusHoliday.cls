@RestResource(urlMapping = '/CampusHolidayFetching/*')
Global class RestApi_CampusHoliday {
    @HttpGet
    Global static void fetchingCampusHoliday(){
        
        String campus=RestContext.request.params.get('campus');
        String programPlanId=RestContext.request.params.get('programPlanId');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        system.debug('entered campus==>'+campus);
        if(!string.isBlank(campus) ){
            hed__Term__c[] term = [Select Id,Name,hed__Start_Date__c,hed__End_Date__c from hed__Term__c where Program_Plan__c=: programPlanId order by Name ASC];
            Date startDate=term[0].hed__Start_Date__c;
            Date endDate=term[term.size()-1].hed__End_Date__c!=null?term[term.size()-1].hed__End_Date__c:term[0].hed__End_Date__c;
            system.debug(startDate);
            system.debug(endDate);
            list<K42_Campus_Holiday__c>listofHolidays=new list<K42_Campus_Holiday__c>();
            if(startDate!=null && endDate!=null){
                listofHolidays =[SELECT K42_Holiday__c,K42_Holiday__r.Name,Campus_Name__c, Campus_Name__r.name,Campus__c, Campus__r.name, Id, Name, K42_Holiday__r.K42_Hol_Start_Date__c, K42_Holiday__r.K42_Hol_End_Date__c FROM K42_Campus_Holiday__c where Campus__r.name=: campus and K42_Holiday__r.K42_Hol_Start_Date__c >=:startDate and K42_Holiday__r.K42_Hol_End_Date__c <=:endDate];
            }else{
				listofHolidays =[SELECT K42_Holiday__c,K42_Holiday__r.Name,Campus_Name__c, Campus_Name__r.name,Campus__c, Campus__r.name, Id, Name, K42_Holiday__r.K42_Hol_Start_Date__c, K42_Holiday__r.K42_Hol_End_Date__c FROM K42_Campus_Holiday__c where Campus__r.name=: campus];
            }
            
            system.debug(listofHolidays);
            if(!listofHolidays.isEmpty()){
                List<responseHolidayDataWrapper> holidayList=new List<responseHolidayDataWrapper>();
                res.statusCode = 200;
                system.debug('entered campus==>'+campus);
                // string allstring = string.join(listofHolidays ,',');
                Map<Integer,List<responseHolidayDataWrapper>> mapOfholidayList = new Map<Integer,List<responseHolidayDataWrapper>>();
                for(K42_Campus_Holiday__c holiday:listofHolidays)
                {
                    
                    responseHolidayDataWrapper holidayWrap=new responseHolidayDataWrapper();
                    holidayWrap.campusHolidayId=holiday.Id;
                    holidayWrap.holidayId=holiday.K42_Holiday__c;
                    holidayWrap.holidayName=holiday.K42_Holiday__r.Name;
                    holidayWrap.campusName=holiday.Campus__r.Name;
                    holidayWrap.campusId=holiday.Campus__c;
                    holidayWrap.programId=holiday.Campus_Name__c;
                    holidayWrap.programName=holiday.Campus_Name__r.Name;
                    holidayWrap.startDate=holiday.K42_Holiday__r.K42_Hol_Start_Date__c;
                    holidayWrap.endDate=holiday.K42_Holiday__r.K42_Hol_End_Date__c;
                    if(mapOfholidayList.containsKey(holiday.K42_Holiday__r.K42_Hol_Start_Date__c.year())){
                        List<responseHolidayDataWrapper> wrapList = mapOfholidayList.get(holiday.K42_Holiday__r.K42_Hol_Start_Date__c.year());
                        wrapList.add(holidayWrap);
                        mapOfholidayList.put(holiday.K42_Holiday__r.K42_Hol_Start_Date__c.year(),wrapList);
                    }else{
                        mapOfholidayList.put(holiday.K42_Holiday__r.K42_Hol_Start_Date__c.year(),new List<responseHolidayDataWrapper> { holidayWrap });
                    }
                    //holidayList.add(holidayWrap);
                    
                }
                //  res.statusCode = 200;
                res.responseBody = Blob.valueOf(JSON.serialize(mapOfholidayList));
            }else{
                res.statusCode = 200;
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "No Data Found"}' );
            }
        }else{
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request"}' );
        }
    }
    public class responseHolidayDataWrapper {
        public string holidayId {get;set;}
        public string holidayName {get;set;}
        public string campusName {get;set;}
        public string campusId {get;set;}
        public string programId {get;set;}
        public string programName {get;set;}
        public string campusHolidayId {get;set;}
        public Date startDate {get;set;}
        public Date endDate {get;set;}
    }
    @HttpDelete
    global static void doDelete(){
        RestResponse res = RestContext.response;
        try{
            String campusHolidayId = RestContext.request.params.get('campusHolidayId');  
            if(!string.isEmpty(campusHolidayId)){
                List<K42_Campus_Holiday__c> campusHolidayList = [SELECT Id FROM K42_Campus_Holiday__c where id =:campusHolidayId];
                
                if(!campusHolidayList.isEmpty()){
                    Delete campusHolidayList;
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf('{"success":"true","message":" records deleted successfully..."}'); 
                }else{ 
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf('{"success":"false","message":"no records found..."}'); 
                } 
            }else{
                res.statusCode = 200;
                res.responseBody = Blob.valueOf('{"success":"false","message":"please provide Id..."}');  
            }
        }catch(exception e){
            res.responseBody = Blob.valueOf('{"success":"false","message":'+e.getMessage()+' at line number ' +e.getLineNumber()+'}');   
        }
    }
    @HttpPost
    global static void doPost(){
        RestResponse res = RestContext.response;
        try{
            List<wrapperData> request = (List<wrapperData>) JSON.deserialize(RestContext.request.requestBody.toString(),List<wrapperData>.class);
            Set<id>campusIds = new Set<id>();
            for(wrapperData wrap : request){
                if(!string.isEmpty(wrap.campusHolidayId)){
                    campusIds.add(wrap.campusHolidayId);
                }
            }
            Map<id,K42_Campus_Holiday__c> originalCampusList = new Map<id,K42_Campus_Holiday__c>([SELECT Id, Name, K42_Holiday__c,K42_Holiday__r.Name,K42_Holiday__r.K42_Hol_Start_Date__c,K42_Holiday__r.K42_Hol_End_Date__c, Campus_Name__c, Campus__c FROM K42_Campus_Holiday__c where id =:campusIds]);
            List<K42_Campus_Holiday__c>campusHolidayListforInsert= new List<K42_Campus_Holiday__c>();
            if(!request.isEmpty()){
                Map<string,K42_Holiday__c> generalHolidaymap = new Map<string,K42_Holiday__c>();
                List<K42_Holiday__c> generalHolidaysUpdateList = new List<K42_Holiday__c>();
                for(wrapperData wrapper : request){
                    if(string.isEmpty(wrapper.campusHolidayId)){
                        K42_Holiday__c generalHoliday = new K42_Holiday__c();
                        
                        generalHoliday.K42_Hol_Start_Date__c = wrapper.startDate; 
                        generalHoliday.K42_Hol_End_Date__c = wrapper.endDate;
                        generalHoliday.Name = wrapper.holidayName;
                        
                        generalHolidaymap.put(generalHoliday.Name +'-'+generalHoliday.K42_Hol_Start_Date__c +'-'+ generalHoliday.K42_Hol_End_Date__c,generalHoliday);
                    }else{
                        K42_Campus_Holiday__c camp= originalCampusList.get(wrapper.campusHolidayId);
                        K42_Holiday__c generalHolidayExisting = new K42_Holiday__c();
                        generalHolidayExisting.id = camp.K42_Holiday__c;
                        
                        generalHolidayExisting.K42_Hol_Start_Date__c = wrapper.startDate; 
                        generalHolidayExisting.K42_Hol_End_Date__c = wrapper.endDate;
                        generalHolidayExisting.Name = wrapper.holidayName;
                        generalHolidaysUpdateList.add(generalHolidayExisting);
                    }   
                }
                if(!generalHolidaysUpdateList.isEmpty()){
                    update generalHolidaysUpdateList;
                    res.statusCode = 200;
                    res.responseBody = blob.valueof('{"success":"true","message":"updated successfully.."}');
                }
                if(!generalHolidaymap.isEmpty()){
                    insert generalHolidaymap.values();   
                }
                system.debug(generalHolidaymap);
                for(wrapperData requestedwrapper : request){
                    system.debug('enterd string =>'+requestedwrapper.holidayName +'-'+requestedwrapper.startDate +'-'+ requestedwrapper.endDate);
                    string requestString = requestedwrapper.holidayName +'-'+requestedwrapper.startDate +'-'+ requestedwrapper.endDate;
                    K42_Campus_Holiday__c campusHolidaynewRecords = new K42_Campus_Holiday__c();
                    system.debug('general holiday Id===>'+generalHolidaymap.get(requestString).Id);
                    campusHolidaynewRecords.K42_Holiday__c  = generalHolidaymap.get(requestString).Id;
                    campusHolidaynewRecords.Campus__c  = requestedwrapper.campusId;
                    campusHolidayListforInsert.add(campusHolidaynewRecords);
                }
            }
            if(!campusHolidayListforInsert.isEmpty()){
                insert campusHolidayListforInsert;
                res.statusCode = 200;
                res.responseBody = blob.valueof('{"success":"true","message":"inserted successfully.."}');
            }
        }catch(exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"success":"false","message":'+e.getMessage()+' at line number ' +e.getLineNumber()+'}');
        }
    }
    
    global class wrapperData{
        global date startDate;
        global date endDate;
        global string campusHolidayId;
        global string holidayName;
        global string campusId;
    }
}