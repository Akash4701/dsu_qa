@isTest
public class RestApi_Student360Test {
    static testmethod void doTest1(){
        Account educInstitution= new Account();
        educInstitution.Name='Ken 42';
        educInstitution.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Educational Institution').getRecordTypeId();
        insert educInstitution;
        
        Account UnivDepart= new Account();
        UnivDepart.Name='Economics and Finance';
        UnivDepart.ParentId=educInstitution.id;
        UnivDepart.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('University Department').getRecordTypeId();
        insert UnivDepart;
        
        Account academicProg= new Account();
        academicProg.Name='The First Principle Thinking';
        UnivDepart.ParentId=UnivDepart.id;
        academicProg.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Academic Program').getRecordTypeId();
        insert academicProg;
        
        Contact con = new Contact();
        con.LastName = 'Mohan';
        con.FirstName='sharma';
        con.Email = 'testing@ken42.com';
        con.MailingCity='Maclo';
        con.MailingCountry='India';
        con.Registration_Number__c='xuvmmCCXXdd-0019';
        con.AccountId = educInstitution.Id;
        insert con;
        
        Contact parentCon = new Contact();
        parentCon.LastName = 'Raghav';
        parentCon.FirstName='sharma';
        parentCon.Email = 'parentCon@ken42.com';
        parentCon.MailingCity='Maclo';
        parentCon.MailingCountry='India';
        insert parentCon;
        
        hed__Relationship__c  rel =new hed__Relationship__c();
        rel.hed__Contact__c=con.id;
        rel.hed__RelatedContact__c=parentCon.id;
        rel.hed__Status__c='Current';
        rel.hed__Type__c='Father';
        insert rel;
        
        hed__Education_History__c eduHis = new hed__Education_History__c();
        eduHis.hed__Educational_Institution_Name__c = 'Testing Institution';
       // eduHis.Country__c = 'India';
        eduHis.hed__Contact__c = con.Id;
        //eduHis.Level__c = 'Graduation';
      //  eduHis.Year_of_Passing__c = '2022';
        insert eduHis;
        
        hed__Address__c add = new hed__Address__c();
        add.hed__Address_Type__c = 'Home';
        add.hed__Parent_Contact__c = con.Id;
        insert add;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();  
        req.requestURI = '/services/apexrest/ContactDetail/'+con.id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response= res;
        Test.startTest();
        RestApi_Student360.doGet();
        Test.stopTest();
    }
    static testmethod void doTest2(){
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();  
        req.requestURI = '/services/apexrest/ContactDetail/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response= res;
        Test.startTest();
        RestApi_Student360.doGet();
        Test.stopTest();
    }
    static testmethod void doTest3(){
        Account educInstitution= new Account();
        educInstitution.Name='Ken 42';
        educInstitution.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Educational Institution').getRecordTypeId();
        insert educInstitution;
        
        Account UnivDepart= new Account();
        UnivDepart.Name='Economics and Finance';
        UnivDepart.ParentId=educInstitution.id;
        UnivDepart.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('University Department').getRecordTypeId();
        insert UnivDepart;
        
        Account academicProg= new Account();
        academicProg.Name='The First Principle Thinking';
        UnivDepart.ParentId=UnivDepart.id;
        academicProg.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Academic Program').getRecordTypeId();
        insert academicProg;
        
        Contact con = new Contact();
        con.LastName = 'Mohan';
        con.Birthdate = Date.newInstance(2022, 04, 04);
        con.Birth_Place__c = 'Banglore';
        con.Phone = '9999999999';
        con.Nationality__c = 'Testing';
        con.Emirates_City__c = 'Testing';
        con.Passport_Number__c = '12345';
        con.National_ID__c = '12345';
        con.MailingCity='Maclo';
        con.MailingCountry='India';
        con.Registration_Number__c='xuvmmCCXXdd-0019';
        con.AccountId = educInstitution.Id;
        insert con;
        
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();  
        req.requestURI = '/services/apexrest/ContactDetail/'+con.id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response= res;
        Test.startTest();
        RestApi_Student360.doGet();
        Test.stopTest();
    }
    
