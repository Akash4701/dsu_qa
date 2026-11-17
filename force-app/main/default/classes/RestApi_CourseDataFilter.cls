@RestResource(urlMapping='/SubjectPageFilter')
global class RestApi_CourseDataFilter {
	@HttpGet
    global static void doGetCourseData(){

        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;
        try{
            List<hed__Course_Offering__c> courseOfferingList =[Select Id,hed__Course__r.Name,Name,hed__Faculty__r.Name,hed__Facility__r.Name,hed__Start_Date__c,hed__End_Date__c FROM hed__Course_Offering__c WHERE hed__Course__c<> null];
            List<string> jsonreponse=new List<string>();
            system.debug('The Course Size'+courseOfferingList.size());
            if(courseOfferingList.size()>0){
                for(hed__Course_Offering__c courOffObj:courseOfferingList){
                    JSONGenerator gen = JSON.createGenerator(true);
                    gen.writeStartObject();
                    gen.writeIdField('CourseOfferingRecordId', courOffObj.Id);
                    if(courOffObj.hed__Course__r.Name != null){
                        gen.writeStringField('Subject', courOffObj.hed__Course__r.Name);
                    }else{gen.writeStringField('Subject', 'N/A');}
                    if(courOffObj.hed__Start_Date__c != null){
                        gen.writeStringField('StartDate',String.valueOf(courOffObj.hed__Start_Date__c));
                    }else{gen.writeStringField('StartDate', 'N/A');}
                    if(courOffObj.hed__End_Date__c != null){
                        gen.writeStringField('EndDate',String.valueOf(courOffObj.hed__End_Date__c));
                    }else{gen.writeStringField('EndDate', 'N/A');}
                    gen.writeStringField('StartTime', 'N/A');
                    gen.writeStringField('EndTime', 'N/A');
                    gen.writeStringField('TZ', 'N/A');
                    if(courOffObj.hed__Faculty__r.Name != null){
                        gen.writeStringField('Faculty',String.valueOf(courOffObj.hed__Faculty__r.Name));
                    }else{gen.writeStringField('Faculty', 'N/A');}
                    if(courOffObj.hed__Facility__r.Name != null){
                        gen.writeStringField('ClassRoom',String.valueOf(courOffObj.hed__Facility__r.Name));
                    }else{gen.writeStringField('ClassRoom', 'N/A');}
                    gen.writeStringField('Status', 'N/A');
                    gen.writeStringField('Holiday', 'N/A');
                    gen.writeEndObject();
                    jsonreponse.add(gen.getAsString());
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
                res.responseBody = Blob.valueOf( '{ "success": "true" , "message": No Data Found}' );
            }
            
    	}Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
}