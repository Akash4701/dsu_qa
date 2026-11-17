@RestResource(urlMapping='/SendEMAIL/*')
global class RestApi_Email_Send {
	@httpPost
    global static void sendmessage( requestBdy emailMessage){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        System.debug('body'+emailMessage);
        String resp =SendEmails_ApxCls.emailSend(emailMessage.emailIds,emailMessage.subject,emailMessage.emailBody);
        res.addHeader('Content-Type', 'application/json');
        res.responseBody=Blob.valueOf(resp);
        res.statusCode=200;
    }
    global class requestBdy{
       public string emailIds;
       public string subject;
       public string emailBody;
    }   
}