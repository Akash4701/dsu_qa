public class SendContactIdsBatch implements Database.Batchable<Id>, Database.AllowsCallouts {
    private List<Id> contactIds;

    public SendContactIdsBatch(List<Id> contactIds) {
        this.contactIds = contactIds;
    }

    public Iterable<Id> start(Database.BatchableContext context) {
        return contactIds;
    }

    public void execute(Database.BatchableContext context, List<Id> scope) {
        Map<Id, Contact> contactMap = new Map<Id, Contact>(
            [SELECT Id, FirstName, MiddleName, LastName, Email, Passport_Size_Photo__c
             FROM Contact
             WHERE Id IN :scope]
        );

        List<hed__Course_Enrollment__c> courseEnrollments = [
            SELECT Id, 
                   hed__Contact__c,
                   hed__Program_Enrollment__c,
                   hed__Program_Enrollment__r.hed__Affiliation__c,
                   hed__Program_Enrollment__r.hed__Affiliation__r.DSU_Email__c,
                   hed__Course_Offering__c,
                   hed__Course_Offering__r.LMS_Id__c, 
                   hed__Course_Offering__r.Name, 
                   hed__Course_Offering__r.hed__Course__c,
                   hed__Course_Offering__r.hed__Course__r.LMS_Id__c,
                   hed__Course_Offering__r.hed__Course__r.hed__Account__c,
                   hed__Course_Offering__r.hed__Course__r.hed__Account__r.LMS_Id__c,
                   hed__Course_Offering__r.hed__Course__r.hed__Account__r.Parent.ParentId,
                   hed__Course_Offering__r.hed__Course__r.hed__Account__r.Parent.Parent.LMS_Id__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Contact__c IN :scope
        ];

        Map<Id, List<hed__Course_Enrollment__c>> contactToEnrollments = new Map<Id, List<hed__Course_Enrollment__c>>();
        for (hed__Course_Enrollment__c ce : courseEnrollments) {
            if (!contactToEnrollments.containsKey(ce.hed__Contact__c)) {
                contactToEnrollments.put(ce.hed__Contact__c, new List<hed__Course_Enrollment__c>());
            }
            contactToEnrollments.get(ce.hed__Contact__c).add(ce);
        }

        List<UserEnrollmentWrapper> payloadList = new List<UserEnrollmentWrapper>();

        for (Id contactId : scope) {
            Contact c = contactMap.get(contactId);
            if (c == null) continue;

            List<hed__Course_Enrollment__c> enrollments = contactToEnrollments.get(contactId);
            if (enrollments == null || enrollments.isEmpty()) continue;

            // Group by Affiliation
            Map<Id, List<hed__Course_Enrollment__c>> affiliationToEnrollments = new Map<Id, List<hed__Course_Enrollment__c>>();
            for (hed__Course_Enrollment__c ce : enrollments) {
                Id affiliationId = ce.hed__Program_Enrollment__r?.hed__Affiliation__c;
                if (affiliationId == null) continue;

                if (!affiliationToEnrollments.containsKey(affiliationId)) {
                    affiliationToEnrollments.put(affiliationId, new List<hed__Course_Enrollment__c>());
                }
                affiliationToEnrollments.get(affiliationId).add(ce);
            }

            for (Id affiliationId : affiliationToEnrollments.keySet()) {
                List<hed__Course_Enrollment__c> affEnrollments = affiliationToEnrollments.get(affiliationId);
                if (affEnrollments == null || affEnrollments.isEmpty()) continue;

                hed__Course_Enrollment__c sample = affEnrollments[0];
                String dsuEmail = sample.hed__Program_Enrollment__r?.hed__Affiliation__r?.DSU_Email__c;

                UserEnrollmentWrapper.UserData user = new UserEnrollmentWrapper.UserData();
                user.OrgDefinedId = c.Id;
                user.FirstName = c.FirstName;
                user.MiddleName = c.MiddleName;
                user.LastName = c.LastName;
                user.ExternalEmail = dsuEmail;
                user.UserName = dsuEmail;
                user.ProfileUrl = c.Passport_Size_Photo__c;

                Set<UserEnrollmentWrapper.EnrollmentData> enrollSet = new Set<UserEnrollmentWrapper.EnrollmentData>();
                for (hed__Course_Enrollment__c ce : affEnrollments) {
                    List<String> orgUnitIds = new List<String>{
                        ce.hed__Course_Offering__r.LMS_Id__c,
                        ce.hed__Course_Offering__r.hed__Course__r.LMS_Id__c,
                        ce.hed__Course_Offering__r.hed__Course__r.hed__Account__r.LMS_Id__c,
                        ce.hed__Course_Offering__r.hed__Course__r.hed__Account__r.Parent?.Parent?.LMS_Id__c
                    };

                    for (String orgUnitId : orgUnitIds) {
                        if (orgUnitId == null) continue;

                        UserEnrollmentWrapper.EnrollmentData enroll = new UserEnrollmentWrapper.EnrollmentData();
                        enroll.OrgSFID = ce.Id;
                        enroll.UserId = ce.hed__Course_Offering__r.Name;
                        enroll.OrgUnitId = orgUnitId;
                        enrollSet.add(enroll);
                    }
                }

                UserEnrollmentWrapper wrapper = new UserEnrollmentWrapper();
                wrapper.user = user;
                wrapper.enroll = new List<UserEnrollmentWrapper.EnrollmentData>(enrollSet);
                payloadList.add(wrapper);
            }
        }

        LMS_URL__c bulkEnroll = [SELECT Id, Bulk_Enroll__c FROM LMS_URL__c WHERE Name = 'Bulk Enrollment' LIMIT 1];

        HttpRequest req = new HttpRequest();
        req.setEndpoint(bulkEnroll.Bulk_Enroll__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payloadList));
        req.setTimeout(120000); // 120 s is the longest an Apex callout may wait

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug(JSON.serialize(payloadList));
        System.debug(JSON.deserializeUntyped(res.getBody()));

        if (res.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> responseData = (List<Object>) response.get('data');

            List<Contact> contactsToUpdate = new List<Contact>();
            Map<Id, hed__Course_Enrollment__c> enrollsToUpdateMap = new Map<Id, hed__Course_Enrollment__c>();

            for (Object obj : responseData) {
                Map<String, Object> wrapper = (Map<String, Object>) obj;

                Map<String, Object> userResp = (Map<String, Object>) wrapper.get('user');
                if (userResp != null && (Boolean) userResp.get('status') == true) {
                    String contactId = (String) userResp.get('recordId');
                    String lmsId = String.valueOf(userResp.get('lmsId'));
                    if (contactId != null && lmsId != null) {
                        contactsToUpdate.add(new Contact(Id = contactId, LMS_ID__c = lmsId, Registered__c = true));
                    }
                }

                List<Object> enrollResp = (List<Object>) wrapper.get('enroll');
                for (Object eObj : enrollResp) {
                    Map<String, Object> enrollMap = (Map<String, Object>) eObj;
                    if (enrollMap != null && (Boolean) enrollMap.get('status') == true) {
                        String enrollId = (String) enrollMap.get('recordId');
                        if (enrollId != null) {
                            enrollsToUpdateMap.put(
                                (Id) enrollId,
                                new hed__Course_Enrollment__c(Id = enrollId, Registered__c = true)
                            );
                        }
                    }
                }
            }

            if (!contactsToUpdate.isEmpty()) update contactsToUpdate;
            if (!enrollsToUpdateMap.isEmpty()) update enrollsToUpdateMap.values();
        }
    }

    public void finish(Database.BatchableContext context) {
       
    }
}