@isTest
global class HttpMockGenerator implements HttpCalloutMock {    
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(200);
        response.setBody('{"access_token":"abcd1234","id":"12345"}');
        return response;
    }
}