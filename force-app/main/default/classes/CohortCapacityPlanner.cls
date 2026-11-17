/**
* @name        CohortCapacityPlanner
* @description Provides course offering search and cohort planning functionality by course code
* @author      Vimal
* @createdDate 2025-07-25
*/

public with sharing class CohortCapacityPlanner {
    
    /**
* @description Search for course offerings by course code for Section cohort type
* @param courseCode - The course code to search for (e.g., "MBAG LSC 113")
* @return Map<String, Object> - Contains success status, course offerings data, and any error messages
*/
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> searchCourseOfferingsByCode(String courseCode) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            System.debug('Searching for course offerings with code: ' + courseCode);
            
            if (String.isBlank(courseCode)) {
                result.put('success', false);
                result.put('error', 'Course code is required');
                return result;
            }
            
            // Clean and prepare course code for search
            String cleanCourseCode = courseCode;
            String searchPattern = '%' + cleanCourseCode + '%';
            System.debug('searchPattern'+searchPattern);
            
            // Query course offerings by course code
            List<hed__Course_Offering__c> courseOfferings = [
                SELECT Id, Name,Parent_Course_Code__c, Course_Version__c,
                Course_Version__r.Course__c, Course_Version__r.Course__r.Name,
                Course_Version__r.Course__r.hed__Course_ID__c,
                hed__Start_Date__c,
                hed__End_Date__c,
                hed__Faculty__r.Name,
                hed__Faculty__c,
                Cohort_Created__c
                FROM hed__Course_Offering__c
                WHERE Parent_Course_Code__c LIKE :searchPattern AND hed__Faculty__c!= null
                WITH SECURITY_ENFORCED
                LIMIT 200
            ];
            System.debug('courseOfferings'+courseOfferings);
            
            
            if (courseOfferings.isEmpty()) {
                result.put('success', false);
                result.put('error', 'No course offerings found for course code: ' + courseCode);
                return result;
            }
            
            // Get course offering IDs for student count aggregation
            Set<Id> courseOfferingIds = new Set<Id>();
            for (hed__Course_Offering__c co : courseOfferings) {
                courseOfferingIds.add(co.Id);
            }
            
            // Get student connection counts
            Map<Id, Integer> studentCounts = getStudentConnectionCounts(courseOfferingIds);
            System.debug('Students'+studentCounts);
            
            // Prepare table data
            List<Map<String, Object>> tableData = new List<Map<String, Object>>();
            
            for (hed__Course_Offering__c co : courseOfferings) {
                Map<String, Object> rowData = new Map<String, Object>();
                System.debug('Id'+co.Id);
                rowData.put('Id', co.Id);
                rowData.put('CourseOfferingId', co.Id);
                System.debug(co.Name);
                rowData.put('CourseOfferingName', co.Name ?? '');
                System.debug(co.Parent_Course_Code__c );
                rowData.put('CourseCode', co.Parent_Course_Code__c ?? '');
                System.debug(co.Course_Version__r?.Course__r?.Name );
                rowData.put('CourseName', co.Course_Version__r?.Course__r?.Name ?? '');
                System.debug(co.hed__Start_Date__c);
                rowData.put('StartDate', co.hed__Start_Date__c);
                System.debug(co.hed__End_Date__c);
                rowData.put('EndDate', co.hed__End_Date__c);
                System.debug(co.hed__Faculty__r.Name);
                rowData.put('Faculty', co.hed__Faculty__r.Name ?? '');
                System.debug(studentCounts.get(co.Id));
                rowData.put('studentConnections', studentCounts.get(co.Id) ?? 0);
                System.debug(co.Cohort_Created__c);
                rowData.put('isFrozen', co.Cohort_Created__c == true);
                System.debug(co.Cohort_Created__c);
                rowData.put('CohortCreated', co.Cohort_Created__c == true);
                
                tableData.add(rowData);
            }
            System.debug('table'+tableData);
            
            result.put('success', true);
            result.put('courseOfferings', tableData);
            result.put('totalCount', tableData.size());
            
            System.debug('Found ' + tableData.size() + ' course offerings for: ' + courseCode);
            
        } catch (Exception e) {
            System.debug('Error in searchCourseOfferingsByCode: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            result.put('success', false);
            result.put('error', 'Error searching course offerings: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
* @description Search for course offerings by course code for Combined cohort type
*              Shows individual offerings but treats them as combined for cohort creation
* @param courseCode - The course code to search for
* @return Map<String, Object> - Contains success status and individual course offerings data
*/
  @AuraEnabled(cacheable=false)
public static Map<String, Object> searchCombinedCourseOfferings(String courseCode) {
    Map<String, Object> result = new Map<String, Object>();

    try {
        System.debug('Searching combined course offerings for code: ' + courseCode);

        if (String.isBlank(courseCode)) {
            result.put('success', false);
            result.put('error', 'Course code is required');
            return result;
        }

        // Clean and prepare course code for search
        String cleanCourseCode = courseCode;
        String searchPattern = '%' + cleanCourseCode + '%';

        // Query course offerings
        List<hed__Course_Offering__c> courseOfferings = [
            SELECT Id, Name,
                   Course_Version__r.Course__r.hed__Course_ID__c,
                   Course_Version__r.Course__r.Name,
                   hed__Start_Date__c,
                   hed__End_Date__c,
                   hed__Faculty__c,
                   hed__Faculty__r.Name,
                   Parent_Course_Code__c,
                   Cohort_Created__c
            FROM hed__Course_Offering__c
            WHERE Parent_Course_Code__c LIKE :searchPattern AND hed__Faculty__c != null
            WITH SECURITY_ENFORCED
            ORDER BY hed__Start_Date__c ASC, hed__End_Date__c ASC, hed__Faculty__c ASC
            LIMIT 200
        ];
        System.debug('courseOfferings' + courseOfferings);

        if (courseOfferings.isEmpty()) {
            result.put('success', false);
            result.put('error', 'No course offerings found for course code: ' + courseCode);
            return result;
        }

        // Get student connection counts for all offerings
        Set<Id> courseOfferingIds = new Set<Id>();
        for (hed__Course_Offering__c co : courseOfferings) {
            courseOfferingIds.add(co.Id);
        }

        Map<Id, Integer> studentCounts = getStudentConnectionCounts(courseOfferingIds);

        // Create individual rows for each course offering
        List<Map<String, Object>> tableData = new List<Map<String, Object>>();

        // Group metadata (used for cohort creation logic)
        Map<String, List<Id>> dateGroups = new Map<String, List<Id>>();
        Map<String, Integer> groupStudentTotals = new Map<String, Integer>();

        for (hed__Course_Offering__c co : courseOfferings) {
            // Create individual row data
            Map<String, Object> rowData = new Map<String, Object>();

            rowData.put('Id', co.Id);
            rowData.put('CourseOfferingId', co.Id);
            rowData.put('CourseOfferingName', co.Name ?? '');
            rowData.put('CourseCode', co.Parent_Course_Code__c ?? '');
            rowData.put('CourseName', co.Course_Version__r?.Course__r?.Name ?? '');
            rowData.put('StartDate', co.hed__Start_Date__c);
            rowData.put('EndDate', co.hed__End_Date__c);
            rowData.put('Faculty', co.hed__Faculty__r?.Name ?? '');

            Integer studentCount = studentCounts.get(co.Id) ?? 0;
            rowData.put('totalStudents', studentCount);
            rowData.put('studentConnections', studentCount);
            rowData.put('isFrozen', co.Cohort_Created__c == true);
            rowData.put('CohortCreated', co.Cohort_Created__c == true);

            // Group by Start Date + End Date + Faculty ID
            String startDateStr = co.hed__Start_Date__c != null ? co.hed__Start_Date__c.format() : 'No Start Date';
            String endDateStr = co.hed__End_Date__c != null ? co.hed__End_Date__c.format() : 'No End Date';
            String facultyIdStr = co.hed__Faculty__c != null ? (String)co.hed__Faculty__c : 'No Faculty';

            String groupKey = startDateStr + '|' + endDateStr + '|' + facultyIdStr;

            if (!dateGroups.containsKey(groupKey)) {
                dateGroups.put(groupKey, new List<Id>());
                groupStudentTotals.put(groupKey, 0);
            }
            dateGroups.get(groupKey).add(co.Id);
            groupStudentTotals.put(groupKey, groupStudentTotals.get(groupKey) + studentCount);

            // Add group info to row
            rowData.put('dateGroupKey', groupKey);
            rowData.put('isPartOfGroup', true);

            tableData.add(rowData);
        }

        // Add group totals to each row for reference
        for (Map<String, Object> rowData : tableData) {
            String groupKey = (String) rowData.get('dateGroupKey');
            List<Id> groupIds = dateGroups.get(groupKey);
            rowData.put('groupTotalStudents', groupStudentTotals.get(groupKey));
            rowData.put('groupOfferingIds', groupIds);
            rowData.put('offeringsCount', groupIds.size());
        }

        result.put('success', true);
        result.put('courseOfferings', tableData);
        result.put('totalCount', tableData.size());
        result.put('dateGroups', dateGroups); // For debugging/reference

        System.debug('Found ' + tableData.size() + ' individual course offerings for: ' + courseCode);

    } catch (Exception e) {
        System.debug('Error in searchCombinedCourseOfferings: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        result.put('success', false);
        result.put('error', 'Error searching combined course offerings: ' + e.getMessage());
    }

    return result;
}
    
    /**
* @description Get the Section Data from course offering course connections records 
* @param  courseOfferingIds         
* @return   Map<String, Object> 
*/ 
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSectionData(List<Id> courseOfferingIds) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('sections', new List<Map<String, Object>>());
        result.put('sectionStudentCounts', new Map<String, Integer>());
        
        if (courseOfferingIds == null || courseOfferingIds.isEmpty()) {
            return result;
        }
        
        // Single aggregate query to get sections and counts
        AggregateResult[] sectionResults = [
            SELECT hed__Program_Enrollment__r.Section__c sec,
            COUNT(Id) cnt
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :courseOfferingIds
            AND hed__Program_Enrollment__r.Section__c != null
            AND Cohort_Planner__c = null
            WITH SECURITY_ENFORCED
            GROUP BY hed__Program_Enrollment__r.Section__c
        ];
        
        List<Map<String, Object>> sectionData = new List<Map<String, Object>>();
        Map<String, Integer> sectionStudentCounts = new Map<String, Integer>();
        
        for (AggregateResult ar : sectionResults) {
            String section = (String) ar.get('sec');
            Integer count = (Integer) ar.get('cnt');
            if (String.isBlank(section)) continue;
            
            sectionStudentCounts.put(section, count);
            sectionData.add(new Map<String, Object>{
                'name' => section,
                    'studentCount' => count,
                    'cohorts' => 1,
                    'capacityPerCohort' => 0
                    });
        }
        
        result.put('sections', sectionData);
        result.put('sectionStudentCounts', sectionStudentCounts);
        return result;
    }

    
    /**
* @description Helper method to get student connection counts for course offerings
* @param courseOfferingIds - Set of course offering IDs
* @return Map<Id, Integer> - Map of course offering ID to student count
*/
    private static Map<Id, Integer> getStudentConnectionCounts(Set<Id> courseOfferingIds) {
        
        Id studentRecordTypeId = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName().get('Student')?.getRecordTypeId();
        
        if (studentRecordTypeId == null) {
            // Handle case where 'Student' record type doesn't exist
            throw new AuraHandledException('Record Type "Student" not found for hed__Course_Enrollment__c');
        }
        Map<Id, Integer> studentCounts = new Map<Id, Integer>();
        
        if (courseOfferingIds.isEmpty()) {
            return studentCounts;
        }
        
        try {
            // Aggregate query to get student counts per course offering
            AggregateResult[] results = [
                SELECT hed__Course_Offering__c courseOfferingId, COUNT(Id) studentCount
                FROM hed__Course_Enrollment__c
                WHERE hed__Course_Offering__c IN :courseOfferingIds AND RecordTypeId = :studentRecordTypeId
                WITH SECURITY_ENFORCED
                GROUP BY hed__Course_Offering__c
            ];
            
            for (AggregateResult ar : results) {
                Id courseOfferingId = (Id) ar.get('courseOfferingId');
                Integer count = (Integer) ar.get('studentCount');
                studentCounts.put(courseOfferingId, count ?? 0);
            }
            
        } catch (Exception e) {
            System.debug('Error getting student connection counts: ' + e.getMessage());
        }
        
        return studentCounts;
    }
    
    /**
* @description Create cohort planner records for selected course offerings
* @param selectedCourseOfferingIds - List of selected course offering IDs
* @param courseCode - The course code being processed
* @param cohorts - Number of cohorts to create (for Combined type)
* @param studentCapacity - Total student capacity (for Combined type)
* @param cohortType - Type of cohort (Section or Combined)
* @param sectionData - JSON string containing section configuration (for Section type)
* @return String - Success or error message
*/
    @AuraEnabled
    public static String createCohortPlanner(
        List<String> selectedCourseOfferingIds,
        String courseCode,
        Decimal cohorts,
        Decimal studentCapacity,
        String cohortType,
        String sectionData
    ) {
        try {
            System.debug('Creating cohort planner for course code: ' + courseCode);
            System.debug('Selected offerings: ' + selectedCourseOfferingIds);
            System.debug('Cohort type: ' + cohortType);
            System.debug('Section data: ' + sectionData);
            
            // Validate input parameters
            if (selectedCourseOfferingIds == null || selectedCourseOfferingIds.isEmpty()) {
                return 'Error: No Course Offerings selected.';
            }
            
            if (String.isBlank(courseCode)) {
                return 'Error: Course code is required.';
            }
            
            // Convert string IDs to actual IDs
            Set<Id> actualOfferingIds = new Set<Id>();
            
            for (String selectedId : selectedCourseOfferingIds) {
                try {
                    actualOfferingIds.add((Id) selectedId);
                } catch (Exception e) {
                    System.debug('Invalid ID format: ' + selectedId);
                }
            }
            
            if (actualOfferingIds.isEmpty()) {
                return 'Error: No valid Course Offering IDs found.';
            }
            
            // Get the course offerings
            List<hed__Course_Offering__c> selectedCourseOfferings = [
                SELECT Id, Name, Course_Version__c, Cohort_Created__c, 
                Course_Version__r.Course__r.hed__Course_ID__c,
                hed__Start_Date__c, hed__End_Date__c
                FROM hed__Course_Offering__c
                WHERE Id IN :actualOfferingIds
                WITH SECURITY_ENFORCED
            ];
            
            if (selectedCourseOfferings.isEmpty()) {
                return 'Error: No Course Offerings found with the provided IDs.';
            }
            
            // Check if any offerings already have cohorts created
            List<String> lockedOfferings = new List<String>();
            for (hed__Course_Offering__c co : selectedCourseOfferings) {
                if (co.Cohort_Created__c == true) {
                    lockedOfferings.add(co.Name);
                }
            }
            
            if (!lockedOfferings.isEmpty()) {
                return 'Error: The following Course Offerings already have cohorts created: ' + 
                    String.join(lockedOfferings, ', ');
            }
            
            // Handle different cohort types
            if (cohortType == 'Section') {
                return createSectionCohorts(actualOfferingIds, courseCode, sectionData);
            } else {
                return createCombinedCohorts(actualOfferingIds, courseCode, cohorts, studentCapacity);
            }
            
        } catch (Exception e) {
            System.debug('Error in createCohortPlanner: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return 'Error creating cohort planner: ' + e.getMessage();
        }
    }
    
    /**
* @description Create cohorts for Section type
*/	
    private static String createSectionCohorts(Set<Id> offeringIds, String courseCode, String sectionDataJson) {
        try {
            if (String.isBlank(sectionDataJson)) {
                return 'Error: Section configuration data is required for Section cohort type.';
            }
            
            // Parse section data
            List<Object> sectionList = (List<Object>) JSON.deserializeUntyped(sectionDataJson);
            Map<String, Map<String, Object>> sectionConfig = new Map<String, Map<String, Object>>();
            
            for (Object sectionObj : sectionList) {
                Map<String, Object> section = (Map<String, Object>) sectionObj;
                String sectionName = (String) section.get('name');
                sectionConfig.put(sectionName, section);
            }
            
            if (sectionConfig.isEmpty()) {
                return 'Error: No valid section configuration found.';
            }
            
            // Get course enrollments grouped by section
            List<hed__Course_Enrollment__c> courseEnrollments = [
                SELECT Id, hed__Course_Offering__c,hed__Course_Offering__r.hed__Course__c, hed__Program_Enrollment__r.Section__c, Cohort_Planner__c
                FROM hed__Course_Enrollment__c
                WHERE hed__Course_Offering__c IN :offeringIds
                AND hed__Program_Enrollment__r.Section__c != null
                AND Cohort_Planner__c = null
                WITH SECURITY_ENFORCED
            ];
            
            // Determine the course ID (assuming all offerings are for the same course)
            Set<Id> courseIds = new Set<Id>();
            for (hed__Course_Enrollment__c ce : courseEnrollments) {
                courseIds.add(ce.hed__Course_Offering__r.hed__Course__c);
            }
            if (courseIds.size() != 1) {
                return 'Error: Expected all offerings to belong to the same course. Found ' + courseIds.size() + ' course(s).';
            }
            Id courseId = courseIds.iterator().next();
            
            
            // Group enrollments by section
            Map<String, List<hed__Course_Enrollment__c>> enrollmentsBySection = new Map<String, List<hed__Course_Enrollment__c>>();
            
            for (hed__Course_Enrollment__c enrollment : courseEnrollments) {
                String section = enrollment.hed__Program_Enrollment__r.Section__c;
                if (!enrollmentsBySection.containsKey(section)) {
                    enrollmentsBySection.put(section, new List<hed__Course_Enrollment__c>());
                }
                enrollmentsBySection.get(section).add(enrollment);
            }
            
            // Create cohort planners for each section
            List<Cohort_Planner__c> cohortsToInsert = new List<Cohort_Planner__c>();
            Map<String, List<Id>> sectionCohortIds = new Map<String, List<Id>>();
            
            for (String sectionName : sectionConfig.keySet()) {
                Map<String, Object> config = sectionConfig.get(sectionName);
                Integer numCohorts = (Integer) config.get('cohorts');
                Integer capacityPerCohort = (Integer) config.get('capacityPerCohort');
                
                List<Id> cohortIds = new List<Id>();
                Integer rand = Integer.valueOf(Math.random());
                
                for (Integer i = 1; i <= numCohorts; i++) {
                    Cohort_Planner__c cohortPlanner = new Cohort_Planner__c();
                    cohortPlanner.Student_Capacity__c = capacityPerCohort;
                   // cohortPlanner.Name = courseCode + ' - ' + sectionName + ' - Cohort ' + i + rand;
                    cohortPlanner.Section__c = sectionName;
                    cohortPlanner.Course__c = courseId;
                    cohortsToInsert.add(cohortPlanner);
                }
                
                sectionCohortIds.put(sectionName, cohortIds);
            }
            
            // Insert cohort planners
            if (!cohortsToInsert.isEmpty()) {
                if (Schema.sObjectType.Cohort_Planner__c.isCreateable()) {
    insert cohortsToInsert;
    
}
                
                // Update the cohort IDs after insertion
                Integer cohortIndex = 0;
                for (String sectionName : sectionConfig.keySet()) {
                    Map<String, Object> config = sectionConfig.get(sectionName);
                    Integer numCohorts = (Integer) config.get('cohorts');
                    
                    List<Id> cohortIds = new List<Id>();
                    for (Integer i = 0; i < numCohorts; i++) {
                        cohortIds.add(cohortsToInsert[cohortIndex].Id);
                        cohortIndex++;
                    }
                    sectionCohortIds.put(sectionName, cohortIds);
                }
            }
            
            // Assign students to cohorts within each section
            List<hed__Course_Enrollment__c> enrollmentsToUpdate = new List<hed__Course_Enrollment__c>();
            
            for (String sectionName : enrollmentsBySection.keySet()) {
                List<hed__Course_Enrollment__c> sectionEnrollments = enrollmentsBySection.get(sectionName);
                List<Id> cohortIds = sectionCohortIds.get(sectionName);
                
                if (cohortIds != null && !cohortIds.isEmpty()) {
                    Integer studentIndex = 0;
                    for (hed__Course_Enrollment__c enrollment : sectionEnrollments) {
                        Integer cohortIndex = Math.mod(studentIndex, cohortIds.size());
                        enrollment.Cohort_Planner__c = cohortIds[cohortIndex];
                        enrollmentsToUpdate.add(enrollment);
                        studentIndex++;
                    }
                }
            }
            
            if (!enrollmentsToUpdate.isEmpty()) {
                if (Schema.sObjectType.hed__Course_Enrollment__c.isUpdateable()) {
        update enrollmentsToUpdate;

    } 
            }
            
            // Update Course Offerings to mark cohorts as created
            List<hed__Course_Offering__c> offeringsToUpdate = new List<hed__Course_Offering__c>();
            for (Id offeringId : offeringIds) {
                hed__Course_Offering__c offering = new hed__Course_Offering__c();
                offering.Id = offeringId;
                offering.Cohort_Created__c = true;
                offeringsToUpdate.add(offering);
            }
            
            if (!offeringsToUpdate.isEmpty()) {
                if (Schema.sObjectType.hed__Course_Offering__c.isUpdateable()) {
        update offeringsToUpdate;
    } 
            }
            
            String resultMessage = String.format(
                'Successfully created section-based cohorts for course code "{0}". ' +
                'Created {1} cohort(s) across {2} section(s). ' +
                'Updated {3} course offering(s) and assigned {4} student(s) to cohorts.',
                new List<Object>{
                    courseCode,
                        cohortsToInsert.size(),
                        sectionConfig.size(),
                        offeringIds.size(),
                        enrollmentsToUpdate.size()
                        }
            );
            
            return resultMessage;
            
        } catch (Exception e) {
            System.debug('Error in createSectionCohorts: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return 'Error creating section cohorts: ' + e.getMessage();
        }
    }
    
    
    
    /**
* @description Create cohorts for Combined type
*/@TestVisible
  private static String createCombinedCohorts(Set<Id> offeringIds, String courseCode, Decimal cohorts, Decimal studentCapacity) {
    try {
        Integer cohortsInt = cohorts != null ? Integer.valueOf(cohorts) : 0;
        Integer studentCapacityInt = studentCapacity != null ? Integer.valueOf(studentCapacity) : 0;

        if (cohortsInt <= 0) {
            return 'Error: Number of cohorts must be a positive number.';
        }

        if (studentCapacityInt <= 0) {
            return 'Error: Student capacity must be a positive number.';
        }

        // Calculate capacity per cohort
        Decimal capacityPerCohort = Decimal.valueOf(studentCapacityInt) / Decimal.valueOf(cohortsInt);

        // 🔹 Get the Course ID from the offerings
        List<hed__Course_Offering__c> offerings = [
            SELECT Id, Course_Version__r.Course__c
            FROM hed__Course_Offering__c
            WHERE Id IN :offeringIds
            WITH SECURITY_ENFORCED
        ];

        if (offerings.isEmpty()) {
            return 'Error: No valid course offerings found for the given IDs.';
        }

        // Ensure all offerings belong to the same course
        Set<Id> courseIds = new Set<Id>();
        for (hed__Course_Offering__c co : offerings) {
            courseIds.add(co.Course_Version__r.Course__c);
        }

        if (courseIds.size() != 1) {
            return 'Error: All selected offerings must belong to the same course. Found ' + courseIds.size() + ' different course(s).';
        }

        Id courseId = courseIds.iterator().next();

        // Create Cohort_Planner__c records
        List<Cohort_Planner__c> cohortsToInsert = new List<Cohort_Planner__c>();

        for (Integer i = 1; i <= cohortsInt; i++) {
            Cohort_Planner__c cohortPlanner = new Cohort_Planner__c();
            cohortPlanner.Student_Capacity__c = capacityPerCohort;
           // cohortPlanner.Name = courseCode + ' - Cohort ' + i;
            cohortPlanner.Course__c = courseId; 
            cohortsToInsert.add(cohortPlanner);
        }

        // Insert cohort planners
        if (!cohortsToInsert.isEmpty()) {
            if (Schema.sObjectType.Cohort_Planner__c.isCreateable()) {
    insert cohortsToInsert;
    
}
        }

        // Get all course enrollments for the offering IDs
        List<hed__Course_Enrollment__c> courseEnrollments = [
            SELECT Id, hed__Course_Offering__c, Cohort_Planner__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :offeringIds
              AND Cohort_Planner__c = null
            WITH SECURITY_ENFORCED
        ];

        
        // Assign students to cohorts using sequential (first-serve) allocation
if (!courseEnrollments.isEmpty() && !cohortsToInsert.isEmpty()) {
    List<Id> cohortPlannerIds = new List<Id>();
    for (Cohort_Planner__c cp : cohortsToInsert) {
        cohortPlannerIds.add(cp.Id);
    }

    List<hed__Course_Enrollment__c> enrollmentsToUpdate = new List<hed__Course_Enrollment__c>();
    
    Integer cohortCount = cohortPlannerIds.size();
    Integer currentCohortIndex = 0;
    Integer studentsInCurrentCohort = 0;
    Integer capacityPerCohortInt = capacityPerCohort.intValue(); // Convert to Integer

    for (hed__Course_Enrollment__c enrollment : courseEnrollments) {
        // If current cohort is full (and capacity > 0), move to next cohort
        if (capacityPerCohortInt > 0 && studentsInCurrentCohort >= capacityPerCohortInt) {
            currentCohortIndex++;
            studentsInCurrentCohort = 0;
            
            // Safety: if we run out of cohorts, assign to the last one
            if (currentCohortIndex >= cohortCount) {
                currentCohortIndex = cohortCount - 1;
                // Optionally log or warn: "All cohorts are full. Remaining students assigned to last cohort."
            }
        }

        // Assign student to current cohort
        enrollment.Cohort_Planner__c = cohortPlannerIds[currentCohortIndex];
        enrollmentsToUpdate.add(enrollment);
        studentsInCurrentCohort++;
    }

    if (!enrollmentsToUpdate.isEmpty()) {
        if (Schema.sObjectType.hed__Course_Enrollment__c.isUpdateable()) {
        update enrollmentsToUpdate;
    } 
    }
}

        // Update Course Offerings to mark cohorts as created
        List<hed__Course_Offering__c> offeringsToUpdate = new List<hed__Course_Offering__c>();
        for (Id offeringId : offeringIds) {
            hed__Course_Offering__c offering = new hed__Course_Offering__c();
            offering.Id = offeringId;
            offering.Cohort_Created__c = true;
            offeringsToUpdate.add(offering);
        }

        if (!offeringsToUpdate.isEmpty()) {
            if (Schema.sObjectType.hed__Course_Offering__c.isUpdateable()) {
        update offeringsToUpdate;
    }
        }

        String resultMessage = String.format(
            'Successfully created {0} cohort(s) for course code "{1}" (Combined type). ' +
            'Updated {2} course offering(s) and assigned {3} student(s) to cohorts.',
            new List<Object>{
                cohortsToInsert.size(),
                courseCode,
                offeringIds.size(),
                courseEnrollments.size()
            }
        );

        return resultMessage;

    } catch (Exception e) {
        System.debug('Error in createCombinedCohorts: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        return 'Error creating combined cohorts: ' + e.getMessage();
    }
}
}