public class MockHttpResponseForTerms implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        // Create a mock HTTP response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"success": "true", "data": [{"name": "Test Term"}]}');
        res.setStatusCode(200);
        return res;
    }
}