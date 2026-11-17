public with sharing class CalculateCgpaController {

    @AuraEnabled
    public static void calculateCgpaForProgramPlan(Id programPlanId) {
        // STEP 1: Get all Affiliations for this Program Plan
        List<hed__Affiliation__c> affiliations = [
            SELECT Id, Program_Plan__c
            FROM hed__Affiliation__c
            WHERE Program_Plan__c = :programPlanId
        ];

        if (affiliations.isEmpty()) {
            System.debug('⚠️ No affiliations found for Program Plan: ' + programPlanId);
            return;
        }

        Set<Id> affiliationIds = new Set<Id>();
        for (hed__Affiliation__c aff : affiliations) {
            affiliationIds.add(aff.Id);
        }

        // STEP 2: Get ALL Course Enrollments linked to these affiliations
        List<hed__Course_Enrollment__c> allCourseEnrollments = [
            SELECT 
                Id,
                Grade_Point__c,
                Points_Secured__c,
                hed__Course_Offering__c,
                hed__Program_Enrollment__r.hed__Affiliation__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Program_Enrollment__r.hed__Affiliation__c IN :affiliationIds
              AND hed__Program_Enrollment__r.hed__Affiliation__c != null
        ];

        System.debug('✅ Found ' + allCourseEnrollments.size() + ' course enrollments');

        // Map: Affiliation Id → List of Course Enrollments
        Map<Id, List<hed__Course_Enrollment__c>> affToCourseEnrollments = new Map<Id, List<hed__Course_Enrollment__c>>();
        for (hed__Course_Enrollment__c ce : allCourseEnrollments) {
            Id affId = ce.hed__Program_Enrollment__r.hed__Affiliation__c;
            if (!affToCourseEnrollments.containsKey(affId)) {
                affToCourseEnrollments.put(affId, new List<hed__Course_Enrollment__c>());
            }
            affToCourseEnrollments.get(affId).add(ce);
        }

        // STEP 3: Collect Course Offering IDs to fetch credits
        Set<Id> offeringIds = new Set<Id>();
        for (hed__Course_Enrollment__c ce : allCourseEnrollments) {
            if (ce.hed__Course_Offering__c != null) {
                offeringIds.add(ce.hed__Course_Offering__c);
            }
        }

        // Map Offering → Credit
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

        // STEP 4: Calculate CGPA per Affiliation
        List<hed__Affiliation__c> affiliationUpdates = new List<hed__Affiliation__c>();
        Integer totalProcessed = 0;
        Integer totalUpdated = 0;

        for (hed__Affiliation__c aff : affiliations) {
            totalProcessed++;
            Decimal totalPointsSecured = 0;
            Decimal totalCredits = 0;

            List<hed__Course_Enrollment__c> ces = affToCourseEnrollments.get(aff.Id);
            if (ces != null) {
                for (hed__Course_Enrollment__c ce : ces) {
                    // Log raw values for debugging
                    System.debug('🔍 Course Enrollment: ' + ce.Id + 
                                 ' | Grade Point: ' + ce.Grade_Point__c + 
                                 ' | Points Secured: ' + ce.Points_Secured__c + 
                                 ' | Offering: ' + ce.hed__Course_Offering__c);

                    if (ce.Points_Secured__c != null) {
                        totalPointsSecured += ce.Points_Secured__c;
                    }

                    Decimal credit = offeringIdToCredit.get(ce.hed__Course_Offering__c);
                    if (credit != null) {
                        totalCredits += credit;
                    }
                }
            }

            System.debug('📊 Affiliation: ' + aff.Id + 
                         ' | Total Points: ' + totalPointsSecured + 
                         ' | Total Credits: ' + totalCredits);

            if (totalCredits > 0 && totalPointsSecured > 0) { // 👈 ADD totalPointsSecured > 0
    Decimal cgpa = (totalPointsSecured / totalCredits).setScale(2);
    affiliationUpdates.add(new hed__Affiliation__c(
        Id = aff.Id,
        CGPA__c = cgpa
    ));
            }else{
// Else: skip update (grades not yet assigned or all zero) else {
                System.debug('❌ No valid credits for Affiliation: ' + aff.Id);
            }
        }

        System.debug('🏁 Processed ' + totalProcessed + ' affiliations, updated ' + totalUpdated);

        // STEP 5: Update
        if (!affiliationUpdates.isEmpty()) {
            update affiliationUpdates;
            System.debug('💾 Updated ' + affiliationUpdates.size() + ' affiliations');
        } else {
            System.debug('⚠️ No affiliations had valid data to update CGPA');
            // Do NOT throw exception — let LWC handle it gracefully
        }
    }
}