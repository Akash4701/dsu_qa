public class CaseTriggerHandler {
    
    public static void handleAfterInsert(List<Case> newCases) {
        
        // Step 1: Collect ContactIds
        Set<Id> contactIds = new Set<Id>();
        for (Case c : newCases) {
            if (c.ContactId != null) {
                contactIds.add(c.ContactId);
            }
        }
                
        if (contactIds.isEmpty()) {
            return;
        }

        // Step 2: Query Active Program Enrollments
        List<hed__Program_Enrollment__c> activeEnrollments = [
            SELECT Id, hed__Contact__c, hed__Enrollment_Status__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Contact__c IN :contactIds
            AND hed__Enrollment_Status__c = 'Active'
         //   WITH SECURITY_ENFORCED
        ];
        

        // Build map: ContactId → EnrollmentId (first active enrollment per contact)
        Map<Id, Id> contactToEnrollmentIdMap = new Map<Id, Id>();
        for (hed__Program_Enrollment__c enr : activeEnrollments) {
            // Only map if not already mapped (to avoid overwriting)
            if (!contactToEnrollmentIdMap.containsKey(enr.hed__Contact__c)) {
                contactToEnrollmentIdMap.put(enr.hed__Contact__c, enr.Id);
            } else {
                System.debug('Multiple active enrollments found for Contact: ' + enr.hed__Contact__c + '. Using first one only.');
            }
        }

        // Step 3: Identify Cases to update
        List<Case> casesToUpdate = new List<Case>();
        for (Case c : newCases) {
            System.debug('Processing Case Id: ' + c.Id + ', ContactId: ' + c.ContactId + ', Current Program_Enrollment__c: ' + c.Program_Enrollment__c);
            if (c.ContactId == null) {
                continue;
            }
            
            if (c.Program_Enrollment__c != null) {
                continue;
            }
            
            Id enrollmentId = contactToEnrollmentIdMap.get(c.ContactId);
            if (enrollmentId != null) {
                casesToUpdate.add(new Case(Id = c.Id, Program_Enrollment__c = enrollmentId));
            } else {
                System.debug(' No active enrollment found for Contact: ' + c.ContactId);
            }
        }

        // Step 4: Perform update
        if (!casesToUpdate.isEmpty()) {
            try {
                 if (Schema.sObjectType.case.isUpdateable()) {
                 update casesToUpdate;
}
            } catch (Exception e) {
                System.debug(' ERROR during update: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug('No Cases qualify for update.');
        }
    }
}