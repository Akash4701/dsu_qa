@isTest
public class RestApi_SpecializationsByProgram_Test {
    @TestSetup
    static void doGet(){
        Account accParent = new Account();
        accParent.Name = 'Academic Program';
        accParent.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Academic Program').getRecordTypeId();
        insert accParent;
        
        Account accSpec = new Account();
        accSpec.Name = 'Specialization';
        accSpec.ParentId = accParent.id;
        accSpec.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Program Specialization').getRecordTypeId();
        insert accSpec;
    }
    @isTest
    static void methodGet1(){
        Account acc = [Select id,Name,ParentId from Account where Name like :'Specialization'];
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SpecializationsByProgram/?';
        req.addParameter('academicProgramId',+acc.ParentId);                
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_SpecializationsByProgram.doGet();
        Test.stopTest();
        //system.assert(res.statusCode==200);
        
    }
        @isTest
    static void methodGet2(){
        Account acc = [Select id,Name,ParentId from Account where Name like :'Specialization'];
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SpecializationsByProgram/?';
       // req.addParameter('academicProgramId',+acc.ParentId);                
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        RestApi_SpecializationsByProgram.doGet();
        Test.stopTest();
    }
    @isTest
    static void methodPost1(){
         Account acc = [Select id,Name,ParentId from Account where Name like :'Specialization'];
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/SpecializationsByProgram/';
          string body = '[{"Name": "Test","programid": "'+acc.ParentId+'"},{"Name": "Test1","programid": "'+acc.ParentId+'"}]';          
        req.httpMethod = 'Post';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest(); 
        RestApi_SpecializationsByProgram.doPost();
        Test.stopTest(); 
    }
}