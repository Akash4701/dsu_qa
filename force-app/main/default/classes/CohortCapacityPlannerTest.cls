@isTest
public class CohortCapacityPlannerTest {
    
    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Program');
        insert acc;
        
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course', 
            hed__Course_ID__c = 'MBAG LSC 113',
            hed__Account__c = acc.Id
        );
        insert course;
        
        Contact faculty = new Contact(
            FirstName = 'Test',
            LastName = 'Faculty',
            Email = 'test@email.com'
        );
        insert faculty;
        hed__Term__c hedTerm = new hed__Term__c(
            Name = 'Fall Term',
            Term_Reference__c= 'Term 1',
            hed__Account__c = acc.id
        );
        insert hedTerm;
        Course_Version__c courseVersion = new Course_Version__c(
            Course__c = course.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30)
        );
        insert courseVersion;
        
        List<hed__Course_Offering__c> offerings = new List<hed__Course_Offering__c>();
        for(Integer i = 0; i < 3; i++) {
            offerings.add(new hed__Course_Offering__c(
                Name = 'Test Offering ' + i,
                Course_Version__c = courseVersion.Id,
                hed__Term__c = hedTerm.id,
                hed__Course__c = course.Id,
                
                hed__Start_Date__c = Date.today(),
                hed__End_Date__c = Date.today().addDays(30),
                hed__Faculty__c = faculty.Id,
                Cohort_Created__c = i == 2 ? true : false
            ));
        }
        insert offerings;
        
        List<hed__Program_Enrollment__c> programEnrollments = new List<hed__Program_Enrollment__c>();
        for(Integer i = 0; i < 5; i++) {
            programEnrollments.add(new hed__Program_Enrollment__c(
                Section__c = (i < 3 ? 'A' : 'B')
            ));
        }
        insert programEnrollments;
        
        List<hed__Course_Enrollment__c> courseEnrollments = new List<hed__Course_Enrollment__c>();
        for(Integer i = 0; i < 5; i++) {
            courseEnrollments.add(new hed__Course_Enrollment__c(
                hed__Course_Offering__c = offerings[i < 2 ? 0 : 1].Id,
                hed__Program_Enrollment__c = programEnrollments[i].Id
            ));
        }
        insert courseEnrollments;
        
        Cohort_Planner__c cohort = new Cohort_Planner__c(
            
            Student_Capacity__c = 30,
            Course__c = course.Id
        );
        insert cohort;
    }
    
    @isTest
    static void testSearchCourseOfferingsByCodeSuccess() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.searchCourseOfferingsByCode('MBAG LSC 113');
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCourseOfferingsByCodeBlank() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.searchCourseOfferingsByCode('');
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCourseOfferingsByCodeNull() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.searchCourseOfferingsByCode(null);
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCourseOfferingsByCodeNotFound() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.searchCourseOfferingsByCode('NONEXISTENT');
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCourseOfferingsByCodeException() {
        Test.startTest();
        try {
            Map<String, Object> result = CohortCapacityPlanner.searchCourseOfferingsByCode('INVALID%QUERY');
        } catch(Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCombinedCourseOfferingsSuccess() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.searchCombinedCourseOfferings('MBAG LSC 113');
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCombinedCourseOfferingsBlank() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.searchCombinedCourseOfferings('');
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCombinedCourseOfferingsNull() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.searchCombinedCourseOfferings(null);
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCombinedCourseOfferingsNotFound() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.searchCombinedCourseOfferings('NOTFOUND');
        Test.stopTest();
    }
    
    @isTest
    static void testSearchCombinedCourseOfferingsException() {
        Test.startTest();
        try {
            Map<String, Object> result = CohortCapacityPlanner.searchCombinedCourseOfferings('ERROR%QUERY');
        } catch(Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetSectionDataSuccess() {
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c LIMIT 2];
        List<Id> offeringIds = new List<Id>();
        for(hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.getSectionData(offeringIds);
        Test.stopTest();
    }
    
    @isTest
    static void testGetSectionDataEmpty() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.getSectionData(new List<Id>());
        Test.stopTest();
    }
    
    @isTest
    static void testGetSectionDataNull() {
        Test.startTest();
        Map<String, Object> result = CohortCapacityPlanner.getSectionData(null);
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerSectionSuccess() {
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c WHERE Cohort_Created__c = false LIMIT 1];
        List<String> offeringIds = new List<String>();
        for(hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        String sectionData = '[{"name":"Section A","cohorts":2,"capacityPerCohort":15}]';
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, 'MBAG LSC 113', null, null, 'Section', sectionData
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerCombinedSuccess() {
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c WHERE Cohort_Created__c = false LIMIT 1];
        List<String> offeringIds = new List<String>();
        for(hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, 'MBAG LSC 113', 2, 50, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerEmptyOfferings() {
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            new List<String>(), 'MBAG LSC 113', 2, 50, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerNullOfferings() {
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            null, 'MBAG LSC 113', 2, 50, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerBlankCourseCode() {
        List<String> offeringIds = new List<String>{'testId'};
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, '', 2, 50, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerNullCourseCode() {
        List<String> offeringIds = new List<String>{'testId'};
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, null, 2, 50, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerInvalidIds() {
        List<String> offeringIds = new List<String>{'invalidId'};
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, 'MBAG LSC 113', 2, 50, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerLockedOfferings() {
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c WHERE Cohort_Created__c = true LIMIT 1];
        List<String> offeringIds = new List<String>();
        for(hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, 'MBAG LSC 113', 2, 50, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerSectionBlankData() {
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c WHERE Cohort_Created__c = false LIMIT 1];
        List<String> offeringIds = new List<String>();
        for(hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, 'MBAG LSC 113', null, null, 'Section', ''
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerSectionInvalidData() {
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c WHERE Cohort_Created__c = false LIMIT 1];
        List<String> offeringIds = new List<String>();
        for(hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, 'MBAG LSC 113', null, null, 'Section', '[]'
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerCombinedZeroCohorts() {
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c WHERE Cohort_Created__c = false LIMIT 1];
        List<String> offeringIds = new List<String>();
        for(hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, 'MBAG LSC 113', 0, 50, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerCombinedZeroCapacity() {
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c WHERE Cohort_Created__c = false LIMIT 1];
        List<String> offeringIds = new List<String>();
        for(hed__Course_Offering__c offering : offerings) {
            offeringIds.add(offering.Id);
        }
        
        Test.startTest();
        String result = CohortCapacityPlanner.createCohortPlanner(
            offeringIds, 'MBAG LSC 113', 2, 0, 'Combined', null
        );
        Test.stopTest();
    }
    
    @isTest
    static void testCreateCohortPlannerException() {
        Test.startTest();
        try {
            String result = CohortCapacityPlanner.createCohortPlanner(
                new List<String>{'invalidFormatId'}, 'MBAG LSC 113', 2, 50, 'Combined', null
            );
        } catch(Exception e) {
        }
        Test.stopTest();
    }
}