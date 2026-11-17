public class ExamCycleTriggerHandler {
    /**
     * Sends hall ticket publish notifications when Publish_Hall_Ticket__c is set.
     */
    public static void handlePublishHallTicket(
        List<Exam_Cycle__c> newList,
        Map<Id, Exam_Cycle__c> oldMap,
        Boolean isInsert
    ) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        // Identify cycles that should trigger notifications.
        Set<Id> cycleIds = new Set<Id>();
        for (Exam_Cycle__c ec : newList) {
            Boolean publish = ec.Publish_Hall_Ticket__c == true;
            Boolean wasPublish = (!isInsert && oldMap != null && oldMap.containsKey(ec.Id))
                ? oldMap.get(ec.Id).Publish_Hall_Ticket__c
                : false;

            if (publish && (isInsert || publish != wasPublish)) {
                cycleIds.add(ec.Id);
            }
        }

        if (cycleIds.isEmpty()) {
            return;
        } else{
			System.debug('cycleIds'+cycleIds);
		}

        // Exams in the published cycles that are active and have results published.
        List<Exam__c> exams = [
            SELECT Id, Exam_Cycle__c
            FROM Exam__c
            WHERE Exam_Cycle__c IN :cycleIds
                AND Exam_Cycle__r.Publish_Hall_Ticket__c = true
                AND Exam_Cycle__r.Is_Active__c = true
        ];

        if (exams.isEmpty()) {
            return;
        }

        Set<Id> examIds = new Set<Id>();
        for (Exam__c ex : exams) {
            examIds.add(ex.Id);
        }

        // Exam connections for eligible students.
        List<Exam_Connections__c> examConnections = [
            SELECT Id, Student_Name__c, Exam_Name__c
            FROM Exam_Connections__c
            WHERE Exam_Name__c IN :examIds
                AND Eligibility__c = 'Eligible'
                AND Course_Connection_ID__r.Exam_Eligibility__c = 'Eligible'
                AND Course_Connection_ID__r.Enrollment_Status__c = 'Enrolled'
        ];

        if (examConnections.isEmpty()) {
            return;
        }

        Set<Id> studentContactIds = new Set<Id>();
        for (Exam_Connections__c ec : examConnections) {
            if (ec.Student_Name__c != null) {
                studentContactIds.add(ec.Student_Name__c);
            }
        }

        if (studentContactIds.isEmpty()) {
            return;
        }

        // Fetch DSU emails from affiliations.
        Map<Id, hed__Affiliation__c> affiliationByContact = new Map<Id, hed__Affiliation__c>();
        for (hed__Affiliation__c aff : [
            SELECT Id, hed__Contact__c, DSU_Email__c,Personal_Email__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c IN :studentContactIds
                AND DSU_Email__c != null
        ]) {
            affiliationByContact.put(aff.hed__Contact__c, aff);
        }

        if (affiliationByContact.isEmpty()) {
            return;
        }

        // Resolve email template.
        Id templateId = null;
        List<EmailTemplate> templates = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = 'Hallticket_Publish_Notify_Emailtemplate_1767597749307'
            LIMIT 1
        ];
        if (!templates.isEmpty()) {
            templateId = templates[0].Id;
        }

        if (templateId == null) {
            return;
        }

        // Resolve org-wide email address.
        Id oweaId = null;
        List<OrgWideEmailAddress> oweas = [
            SELECT Id
            FROM OrgWideEmailAddress WHERE Address ='helpdesk@dsuonline.com'
            LIMIT 1
        ];
        if (!oweas.isEmpty()) {
            oweaId = oweas[0].Id;
        } else {
            // Fallback to any available org-wide email address.
            oweas = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
            if (!oweas.isEmpty()) {
                oweaId = oweas[0].Id;
            }
        }

        // Build and send notifications (deduped per contact).
        Set<Id> notifiedContacts = new Set<Id>();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (Exam_Connections__c conn : examConnections) {
            Id contactId = conn.Student_Name__c;
            if (contactId == null || notifiedContacts.contains(contactId)) {
                continue;
            }

            hed__Affiliation__c aff = affiliationByContact.get(contactId);
            if (aff == null || String.isBlank(aff.DSU_Email__c)) {
                continue;
            }

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTemplateId(templateId);
            email.setTargetObjectId(contactId);
            email.setToAddresses(new String[] { aff.DSU_Email__c });
            email.setSaveAsActivity(false);
            if (oweaId != null) {
                email.setOrgWideEmailAddressId(oweaId);
            }

            emailsToSend.add(email);
            notifiedContacts.add(contactId);
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend, false);
        }
    }
	@TestVisible private static Id TEST_templateId;
	@TestVisible private static Id TEST_oweaId;

}