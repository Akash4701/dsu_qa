public class ContactController {
    @AuraEnabled
    public static void sendUserDetails(id contactId1){
        
        system.debug('working');
        
        contact con = [SELECT id,FirstName,MiddleName,LastName,Email,LMS_ID__c,Registered__c FROM Contact WHERE Id = :contactId1 LIMIT 1];
        
        List<Map<String, Object>> payloadList = new List<Map<String, Object>>();
        
        Map<String, Object> userMap = new Map<String, Object>{
                'OrgDefinedId'       => con.Id,
                'FirstName'          => con.FirstName,
                'MiddleName'         => con.MiddleName,
                'LastName'           => con.LastName,
                'ExternalEmail'      => con.Email,
                'UserName'           => con.Email,
                'RoleId'             => '110',
                'IsActive'           => true,
                'SendCreationEmail'  => false
            };
                
        payloadList.add(new Map<String, Object>{
                'user'   => userMap
            });
        
        HTTPRequest req = new HTTPRequest();
        req.setEndpoint('https://dsu-dev-api.ken42.com/api/v1/brightspace/bulkenrollment');
        req.setMethod('POST');
        req.setHeader('Content-Type','application/json');
        
        req.setBody(JSON.serialize(payloadList));
        
        String jsonBody = JSON.serialize(payloadList);
        System.debug('Sending JSON: ' + jsonBody);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        System.debug('Response: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> responseData = (List<Object>) response.get('data');
            List<Contact> contactsToUpdate = new List<Contact>();
             for (Object obj : responseData) {
                Map<String, Object> wrapper = (Map<String, Object>) obj;

                Map<String, Object> user = (Map<String, Object>) wrapper.get('user');
                if (user != null && (Boolean) user.get('status') == true) {
                    String contactId = (String) user.get('recordId');
                    String lmsId = String.valueOf(user.get('lmsId'));
                    if (contactId != null && lmsId != null) {
                        Contact con1 = [SELECT Id,Registered__c,LMS_ID__c FROM Contact WHERE id = :contactId];
                        con1.Registered__C = True;
                        con1.LMS_ID__c = lmsId;
                    }
                }
             }
           
    }

    }}