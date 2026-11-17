@istest
public class RestApi_ContactAllDetailsTest {
@testSetup
    static void dataSetup(){
         Account acc = new Account();
        acc.Name = 'Institute';
        insert acc;
        
         Contact con = new Contact();
        con.lastname = 'Student';
        con.email = 'Student@gmail.com';
con.RecordTypeId=Schema.SObjectType.Contact.getRecordTypeinfosbyname().get('Student').getRecordTypeId();
        insert con;

          hed__Address__c address = new hed__Address__c();
        address.hed__Parent_Contact__c = con.id;
        address.hed__Address_Type__c ='Work';
        address.hed__MailingStreet__c = 'Testing Street';
        address.hed__MailingCity__c = 'Banglore';
        address.hed__MailingCounty__c = 'India';
        insert address;
        
        hed__Education_History__c ed= new hed__Education_History__c();
        ed.hed__Contact__c=con.ID;
        
        ed.hed__Educational_Institution_Name__c='123 institution';
        
        
        insert ed;
    }
    @isTest
    static void method1(){
        Contact con = [Select id from Contact limit 1];
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/contactAllDetails/'+con.id;
       
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_ContactAllDetails.doGet();
        Test.stopTest();   
    }
}