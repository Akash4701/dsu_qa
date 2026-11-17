@RestResource(urlMapping='/studentAffId/*')
global with sharing class StudentInformation {
    
    @HttpGet
    global static AffiliationResponse getAffiliationDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // Extract the affiliation ID from the URL
            String affiliationId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
            
            // Validate the ID format
            if (String.isBlank(affiliationId) || !isValidId(affiliationId)) {
                res.statusCode = 400;
                return new AffiliationResponse(false, 'Invalid Affiliation ID provided', null);
            }
            
            // Query the Affiliation record with related Contact and Account data
            List<hed__Affiliation__c> affiliations = [
                SELECT Id, 
                       Roll_Number__c,
                       hed__Contact__c,
                       hed__Contact__r.DEB_ID__c,
                       hed__Account__c,
                       hed__Account__r.Name,
                       Locality__c,
                       Country_Residence__c,
                       Nationality__c,
                       DSU_Email__c,
                       Date_Of_Birth__c,
                      Admission_Date__c,
                      hed__Contact__r.MailingAddress,
                      hed__Contact__r.Contact_Phone__c,
                      hed__Contact__r.MailingPostalCode,
                      hed__Contact__r.ABC_ID__c,
                      Program_Plan__c,
                      Program_Plan__r.Intake__c,
                      Program_Plan__r.Batch__c
                    
                FROM hed__Affiliation__c 
                WHERE Id = :affiliationId
                LIMIT 1
            ];
            List<hed__Term__c> Semesters = [SELECT Id,
                                            Term_Reference__c, 
                                            hed__Start_Date__c,
                                            hed__End_Date__c 
                                            FROM hed__Term__c 
                                            WHERE Program_Plan__c = :affiliations[0].Program_Plan__c ]; 
            
            Address mailing = affiliations[0].hed__Contact__r.MailingAddress;
            
            String fullAddress = '';
            if (mailing != null) {
                List<String> parts = new List<String>();
                if (mailing.street != null) parts.add(mailing.street);
                if (mailing.city != null) parts.add(mailing.city);
                if (mailing.state != null) parts.add(mailing.state);
                if (mailing.postalCode != null) parts.add(mailing.postalCode);
                if (mailing.country != null) parts.add(mailing.country);
                
                fullAddress = String.join(parts, ', ');
            }
            
            if (affiliations.isEmpty()) {
                res.statusCode = 404;
                return new AffiliationResponse(false, 'Affiliation record not found', null);
            }
            
            
            hed__Affiliation__c affiliation = affiliations[0];
             
            // Create the response data
            AffiliationData data = new AffiliationData();
            data.debId = affiliation.hed__Contact__r?.DEB_ID__c;
            data.USN = affiliation.Roll_Number__c;
            data.programName = affiliation.hed__Account__r?.Name;
            data.affiliationId = affiliation.Id;
            data.Locality = affiliation.Locality__c;
            data.CountryResidence = affiliation.Country_Residence__c;
            data.Nationality = affiliation.Nationality__c;
            data.AdmissionDate = affiliation.Admission_Date__c;
            data.DSUEmail = affiliation.DSU_Email__c;
           if (affiliation.Date_Of_Birth__c != null) {
             data.DateOfBirth = DateTime.newInstance(affiliation.Date_Of_Birth__c, Time.newInstance(0, 0, 0, 0));
             }
            data.MailingAddress = fullAddress;
           data.AcadamicSession = affiliation.Program_Plan__r.Intake__c + ' - ' + affiliation.Program_Plan__r.Batch__c;
           data.PostalCode = affiliation.hed__Contact__r.MailingPostalCode;
            data.ABC_Id = affiliation.hed__Contact__r.ABC_ID__c;
            data.ContactPhone = affiliation.hed__Contact__r.Contact_Phone__c;
            data.terms = new List<TermData>();
           for (hed__Term__c semester : Semesters) {
            TermData t = new TermData();
            t.name = semester.Term_Reference__c;
            if (semester.hed__Start_Date__c != null) {
                DateTime startDateTime = DateTime.newInstance(semester.hed__Start_Date__c, Time.newInstance(0, 0, 0, 0));
                t.StartDate = startDateTime.format('dd/MM/yyyy');
            }
            if (semester.hed__End_Date__c != null) {
            DateTime endDateTime = DateTime.newInstance(semester.hed__End_Date__c, Time.newInstance(0, 0, 0, 0));
            t.EndDate = endDateTime.format('dd/MM/yyyy');
            }
            data.terms.add(t);
             }

            
            res.statusCode = 200;
            return new AffiliationResponse(true, 'Success', data);
            
        } catch (QueryException e) {
            res.statusCode = 500;
            return new AffiliationResponse(false, 'Database error: ' + e.getMessage(), null);
        } catch (Exception e) {
            res.statusCode = 500;
            return new AffiliationResponse(false, 'Unexpected error: ' + e.getMessage(), null);
        }
    }
    
    // Helper method to validate Salesforce ID format
    private static Boolean isValidId(String recordId) {
        try {
            Id testId = (Id) recordId;
            return true;
        } catch (Exception e) {
            return false;
        }
    }
    
    // Response wrapper class
    global class AffiliationResponse {
        global Boolean success;
        global String message;
        global AffiliationData data;
        
        global AffiliationResponse(Boolean success, String message, AffiliationData data) {
            this.success = success;
            this.message = message;
            this.data = data;
        }   
    }
    
    // Data class for the affiliation details
    global class AffiliationData {
        global String debId;           // DEB_ID__c from Contact
        global String USN;             // Roll_Number__c from Affiliation (USN/Roll Number)
        global String programName;     // Name from Account (Program Name)
        global String affiliationId;   // Affiliation ID for reference
         global String Locality;
        global String CountryResidence;
        global String Nationality;
        global DateTime DateOfBirth;
        global Date AdmissionDate;
        global String DSUEmail;
        global String MailingAddress;
        global String AcadamicSession;
        global String PostalCode;
        global String ABC_Id;
        global String ContactPhone;
        global List<TermData> terms;
    }
    global class TermData {
    global String Name;
    global String StartDate;
    global String EndDate;
}
}