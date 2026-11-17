@isTest
public class AffiliationControllerTest {
    
  public class MockHttpResponseSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String mockResponse = '{' +
                '"Status": "Process Success",' +
                '"Resource": [{' +
                '"StudentID": "STU001",' +
                '"Program": "Computer Science",' +
                '"email": "student@test.com",' +
                '"stdname": "John Doe",' +
                '"fathername": "Robert Doe",' +
                '"mobile": 9876543210,' +
                '"institutename": "Test Institute",' +
                '"InstituteID": "INST001",' +
                '"ipaddress": "192.168.1.1",' +
                '"programcode": "CS101",' +
                '"mode": "Online",' +
                '"AdmissionDate": "27/05/2025",' +
                '"AdmissionDetails": "Regular Admission",' +
                '"UniversityName": "Test University",' +
                '"CourseName": "Bachelor of Computer Science",' +
                // '"ABCID": "ABC123",' +
                // '"DEBUniqueID": "DEB123",' +
                '"Gender": "Male",' +
                '"DOB": "01/01/2000",' +
                '"EnrollmentNumber": 12345,' +
                '"UniqueNumber": 67890' +
                '}]' +
                '}';
            
            res.setBody(mockResponse);
            return res;
        }
    }
    
    public class MockHttpResponseUnSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String mockResponse = '{' +
                '"Status": "Process UnSuccess",' +
                '"Resource": []' +
                '}';
            
            res.setBody(mockResponse);
            return res;
        }
    }
    
    public class MockHttpResponseError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    public class MockHttpResponseEmptyResource implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String mockResponse = '{' +
                '"Status": "Process Success",' +
                '"Resource": []' +
                '}';
            
            res.setBody(mockResponse);
            return res;
        }
    }
    
    public class MockHttpResponseInvalidResource implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String mockResponse = '{' +
                '"Status": "Process Success",' +
                '"Resource": "Not a list"' +
                '}';
            
            res.setBody(mockResponse);
            return res;
        }
    }
    
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name ='Test');
        insert acc;
        Contact con = new Contact(DEB_ID__c='022501558907',LastName='Test',AccountId=acc.Id,Nationality__c = 'Indian',MailingCountry = 'India',Student_Category__c = 'OBC',Aadhar_Number__c='65979');
        insert con;
        
        hed__Affiliation__c testAff = new hed__Affiliation__c(Institute_Name__c='test',Institute_ID__c='232xdsf',IP_address__c='123.3r3',Mode__c='test',Admission_Date__c=System.today(),Admission_Details__c='test',Course_Name__c='test',Gender__c='Male',Enrollment_Number__c='1332',Unique_Number__c=1313);
        testAff.hed__Contact__c = con.Id;
        
        insert testAff;
        Student_Detail_URL__c urlRecord = new Student_Detail_URL__c(
            Name = 'UGC URL',
            Student_URL__c = 'https://dsu-dev-api.ken42.com/api/v1/deb/studentdetail?DEBUniqueID='
        );
        insert urlRecord;
        DSU_Name__c DSU = new DSU_Name__c(Name = 'Dayananda Sagar University',
                                          Record_Id__c = acc.Id,
                                          Mode_of_Education__c = 'Online(OL)',
                                          Government_issued_Identifier__c = 'AADHAR');
        insert DSU;
    }
    
    @isTest
    static void testSendDebIdToNode_Success() {
        hed__Affiliation__c testAff = [SELECT Id, DEB_ID__c FROM hed__Affiliation__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        String result = AffiliationController.sendDebIdToNode(testAff.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testSendDebIdToNode_ProcessUnSuccess() {
        hed__Affiliation__c testAff = [SELECT Id, DEB_ID__c FROM hed__Affiliation__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseUnSuccess());
        
        String result = AffiliationController.sendDebIdToNode(testAff.Id);
        Test.stopTest();
        
        
        hed__Affiliation__c updatedAff = [SELECT Status__c FROM hed__Affiliation__c WHERE Id = :testAff.Id];
    }
    
    @isTest
    static void testSendDebIdToNode_HttpError() {
        hed__Affiliation__c testAff = [SELECT Id, DEB_ID__c FROM hed__Affiliation__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());
        
        String result = AffiliationController.sendDebIdToNode(testAff.Id);
        Test.stopTest();
        
        System.assert(result.contains('Error: HTTP status 500'), 'Expected HTTP error message');
    }
    
    @isTest
    static void testSendDebIdToNode_EmptyResourceList() {
        hed__Affiliation__c testAff = [SELECT Id, DEB_ID__c FROM hed__Affiliation__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseEmptyResource());
        
        String result = AffiliationController.sendDebIdToNode(testAff.Id);
        Test.stopTest();
        
        System.assertEquals('No student data found in Resource list.', result, 'Expected empty resource message');
    }
    
    @isTest
    static void testSendDebIdToNode_InvalidResourceType() {
        hed__Affiliation__c testAff = [SELECT Id, DEB_ID__c FROM hed__Affiliation__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseInvalidResource());
        
        String result = AffiliationController.sendDebIdToNode(testAff.Id);
        Test.stopTest();
        
        System.assertEquals('Unexpected response: Resource is not a list.', result, 'Expected invalid resource type message');
    }
    
    @isTest
    static void testSendDebIdToNode_Exception() {
        hed__Affiliation__c testAff = [SELECT Id, DEB_ID__c,Institute_Name__c,Institute_ID__c,Unique_Number__c,Enrollment_Number__c,Gender__c,Course_Name__c,Admission_Details__c,Admission_Date__c,Mode__c,IP_address__c FROM hed__Affiliation__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseInvalidResource());
        
        String result = AffiliationController.sendDebIdToNode(testAff.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testParseDate_ValidDate() {
        hed__Affiliation__c testAff = [SELECT Id FROM hed__Affiliation__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        String result = AffiliationController.sendDebIdToNode(testAff.Id);
        Test.stopTest();
        
        hed__Affiliation__c updatedAff = [SELECT Date_Of_Birth__c FROM hed__Affiliation__c WHERE Id = :testAff.Id];
    }
    
    @isTest
    static void testHttpRequestParameters() {
        hed__Affiliation__c testAff = [SELECT Id, DEB_ID__c FROM hed__Affiliation__c LIMIT 1];
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        String result = AffiliationController.sendDebIdToNode(testAff.Id);
        Test.stopTest();
        
    }
    @isTest static void testDateParsers() {
        Date d1 = AffiliationController.parseDate('27/05/2025');
        System.assertNotEquals(null, d1, 'Expected a valid Date object');
        
        Date d2 = AffiliationController.parseDate('bad-date');
        System.assertEquals(null, d2, 'Should return null for invalid date');
        
        DateTime dt1 = AffiliationController.parseDateTime('2025-05-27 10:00:00');
        System.assertNotEquals(null, dt1, 'Expected a valid DateTime object');
        
        DateTime dt2 = AffiliationController.parseDateTime('bad-datetime');
        System.assertEquals(null, dt2, 'Should return null for invalid datetime');
    }
}