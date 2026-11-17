global class MockEnrollmentRespBBClass implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        // Mock the getAccessToken endpoint
        if (req.getEndpoint().contains('oauth2/token')) {
            res.setStatusCode(200);
            res.setBody('{"access_token": "mockAccessToken"}');
        }
        // Mock the createUser endpoint
        else if (req.getEndpoint().contains('users') && req.getMethod() == 'POST') {
            res.setStatusCode(201);
            res.setBody('{"id": "mockUserId", "userName": "prabhakaran@tsquaredc.com", "password": "mockPassword"}');
        }
        // Mock the updateCourse endpoint
        else if (req.getEndpoint().contains('courses/') && req.getMethod() == 'PATCH') {
            res.setStatusCode(200);
            res.setBody('{}');  // Returning an empty JSON object
        }
        // Mock the deleteCourse endpoint
        else if (req.getEndpoint().contains('courses/') && req.getMethod() == 'DELETE') {
            res.setStatusCode(204);
            res.setBody('');  // Returning an empty body for DELETE
        } 
        
         else if (req.getEndpoint().contains('users/') && req.getMethod() == 'DELETE') {
            res.setStatusCode(204);
            res.setBody('');  // Returning an empty body for DELETE
        } 
        // Mock the enrollment endpoint
        else if (req.getEndpoint().contains('courses/') && req.getEndpoint().contains('/users/') && req.getMethod() == 'PUT') {
            res.setStatusCode(201);
            res.setBody('{"id": "mockEnrollmentId"}');
        } else {
            res.setStatusCode(404);
            res.setBody('{"error": "Endpoint not found"}');
        }

        return res;
    }
}