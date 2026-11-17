public with sharing class ResultPublishController {

    @AuraEnabled
    public static void publishResults(Id termId) {
        // Validate input
        if (termId == null) {
            throw new AuraHandledException('Term ID is required.');
        }

        // Query and update Term
        hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Id = :termId];
        term.Result_Published__c = true;
        update term;

        // Query related Course Offerings
        List<hed__Course_Offering__c> offeringsToUpdate = [
            SELECT Id 
            FROM hed__Course_Offering__c 
            WHERE hed__Term__c = :termId 
            AND Result_Published__c = false // Only update if not already published (optional optimization)
        ];

        // Set flag to true
        for (hed__Course_Offering__c co : offeringsToUpdate) {
            co.Result_Published__c = true;
        }

        // Update if any found
        if (!offeringsToUpdate.isEmpty()) {
            update offeringsToUpdate;
        }
    }
}