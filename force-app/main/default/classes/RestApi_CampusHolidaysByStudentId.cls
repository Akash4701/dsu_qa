@RestResource(urlMapping = '/campusHolidays/*')
Global class RestApi_CampusHolidaysByStudentId {
    @HttpGet
    //EndPoint:       /services/apexrest/campusHolidays/?campusId=a211y000000oP1gAAE
    Global static void doGet(){
        String studentId=RestContext.request.params.get('studentId');
        String campusId=RestContext.request.params.get('campusId');
        system.debug(campusId);
        String commonHoliday=RestContext.request.params.get('commonHoliday');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String query;
		boolean check=true;
        /*if(String.isBlank(campusId) || campusId=='null'){
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Invalid campusId"}' );
            res.statusCode=400;
            return;
        }*/
        List<hed__Program_Enrollment__c> studentEnrollementList=new List<hed__Program_Enrollment__c>();
        List<K42_Holiday__c> generalHolidayList=new List<K42_Holiday__c>([SELECT Id,Name,K42_Holiday_Type__c,K42_Hol_End_Date__c,K42_Hol_Start_Date__c FROM K42_Holiday__c WHERE Common_Holiday__c='Yes']);
       	if(!String.isBlank(studentId) ){
            studentEnrollementList =   [SELECT Campus__c, Term__c, hed__Contact__c, Name, Id FROM hed__Program_Enrollment__c where hed__Contact__c =:studentId];
            check=false;
              
        }
        query='SELECT K42_Holiday__c,K42_Holiday__r.Name,K42_Holiday__r.K42_Holiday_Type__c,K42_Holiday__r.K42_Hol_Start_Date__c,K42_Holiday__r.K42_Hol_End_Date__c,Campus_Name__c, Campus_Name__r.name,Campus__c, Campus__r.name, Id, Name FROM K42_Campus_Holiday__c ';
        if(!String.isBlank(campusId) ){
             query+=' WHERE Campus__c=\''+campusId+'\'' ;
        }
         system.debug('query====>'+query);
        if(!String.isBlank(studentId)  && !studentEnrollementList.isEmpty() && !String.isBlank(studentEnrollementList[0].Campus__c)){
            query+=' WHERE Campus__r.Name=\''+studentEnrollementList[0].Campus__c+'\'' ;
            system.debug('query====>'+query);
            check=true;
        }
        system.debug('@@@query'+query);
        List<responseHolidayDataWrapper> campusHolidayList=new List<responseHolidayDataWrapper>();
        List<String> campusGeneralHolidayList=new List<String>();
        if(check==true && commonHoliday==null)
        {
            for(K42_Campus_Holiday__c campusHoliday:Database.query(query))
            {
               
                responseHolidayDataWrapper holidayWrap=new responseHolidayDataWrapper();
                holidayWrap.campusHolidayId=campusHoliday.Id;
                holidayWrap.holidayId=campusHoliday.K42_Holiday__c;
                holidayWrap.holidayName=campusHoliday.K42_Holiday__r.Name;
                holidayWrap.holidayType=campusHoliday.K42_Holiday__r.K42_Holiday_Type__c;
                if(campusHoliday.K42_Holiday__r.K42_Hol_Start_Date__c!=null)
                {
                    holidayWrap.startDate=String.ValueOf(campusHoliday.K42_Holiday__r.K42_Hol_Start_Date__c);
                }
                if(campusHoliday.K42_Holiday__r.K42_Hol_End_Date__c!=null)
                {
                    holidayWrap.endDate=String.ValueOf(campusHoliday.K42_Holiday__r.K42_Hol_End_Date__c);
                }
                holidayWrap.campusName=campusHoliday.Campus__r.Name;
                holidayWrap.campusId=campusHoliday.Campus__c;
                holidayWrap.programId=campusHoliday.Campus_Name__c;
                holidayWrap.programName=campusHoliday.Campus_Name__r.Name;
                campusGeneralHolidayList.add(campusHoliday.K42_Holiday__c);
                campusHolidayList.add(holidayWrap);
                system.debug('@@@campusHolidayList'+campusHolidayList);
            }
            /*if(!generalHolidayList.isEmpty())
            {
                campusHolidayList=getGeneralHoliday(generalHolidayList,campusGeneralHolidayList,campusHolidayList);
            }*/
            
        }/*else if (commonHoliday=='Yes' && !generalHolidayList.isEmpty())
        {
            campusHolidayList=getGeneralHoliday(generalHolidayList,null,null);
        }*/else{
            
            system.debug('65');
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "No Data Found"}' );
        }
        if(!campusHolidayList.isEmpty()){
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('{ "success": "true" , "data": '+JSON.serialize(campusHolidayList)+'}');
        }else{

            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "No Data Found"}' );
        }
    }
    public class responseHolidayDataWrapper {
        public string holidayId {get;set;}
        public string holidayName {get;set;}
        public string holidayType {get;set;}
        public string startDate {get;set;}
        public string endDate {get;set;}
        public string campusName {get;set;}
        public string campusId {get;set;}
        public string programId {get;set;}
        public string programName {get;set;}
        public string campusHolidayId {get;set;}
    }
    public static List<responseHolidayDataWrapper> getGeneralHoliday(List<K42_Holiday__c> generalHolidayList,List<String> campusGeneralHolidayList,List<responseHolidayDataWrapper> campusHolidayList) {
        List<responseHolidayDataWrapper> campusHolidayListVal=new List<responseHolidayDataWrapper>();
        if(campusHolidayList<> null)
        {
            campusHolidayListVal.addAll(campusHolidayList);
        }
        
        for(K42_Holiday__c generalHoliday:generalHolidayList)
        {
            boolean check=true;
            system.debug('@@@generalHoliday'+generalHoliday.Name);
          
            if(campusGeneralHolidayList<> null)
            {
              
                if(campusGeneralHolidayList.contains(generalHoliday.Id))
                {
                    check=false;
                   
                }
            }
            system.debug('@@@check'+check);
            if(check==true)
            {
                responseHolidayDataWrapper holidayWrap=new responseHolidayDataWrapper();
                holidayWrap.holidayId=generalHoliday.Id;
                holidayWrap.holidayName=generalHoliday.Name;
                holidayWrap.holidayType=generalHoliday.K42_Holiday_Type__c;
                if(generalHoliday.K42_Hol_Start_Date__c!=null)
                {
                    holidayWrap.startDate=String.ValueOf(generalHoliday.K42_Hol_Start_Date__c);
                }
                if(generalHoliday.K42_Hol_End_Date__c!=null)
                {
                    holidayWrap.endDate=String.ValueOf(generalHoliday.K42_Hol_End_Date__c);
                }
                campusHolidayListVal.add(holidayWrap);
            }
        }
     
        return campusHolidayListVal;
    }
}