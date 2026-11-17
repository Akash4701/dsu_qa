public class AffiliationToUserSyncBatchable implements Database.Batchable<SObject>, Database.AllowsCallouts {
    private List<Id> affiliationIds;

    public AffiliationToUserSyncBatchable(List<Id> affiliationIds) {
        this.affiliationIds = affiliationIds;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id,(SELECT Id, hed__Contact__c FROM hed__Program_Enrollment__r) FROM hed__Affiliation__c WHERE Id IN :affiliationIds]);
    }

    public void execute(Database.BatchableContext BC, List<hed__Affiliation__c> scope) {
        Set<Id> contactIds = new Set<Id>();
        for (hed__Affiliation__c aff : scope) {
            for (hed__Program_Enrollment__c pe : aff.hed__Program_Enrollment__r) {
                if (pe.hed__Contact__c != null) {
                    contactIds.add(pe.hed__Contact__c);
                }
            }
        }
        if (contactIds.isEmpty()) return;
        Map<Id, Contact> contactMap = new Map<Id, Contact>([SELECT Id, FirstName, MiddleName, LastName, Email , Passport_Size_Photo__c FROM Contact WHERE Id IN :contactIds]);

        System.debug('Contact Map: ' + contactMap);
        List<hed__Course_Enrollment__c> courseEnrollments = [SELECT Id, hed__Contact__c, hed__Course_Offering__c , hed__Course_Offering__r.LMS_Id__c ,hed__Course_Offering__r.Name , hed__Course_Offering__r.hed__Course__c,
                                                             hed__Course_Offering__r.hed__Course__r.LMS_Id__c ,hed__Course_Offering__r.hed__Course__r.hed__Account__c , 
                                                             hed__Course_Offering__r.hed__Course__r.hed__Account__r.LMS_Id__c ,
                                                             hed__Course_Offering__r.hed__Course__r.hed__Account__r.Parent.ParentId,
                                                             hed__Course_Offering__r.hed__Course__r.hed__Account__r.Parent.Parent.LMS_Id__c
                                                             
                                                            FROM hed__Course_Enrollment__c WHERE hed__Contact__c IN :contactIds];

        Map<Id, List<hed__Course_Enrollment__c>> contactToEnrollments = new Map<Id, List<hed__Course_Enrollment__c>>();
        for (hed__Course_Enrollment__c ce : courseEnrollments) {
            if (!contactToEnrollments.containsKey(ce.hed__Contact__c)) contactToEnrollments.put(ce.hed__Contact__c, new List<hed__Course_Enrollment__c>());
            contactToEnrollments.get(ce.hed__Contact__c).add(ce);
        }
        List<UserEnrollmentWrapper> payloadList = new List<UserEnrollmentWrapper>();
        for (Id contactId : contactIds) {

    Contact c = contactMap.get(contactId);
    if (c == null) continue;

    UserEnrollmentWrapper.UserData user = new UserEnrollmentWrapper.UserData();
    user.OrgDefinedId = c.Id;
    user.FirstName = c.FirstName;
    user.MiddleName = c.MiddleName;
    user.LastName = c.LastName;
    user.ExternalEmail = c.Email;
    user.UserName = c.Email;
    user.ProfileUrl = c.Passport_Size_Photo__c;

    Set<UserEnrollmentWrapper.EnrollmentData> enrollSet = new Set<UserEnrollmentWrapper.EnrollmentData>();
    List<hed__Course_Enrollment__c> enrollments = contactToEnrollments.containsKey(contactId) ? contactToEnrollments.get(contactId) : new List<hed__Course_Enrollment__c>();

    for (hed__Course_Enrollment__c ce : enrollments) {
        UserEnrollmentWrapper.EnrollmentData enroll3 = new UserEnrollmentWrapper.EnrollmentData();
        enroll3.OrgSFID = ce.Id;
        enroll3.UserId = ce.hed__Course_Offering__r.Name;
        enroll3.OrgUnitId = ce.hed__Course_Offering__r.hed__Course__r.hed__Account__r.Parent.Parent.LMS_Id__c;
        enrollSet.add(enroll3);
        
        UserEnrollmentWrapper.EnrollmentData enroll2 = new UserEnrollmentWrapper.EnrollmentData();
        enroll2.OrgSFID = ce.Id;
        enroll2.UserId = ce.hed__Course_Offering__r.Name;
        enroll2.OrgUnitId = ce.hed__Course_Offering__r.hed__Course__r.hed__Account__r.LMS_Id__c;
        enrollSet.add(enroll2);
        
        UserEnrollmentWrapper.EnrollmentData enroll = new UserEnrollmentWrapper.EnrollmentData();
        enroll.OrgSFID = ce.Id;
        enroll.UserId = ce.hed__Course_Offering__r.Name;
        enroll.OrgUnitId = ce.hed__Course_Offering__r.hed__Course__r.LMS_Id__c;
        enrollSet.add(enroll);

        UserEnrollmentWrapper.EnrollmentData enroll1 = new UserEnrollmentWrapper.EnrollmentData();
        enroll1.OrgSFID = ce.Id;
        enroll1.UserId = ce.hed__Course_Offering__r.Name;
        enroll1.OrgUnitId = ce.hed__Course_Offering__r.LMS_Id__c;
        enrollSet.add(enroll1);
}

    UserEnrollmentWrapper wrapper = new UserEnrollmentWrapper();
    wrapper.user = user;
    wrapper.enroll = new List<UserEnrollmentWrapper.EnrollmentData>(enrollSet);

    payloadList.add(wrapper);
}

        LMS_URL__c bulkEnroll = [SELECT id, Bulk_Enroll__c FROM LMS_URL__c WHERE Name = 'Bulk Enrollment' LIMIT 1];
        HttpRequest req = new HttpRequest();
        req.setEndpoint(bulkEnroll.Bulk_Enroll__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payloadList));

        system.debug(JSON.serialize(payloadList));
        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> responseData = (List<Object>) response.get('data');
            List<Contact> contactsToUpdate = new List<Contact>();
            List<hed__Course_Enrollment__c> enrollsToUpdate = new List<hed__Course_Enrollment__c>();
            for (Object obj : responseData) {
                Map<String, Object> wrapper = (Map<String, Object>) obj;
                Map<String, Object> userResp = (Map<String, Object>) wrapper.get('user');
                if (userResp != null && (Boolean) userResp.get('status') == true) {
                    String contactId = (String) userResp.get('recordId');
                    String lmsId = String.valueOf(userResp.get('lmsId'));
                    if (contactId != null && lmsId != null) contactsToUpdate.add(new Contact(Id = contactId, LMS_ID__c = lmsId, Registered__c = true));
                }
                List<Object> enrollResp = (List<Object>) wrapper.get('enroll');
                for (Object eObj : enrollResp) {
                    Map<String, Object> enrollMap = (Map<String, Object>) eObj;
                    if (enrollMap != null && (Boolean) enrollMap.get('status') == true) {
                        String enrollId = (String) enrollMap.get('recordId');
                        if (enrollId != null) enrollsToUpdate.add(new hed__Course_Enrollment__c(Id = enrollId, Registered__c = true));
                    }
                }
            }
            if (!contactsToUpdate.isEmpty()) update contactsToUpdate;
            if (!enrollsToUpdate.isEmpty()) update enrollsToUpdate;
        }
    }

    public void finish(Database.BatchableContext BC){}
}