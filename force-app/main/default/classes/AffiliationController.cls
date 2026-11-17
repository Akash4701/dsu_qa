public with sharing class AffiliationController {
    @AuraEnabled
    public static String sendDebIdToNode(Id affiliationId) {
        hed__Affiliation__c aff = [
            SELECT Id, 
            DEB_ID__c ,
            Roll_Number__c,
            hed__Contact__c,
            hed__Contact__r.Nationality__c,
            hed__Contact__r.MailingCountry,
            hed__Contact__r.Student_Category__c,
            hed__Contact__r.Aadhar_Number__c,
            hed__Contact__r.Locality__c,
            Individual_Application__c,
            Individual_Application__r.Program__c,
            hed__Account__c,
            hed__Account__r.Programme_Name__c,
            hed__Account__r.AISHE_Code__c,
            hed__Account__r.Programme_Map_Code__c
            FROM hed__Affiliation__c WHERE Id = :affiliationId LIMIT 1
        ];
        Student_Detail_URL__c query = [SELECT Id, Student_URL__c FROM Student_Detail_URL__c WHERE Name = 'UGC URL' LIMIT 1];
        DSU_Name__c DSU = [SELECT Id,
                           Record_Id__c,
                           Mode_of_Education__c,
                           Government_issued_Identifier__c
                           FROM DSU_Name__c
                           WHERE Name = 'Dayananda Sagar University'
                           LIMIT 1];
        Account Institute = [SELECT Id,Institute_Code__c,Name FROM Account WHERE Id = :DSU.Record_Id__c];
        String endpoint = query.Student_URL__c + '/api/v1/deb/studentdetail?DEBUniqueID=' + EncodingUtil.urlEncode(aff.DEB_ID__c, 'UTF-8');
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, String> body = new Map<String, String>();
        body.put('DEBUniqueID', aff.DEB_ID__c);
        req.setBody(JSON.serialize(body));

        try {
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String status = (String) resMap.get('Status');
                aff.Status__c = status;
                update aff;

                if (status == 'Process UnSuccess') {
                    return 'No record found for DEBUniqueID: ' + aff.DEB_ID__c;
                }

                Object resourceObj = resMap.get('Resource');
                if (resourceObj instanceof List<Object>) {
                    List<Object> resourceList = (List<Object>) resourceObj;
                    System.debug('Got Response');
                    if (!resourceList.isEmpty()) {
                        Map<String, Object> studentData = (Map<String, Object>) resourceList[0];

                        String response = res.getBody();
                        Integer chunkSize = 1000;
                        for (Integer i = 0; i < response.length(); i += chunkSize) {
                            Integer tend = Math.min(i + chunkSize, response.length());
                            System.debug('Chunk ' + i + ': ' + response.substring(i, tend));
                        }

                        aff.StudentID__c = (String) studentData.get('StudentID');
                        aff.Gender__c = (String) studentData.get('Gender');
                        aff.Date_Of_Birth__c = parseDate((String) studentData.get('DOB'));
                        aff.Admission_Date__c = parseAdmissionDate((String) studentData.get('AdmissionDate'));
                        aff.Enrollment_Number__c = aff.Roll_Number__c!=Null? aff.Roll_Number__c : '';
                        aff.Unique_Number__c = (Integer) studentData.get('UniqueNumber');
                        aff.Program__c = aff.hed__Account__r.Programme_Name__c!=Null? aff.hed__Account__r.Programme_Name__c:'';
                        aff.Email__c = (String) studentData.get('email');
                        aff.IP_address__c = (String) studentData.get('ipaddress');
                        aff.Course_Name__c = (String) studentData.get('CourseName');
                        aff.University_Name__c = aff.hed__Account__r.AISHE_Code__c!=Null ? aff.hed__Account__r.AISHE_Code__c : '';
                        aff.Admission_Details__c = (String) studentData.get('AdmissionDetails');
                        aff.Mode__c = DSU.Mode_of_Education__c!=Null ? DSU.Mode_of_Education__c :'' ;
                        aff.Institute_Name__c = (String)studentData.get('institutename');
                        aff.Institute_ID__c = (String)studentData.get('InstituteID');
                        aff.Student_Name__c = (String) studentData.get('stdname');
                        aff.Father_Name__c = (String) studentData.get('fathername');
                        aff.Program_Code__c = aff.hed__Account__r.Programme_Map_Code__c!=Null ? aff.hed__Account__r.Programme_Map_Code__c : '';
                        aff.Mobile__c = (String) studentData.get('mobile');
                        aff.Nationality__c = aff.hed__Contact__r.Nationality__c!=Null ?aff.hed__Contact__r.Nationality__c : '';
                        aff.Locality__c = aff.hed__Contact__r.Locality__c!=Null ?aff.hed__Contact__r.Locality__c : '';
                        aff.Country_Residence__c = aff.hed__Contact__r.MailingCountry!=Null?aff.hed__Contact__r.MailingCountry:'';
                        aff.Government_Identifier__c = DSU.Government_issued_Identifier__c!=Null ?DSU.Government_issued_Identifier__c:'';
                        aff.Government_Identifier_Number__c = aff.hed__Contact__r.Aadhar_Number__c!=Null?aff.hed__Contact__r.Aadhar_Number__c:'';
                        aff.Category__c = aff.hed__Contact__r.Student_Category__c!=Null ? aff.hed__Contact__r.Student_Category__c:'';
                        
                        update aff;
    

                        
                        return 'Success: Affiliation updated with student data.';
                    } else {
                        return 'No student data found in Resource list.';
                    }
                } else {
                    return 'Unexpected response: Resource is not a list.';
                }
            } else {
                return 'Error: HTTP status ' + res.getStatusCode() + ' - ' + res.getBody();
            }
        } catch (Exception e) {
            return 'Exception: ' + e.getMessage();
        }
    }

    public static Date parseDate(String input) {
        try {
            List<String> parts = input.split('/');
            return Date.newInstance(Integer.valueOf(parts[2]), Integer.valueOf(parts[1]), Integer.valueOf(parts[0]));
        } catch (Exception e) {
            System.debug('Invalid DOB format: ' + input);
            return null;
        }
    }

    public static Date parseAdmissionDate(String input) {
    try {
        return Date.valueOf(input); // Accepts 'yyyy-MM-dd'
    } catch (Exception e) {
        System.debug('Invalid AdmissionDate format: ' + input);
        return null;
    }
}

    public static DateTime parseDateTime(String input) {
        try {
            return DateTime.valueOfGmt(input);
        } catch (Exception e) {
            return null;
        }
    }

    @AuraEnabled
