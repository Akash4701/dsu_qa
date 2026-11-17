@RestResource(urlMapping='/CurrentPageFilter/*')
global class RestApi_ProgramPlanAndTermDataFilter {
    @HttpGet
    global static void doGet(){
        String termStatus=RestContext.request.params.get('termStatus');
        String campus=RestContext.request.params.get('campus');
        String intake=RestContext.request.params.get('intake');
        system.debug('The intake'+intake);
        String year=RestContext.request.params.get('batch');
        system.debug('The Year'+year);
        String program=RestContext.request.params.get('program');
        system.debug('The program'+program);
        string programPlanFilter='';
        string termsFilter='';
        if(!String.isBlank(campus))
            {
                termsFilter+=' Campus__r.Name like \'%'+campus+'%\' AND ';
            }
            
            if(!String.isBlank(termStatus))
            {
                termsFilter+=' Term_Status__c = \''+termStatus+'\' AND ';
            }
        system.debug('termFilter>>'+termsFilter);
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;
        try{
            if(String.isNotBlank(year)||String.isNotBlank(intake)||String.isNotBlank(program)){
                if(!String.isBlank(year))
            {
                programPlanFilter+=' AND Batch__c =\''+year+'\'  ';
            }
            
            if(!String.isBlank(intake))
            {
                programPlanFilter+=' AND Intake__c=\''+intake+'\'  ';
            }
            
            if(!String.isBlank(program))
            {
              //  programPlanFilter+=' AND hed__Account__r.Name like \'%'+program+'%\'  ';
              programPlanFilter+=' AND hed__Account__r.Name=\''+program+'\'  ';
            }
            
            
            String programplanQuery='Select Id,No_of_Student__c,hed__Account__c,Batch__c,hed__Account__r.Name,hed__End_Date__c,Intake__c,hed__Is_Primary__c,Parent_Program_Plan__c,Name,RecordTypeId,hed__Start_Date__c,hed__Status__c,hed__Total_Required_Credits__c,hed__Version__c from hed__Program_Plan__c where Recordtype.Name=\'Program Version\' AND hed__Status__c=\'Current\'' +programPlanFilter;
            String termsQuery='Select Id,Name,hed__Account__c,Campus__c,Campus__r.Name,hed__End_Date__c,Facility__c,hed__Grading_Period_Sequence__c,hed__Instructional_Days__c,hed__Parent_Term__c,Program_Plan__c,hed__Start_Date__c,hed__Type__c,Term_Status__c from hed__Term__c where recordtype.Name=\'Default Record\' AND '+termsFilter+' Program_Plan__c=\'';
            List<hed__Program_Plan__c> progPlnList = [Select Id,Name from hed__Program_Plan__c];
            List<hed__Term__c> trmList = new List<hed__Term__c>();
            List<string> jsonreponse=new List<string>();
                system.debug('programplanQuery >>>' +programplanQuery);
            system.debug('The ProgramPlanList Size'+progPlnList.size());
            if(progPlnList.size()>0){
                for(hed__Program_Plan__c ppObj:Database.query(programplanQuery)){
                    System.debug('termsQuery::::' + termsQuery+ppObj.Id+'\'');
                    for(hed__Term__c trmObj:Database.query(termsQuery+ppObj.Id+'\'')){
                        JSONGenerator gen = JSON.createGenerator(true);
                        gen.writeStartObject();
                        gen.writeIdField('ProgramPlanRecordId', ppObj.Id);
                        if(ppObj.Name != null){
                            gen.writeStringField('ProgramName',ppObj.Name);
                        }else{gen.writeStringField('ProgramName', 'N/A');}
                        if(ppObj.No_of_Student__c != null){
                            gen.writeStringField('NoOfStudent',String.valueOf(ppObj.No_of_Student__c));
                        }else{gen.writeStringField('NoOfStudent', 'N/A');}
                        if(ppObj.hed__Account__r.Name != null){
                            gen.writeStringField('Course', ppObj.hed__Account__r.Name);
                        }else{gen.writeStringField('Course', 'N/A');}
                        if(ppObj.hed__Start_Date__c != null){
                            gen.writeDateField('ProgramPlanStartDate', ppObj.hed__Start_Date__c);
                        }else{gen.writeStringField('ProgramPlanStartDate', 'N/A');}
                        if(ppObj.hed__End_Date__c != null){
                            gen.writeDateField('ProgramPlanEndDate', ppObj.hed__End_Date__c);
                        }else{gen.writeStringField('ProgramPlanEndDate', 'N/A');}
                        if(ppObj.Batch__c != null){
                            gen.writeStringField('Batch',ppObj.Batch__c);
                        }else{gen.writeStringField('Batch', 'N/A');}
                        if(ppObj.Intake__c != null){
                            gen.writeStringField('Intake', String.valueOf(ppObj.Intake__c));
                        }else{gen.writeStringField('Intake', 'N/A');}
                        if(trmObj.Id != null){
                            gen.writeIdField('TermRecordId',trmObj.Id);
                        }
                        if(trmObj.Name != null){
                            gen.writeStringField('Semester', trmObj.Name);
                        }else{gen.writeStringField('Semester', 'N/A');}
                        if(trmObj.Term_Status__c != null){
                            gen.writeStringField('TermStatus', trmObj.Term_Status__c);
                        }else{
                            gen.writeStringField('TermStatus', 'N/A');
                        }
                        if(trmObj.hed__Start_Date__c != null){
                            gen.writeDateField('TermStartDate',trmObj.hed__Start_Date__c);
                        }else{
                            gen.writeStringField('TermStartDate','N/A');
                        }
                        if(trmObj.hed__End_Date__c != null){
                            gen.writeDateField('TermEndDate',trmObj.hed__End_Date__c);
                        }else{
                            gen.writeStringField('TermEndDate','N/A');
                        }
                        if(trmObj.Campus__r.Name != null){
                            gen.writeStringField('Campus', trmObj.Campus__r.Name);
                        }else{gen.writeStringField('Campus', 'N/A');}
                        if(trmObj.Campus__r.Name != null){
                            gen.writeStringField('CampusId', trmObj.Campus__c);
                        }else{gen.writeStringField('CampusId', 'N/A');}
                        gen.writeEndObject();
                        jsonreponse.add(gen.getAsString());
                    }
                }
                jsonResponses = String.join(jsonreponse,',');
                jsonResponse = '[' +jsonResponses+ ']';
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf(jsonResponse);    
                }
                else{     
                    res.responseBody=Blob.valueOf('[]'); 
                }
                res.statusCode = 200;
            }else{
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "No Data Found"}' );
            }
            }else{
                res.responseBody = Blob.valueOf('{ "success": "false" , "message": "Invalid Parameters"}');
            }
            
            
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
       /* public static void testCoverage() {
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
        }*/
}