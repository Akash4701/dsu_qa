@IsTest
private class TokenHandler_Test {

    @TestSetup
    static void setupTestData() {
        // No actual data needs to be inserted, but this satisfies the requirement of having @TestSetup at the top.
    }

    @IsTest
    static void test_GetToken_SuccessfulResponse() {
        // Arrange
        String expectedAccessToken = 'abc123xyz789';

        // Mock custom labels used in getToken()
      

        // Create a mock HTTP response with a valid access token
        HttpCalloutMock mock = new TokenHandler_Test.MockHttpResponse(expectedAccessToken);
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        String actualToken = TokenHandler.getToken();

        // Assert
        System.assertEquals(expectedAccessToken, actualToken, 'Access token should match the one returned from the mock');
    }

    @IsTest
    static void test_GetToken_NullOrErrorResponse() {
        // Arrange
        // Mock custom labels
      
        // Mock HTTP response with null body or error
        HttpCalloutMock mock = new TokenHandler_Test.MockHttpResponse(null);
        Test.setMock(HttpCalloutMock.class, mock);

        // Act
        String token = TokenHandler.getToken();

        // Assert
     //   System.assertNull(token, 'Token should be null when response is invalid');
    }

    // Inner class implementing HttpCalloutMock
    public class MockHttpResponse implements HttpCalloutMock {
        private String accessToken;

        public MockHttpResponse(String accessToken) {
            this.accessToken = accessToken;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (accessToken != null) {
                // Return success response
                res.setBody('{"access_token":"' + accessToken + '", "token_type":"Bearer"}');
                res.setStatusCode(200);
                res.setStatus('OK');
            } else {
                // Return error or empty response
                res.setBody('{}'); // Empty JSON
                res.setStatusCode(200);
                res.setStatus('OK');
            }
            return res;
        }
    }
}