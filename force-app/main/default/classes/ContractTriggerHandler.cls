public class ContractTriggerHandler extends TriggerHandler{
	
    public override void processAfterUpdate(){
        /*EnrollFaculty();
        UnEnrollFaculty();*/
        sendEmailToFacultyAndAdmin();
    }
    

    
    public static void UnEnrollFaculty() {
        List<Contract> contracts = [SELECT Id, Faculty_Onboarding__r.Activities__c, Faculty_Onboarding__r.Term__c, Faculty_Onboarding__r.Faculty__c, Faculty_Onboarding__r.Course__c
                                    FROM Contract
                                    WHERE Id IN :Trigger.new
                                    AND Status = 'Cancelled'
                                    AND Revised_Contract_Status__c = 'Cancelled'];
        
        Set<String> activityIds = new Set<String>();
        Set<Id> contactIds = new Set<Id>();
        
        for (Contract contract : contracts) {
            String[] activityIdsArray = contract.Faculty_Onboarding__r.Activities__c.split(',');
            activityIds.addAll(activityIdsArray);
            contactIds.add(contract.Faculty_Onboarding__r.Faculty__c);
        }
        
        Map<String, hed__Course_Enrollment__c> courseEnrollmentByString = new Map<String, hed__Course_Enrollment__c>();
        for (hed__Course_Enrollment__c courseEnroll : [SELECT Id, hed__Contact__c, hed__Course_Offering__c, hed__Course_Offering__r.hed__Course__c, hed__Course_Offering__r.hed__Term__c, hed__Program_Enrollment__r.Id, hed__Program_Enrollment__r.hed__Affiliation__c, hed__Program_Enrollment__r.hed__Account__c
                                                       FROM hed__Course_Enrollment__c
                                                       WHERE hed__Course_Offering__c IN (SELECT Course_Offering__c FROM Activity__c WHERE Id IN :activityIds)
                                                       AND RecordType.Name = 'Faculty'
                                                       AND hed__Contact__c IN :contactIds]) 
        {
            courseEnrollmentByString.put(courseEnroll.hed__Contact__c + '_' + courseEnroll.hed__Course_Offering__r.hed__Course__c, courseEnroll);
        }
        
        List<Activity__c> activitiesToUpdate = new List<Activity__c>();
        for (Activity__c activity : [SELECT Id, isAccepted__c, Faculty1__c
                                     FROM Activity__c
                                     WHERE Id IN :activityIds]) 
        {
            activity.isAccepted__c = false;
            activity.Faculty1__c = null;
            activitiesToUpdate.add(activity);
        }
        
        List<hed__Course_Enrollment__c> courseEnrollmentsToUpdate = new List<hed__Course_Enrollment__c>();
    for (Contract contract : contracts) 
    {
        String key = contract.Faculty_Onboarding__r.Faculty__c + '_' + contract.Faculty_Onboarding__r.Course__c;
        if (courseEnrollmentByString.containsKey(key)) {
            hed__Course_Enrollment__c enrollment = courseEnrollmentByString.get(key);
            enrollment.hed__Status__c = 'former'; 
            courseEnrollmentsToUpdate.add(enrollment);
        }
    }
    
    if (!courseEnrollmentsToUpdate.isEmpty()) {
        update courseEnrollmentsToUpdate;
    }
    
        system.debug(activitiesToUpdate);
        if (!activitiesToUpdate.isEmpty()) {
            update activitiesToUpdate;
        }
    }
    
    public static void sendEmailToFacultyAndAdmin() {
        Map<Id,Contract> ContractsById = (Map<Id,Contract>)trigger.oldMap;
        List<Contract> contracts = [SELECT Id, Name, Contact__r.Id, Contact__r.Email, Status, Revised_Contract_Status__c from Contract where Id IN:trigger.new];//(List<Contract>)trigger.new;
        
        EmailTemplate et = [Select Id, Subject, HtmlValue from EmailTemplate where Name='FacultyContractAcceptEmail'];
        EmailTemplate contractAcceptedEmailTemplt = [Select Id, Subject, HtmlValue from EmailTemplate where Name='Contract Accepted Email to Admin'];
        EmailTemplate contractRejectedEmailTemplt = [Select Id, Subject, HtmlValue from EmailTemplate where Name='Contract Rejected Email to Admin'];
        EmailTemplate contractCancelledEmailTemplt = [Select Id, Subject, HtmlValue from EmailTemplate where Name='Contract Cancelled Email to Faculty'];

        Messaging.Email[] messages = new Messaging.Email[0];
        OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName='Do Not Reply' LIMIT 1];
        
        for(Contract contract:contracts)
        {
            if( (ContractsById.get(contract.Id).Status!=contract.Status && contract.Status=='Accepted') || (/*ContractsById.get(contract.Id).Revised_Contract_Status__c!=null &&*/ ContractsById.get(contract.Id).Revised_Contract_Status__c!=contract.Revised_Contract_Status__c && contract.Revised_Contract_Status__c=='Accepted') ){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(contract.Contact__r.Id);
                mail.setWhatId(contract.Id);
                mail.setSaveAsActivity(true);
                mail.setTemplateId(et.Id);
                if ( owea != null) {
                    mail.setOrgWideEmailAddressId(owea.Id);
                }
                messages.add(mail);
                
                Messaging.SingleEmailMessage mail2 = new Messaging.SingleEmailMessage();
                mail2.setTargetObjectId(contract.Contact__r.Id);
                mail2.setWhatId(contract.Id);
                mail2.setToAddresses(new List<String> {System.Label.Admin_Email_Id});
                mail2.setSaveAsActivity(true);
                mail2.setTemplateId(contractAcceptedEmailTemplt.Id);
                mail2.setTreatTargetObjectAsRecipient(false);
                if ( owea != null) {
                    mail2.setOrgWideEmailAddressId(owea.Id);
                }
                messages.add(mail2);
            }
            
            if( (ContractsById.get(contract.Id).Status!=contract.Status && contract.Status=='Rejected') || (/*ContractsById.get(contract.Id).Revised_Contract_Status__c!=null &&*/ ContractsById.get(contract.Id).Revised_Contract_Status__c!=contract.Revised_Contract_Status__c && contract.Revised_Contract_Status__c=='Rejected') ){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(contract.Contact__r.Id);
                mail.setWhatId(contract.Id);
                mail.setToAddresses(new List<String> {System.Label.Admin_Email_Id});
                mail.setSaveAsActivity(true);
                mail.setTreatTargetObjectAsRecipient(false);
                mail.setTemplateId(contractRejectedEmailTemplt.Id);
                if ( owea != null) {
                    mail.setOrgWideEmailAddressId(owea.Id);
                }
                messages.add(mail);
            }
            
            if( (ContractsById.get(contract.Id).Status!=contract.Status && contract.Status=='Cancelled') || (/*ContractsById.get(contract.Id).Revised_Contract_Status__c!=null &&*/ ContractsById.get(contract.Id).Revised_Contract_Status__c!=contract.Revised_Contract_Status__c && contract.Revised_Contract_Status__c=='Cancelled') ){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(contract.Contact__r.Id);
                mail.setWhatId(contract.Id);
                mail.setToAddresses(new List<String> {contract.Contact__r.Email});
                mail.setSaveAsActivity(true);
                mail.setTemplateId(contractCancelledEmailTemplt.Id);
                mail.setTreatTargetObjectAsRecipient(false);
                if ( owea != null) {
                    mail.setOrgWideEmailAddressId(owea.Id);
                }
                messages.add(mail);
            }
        }
        
        Messaging.sendEmail(messages, true);
    }
        /*public static void EnrollFaculty() {
        testCoverage();
        List<Faculty_Onboarding__c> facultyOnbardings = new List<Faculty_Onboarding__c>();
        
        facultyOnbardings=[Select Id from Faculty_Onboarding__c where Id IN(Select Faculty_Onboarding__c from Contract where Id=:trigger.new and (Status='Accepted' OR Revised_Contract_Status__c='Accepted'))];
        
        if(!facultyOnbardings.isEmpty()){
            FacultyOnbordingHandler.EnrollFaculty(facultyOnbardings,'Adjunct');
        }
    }*/
 
}