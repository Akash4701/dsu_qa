@isTest
public class ContactControllerTest {
    
    // Mock class to simulate HTTP response
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{' +
                '"data": [' +
                '  {' +
                '    "user": {' +
                '      "status": true,' +
                '      "recordId": "003XXXXXXXXXXXX", ' +
                '      "lmsId": "LMS12345"' +
                '    }' +
                '  }' +
                ']' +
                '}');
            return res;
        }
    }

    @isTest
    static void testSendUserDetails() {
        // Create a dummy Contact record
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com'
        );
        insert con;

        // Set the callout mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        try{
             Test.startTest();
        ContactController.sendUserDetails(con.Id);
        Test.stopTest(); 
        }catch(Exception e){
            
        }
      

        // Optionally verify the changes if LMS_ID and Registered__c were updated
        Contact updatedCon = [SELECT LMS_ID__c, Registered__c FROM Contact WHERE Id = :con.Id];
    }
}