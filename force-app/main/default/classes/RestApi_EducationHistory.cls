@RestResource(urlMapping='/EducationHistoryApi/*')
global class RestApi_EducationHistory {
  @HttpPost
    global Static void createEducationHistory(List<hed__Education_History__c> records){
        System.debug('hed__Education_History__c'+records);
        RestRequest req = RestContext.request;
        RestResponse res = Restcontext.response;
        try{
            upsert records;
            String json='';
            for( hed__Education_History__c edu:records){
                json+='{';
                  json+='"Id":"'+edu.Id+'"';
                json+='},';
            }
            json=json.removeEnd(',');
            res.responseBody=blob.valueOf('{"Status":"200","result":['+json+']}');
        }catch(DmlException e){
            res.responseBody=blob.valueOf('{"Status":"400","Message":"'+e.getMessage()+'"}');
        }
    }
    
     @HttpDelete
    global static void deleteEducationHistory(){
        RestRequest req = RestContext.request;
        RestResponse res = Restcontext.response;
        
        String recordId = RestContext.request.params.get('recordId');
        
        try{
            if(string.isNotBlank(recordId)){
                List<hed__Education_History__c> eduHisList = [Select Id from hed__Education_History__c where Id=:recordId];
                
                if(!eduHisList.isEmpty()){
                    delete eduHisList;
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "Deleted Successfully"}' );
                }else{
                    res.statusCode = 400;
                    res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "No Data Found"}' );
                }
            }else{
                res.statusCode = 400;
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Invalid Parameter"}' );
            }
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
}