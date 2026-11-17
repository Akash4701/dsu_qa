/**
 * @description Sends the student portal OTP email through Amazon SES instead of Salesforce email.
 *
 *              WHY THIS EXISTS
 *              Salesforce allows about 5,000 single emails per org per day. When that limit is used up, students
 *              cannot receive their login OTP. Emails sent through Amazon SES do not count against the Salesforce
 *              limit, so OTP delivery keeps working.
 *
 *              ON/OFF SWITCH (no deployment needed)
 *              Setup > Custom Settings > CRM Org Parameters > org default record:
 *              - Use SSO checked        -> no OTP email is sent (portal logs students in with SSO). SSO wins.
 *              - Use Amazon SES checked -> the OTP email is sent through Amazon SES.
 *              - Both unchecked         -> the original Salesforce email is used (same as before this change).
 *
 *              WHAT IS CONFIGURED OUTSIDE THE CODE (nothing secret or environment-specific is hardcoded)
 *              - Named Credential AWS_SES               : SES endpoint, https://email.ap-south-1.amazonaws.com
 *              - External Credential AWS_SES_Credential : AWS access key + secret, entered in Setup only
 *              - Custom Label SES_From_Address          : sender, "Dayananda Sagar University <noreply@thekenverse.com>"
 *              - Permission Set SES_Email_Sender        : lets the portal API user use the AWS credential
 *
 *              The email content is the existing template PFSOtpEmailTemplate, unchanged; only the sender differs.
 *              If Amazon SES fails, the caller sends the original Salesforce email so the student still gets the OTP.
 *              Every Amazon SES attempt is recorded in Email Delivery Logs (App Launcher > Email Delivery Logs):
 *              Sent (with the SES Message Id) or Failed (with the HTTP status / error). The OTP is never logged.
 * @group OTP
 */
