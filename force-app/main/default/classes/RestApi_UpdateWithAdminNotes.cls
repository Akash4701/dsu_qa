@RestResource(UrlMapping='/adminNotes/*')
global class RestApi_UpdateWithAdminNotes {
	
    @HttpPost
    global static void doPost(){
        RestResponse res = RestContext.response;
        try{
            List<requestWrapper> request = (List<requestWrapper>) JSON.deserialize(RestContext.request.requestBody.toString(),List<requestWrapper>.class);
            Set<Id> reqContactIds = new Set<Id>();
            for(requestWrapper wrapObj:request){
                reqContactIds.add(wrapObj.contactId);
            }
            List<Contact> reqContactList = [Select id,Name,Admin_Notes__c,RecordType.Name from Contact where Id IN: reqContactIds];
            List<Contact> contactList = new List<Contact>();
            if(!reqContactList.isEmpty()){
                for(requestWrapper wrapObj:request){
                    if(wrapObj.contactId!=null && String.isNotBlank(wrapObj.contactId)){
                        Contact conObj = new Contact();
                        conObj.Id = wrapObj.contactId;
                        conObj.Admin_Notes__c = wrapObj.adminNotes;
                        contactList.add(conObj);
                    } 
                }
                if(!contactList.isEmpty()){
                    update contactList;
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf('{ "success": "true" , "message": "Data added successfully" }');
                }
            }else{
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('{ "success": "false" , "message": "Invalid Data" }');
            }
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    
    global class requestWrapper{
        public Id contactId;
        public String adminNotes;
    }
    
        
}