public static void sendAdmissionDetails(Id affiliationId) {
    hed__Affiliation__c aff = [
        SELECT Id, Admission_Details__c, ABC_ID__c, Course_Name__c, DEB_ID__c, Date_Of_Birth__c, Category__c, Government_Identifier__c,Program__c,
               Government_Identifier_Number__c, Locality__c, Nationality__c, Country_Residence__c, Enrollment_Number__c,Admission_Date__c,
               University_Name__c, hed__Account__r.AISHE_Code__c, hed__Account__r.Programme_Name__c,Message__c,
               hed__Account__r.Programme_Map_Code__c, hed__Account__r.Mode_Of_Education__c
        FROM hed__Affiliation__c
        WHERE Id = :affiliationId
        LIMIT 1
    ];

    Student_Detail_URL__c query = [SELECT Student_URL__c FROM Student_Detail_URL__c WHERE Name = 'UGC URL' LIMIT 1];

    String admissionEndpoint = query.Student_URL__c + '/api/v1/deb/admissiondetail'
    + '?DEBuniqueID=' + EncodingUtil.urlEncode(String.valueOf(aff.DEB_ID__c != null ? aff.DEB_ID__c : ''), 'UTF-8')
    + '&UniversityName=' + EncodingUtil.urlEncode(String.valueOf(aff.hed__Account__r.AISHE_Code__c != null ? aff.hed__Account__r.AISHE_Code__c : ''), 'UTF-8')
    + '&CourseName=' + EncodingUtil.urlEncode(String.valueOf(aff.Program__c != null ? aff.Program__c : ''), 'UTF-8')
    + '&AdmissionDate=' + EncodingUtil.urlEncode(aff.Admission_Date__c != null ? String.valueOf(aff.Admission_Date__c) : '', 'UTF-8')
    + '&AdmissionDetails=' + EncodingUtil.urlEncode(String.valueOf(aff.Admission_Details__c != null ? aff.Admission_Details__c : ''), 'UTF-8')
    + '&EnrollmentNumber=' + EncodingUtil.urlEncode(String.valueOf(aff.Enrollment_Number__c != null ? aff.Enrollment_Number__c : ''), 'UTF-8')
    + '&ModeEducation=' + EncodingUtil.urlEncode(String.valueOf(aff.hed__Account__r.Mode_Of_Education__c != null ? aff.hed__Account__r.Mode_Of_Education__c : ''), 'UTF-8')
    + '&Category=' + EncodingUtil.urlEncode(String.valueOf(aff.Category__c != null ? aff.Category__c : ''), 'UTF-8')
    + '&GovernmentIdentifier=' + EncodingUtil.urlEncode(String.valueOf(aff.Government_Identifier__c != null ? aff.Government_Identifier__c : ''), 'UTF-8')
    + '&Locality=' + EncodingUtil.urlEncode(String.valueOf(aff.Locality__c != null ? aff.Locality__c : ''), 'UTF-8')
    + '&Nationality=' + EncodingUtil.urlEncode(String.valueOf(aff.Nationality__c != null ? aff.Nationality__c : ''), 'UTF-8')
    + '&GovernmentIdentifierNumber=' + EncodingUtil.urlEncode(String.valueOf(aff.Government_Identifier_Number__c != null ? aff.Government_Identifier_Number__c : ''), 'UTF-8')
    + '&CountryResidence=' + EncodingUtil.urlEncode(String.valueOf(aff.Country_Residence__c != null ? aff.Country_Residence__c : ''), 'UTF-8');


    Http http = new Http();
    HttpRequest req = new HttpRequest();
    req.setEndpoint(admissionEndpoint);
    req.setMethod('POST'); // As per confirmation
    // No body
    // No Content-Type header
    if (aff.Message__c == 'Data retrival successful.') {
    throw new AuraHandledException('Data already retrieved. No further transmission allowed.');
}
    try {
        HttpResponse res = http.send(req);
        System.debug('Response: ' + res.getBody());

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        aff.Message__c = (String) result.get('Message');
        aff.Acadamic_Status__c = (String) result.get('Status');
        aff.Flag__c = (String) result.get('Flag');

        update aff;

    } catch (Exception e) {
        System.debug('Exception: ' + e.getMessage());
        aff.Message__c = 'Error: ' + e.getMessage();
        aff.Acadamic_Status__c = 'Exception';
        aff.Flag__c = '0';
        update aff;
    }
}


}