public class SendEmails_ApxCls {
    public static String emailSend(String emailIds, String subject, String bdy){
        String response;
        try{
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = emailIds.split(',');
            System.debug('toAddresses count'+toAddresses.Size());
            mail.setBccAddresses(toAddresses);
            System.debug('toAddresses'+toAddresses);
            mail.setSubject(subject);
            mail.setHtmlBody(bdy);
            if(!Test.isRunningTest()){
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
            response='{"Status":"200","Message":"Email Sent Succesfully"}';
        }catch(DmlException e) {
            System.debug('The following exception has occurred: ' + e.getMessage());
            response=' {"Status":"400","Message":"'+e.getMessage()+'"}';
        }
        return response;
    }
}