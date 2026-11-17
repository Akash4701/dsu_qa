/**
 * PFSLogoutServiceRestApiTest
 * ---------------------------
 * Exercises the /PFSLogout REST endpoint: happy path plus the missing,
 * not-found, and already-completed error branches.
 */
@isTest
private class PFSLogoutServiceRestApiTest {

    @testSetup
    static void setupData() {
        Contact ct = new Contact(FirstName = 'Log', LastName = 'Out', Email = 'logout@example.com');
        insert ct;

        insert new Portal_Session__c(
            Contact__c        = ct.Id,
            Login_Time__c     = Datetime.now().addMinutes(-45),
            Session_Status__c = 'Active'
        );
    }

    private static PFSLogoutServiceRestApi.LogoutResult callLogout(String sessionId) {
        RestRequest req = new RestRequest();
        req.httpMethod  = 'POST';
        req.requestUri  = '/PFSLogout';
        if (sessionId != null) {
            req.params.put('sessionId', sessionId);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();

        PFSLogoutServiceRestApi.logout();

        return (PFSLogoutServiceRestApi.LogoutResult) JSON.deserialize(
            RestContext.response.responseBody.toString(),
            PFSLogoutServiceRestApi.LogoutResult.class
        );
    }

    @isTest
    static void testSuccessfulLogout() {
        Portal_Session__c s = [SELECT Id FROM Portal_Session__c LIMIT 1];

        Test.startTest();
        PFSLogoutServiceRestApi.LogoutResult result = callLogout(s.Id);
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'HTTP 200 on success');
        System.assertEquals(true, result.success, 'Success flag set');
        System.assertEquals('Completed', result.sessionStatus, 'Status flipped to Completed');
        System.assertNotEquals(null, result.logoutTime, 'Logout time populated');

        Portal_Session__c updated = [SELECT Session_Status__c, Logout_Time__c FROM Portal_Session__c WHERE Id = :s.Id];
        System.assertEquals('Completed', updated.Session_Status__c, 'Record persisted as Completed');
        System.assertNotEquals(null, updated.Logout_Time__c, 'Logout time persisted');
    }

    @isTest
    static void testMissingSessionId() {
        Test.startTest();
        PFSLogoutServiceRestApi.LogoutResult result = callLogout(null);
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'HTTP 400 when sessionId missing');
        System.assertEquals(false, result.success, 'Failure flagged');
        System.assert(result.errorMessage.contains('Missing sessionId'), 'Explains the missing parameter');
    }

    @isTest
    static void testSessionNotFound() {
        // A syntactically valid but non-existent Portal_Session__c Id.
        Id fakeId = Portal_Session__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';

        Test.startTest();
        PFSLogoutServiceRestApi.LogoutResult result = callLogout(fakeId);
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode, 'HTTP 404 when not found');
        System.assertEquals(false, result.success, 'Failure flagged');
        System.assert(result.errorMessage.contains('not found'), 'Explains the missing record');
    }

    @isTest
    static void testAlreadyCompleted() {
        Portal_Session__c s = [SELECT Id FROM Portal_Session__c LIMIT 1];
        s.Session_Status__c = 'Completed';
        s.Logout_Time__c    = Datetime.now();
        update s;

        Test.startTest();
        PFSLogoutServiceRestApi.LogoutResult result = callLogout(s.Id);
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'HTTP 400 when already completed');
        System.assertEquals(false, result.success, 'Failure flagged');
        System.assert(result.errorMessage.contains('already completed'), 'Explains the completed state');
    }
}