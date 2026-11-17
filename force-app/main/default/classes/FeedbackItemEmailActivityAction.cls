public with sharing class FeedbackItemEmailActivityAction {
    public class Request {
        @InvocableVariable(required=true label='Feedback Item Id')
        public Id feedbackItemId;

        @InvocableVariable(label='Template Developer Name')
        public String templateDeveloperName;

        @InvocableVariable(label='Is Reminder Email')
        public Boolean isReminder;
    }

    public class Response {
        @InvocableVariable(label='Feedback Item Id')
        public Id feedbackItemId;

        @InvocableVariable(label='Success')
        public Boolean success;

        @InvocableVariable(label='Message')
        public String message;
    }

    @InvocableMethod(
        label='Send Feedback Email and Save Activity'
        description='Sends a Feedback Item email to the Assignee contact and saves it to the activity timeline.'
    )
    public static List<Response> sendEmails(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        Set<Id> feedbackItemIds = new Set<Id>();
        Set<String> templateDeveloperNames = new Set<String>();

        for (Request req : requests) {
            Response res = new Response();
            res.feedbackItemId = req == null ? null : req.feedbackItemId;
            responses.add(res);

            if (req == null || req.feedbackItemId == null) {
                res.success = false;
                res.message = 'Feedback Item Id is required.';
                continue;
            }

            feedbackItemIds.add(req.feedbackItemId);
            templateDeveloperNames.add(resolveTemplateDeveloperName(req));
        }

        if (feedbackItemIds.isEmpty()) {
            return responses;
        }

        Map<Id, Feedback_Item__c> feedbackItemById = new Map<Id, Feedback_Item__c>([
            SELECT Id, Assignee__c, Start_Date__c, Feedback_Scheduler__r.Term__r.Program_Office_Email__c
            FROM Feedback_Item__c
            WHERE Id IN :feedbackItemIds
        ]);

        Map<String, EmailTemplate> templateByDeveloperName = new Map<String, EmailTemplate>();
        for (EmailTemplate template : [
            SELECT Id, DeveloperName
            FROM EmailTemplate
            WHERE DeveloperName IN :templateDeveloperNames
        ]) {
            templateByDeveloperName.put(template.DeveloperName, template);
        }

        Id orgWideEmailAddressId = FeedbackEmailSettings.orgWideEmailAddressId();
        List<Messaging.SingleEmailMessage> messages = new List<Messaging.SingleEmailMessage>();
        List<Integer> responseIndexes = new List<Integer>();

        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            Response res = responses[i];
            if (res.success == false) {
                continue;
            }

            Feedback_Item__c feedbackItem = feedbackItemById.get(req.feedbackItemId);
            if (feedbackItem == null) {
                res.success = false;
                res.message = 'Feedback Item was not found.';
                continue;
            }
            if (feedbackItem.Assignee__c == null) {
                res.success = false;
                res.message = 'Feedback Item Assignee is required.';
                continue;
            }
            // Guarantee the email only goes out once the Feedback Item's own Start_Date__c
            // has arrived, regardless of when/why this action was invoked.
            if (feedbackItem.Start_Date__c == null || feedbackItem.Start_Date__c > Date.today()) {
                res.success = false;
                res.message = 'Feedback Item Start Date has not arrived yet — email not sent.';
                continue;
            }

            String templateDeveloperName = resolveTemplateDeveloperName(req);
            EmailTemplate template = templateByDeveloperName.get(templateDeveloperName);
            if (template == null) {
                res.success = false;
                res.message = 'Email template was not found: ' + templateDeveloperName;
                continue;
            }

            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setTargetObjectId(feedbackItem.Assignee__c);
            message.setWhatId(feedbackItem.Id);
            message.setTemplateId(template.Id);
            message.setSaveAsActivity(true);
            if (orgWideEmailAddressId != null) {
                message.setOrgWideEmailAddressId(orgWideEmailAddressId);
            }
            String programOfficeEmail = feedbackItem.Feedback_Scheduler__r?.Term__r?.Program_Office_Email__c;
            if (String.isNotBlank(programOfficeEmail)) {
                message.setCcAddresses(new List<String>{ programOfficeEmail });
            }

            messages.add(message);
            responseIndexes.add(i);
        }

        if (!messages.isEmpty()) {
            Messaging.SendEmailResult[] sendResults = Messaging.sendEmail(messages, false);
            for (Integer i = 0; i < sendResults.size(); i++) {
                Response res = responses[responseIndexes[i]];
                if (sendResults[i].isSuccess()) {
                    res.success = true;
                    res.message = 'Email sent and activity saved.';
                } else {
                    res.success = false;
                    res.message = buildErrorMessage(sendResults[i]);
                }
            }
        }

        return responses;
    }

    private static String resolveTemplateDeveloperName(Request req) {
        if (req != null && String.isNotBlank(req.templateDeveloperName)) {
            return req.templateDeveloperName.trim();
        }
        if (req != null && req.isReminder == true) {
            return FeedbackEmailSettings.reminderTemplateDeveloperName();
        }
        return FeedbackEmailSettings.firstTemplateDeveloperName();
    }

    private static String buildErrorMessage(Messaging.SendEmailResult result) {
        List<String> messages = new List<String>();
        for (Messaging.SendEmailError error : result.getErrors()) {
            messages.add(String.valueOf(error.getStatusCode()) + ': ' + error.getMessage());
        }
        return messages.isEmpty() ? 'Email send failed.' : String.join(messages, '; ');
    }
}