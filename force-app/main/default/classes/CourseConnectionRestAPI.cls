@RestResource(urlMapping='/courseconnections')
global with sharing class CourseConnectionRestAPI {
    
    // Wrapper for individual connection
    global class ConnectionWrapper {
        public String CourseEnrollmentId;
        public String CourseOfferingId;
        public String CourseEnrollmentManagementId;
        public Decimal creditsAttempted;
    }
    
    // Wrapper for entire request
    global class RequestWrapper {
        public String ProgramEnrollmentId;
        public String ContactId;
        public List<ConnectionWrapper> connections;
    }
    
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // Deserialize into our wrapper
            RequestWrapper input = (RequestWrapper) JSON.deserialize(req.requestBody.toString(), RequestWrapper.class);
            
            // Validate
            if (input == null || 
                String.isBlank(input.ProgramEnrollmentId) || 
                String.isBlank(input.ContactId) ||
                input.connections == null || 
                input.connections.isEmpty()) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Invalid payload');
                return;
            }
            
            // Get RecordType Id for "Student"
            Id studentRecordTypeId = [
                SELECT Id 
                FROM RecordType 
                WHERE SObjectType = 'hed__Course_Enrollment__c' 
                AND Name = 'Student' 
                LIMIT 1
            ].Id;
            
            List<hed__Course_Enrollment__c> recordsToInsert = new List<hed__Course_Enrollment__c>();
            
            // Build list of course enrollment records
            for (ConnectionWrapper c : input.connections) {
                hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c();
                ce.RecordTypeId = studentRecordTypeId;
                ce.hed__Contact__c = input.ContactId;
                ce.Course_Enrollment__c = c.CourseEnrollmentId;
                ce.hed__Course_Offering__c = c.CourseOfferingId;
                ce.Credits__c = c.creditsAttempted;
                if(String.isNotBlank(c.CourseEnrollmentManagementId)){
                    ce.Course_Enrollment_Management__c = c.CourseEnrollmentManagementId;}
                ce.put('hed__Program_Enrollment__c', input.ProgramEnrollmentId);
                recordsToInsert.add(ce);
            }
            
            // Insert
            if (Schema.sObjectType.hed__Course_Enrollment__c.isCreateable()) {
    insert recordsToInsert;
    
}
            
            // Success response
            res.statusCode = 201;
            res.responseBody = Blob.valueOf(JSON.serialize(recordsToInsert));
            
        } catch (Exception ex) {
            res.statusCode = 500;
            String errorMessage = 'Error: ' + ex.getMessage();
            String stackTrace = ex.getStackTraceString();
            res.responseBody = Blob.valueOf(errorMessage + '\nStack Trace:\n' + stackTrace);
        }
    }
}