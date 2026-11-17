@RestResource(urlMapping='/Address/*')
global class RestApi_Address {
	@HttpPost
    global Static void createRelationship(List<hed__Address__c> records){
        System.debug('hed__Address__c'+records);
        RestRequest req = RestContext.request;
        RestResponse res = Restcontext.response;
        try{
            upsert records;
            String json='';
            for( hed__Address__c add:records){
                json+='{';
                  json+='"Id":"'+add.Id+'"';
                json+='},';
            }
            json=json.removeEnd(',');
            res.responseBody=blob.valueOf('{"Status":"200","result":['+json+']}');
        }catch(DmlException e){
            res.responseBody=blob.valueOf('{"Status":"400","Message":"'+e.getMessage()+'"}');
        }
    }
    
       @HttpDelete
    global static void deleteAddress(){
        RestRequest req = RestContext.request;
        RestResponse res = Restcontext.response;
        
        String recordId = RestContext.request.params.get('recordId');
        
        try{
            if(string.isNotBlank(recordId)){
                List<hed__Address__c> addList = [Select Id from hed__Address__c where Id=:recordId];
                
                if(!addList.isEmpty()){
                    delete addList;
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