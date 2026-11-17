@RestResource(urlMapping='/PFSLogout/*')
global without sharing class PFSLogoutServiceRestApi {

    private static final Integer HTTP_SUCCESS = 200;
    private static final Integer HTTP_BAD_REQUEST = 400;
    private static final Integer HTTP_NOT_FOUND = 404;

    @HttpPost
    global static void logout() {
        RestRequest request = RestContext.request;
        String sessionId = request.params.get('sessionId');

        if (String.isBlank(sessionId)) {
            sendError(HTTP_BAD_REQUEST, 'Missing sessionId parameter.');
            return;
        }

        List<Portal_Session__c> sessions = [
            SELECT Id, Contact__c, Login_Time__c, Session_Status__c
            FROM Portal_Session__c
            WHERE Id = :sessionId
            LIMIT 1
        ];

        if (sessions.isEmpty()) {
            sendError(HTTP_NOT_FOUND, 'Session not found.');
            return;
        }

        Portal_Session__c session = sessions[0];

        if (session.Session_Status__c == 'Completed') {
            sendError(HTTP_BAD_REQUEST, 'Session is already completed.');
            return;
        }

        session.Logout_Time__c = System.now();
        session.Session_Status__c = 'Completed';

        try {
            update session;
        } catch (Exception ex) {
            sendError(HTTP_BAD_REQUEST, 'Failed to update session: ' + ex.getMessage());
            return;
        }

        Portal_Session__c updated = [
            SELECT Id, Contact__c, Login_Time__c, Logout_Time__c, Session_Duration_Minutes__c, Session_Status__c
            FROM Portal_Session__c
            WHERE Id = :session.Id
            LIMIT 1
        ];

        LogoutResult result = new LogoutResult();
        result.success = true;
        result.sessionId = updated.Id;
        result.contactId = updated.Contact__c;
        result.loginTime = String.valueOf(updated.Login_Time__c);
        result.logoutTime = String.valueOf(updated.Logout_Time__c);
        result.durationMinutes = updated.Session_Duration_Minutes__c;
        result.sessionStatus = updated.Session_Status__c;

        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.statusCode = HTTP_SUCCESS;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }

    private static void sendError(Integer statusCode, String message) {
        LogoutResult result = new LogoutResult();
        result.success = false;
        result.errorMessage = message;
        RestContext.response.statusCode = statusCode;
        RestContext.response.headers.put('content-type', 'text/plain');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }

    public class LogoutResult {
        public Boolean success;
        public String errorMessage;
        public String sessionId;
        public String contactId;
        public String loginTime;
        public String logoutTime;
        public Decimal durationMinutes;
        public String sessionStatus;
    }
}