@isTest
public class RestApi_EducationHistoryTest {
    public static testMethod void postTest(){       
         Account acc= new Account();        
        acc.Name='TestCollege';
        acc.RecordTypeId =schema.SObjectType.account.getRecordTypeinfosbyname().get('Educational Institution').getRecordTypeId();
        acc.Phone='9345829333';
        insert acc;
        Contact c =new Contact();
        c.AccountId = acc.Id;
        c.FirstName = 'Test';
        c.LastName = 'Class';
        insert c;
        hed__Education_History__c ed= new hed__Education_History__c
        (hed__Contact__c=c.ID,hed__Educational_Institution_Name__c='123 institution');
        insert ed;
        system.debug('education history'+ed);        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/EducationHistoryAPI/'+c.ID;
        req.httpMethod = 'POST'; 
        RestContext.request = req;
        RestContext.response = res;
        list<hed__Education_History__c> lhistory = new list<hed__Education_History__c>();
        lhistory.add(ed);
          Test.startTest();
     RestApi_EducationHistory.createEducationHistory(lhistory);            
       Test.stopTest();  
    }
    
    @isTest 
    public static void testDeleteMethod1(){
        
        Account acc= new Account();        
        acc.Name='TestCollege';
        acc.RecordTypeId =schema.SObjectType.account.getRecordTypeinfosbyname().get('Educational Institution').getRecordTypeId();
        acc.Phone='9345829333';
        insert acc;
        Contact c =new Contact();
        c.AccountId = acc.Id;
        c.FirstName = 'Test';
        c.LastName = 'Class';
        insert c;
        
        hed__Education_History__c ed= new hed__Education_History__c();
        ed.hed__Contact__c=c.ID;
        
        ed.hed__Educational_Institution_Name__c='123 institution';
       
        insert ed;
        system.debug('The historyList'+ed);
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/EducationHistoryApi/?';
        req.addParameter('recordId',ed.Id);
        req.httpMethod = 'DELETE';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_EducationHistory.deleteEducationHistory();
        Test.stopTest();  
    }
    
    @isTest 
    public static void testDeleteMethod2(){
        
        Account acc= new Account();        
        acc.Name='TestCollege';
        acc.RecordTypeId =schema.SObjectType.account.getRecordTypeinfosbyname().get('Educational Institution').getRecordTypeId();
        acc.Phone='9345829333';
        insert acc;
        Contact c =new Contact();
        c.AccountId = acc.Id;
        c.FirstName = 'Test';
        c.LastName = 'Class';
        insert c;
        
        hed__Education_History__c ed= new hed__Education_History__c();
        ed.hed__Contact__c=c.ID;
        
        ed.hed__Educational_Institution_Name__c='123 institution';
        
        insert ed;
        system.debug('The historyList'+ed);
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/EducationHistoryApi/?';
        req.addParameter('recordId','12345');
        req.httpMethod = 'DELETE';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_EducationHistory.deleteEducationHistory();
        Test.stopTest();  
    }
    
    @isTest 
    public static void testDeleteMethod3(){
        
        Account acc= new Account();        
        acc.Name='TestCollege';
        acc.RecordTypeId =schema.SObjectType.account.getRecordTypeinfosbyname().get('Educational Institution').getRecordTypeId();
        acc.Phone='9345829333';
        insert acc;
        Contact c =new Contact();
        c.AccountId = acc.Id;
        c.FirstName = 'Test';
        c.LastName = 'Class';
        insert c;
        
        hed__Education_History__c ed= new hed__Education_History__c();
        ed.hed__Contact__c=c.ID;
        
        ed.hed__Educational_Institution_Name__c='123 institution';
        
        insert ed;
        system.debug('The historyList'+ed);
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/EducationHistoryApi/?';
        //req.addParameter('recordId','12345');
        req.httpMethod = 'DELETE';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_EducationHistory.deleteEducationHistory();
        Test.stopTest();  
    }
}