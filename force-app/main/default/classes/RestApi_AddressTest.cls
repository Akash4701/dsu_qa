@isTest
public class RestApi_AddressTest {
    
    @isTest 
    public static void testPostMethod1(){
        account acc = new account();
        acc.name ='Testing';
        acc.rating = 'Hot';
        insert acc;
        contact con = new contact();
        con.lastname = 'Testing';
        con.firstname = 'Name';
        con.AccountId = acc.id;
        insert con;
        
        hed__Address__c address = new hed__Address__c(hed__Parent_Contact__c = con.id,hed__Address_Type__c ='Work',hed__MailingStreet__c = 'Testing Street',hed__MailingCity__c = 'Banglore',hed__MailingCounty__c = 'India');
        insert address;
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/Address/';
        req.httpMethod = 'POST'; 
        RestContext.request = req;
        RestContext.response = res;
        list<hed__Address__c> addressList = new list<hed__Address__c>();
        addressList.add(address);
        Test.startTest();
        RestApi_Address.createRelationship(addressList);            
        Test.stopTest();
    }
    
    @isTest 
    public static void testDeleteMethod1(){
        
        account acc = new account();
        acc.name ='Testing';
        acc.rating = 'Hot';
        insert acc;
        contact con = new contact();
        con.lastname = 'Testing';
        con.firstname = 'Name';
        con.AccountId = acc.id;
        insert con;
        
        hed__Address__c address = new hed__Address__c();
        address.hed__Parent_Contact__c = con.id;
        address.hed__Address_Type__c ='Work';
        address.hed__MailingStreet__c = 'Testing Street';
        address.hed__MailingCity__c = 'Banglore';
        address.hed__MailingCounty__c = 'India';
        insert address;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/Address/?';
        req.addParameter('recordId',address.Id);
        req.httpMethod = 'DELETE';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_Address.deleteAddress();
        Test.stopTest();  
    }
    
    @isTest 
    public static void testDeleteMethod2(){
        
        account acc = new account();
        acc.name ='Testing';
        acc.rating = 'Hot';
        insert acc;
        contact con = new contact();
        con.lastname = 'Testing';
        con.firstname = 'Name';
        con.AccountId = acc.id;
        insert con;
        
        hed__Address__c address = new hed__Address__c();
        address.hed__Parent_Contact__c = con.id;
        address.hed__Address_Type__c ='Work';
        address.hed__MailingStreet__c = 'Testing Street';
        address.hed__MailingCity__c = 'Banglore';
        address.hed__MailingCounty__c = 'India';
        insert address;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/Address/?';
        req.addParameter('recordId','12345');
        req.httpMethod = 'DELETE';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_Address.deleteAddress();
        Test.stopTest();  
    }
    
    @isTest 
    public static void testDeleteMethod3(){
        
        account acc = new account();
        acc.name ='Testing';
        acc.rating = 'Hot';
        insert acc;
        contact con = new contact();
        con.lastname = 'Testing';
        con.firstname = 'Name';
        con.AccountId = acc.id;
        insert con;
        
        hed__Address__c address = new hed__Address__c();
        address.hed__Parent_Contact__c = con.id;
        address.hed__Address_Type__c ='Work';
        address.hed__MailingStreet__c = 'Testing Street';
        address.hed__MailingCity__c = 'Banglore';
        address.hed__MailingCounty__c = 'India';
        insert address;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/Address/?';
        req.httpMethod = 'DELETE';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_Address.deleteAddress();
        Test.stopTest();  
    }
}