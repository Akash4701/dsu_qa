@RestResource(urlMapping='/AcademicProgramsName')
global class RestApi_GetAcademicProgramsName {
	@HttpGet
    global static void doGetAcademicProgramsName(){
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        Map<string, Map<String,Map<String,String>>>  mapList = new Map<string, Map<String,Map<String,String>>>();
        Map<String,String> pgmAliasMap=new Map<String,String> ();
        try{
            List<Account> accAllPgmList =new List<Account>([SELECT Id,Name,Number_of_Terms__c,RecordType.DeveloperName,Course_duration__c,Program_Duration_in_Weeks__c,Duration_Per_Session__c,(Select Id,Name from hed__Terms__r WHERE  RecordType.Name='Default Record' ),(SELECT Id, Name, Combination_Name__c FROM Program_Campus_Relationships1__r where RecordType.Name='Program Level Campus Combination') FROM Account WHERE RecordType.DeveloperName IN ('Academic_Program','University_Department')]);
            for(K42_Program_Alias__c alias:[SELECT Id,Name,Program__r.Name FROM K42_Program_Alias__c])
            {
                pgmAliasMap.put(alias.Program__r.Name,alias.Name);
            }
            List<hed__Course__c> coursesList =new List<hed__Course__c>([SELECT Id,Name,Credits__c,hed__Course_ID__c,hed__Account__c FROM hed__Course__c]);
            Map<String,Map<String,String>> accAcademicPgmList=new Map<String,Map<String,String>>();
            Map<String,Map<String,String>> acclevelPgmList=new Map<String,Map<String,String>>();
            Map<String,Map<String,String>> campusList =new  Map<String,Map<String,String>>();
            Map<String,Map<String,String>> courseList=new Map<String,Map<String,String>>();
            system.debug('The Academic Program Size'+accAllPgmList.size());
            if(accAllPgmList.size()>0){
                for(Campus__c camp:[SELECT Id,Name FROM Campus__c ])
                {
                    Map<String,String> valueCamp=new Map<String,String>();
                    valueCamp.put('Id',camp.Id);
                    campusList.put(camp.Name,valueCamp);
                }
                for(Account acc:accAllPgmList)
                {
                    Map<String,String> value=new Map<String,String>();
                    if(String.isBlank(acc.Number_of_Terms__c))
                    {
                        value.put('noOfTerms','N/A');
                    }
                    else
                    {
                        value.put('noOfTerms',acc.Number_of_Terms__c);
                    }
                    value.put('id',acc.Id);
                    if(acc.Program_Duration_in_Weeks__c!=null){
                        value.put('prgDurationInWeeks',String.valueOf(acc.Program_Duration_in_Weeks__c));
                    }else{
                        value.put('prgDurationInWeeks','0');
                    }
                     if(acc.Duration_Per_Session__c!=null){
                        value.put('durationPerSession',String.valueOf(acc.Duration_Per_Session__c));
                    }
                   
                    if(String.isBlank(acc.Course_duration__c))
                    {
                        value.put('durationYear','N/A');
                        value.put('durationMonth','N/A');
                    }
                    else
                    {
                        acc.Course_duration__c=acc.Course_duration__c.replace(' ','');
                        String month=acc.Course_duration__c.substringAfter('years').substringBefore('month');
                        String year=acc.Course_duration__c.substringAfter('').substringBefore('years');
						value.put('durationYear',year);
                    	value.put('durationMonth',month);
                    }

                    if(acc.RecordType.DeveloperName=='Academic_Program')
                    {
                        List<responseAcademicProgramsTermsWrapper> respList=new List<responseAcademicProgramsTermsWrapper>();
                        if(!acc.hed__Terms__r.isEmpty())
                        {
                            
                            for(hed__Term__c term:acc.hed__Terms__r)
                            {
                                responseAcademicProgramsTermsWrapper resp=new responseAcademicProgramsTermsWrapper();
                                resp.id=term.Id;
                                resp.name=term.Name;
                                //resp.batch=term.Name;
                                //resp.intake=term.Name;
                                respList.add(resp);
                            } 
                        }
                        String jsonData=json.serialize(respList);
                        value.put('terms',jsonData);
                        //Adding campusComination Data also in these api
                        //modified by vamsi
                        List<responseProgramCampusCombinationWrapper> campusFormatList = new List<responseProgramCampusCombinationWrapper>();
                        if(!acc.Program_Campus_Relationships1__r.isEmpty()){
                            for(Program_Campus_Relationship__c combiObj:acc.Program_Campus_Relationships1__r){
                                responseProgramCampusCombinationWrapper wrapObj = new responseProgramCampusCombinationWrapper();
                                wrapObj.combinationId = combiObj.Id;
                                wrapObj.combinationName = combiObj.Combination_Name__c;
                                campusFormatList.add(wrapObj);
                            }
                            value.put('campusFormats',json.serialize(campusFormatList));
                        }
                        //
                        if(pgmAliasMap.Keyset().contains(acc.Name))
                        {
                            value.put('alias',pgmAliasMap.get(acc.Name));
                        }
                        else
                        {
                            value.put('alias','N/A');
                        }
                        accAcademicPgmList.put(acc.Name,value);
                    }
                    else
                    {
                         acclevelPgmList.put(acc.Name,value);
                    }
                    
                }
                
                if(coursesList.size()>0){
                    for(hed__Course__c course:coursesList)
                    {
                        Map<String,String> valueCourse=new Map<String,String>();
                        valueCourse.put('id',course.Id);
                        valueCourse.put('courseName',course.Name);
                        valueCourse.put('courseId',course.hed__Course_ID__c);
                        valueCourse.put('courseAcademicProgramId',course.hed__Account__c);
                        if(course.Credits__c!=null)
                        {
                            valueCourse.put('credit',String.ValueOf(course.Credits__c));
                        }
                        else
                        {
                            valueCourse.put('credit','N/A');
                        }
                        courseList.put(course.Name+'#'+course.hed__Course_ID__c,valueCourse);
                    }
                }
                
                mapList.put('Academic Program',accAcademicPgmList);
     			mapList.put('University Department',acclevelPgmList);
                mapList.put('Campus',campusList);
                mapList.put('Courses',courseList);
                jsonResponse = JSON.serialize(mapList);
                if(jsonResponse!=null){    
                	res.responseBody=Blob.valueOf(jsonResponse); 
                }
                else
                {
                    res.responseBody=Blob.valueOf('[]'); 
                }
                res.statusCode = 200;
            }
            else{     
               res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
            }
        res.statusCode = 200;
    	}Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }

    public class responseAcademicProgramsTermsWrapper {
        public string id {get;set;}
        public string name {get;set;}
        public List<responseProgramCampusCombinationWrapper> campusFormatData{get;set;}
        public List<responseAcademicProgramsTermsDataWrapper> data {get;set;}
    }
    public class responseAcademicProgramsTermsDataWrapper {
        public string batch {get;set;}
        public string intake {get;set;}
    }
    public class responseProgramCampusCombinationWrapper{
        public Id combinationId;
        public string combinationName;
    }
}