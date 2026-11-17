@isTest
global class MockHttpResponseGenerator implements HttpCalloutMock {    
    global HTTPResponse respond(HTTPRequest req) {
        String currUrl=req.getEndpoint();
        HttpResponse res = new HttpResponse();
        if(currUrl.containsIgnoreCase('sendSMS')){
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"responseCode": "Message SuccessFully Submitted"},{"msgid": "a5a20490-d7d0-11eb-adff-d9fcee8528d9"}]');
            res.setStatusCode(200);    
        }       
        if(currUrl.containsIgnoreCase('sendSMS')){
            
        }
        return res;
    }
}