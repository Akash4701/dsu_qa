@isTest
global class RestApi_CreateSessionTestMOC implements HttpCalloutMock {
    // Implement the respond method to simulate the HTTP response
    global HTTPResponse respond(HTTPRequest req) {
        // Create a mock HTTP response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        
        // Simulate a successful response with JSON body
        res.setBody('{"success": true, "message": "Mock response"}');
        res.setStatusCode(200); // Simulate a successful response
        
        return res;
    }
}