public with sharing class CalculateSgpaController {

    @AuraEnabled
    public static void calculateSgpaForTerm(Id termId) {
        List<hed__Program_Enrollment__c> programUpdates = new List<hed__Program_Enrollment__c>();

        // Step 1: Get all Course Enrollments for this Term
        List<hed__Course_Enrollment__c> courseEnrollments = [
            SELECT Id, Points_Secured__c, hed__Course_Offering__c,
                   hed__Program_Enrollment__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__r.hed__Term__c = :termId
        ];

        if (courseEnrollments.isEmpty()) return;

        // Step 2: Collect unique Program Enrollment IDs
        Set<Id> programEnrollmentIds = new Set<Id>();
        for (hed__Course_Enrollment__c ce : courseEnrollments) {
            if (ce.hed__Program_Enrollment__c != null) {
                programEnrollmentIds.add(ce.hed__Program_Enrollment__c);
            }
        }

        // Step 3: Query Program Enrollments + their Course Enrollments (with Credits)
        List<hed__Program_Enrollment__c> programEnrollments = [
            SELECT Id,
                (SELECT Id, Points_Secured__c, hed__Course_Offering__c 
                 FROM hed__Course_Enrollments__r)
            FROM hed__Program_Enrollment__c
            WHERE Id IN :programEnrollmentIds
        ];

        // Step 4: Collect all Course Offering IDs to get Credits
        Set<Id> offeringIds = new Set<Id>();
        for (hed__Program_Enrollment__c pe : programEnrollments) {
            for (hed__Course_Enrollment__c ce : pe.hed__Course_Enrollments__r) {
                if (ce.hed__Course_Offering__c != null) {
                    offeringIds.add(ce.hed__Course_Offering__c);
                }
            }
        }

        // Step 5: Map Offering ID → Credit
        Map<Id, Decimal> offeringIdToCredit = new Map<Id, Decimal>();
        if (!offeringIds.isEmpty()) {
            for (hed__Course_Offering__c co : [
                SELECT Id, hed__Course__r.Credits__c 
                FROM hed__Course_Offering__c 
                WHERE Id IN :offeringIds
            ]) {
                if (co.hed__Course__r.Credits__c != null) {
                    offeringIdToCredit.put(co.Id, co.hed__Course__r.Credits__c);
                }
            }
        }

        // Step 6: Calculate SGPA for each Program Enrollment
        for (hed__Program_Enrollment__c pe : programEnrollments) {
            Decimal totalPointsSecured = 0;
            Decimal totalCredits = 0;

            for (hed__Course_Enrollment__c ce : pe.hed__Course_Enrollments__r) {
                // Use formula field Points_Secured__c (already Grade Point × Credit)
                if (ce.Points_Secured__c != null) {
                    totalPointsSecured += ce.Points_Secured__c;
					System.debug('totalPointsSecured'+totalPointsSecured);
                }

                // Get credit from map (for denominator)
                Decimal credit = offeringIdToCredit.get(ce.hed__Course_Offering__c);
                if (credit != null) {
                    totalCredits += credit;
                    System.debug('totalCredits'+totalCredits);
                }
            }

            // Only calculate SGPA if credits > 0
            if (totalCredits > 0) {
                Decimal sgpa = (totalPointsSecured / totalCredits).setScale(2);
				System.debug('Sgpa'+sgpa);
                programUpdates.add(new hed__Program_Enrollment__c(
                    Id = pe.Id,
                    SGPA__c = sgpa
                ));
            }
        }

        // Step 7: Bulk update
        if (!programUpdates.isEmpty()) {
            update programUpdates;
        }
    }
}