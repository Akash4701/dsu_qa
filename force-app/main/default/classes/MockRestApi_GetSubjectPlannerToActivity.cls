@isTest
global class MockRestApi_GetSubjectPlannerToActivity implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"message": "Mock response"}'); // Simulated response
        res.setStatusCode(200);
        return res;
    }
}