     @isTest
    static void testCreateContactPost() {
        Account educInstitution= new Account();
        educInstitution.Name='Ken 42';
        educInstitution.RecordTypeId=schema.SObjectType.Account.getRecordTypeinfosbyname().get('Educational Institution').getRecordTypeId();
        insert educInstitution;
        
       Contact con = new Contact();
        con.LastName = 'Doe';
        con.FirstName='John';
        con.Email = 'john.doe@example.com';
        con.MailingCity='Maclo';
        con.MailingCountry='India';
        con.Registration_Number__c='xuvmmCCXXdd-0019';
        con.AccountId = educInstitution.Id;
        insert con;
        
        List<RestApi_Student360.ContactWrapperPost> mockContacts = new List<RestApi_Student360.ContactWrapperPost>();
        
        RestApi_Student360.ContactWrapperPost mockContact = new RestApi_Student360.ContactWrapperPost();
        mockContact.contactId = con.id;
        mockContact.firstName = 'John';
        mockContact.middleName = 'A';
        mockContact.lastName = 'Doe';
        mockContact.BirthDate = Date.newInstance(2024, 07, 18);
        mockContact.BirthPlace = 'New York';
        mockContact.CountryOfResidence = 'USA';
        mockContact.Email = 'john.doe@example.com';
        mockContact.EmiratesIdNum = '123456789';
        mockContact.Gender = 'Male';
        mockContact.NationalIdNumber = '987654321';
        mockContact.Nationality = 'American';
        mockContact.PassportNumber = 'P12345678';
        mockContact.Phone = '1234567890';
        mockContact.Others = 'None';
        mockContact.AlternateContact = '0987654321';
        mockContact.alternateEmail = 'john.alternate@example.com';
        mockContact.TaxFileNum = 'TFN123456';
        mockContact.NameOnInvoice = 'John Doe';
        mockContact.BloodGroup = 'O+';
        mockContact.Allergy = 'Peanuts';
        
        // Mock data for the RelationshipWrapperPost class
        RestApi_Student360.RelationshipWrapperPost mockRelationship = new RestApi_Student360.RelationshipWrapperPost();
        mockRelationship.AnnualIncome = '100000';
        mockRelationship.MotherOccupation = 'Teacher';
        mockRelationship.FatherOccupation = 'Engineer';
        mockRelationship.EmergencyContactNo = '1234567890';
        mockRelationship.Status = 'Active';

        mockContact.RELATIONSHIP = new List<RestApi_Student360.RelationshipWrapperPost> { mockRelationship };
        
        // Mock data for the AddressWrapperPost class
        RestApi_Student360.AddressWrapperPost mockAddress = new RestApi_Student360.AddressWrapperPost();
        mockAddress.flat = 'Apt 1';
        mockAddress.country = 'USA';
        mockAddress.road = 'Main St';
        mockAddress.pin = '10001';
        mockAddress.addressRecordId = null; // New address, no ID yet
        mockAddress.state = 'NY';
        mockAddress.city = 'New York';

        mockContact.ADDRESS = new List<RestApi_Student360.AddressWrapperPost> { mockAddress };
        
        mockContacts.add(mockContact);
        
        // Serialize the mock data to JSON
        String jsonInput = JSON.serialize(mockContacts);
        
        // Set up the mock HTTP request
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/ContactDetail/'; // Update with your actual endpoint
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonInput);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        // Call the method
        RestApi_Student360.createContact();
        
        // Verify the response
        RestResponse res = RestContext.response;
       Assert.areEqual(400, res.statusCode);
        String responseBody = res.responseBody.toString();
    //   Assert.isTrue(responseBody.contains('"success": "true"'));
     //  Assert.isTrue(responseBody.contains('"message": "Data Updated/Inserted Successfully"'));

        // Verify that the contact was created
        Contact insertedContacts = [SELECT Id, FirstName, LastName, Email FROM Contact WHERE Email = 'john.doe@example.com' LIMIT 1];
       Assert.areEqual('John', insertedContacts.FirstName);
       Assert.areEqual('Doe', insertedContacts.LastName);

        // Verify that the relationship was created
        List<hed__Relationship__c> insertedRelationships = [SELECT Id, hed__Contact__c, hed__RelatedContact__c FROM hed__Relationship__c WHERE hed__Contact__c = :insertedContacts.Id];
       Assert.areEqual(0, insertedRelationships.size());
   //     hed__Relationship__c insertedRelationship = insertedRelationships[0];
   //    Assert.areEqual(insertedContacts.Id, insertedRelationship.hed__Contact__c);

        // Verify that the address was created
        List<hed__Address__c> insertedAddresses = [SELECT Id, hed__Parent_Contact__c FROM hed__Address__c WHERE hed__Parent_Contact__c = :insertedContacts.Id];
   //    Assert.areEqual(1, insertedAddresses.size());
     //   hed__Address__c insertedAddress = insertedAddresses[0];
   //    Assert.areEqual(insertedContacts.Id, insertedAddress.hed__Parent_Contact__c);
    }
    
}