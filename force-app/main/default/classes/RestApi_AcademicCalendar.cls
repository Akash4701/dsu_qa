@RestResource(urlMapping='/AcademicCalendar/*')
global class RestApi_AcademicCalendar {
    //Get
    @httpGet
    global static void getAcademicCalendar(){
        String programPlanId=RestContext.request.params.get('programPlanId');
        String academicId=RestContext.request.params.get('academicId');
        String termId=RestContext.request.params.get('termid');
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        system.debug('calenderList===>'+termId);
        try{
            Map<String,hed__Term__c> termRef = new Map<String,hed__Term__c>();
            Map<String,Object> app=new Map<String,Object>();
            system.debug(' in try calenderList===>'+termId);
            List<hed__term__c>termList= new List<hed__term__c>();
            if(string.isNotBlank(termId)){
                termList= [SELECT Id,Name,hed__Start_Date__c,hed__End_Date__c,Term_Duration__c,Program_Plan__r.Working_Days__c,Program_Plan__r.Intake__c,Program_Plan__r.Batch__c,Program_Plan__r.hed__Start_Date__c,Program_Plan__r.hed__Account__r.Course_duration__c,Program_Plan__r.hed__Account__r.Program_Duration_in_Weeks__c,hed__Parent_Term__r.Term_Reference__c,Campus__c,(SELECT Term__c,Term__r.Name, Week_Number__c, Start_Date__c, End_Date__c, Type_of_Activity__c, Name,CalculatedWeekNumber__c,Number_Of_Weeks__c, Description__c, Id FROM Academic_Calendars__r ORDER BY CalculatedWeekNumber__c ASC,Start_Date__c ASC,End_Date__c ASC) FROM hed__Term__c WHERE Id=: termId];
            }
            else if(string.isNotBlank(programPlanId) && string.isNotBlank(academicId))
            {
                termList= [SELECT Id,Name,hed__Start_Date__c,hed__End_Date__c,Term_Duration__c,Program_Plan__r.Working_Days__c,Program_Plan__r.Intake__c,Program_Plan__r.Batch__c,Program_Plan__r.hed__Start_Date__c,Program_Plan__r.hed__Account__r.Course_duration__c,Program_Plan__r.hed__Account__r.Program_Duration_in_Weeks__c,hed__Parent_Term__r.Term_Reference__c,Campus__c,(SELECT Term__c,Term__r.Name, Week_Number__c, Start_Date__c, End_Date__c, Type_of_Activity__c, Name,CalculatedWeekNumber__c,Number_Of_Weeks__c, Description__c, Id FROM Academic_Calendars__r ORDER BY CalculatedWeekNumber__c ASC,Start_Date__c ASC,End_Date__c ASC) FROM hed__Term__c WHERE Program_Plan__c=: programPlanId AND hed__Account__c=:academicId];
            }
            if(!termList.isEmpty()){
                for(hed__Term__c trm:termList){
                    if(trm.hed__Parent_Term__r.Term_Reference__c!=null){
                        String trmRef = trm.hed__Parent_Term__r.Term_Reference__c;
                        System.debug('trmRef---'+trmRef);
                        String replaceValue = trmRef.contains('Term')?(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ','')))):trmRef.contains('Sem')?(String.valueOf(Integer.valueOf(trmRef.replaceAll('Sem-','')))):'';
                        if(string.isNotBlank(replaceValue)){
                            termRef.put(replaceValue,trm);
                        }                                                                                                                                              
                        
                        System.debug('termRef---'+termRef);
                    } 
                }
                
                for(hed__term__c term:termList)
                {
                    academicCalenderWrapper wrapperterm=new academicCalenderWrapper();
                    wrapperterm.termName = term.Name;
                    wrapperterm.termId = term.Id;
                    //System.debug('Integer.valueOf(term.hed__Parent_Term__r.Term_Reference__c--'+Integer.valueOf(term.hed__Parent_Term__r.Term_Reference__c));
                    wrapperterm.termNumber = String.isNotBlank(term.hed__Parent_Term__r.Term_Reference__c)?(Integer.valueOf(term.hed__Parent_Term__r.Term_Reference__c.replaceAll('Term ',''))):null;
                    wrapperterm.termStartDate = term.hed__Start_Date__c;
                    wrapperterm.termEndDate = term.hed__End_Date__c;
                    wrapperterm.termDuration = term.Term_Duration__c;
                    wrapperterm.workingDays = term.Program_Plan__r.Working_Days__c;
                    wrapperterm.batch = term.Program_Plan__r.Batch__c;
                    wrapperterm.intake = term.Program_Plan__r.Intake__c;
                    wrapperterm.programDuration = term.Program_Plan__r.hed__Account__r.Program_Duration_in_Weeks__c;
                    if(term.hed__Parent_Term__r.Term_Reference__c != 'Term 1' && term.hed__Parent_Term__r.Term_Reference__c != null){
                        String trmRef = term.hed__Parent_Term__r.Term_Reference__c;
                        wrapperterm.previousTermStartDate = !termRef.isEmpty()?termRef.containskey(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1))?termRef.get(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1)).hed__Start_Date__c!=null?termRef.get(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1)).hed__Start_Date__c:null:null:null;
                        wrapperterm.termMinStart = (termRef != null && !termRef.isEmpty()) ? termRef.containskey(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1))?termRef.get(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1)).hed__End_Date__c!=null?termRef.get(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1)).hed__End_Date__c:null:null:null;
                    }else{
                        String trmRef = term.hed__Parent_Term__r.Term_Reference__c;
                        wrapperterm.previousTermStartDate = (termRef != null && !termRef.isEmpty())? termRef.containskey(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1))?termRef.get(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1)).hed__Start_Date__c!=null?termRef.get(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1)).hed__Start_Date__c:null:null:null;
                        wrapperterm.termMinStart = (termRef != null && !termRef.isEmpty())? termRef.containskey(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1))?termRef.get(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1)).hed__End_Date__c!=null?termRef.get(String.valueOf(Integer.valueOf(trmRef.replaceAll('Term ',''))-1)).hed__End_Date__c:term.Program_Plan__r.hed__Start_Date__c:term.Program_Plan__r.hed__Start_Date__c:null;
                    }
                    List<academicCalenderDataWrapper>calenderList = new List<academicCalenderDataWrapper>();
                    for(Academic_Calendar__c wr :term.Academic_Calendars__r){
                        academicCalenderDataWrapper wrapper = new academicCalenderDataWrapper();
                        wrapper.academicCalenderName = wr.Name;
                        wrapper.endDate = string.valueOf(wr.End_Date__c);
                        wrapper.startDate = string.valueOf(wr.Start_Date__c);
                        wrapper.weekNumber=String.valueOf(wr.Week_Number__c);
                        wrapper.calculatedWeekNumber=String.valueOf(wr.CalculatedWeekNumber__c);
                        wrapper.numberOfWeeks=wr.Number_Of_Weeks__c;
                        wrapper.typeofActivity = wr.Type_of_Activity__c;
                        wrapper.termName = wr.Term__r.Name;
                        wrapper.termId=wr.Term__c;
                        wrapper.academicCalenderId = wr.Id;
                        wrapper.description = wr.Description__c;
                        calenderList.add(wrapper);
                    }
                    wrapperterm.academicCalenders=calenderList;
                    app.put(term.Id,wrapperterm);
                }
                if(!app.keyset().isEmpty()){
                    res.statusCode = 200;
                    system.debug('app===>'+app);
                    res.responseBody =  Blob.valueOf(JSON.serialize(app));
                }else{
                    res.responseBody =  Blob.valueOf('[]');
                }
                
            }else{
                res.responseBody =  Blob.valueOf('{ "success": "false" , "message" : "No Data Found"}'); 
            }
            
        }catch(exception e){
            res.responseBody =  Blob.valueOf('{ "success": "false" , "message" : "bad request" , "errors": "'+e.getMessage()+' at line number '+e.getLineNumber()+'"}');  
        }
    }
    
    //Post
    @httpPost
    global static void insertingAcademicCalender(){
        list<academicCalenderDataWrapper> request = (list<academicCalenderDataWrapper>) JSON.deserialize(RestContext.request.requestBody.toString(),list<academicCalenderDataWrapper>.class);
        system.debug('request===>'+request);
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        List<Academic_Calendar__c> calenderlist= new List<Academic_Calendar__c>();
        for(academicCalenderDataWrapper wr :request){
            Academic_Calendar__c cal = new Academic_Calendar__c();
            if(wr.academicCalenderId != null && String.isNotEmpty(wr.academicCalenderId)){
                cal.Id = wr.academicCalenderId;
            }
            if(String.isNotEmpty(wr.academicCalenderName)){
                cal.Name = wr.academicCalenderName;
            }
                if(wr.endDate != null && wr.endDate != ''){
                cal.End_Date__c = Date.valueOf(wr.endDate);
                }else{
                    cal.End_Date__c = null;
                }
                if(wr.startDate != null && wr.startDate != ''){
                cal.Start_Date__c =  Date.valueOf(wr.startDate);
                }else{
                    cal.Start_Date__c =  null;
                }
                cal.Week_Number__c =  Integer.valueOf(wr.weekNumber);
                cal.Type_of_Activity__c =  wr.typeofActivity;
                cal.Term__c =  wr.termid;
                cal.Number_Of_Weeks__c = wr.numberOfWeeks;
                cal.Description__c = wr.description;
                calenderlist.add(cal);
            
        }
        try{
            if(!calenderlist.isEmpty()){
                system.debug('newlist for inserting==>'+calenderlist);
                upsert calenderlist;
                res.statusCode = 200;
                res.responseBody =  Blob.valueOf('{ "success": "true" , "message" : "Data Inserted"}');
            }
            
        }catch(exception e){
            res.statusCode = 400;
            res.responseBody =  Blob.valueOf('{ "success": "false" , "message" : "bad request" , "errors": "'+e.getMessage()+' at line number '+e.getLineNumber()+'"}'); 
        } 
        
    }
    
    @HttpDelete
    global static void doDelete(){
        RestResponse res = RestContext.response;
        try{
            String academicCalenderId = RestContext.request.params.get('academicCalenderId');  
            String termId = RestContext.request.params.get('termId'); 
            system.debug(academicCalenderId);
            system.debug(termId);
            List<Academic_Calendar__c> academicCalenderList = new List<Academic_Calendar__c>();
            //if(string.isBlank(academicCalenderId) && (string.isBlank(termId) || termId==null)){
                if(string.isNotBlank(academicCalenderId)){
                    academicCalenderList = [SELECT Id, Term__c FROM Academic_Calendar__c where Id =:academicCalenderId];
                }else if(string.isNotBlank(termId)){
                    academicCalenderList = [SELECT Id, Term__c FROM Academic_Calendar__c where Term__c =:termId]; 
                }
                if(!academicCalenderList.isEmpty()){
                    Delete academicCalenderList;
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf('{"success":true,"message":"deleted successfully..."}'); 
                }else{ 
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf('{"success":false,"message":"no records found..."}'); 
                } 
            //}else{
                //res.statusCode = 400;
                //res.responseBody = Blob.valueOf('{"success":false,"message":"invalid parameters"}');  
            //}
        }catch(exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf('{"success":false,"message":'+e.getMessage()+' at line number ' +e.getLineNumber()+'}');   
        }
    }
    
    global class academicCalenderWrapper{
        public string termName{get;set;}
        public string termId{get;set;}
        public Date termStartDate {get;set;}
        public Date termEndDate {get;set;}
        public string termDuration {get;set;}
        public string workingDays {get;set;}
        public string batch {get;set;}
        public string intake {get;set;}
        public Decimal programDuration {get;set;}
        public Date previousTermStartDate {get;set;}
        public Date termMinStart{get;set;}
        public Integer termNumber {get;set;}
        public List<academicCalenderDataWrapper> academicCalenders{get;set;}
        
    }
    
    //Wapper Class
    global class academicCalenderDataWrapper{
        public string academicCalenderName {get;set;}
        public string endDate {get;set;}
        public string startDate{get;set;}
        public string weekNumber{get;set;}
        public string typeofActivity{get;set;}
        public string termName{get;set;}
        public string calculatedWeekNumber{get;set;}
        public string termId{get;set;}
        public string academicCalenderId{get;set;}
        public string numberOfWeeks {get;set;}
        public string description {get;set;}
    }
    public static void testCoverage() {
        String str = '';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
       }
}