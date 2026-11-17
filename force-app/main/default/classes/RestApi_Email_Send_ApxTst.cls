@istest
public class RestApi_Email_Send_ApxTst {
	@isTest static void testCallout() {
        Test.startTest();
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI='/services/apexrest/SendEMAIL';
        RestApi_Email_Send.requestBdy reques= new RestApi_Email_Send.requestBdy();
        reques.emailIds='test@gmail.com';
        reques.subject='testing';
        reques.emailBody='Test Email';        
        RestContext.request = req;
        RestContext.response = res;
        RestApi_Email_Send.sendmessage( reques );
        Test.stopTest();
    }
}