public inherited sharing class AmazonSesOtpService {
    /**
     * @description What the caller must do after sendStudentOtp():
     *              SENT_BY_SES          - Amazon SES sent the email; nothing else to do.
     *              USE_SALESFORCE_EMAIL - send the original Salesforce email (switch is off, or SES failed).
     *              NOT_SENT             - Use SSO is checked; no OTP email is sent.
     */
    public enum Outcome {
        SENT_BY_SES,
        USE_SALESFORCE_EMAIL,
        NOT_SENT
    }

    // Existing student OTP template (same one the original Salesforce email uses) and the merge field in it
    // that holds the OTP. The template is read as stored and the merge field is replaced here, because the
    // OTP record is saved only after this call (Salesforce does not allow an HTTP callout after DML).
    @TestVisible
    private static String templateName = 'PFSOtpEmailTemplate';
    private static final String OTP_MERGE_FIELD = '{{{One_Time_Password__c.OTP__c}}}';

    // Amazon SES v2 "SendEmail" API, called through the AWS_SES Named Credential, which signs the request
    // with the AWS key from the External Credential.
    private static final String SES_SEND_EMAIL = 'callout:AWS_SES/v2/email/outbound-emails';

    // Short timeout: if Amazon SES is slow, fall back quickly instead of keeping the student waiting.
    private static final Integer TIMEOUT_MS = 5000;
    private static final Integer HTTP_OK = 200;
    private static final String CHARSET = 'UTF-8';

    // Email Delivery Log status values.
    private static final String STATUS_SENT = 'Sent';
    private static final String STATUS_FAILED = 'Failed';

    // Test seam: unit tests set the CRM Org Parameters switch here instead of relying on org data.
    @TestVisible
    private static CRM_Org_Parameters__c switchOverride;

    /**
     * @description Sends the student OTP email through Amazon SES when the org switch allows it.
     *              Call it BEFORE any DML in the request, because Salesforce blocks HTTP callouts after DML.
     * @param recipientEmail Student's DSU email address.
     * @param otp One-time password to put into the email.
     * @return SENT_BY_SES, USE_SALESFORCE_EMAIL (caller sends the original email) or NOT_SENT (SSO is on).
     */
    public static Outcome sendStudentOtp(String recipientEmail, String otp) {
        CRM_Org_Parameters__c orgSwitch = switchOverride != null
            ? switchOverride
            : CRM_Org_Parameters__c.getOrgDefaults();

        if (orgSwitch.Use_SSO__c == true) {
            return Outcome.NOT_SENT;
        }
        if (orgSwitch.Use_Amazon_SES__c != true || String.isBlank(recipientEmail)) {
            return Outcome.USE_SALESFORCE_EMAIL;
        }
        return sendThroughSes(recipientEmail.trim(), otp) ? Outcome.SENT_BY_SES : Outcome.USE_SALESFORCE_EMAIL;
    }

    /**
     * @description Builds the email from the existing template, posts it to Amazon SES and records the result in
     *              Email Delivery Logs. Any problem returns false so the caller falls back to Salesforce email:
     *              a student login must never fail because of the email provider.
     * @param recipientEmail Student's DSU email address.
     * @param otp One-time password.
     * @return True when Amazon SES accepted the email.
     */
    private static Boolean sendThroughSes(String recipientEmail, String otp) {
        Email_Delivery_Log__c log = new Email_Delivery_Log__c(Recipient__c = recipientEmail.left(255), Status__c = STATUS_FAILED);
        String details;
        try {
            HttpResponse response = new Http().send(buildRequest(recipientEmail, otp));
            if (response.getStatusCode() == HTTP_OK) {
                log.Status__c = STATUS_SENT;
                // The MessageId identifies this email in the AWS SES console.
                details = 'SES MessageId: ' + readMessageId(response.getBody());
            } else {
                details = 'HTTP ' + response.getStatusCode() + ': ' + response.getBody();
            }
        } catch (Exception sesError) {
            // Callout timeout, missing AWS key access, missing template, ... -> logged, then Salesforce email fallback.
            details = sesError.getTypeName() + ': ' + sesError.getMessage();
        }
        log.Details__c = details.left(32000);
        // System mode + partial success: the portal API user needs no access to the log object, and a logging
        // problem can never break the student's login.
        Database.insert(new List<Email_Delivery_Log__c>{ log }, false, AccessLevel.SYSTEM_MODE);
        return log.Status__c == STATUS_SENT;
    }

    /**
     * @description Reads the MessageId from the SES response; it identifies the email in the AWS SES console.
     * @param responseBody JSON returned by SES, e.g. {"MessageId":"0109..."}.
     * @return MessageId, or null when it cannot be read.
     */
    private static String readMessageId(String responseBody) {
        try {
            Object messageId = ((Map<String, Object>) JSON.deserializeUntyped(responseBody)).get('MessageId');
            return messageId == null ? null : String.valueOf(messageId);
        } catch (Exception parseError) {
            return null;
        }
    }

    /**
     * @description Creates the SES SendEmail request: existing template subject and HTML with the OTP filled in,
     *              sender from the Custom Label, recipient = the student.
     * @param recipientEmail Student's DSU email address.
     * @param otp One-time password.
     * @return HTTP request ready to send.
     */
    private static HttpRequest buildRequest(String recipientEmail, String otp) {
        EmailTemplate template = [
            SELECT Subject, HtmlValue
            FROM EmailTemplate
            WHERE Name = :templateName
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (String.isBlank(otp) || template.HtmlValue == null || !template.HtmlValue.contains(OTP_MERGE_FIELD)) {
            // Never send an OTP email that does not contain the OTP.
            throw new OtpEmailException('Template ' + templateName + ' does not contain ' + OTP_MERGE_FIELD);
        }

        Map<String, Object> email = new Map<String, Object>{
            'FromEmailAddress' => System.Label.SES_From_Address,
            'Destination' => new Map<String, Object>{ 'ToAddresses' => new List<String>{ recipientEmail } },
            'Content' => new Map<String, Object>{
                'Simple' => new Map<String, Object>{
                    'Subject' => new Map<String, Object>{ 'Data' => template.Subject, 'Charset' => CHARSET },
                    'Body' => new Map<String, Object>{
                        'Html' => new Map<String, Object>{
                            'Data' => template.HtmlValue.replace(OTP_MERGE_FIELD, otp),
                            'Charset' => CHARSET
                        }
                    }
                }
            }
        };

        HttpRequest request = new HttpRequest();
        request.setEndpoint(SES_SEND_EMAIL);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MS);
        request.setBody(JSON.serialize(email));
        return request;
    }

    /**
     * @description Raised when the template cannot produce a valid OTP email. It is always caught in
     *              sendThroughSes() and leads to the Salesforce email fallback.
     */
    public class OtpEmailException extends Exception {
    }
}