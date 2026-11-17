@RestResource(urlMapping='/createTermData')
global class RestApi_CreateTerms {
    @HttpPost
    global static void doCreateTerms(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
        try{
            requestTermsWrapper request = (requestTermsWrapper) JSON.deserialize(RestContext.request.requestBody.toString(),requestTermsWrapper.class);
            responseTermsWrapper response=new responseTermsWrapper();
            if(!String.isBlank(request.Terms.termName))
            {
                List<hed__Term__c> termList=new List<hed__Term__c>([SELECT Id,Name FROM hed__Term__c WHERE Name=:request.Terms.termName AND RecordType.Name='Default Record']);
                if(!termList.isEmpty())
                {
                    hed__Term__c term=new hed__Term__c();
                    term.Id=termList[0].Id;
                    if(!String.isBlank(request.Terms.startDate))
                    {
                        term.hed__Start_Date__c=date.parse(request.Terms.startDate);
                    }
                    if(!String.isBlank(request.Terms.endDate))
                    {
                        term.hed__End_Date__c=date.parse(request.Terms.endDate);
                    }
                    upsert term;
					response.termId=term.Id;
                    res.statusCode = 200;
                    if(!String.isBlank(response.termId))
                    {
                        jsonResponse=json.serialize(response);
                        res.responseBody=Blob.valueOf(jsonResponse); 
                    }
                    else 
                    {
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                    } 
                }
                else 
                {
                     res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                }
            }
            else 
            {
                 res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
            }
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    //Wrapper class for the request from API 
    public class requestTermsWrapper {
        public requestTermsDataWrapper Terms {get;set;}
   
    }
    public class requestTermsDataWrapper {
        public String termName {get;set;}
        public String startDate {get;set;}
        public String endDate {get;set;} 
    }
    public class responseTermsWrapper {
        public string success='true';
        public string message='Data is Added';
        public String termId {get;set;}
    }
    
 
    
}