@IsTest
public class RestApiUtilityTest {
    
    @IsTest
    static void testAddError() {
        // Setup test data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        List<RestApiUtility.ErrorBody> errors = new List<RestApiUtility.ErrorBody>();
        errors.add(new RestApiUtility.ErrorBody('Account', 'Name', 'Name is required'));

        // Call the method
        //RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST, errors);

        // Verify results
       //Assert.areEqual(RestApiUtility.HTTP_BAD_REQUEST, RestContext.response.statusCode);
        //Assert.areEqual('text/plain', RestContext.response.headers.get('content-type'));
        //RestApiUtility.ApiResponse result = (RestApiUtility.ApiResponse)JSON.deserialize(
            //RestContext.response.responseBody.toString(),
            //RestApiUtility.ApiResponse.class
        //);
    
        //Assert.areEqual(false, result.success);
       //Assert.areEqual(1, result.errorMessages.size());
        //Assert.areEqual('Name is required', result.errorMessages[0].errorMessage);
    }
    
    @IsTest
    static void testCreateSuccessGetResponse() {
        // Setup test data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Map<String, String> responseWrapper = new Map<String, String>();
        responseWrapper.put('key', 'value');
        
        // Call the method
        RestApiUtility.createSuccessGetResponse(responseWrapper);
        
        // Verify results
        Assert.areEqual(RestApiUtility.HTTP_SUCCESS, RestContext.response.statusCode);
       Assert.areEqual('application/json', RestContext.response.headers.get('Content-Type'));

    }
    
    @IsTest
    static void testCreateSuccessPostResponse() {
        // Setup test data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Map<String, String> responseWrapper = new Map<String, String>();
        responseWrapper.put('key', 'value');
        
        // Call the method
        RestApiUtility.createSuccessPostResponse(responseWrapper);
        
        // Verify results
        Assert.areEqual(RestApiUtility.HTTP_SUCCESS, RestContext.response.statusCode);
       Assert.areEqual('application/json', RestContext.response.headers.get('Content-Type'));

    }

    @IsTest
    static void testCreateSuccessPostResponseWithNull() {
        // Setup test data
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        RestApiUtility.createSuccessPostResponse(null);
        
        // Verify results
        Assert.areEqual(RestApiUtility.HTTP_SUCCESS, RestContext.response.statusCode);
      Assert.areEqual('application/json', RestContext.response.headers.get('Content-Type'));
        RestApiUtility.ApiPostResponse result = (RestApiUtility.ApiPostResponse)JSON.deserialize(
            RestContext.response.responseBody.toString(),
            RestApiUtility.ApiPostResponse.class
        );
       Assert.areEqual(true, result.success);
      Assert.areEqual(null, result.data);
    }
}