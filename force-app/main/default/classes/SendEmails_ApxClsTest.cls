@isTest
public class SendEmails_ApxClsTest {
    @isTest
    static void testEmailSend_Success() {
        // Arrange test data
        String email = 'testuser1@example.com,testuser2@example.com';
        String subject = 'Test Email Subject';
        String body = '<p>This is a test email body</p>';

        Test.startTest();

        // Act: Call the method
        String result = SendEmails_ApxCls.emailSend(email, subject, body);

        Test.stopTest();

        // Assert
        System.debug('Email Send Response: ' + result);
        System.assert(result.contains('"Status":"200"'), 'Should return success response');

        // Optionally verify if email was queued (not actually sent in test context)
        List<Messaging.SendEmailResult> results = Limits.getEmailInvocations() > 0 ? 
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {}) : 
            new List<Messaging.SendEmailResult>();
        System.assertEquals(true, result.contains('Email Sent'), 'Email should be sent');
    }

    @isTest
    static void testEmailSend_InvalidEmail() {
        // Pass an invalid email to simulate failure
        String email = 'invalidemail'; // not a valid format
        String subject = 'Subject';
        String body = 'Body';
        try{
            Test.startTest();
        String result = SendEmails_ApxCls.emailSend(email, subject, body);
        Test.stopTest();
}
        catch(Exception e){
}
        
    }
}