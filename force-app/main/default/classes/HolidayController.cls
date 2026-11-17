/**
 * Controller for Holiday functionality in Academic Program Planner
 */
public with sharing class HolidayController {
    
    /**
     * Get all holidays
     * @return List of all holidays
     */
    @AuraEnabled(cacheable=true)
    public static List<K42_Holiday__c> getAllHolidays() {
        try {
            return [
                SELECT Id, Name, K42_Hol_Start_Date__c, K42_Hol_End_Date__c
                FROM K42_Holiday__c
                WITH SECURITY_ENFORCED
                ORDER BY K42_Hol_Start_Date__c
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving holidays: ' + e.getMessage());
        }
    }
    
   /**
 * Method to get course offerings for a term
 * @param termId - Id of the term
 * @return List of course offerings
 */
@AuraEnabled(cacheable=false) // Change from cacheable=true to false to prevent caching
public static List<hed__Course_Offering__c> getTermCourseOfferings(String termId) {
    try {
        System.debug('Getting course offerings for term: ' + termId);
        
        List<hed__Course_Offering__c> offerings = [
            SELECT Id, 
                   Name, 
                   hed__Course__c, 
                   hed__Course__r.Name, 
                   hed__Course__r.hed__Course_ID__c, 
                   hed__Course__r.Credits__c,
                   hed__Capacity__c,
                   hed__Section_ID__c, 
                   hed__Start_Date__c, 
                   hed__End_Date__c,
                   Course_Version__c,
                   Course_Version__r.WeekNo__c
            FROM hed__Course_Offering__c
            WHERE hed__Term__c = :termId
            WITH SECURITY_ENFORCED
            ORDER BY hed__Course__r.Name, hed__Section_ID__c
        ];
        
        System.debug('Found ' + offerings.size() + ' course offerings');
        return offerings;
    } catch (Exception e) {
        System.debug('Error retrieving course offerings: ' + e.getMessage());
        throw new AuraHandledException('Error retrieving course offerings: ' + e.getMessage());
    }
}
    
    /**
     * Method to delete a course offering
     * @param courseOfferingId - Id of the course offering to delete
     * @return Boolean indicating success or failure
     */
    @AuraEnabled
    public static Boolean deleteCourseOffering(String courseOfferingId) {
        try {
            hed__Course_Offering__c courseOffering = [
                SELECT Id 
                FROM hed__Course_Offering__c 
                WHERE Id = :courseOfferingId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
           if (Schema.sObjectType.hed__Course_Offering__c.isDeletable()) {
        delete courseOffering;
    } 
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting course offering: ' + e.getMessage());
        }
    }
    
    /**
     * Method to get available subjects (courses) for a term, filtered by academic program
     * @param termId - Id of the term
     * @return List of available courses for the term's academic program
     */
    @AuraEnabled
    public static List<hed__Course__c> getAvailableSubjects(String termId) {
        try {
            // First, get the academic program ID associated with this term
            String academicProgramId = '';
            
            // Query the term to get its associated program plan
            hed__Term__c term = [
                SELECT Id, hed__Account__c, Program_Plan__c, Program_Plan__r.hed__Account__c
                FROM hed__Term__c
                WHERE Id = :termId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            // Determine which account ID to use for filtering courses
            if (term.Program_Plan__c != null && term.Program_Plan__r.hed__Account__c != null) {
                // If term is linked to a program plan, use the program plan's account
                academicProgramId = term.Program_Plan__r.hed__Account__c;
            } else if (term.hed__Account__c != null) {
                // Otherwise use the term's directly associated account
                academicProgramId = term.hed__Account__c;
            }
            
            // Query courses filtered by academic program if we have an academic program ID
            if (String.isNotBlank(academicProgramId)) {
                return [
                    SELECT Id, Name, hed__Course_ID__c, Credits__c
                    FROM hed__Course__c
                    WHERE hed__Account__c = :academicProgramId
                    WITH SECURITY_ENFORCED
                    ORDER BY Name
                ];
            } else {
                // Fallback: if no academic program found, return all courses
                return [
                    SELECT Id, Name, hed__Course_ID__c, Credits__c
                    FROM hed__Course__c
                    WITH SECURITY_ENFORCED
                    ORDER BY Name
                ];
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving available subjects: ' + e.getMessage());
        }
    }
    
    /**
 * Method to get available subjects based on Plan Requirements with Master Unit record type
 * @param termId - Id of the term
 * @return List of available courses from Master Unit plan requirements
 */
/**
 * Method to get available subjects based on Plan Requirements with Master Unit record type
 * @param termId - Id of the term
 * @return List of available courses from Master Unit plan requirements
 */
@AuraEnabled
public static List<Map<String, Object>> getAvailableSubjectsFromMasterUnits(String termId,Id academicProgramId) {
    try {
        // Get the term with program plan information
        hed__Term__c term = [
            SELECT Id, Name, Program_Plan__c
            FROM hed__Term__c
            WHERE Id = :termId 
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        hed__Course__c course = [
            SELECT Id, Name
            FROM hed__Course__c
            WHERE hed__Account__c = :academicProgramId
           WITH SECURITY_ENFORCED
            LIMIT 1
        ];

         // Extract term number from the term name
         String termName = Term.Name;
         String termNumber = '';
         
         



        // Get master unit record type ID
        Id masterUnitRecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();

        //String likePattern1 ='%'+termNumber+'__';
        //String likePattern2 ='%'+termNumber+'___';

        // Query for Plan Requirements with Master Unit record type
        List<hed__Plan_Requirement__c> masterUnits = [
            SELECT Id, hed__Course__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c, 
                   hed__Course__r.Credits__c, hed__Course__r.hed__Credit_Hours__c
            FROM hed__Plan_Requirement__c
            WHERE RecordTypeId = :masterUnitRecordTypeId
            AND hed__Course__c != null
            AND hed__Course__r.hed__Account__c = :academicProgramId
            WITH SECURITY_ENFORCED
            ORDER BY hed__Course__r.Name
        ];
        
        // Transform results to a list of maps
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        Set<Id> uniqueCourseIds = new Set<Id>(); // To avoid duplicates
        
        for(hed__Plan_Requirement__c unit : masterUnits) {
            // Skip duplicate courses
            if(uniqueCourseIds.contains(unit.hed__Course__c)) {
                continue;
            }
            
            // Add to unique course IDs set
            uniqueCourseIds.add(unit.hed__Course__c);
            
            Map<String, Object> courseInfo = new Map<String, Object>();
            courseInfo.put('id', unit.hed__Course__c);
            courseInfo.put('label', unit.hed__Course__r.Name);
            courseInfo.put('value', unit.hed__Course__c);
            courseInfo.put('courseId', unit.hed__Course__r.hed__Course_ID__c);
            courseInfo.put('credits', unit.hed__Course__r.Credits__c);
            courseInfo.put('creditHours', unit.hed__Course__r.hed__Credit_Hours__c);
            
            result.add(courseInfo);
        }
        
        return result;
    } catch (Exception e) {
        throw new AuraHandledException('Error retrieving subjects from Master Units: ' + e.getMessage());
    }
}
 
  /**
 * Method to add a subject as a Plan Requirement and create Course Version
 * @param termId - Id of the term
 * @param courseId - Id of the course
 * @param sectionId - Section ID
 * @param startDate - Start date
 * @param endDate - End date
 * @param capacity - Capacity value
 * @return Id of the created Plan Requirement record
 */
/**
 * Method to add a subject as a Plan Requirement and create Course Version
 * Ensures only one of each record type is created
 * @param termId - Id of the term
 * @param courseId - Id of the course
 * @param sectionId - Section ID
 * @param startDate - Start date
 * @param endDate - End date
 * @param capacity - Capacity value
 * @return Id of the created Plan Requirement record
 */
/**
 * Method to add a subject as a Plan Requirement and create Course Version
 * Ensures only one of each record type is created
 * @param termId - Id of the term
 * @param courseId - Id of the course
 * @param sectionId - Section ID
 * @param startDate - Start date
 * @param endDate - End date
 * @param capacity - Capacity value
 * @return Id of the created Plan Requirement record
 */
@AuraEnabled
public static String addSubjectAsPlanRequirement(String termId, String courseId, String sectionId, 
                                              String startDate, String endDate, String capacity) {
    // Create a savepoint for transaction control
    Savepoint sp = Database.setSavepoint();
    
    try {
        System.debug('Starting addSubjectAsPlanRequirement with parameters:');
        System.debug('  termId: ' + termId);
        System.debug('  courseId: ' + courseId);
        System.debug('  sectionId: ' + sectionId);
        System.debug('  startDate: ' + startDate);
        System.debug('  endDate: ' + endDate);
        System.debug('  capacity: ' + capacity);
        
        // Ensure Section ID is provided
        if (String.isBlank(sectionId)) {
            throw new AuraHandledException('Section ID is required to create a course offering.');
        }
        
        // Get the term and course
        hed__Term__c term = [
            SELECT Id, Name, Program_Plan__c, Program_Plan__r.hed__Account__c, 
                   hed__Start_Date__c, hed__End_Date__c, Campus__c
            FROM hed__Term__c 
            WHERE Id = :termId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
     
        
        hed__Course__c course = [
    SELECT Id, Name, hed__Course_ID__c, Credits__c, hed__Credit_Hours__c,
           (SELECT Id, hed__Category__c 
            FROM hed__Plan_Requirements__r 
            WHERE RecordType.DeveloperName = 'Master_Unit'
            LIMIT 1)
    FROM hed__Course__c
    WHERE Id = :courseId
    WITH SECURITY_ENFORCED
    LIMIT 1
];
        
        String standardizedName = term.Name + ' ' + course.Name + '-' + sectionId;
        System.debug('Generated name: ' + standardizedName);
        
        // STEP 1: DELETE ANY EXISTING RECORDS FOR THIS COURSE IN THIS TERM
        // This ensures we're starting with a clean slate and avoids duplicates
        
        // Check for existing course offerings
        List<hed__Course_Offering__c> existingOfferings = [
            SELECT Id 
            FROM hed__Course_Offering__c 
            WHERE hed__Term__c = :termId 
            AND hed__Course__c = :courseId
            AND hed__Section_ID__c = :sectionId
            WITH SECURITY_ENFORCED
        ];
        
        // Check for existing course versions
        List<Course_Version__c> existingVersions = [
            SELECT Id 
            FROM Course_Version__c 
            WHERE Term__c = :termId 
            AND Course__c = :courseId
            WITH SECURITY_ENFORCED
        ];
        
        // Check for existing plan requirements (only Unit record type)
        Id unitRecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c
            .getRecordTypeInfosByDeveloperName().get('Unit').getRecordTypeId();
            
        // Log the record type ID to debug
        System.debug('Unit record type ID: ' + unitRecordTypeId);
            
        List<hed__Plan_Requirement__c> existingReqs = [
            SELECT Id, RecordTypeId 
            FROM hed__Plan_Requirement__c 
            WHERE Term__c = :termId 
            AND hed__Course__c = :courseId
            WITH SECURITY_ENFORCED
        ];
        
        // Log all plan requirements for this course and term for debugging
        System.debug('Found ' + existingReqs.size() + ' existing plan requirements');
        for (hed__Plan_Requirement__c req : existingReqs) {
            System.debug('Existing plan requirement: Id=' + req.Id + ', RecordTypeId=' + req.RecordTypeId);
        }
        
        // Filter to get only Unit record type plan requirements
        List<hed__Plan_Requirement__c> unitReqs = new List<hed__Plan_Requirement__c>();
        for (hed__Plan_Requirement__c req : existingReqs) {
            if (req.RecordTypeId == unitRecordTypeId) {
                unitReqs.add(req);
            }
        }
        System.debug('Found ' + unitReqs.size() + ' Unit record type plan requirements');
        
        // Delete existing records in correct order to maintain referential integrity
        if (!existingOfferings.isEmpty()) {
            System.debug('Deleting ' + existingOfferings.size() + ' existing course offerings');
            if (Schema.sObjectType.hed__Course_Offering__c.isDeletable()) {
        delete existingOfferings;
    } 
        }
        
        if (!unitReqs.isEmpty()) {
            System.debug('Deleting ' + unitReqs.size() + ' existing Unit record type plan requirements');
            if (Schema.sObjectType.hed__Plan_Requirement__c.isDeletable()) {
        delete unitReqs;
    } 
        } else if (!existingReqs.isEmpty()) {
            // If there are plan requirements but none with Unit record type,
            // log this for debugging purposes
            System.debug('No Unit record type plan requirements found among ' + existingReqs.size() + ' existing requirements');
        }
        
        if (!existingVersions.isEmpty()) {
            System.debug('Deleting ' + existingVersions.size() + ' existing course versions');
           if (Schema.sObjectType.Course_Version__c.isDeletable()) {
        delete existingVersions;
    } 
        }
        
        // STEP 2: CREATE NEW COURSE VERSION
        Course_Version__c courseVersion = new Course_Version__c();
        
        // Set fields
        if (String.isNotBlank(startDate)) {
            courseVersion.Start_Date__c = Date.valueOf(startDate);
        } else if (term.hed__Start_Date__c != null) {
            courseVersion.Start_Date__c = term.hed__Start_Date__c;
        }
        
        if (String.isNotBlank(endDate)) {
            courseVersion.End_Date__c = Date.valueOf(endDate);
        } else if (term.hed__End_Date__c != null) {
            courseVersion.End_Date__c = term.hed__End_Date__c;
        }
        Decimal courseCred = course.Credits__c;
        courseVersion.Credits__c = String.valueOf(courseCred);
        //String.isNotBlank(course.Credits__c) ? course.Credits__c : (course.Credits__c != null ? String.valueOf(course.Credits__c) : '');
                                
        courseVersion.Credit_hours__c = course.hed__Credit_Hours__c != null ? 
                                     String.valueOf(course.hed__Credit_Hours__c) : '';
        courseVersion.Account_Name__c = term.Program_Plan__r.hed__Account__c;
        courseVersion.Course__c = course.Id;
        courseVersion.Term__c = term.Id;
        
        if (Schema.sObjectType.Course_Version__c.isCreateable()) {
    insert courseVersion;
    
}
        System.debug('Created Course Version: ' + courseVersion.Id);
        
        // STEP 3: CREATE NEW COURSE OFFERING
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c();
        
        // Set fields
        courseOffering.Course_Version__c = courseVersion.Id;
        courseOffering.hed__Course__c = course.Id;
        courseOffering.hed__Term__c = term.Id;
        courseOffering.Campus__c = term.Campus__c;
        courseOffering.hed__Section_ID__c = sectionId;
        courseOffering.Name = standardizedName;
        
        // Set dates
        if (String.isNotBlank(startDate)) {
            courseOffering.hed__Start_Date__c = Date.valueOf(startDate);
        } else if (term.hed__Start_Date__c != null) {
            courseOffering.hed__Start_Date__c = term.hed__Start_Date__c;
        }
        
        if (String.isNotBlank(endDate)) {
            courseOffering.hed__End_Date__c = Date.valueOf(endDate);
        } else if (term.hed__End_Date__c != null) {
            courseOffering.hed__End_Date__c = term.hed__End_Date__c;
        }
        
        // Set capacity
        if (String.isNotBlank(capacity)) {
            try {
                Decimal capacityValue = Decimal.valueOf(capacity);
                courseOffering.hed__Capacity__c = capacityValue;
            } catch (Exception e) {
                System.debug('Error converting capacity: ' + e.getMessage());
            }
        }
        
        if (Schema.sObjectType.hed__Course_Offering__c.isCreateable()) {
    insert courseOffering;
    
}
        System.debug('Created Course Offering: ' + courseOffering.Id);
        
        // STEP 4: CREATE NEW PLAN REQUIREMENT
        hed__Plan_Requirement__c planRequirement = new hed__Plan_Requirement__c();
        
        // Set record type to 'Unit'
        planRequirement.RecordTypeId = unitRecordTypeId;
        
        String masterUnitCategory = null;
if (!course.hed__Plan_Requirements__r.isEmpty()) {
    masterUnitCategory = course.hed__Plan_Requirements__r[0].hed__Category__c;
}
        if (masterUnitCategory != null) {
    planRequirement.hed__Category__c = masterUnitCategory;
} else {
    // Optionally fallback to Elective or throw error
    planRequirement.hed__Category__c = 'Elective'; // or leave blank
}
        
        // Set required fields
        String courseIdValue = course.hed__Course_ID__c != null ? course.hed__Course_ID__c : '';
        planRequirement.Name = term.Name + ' ' + courseIdValue;
       // planRequirement.hed__Category__c = '';
        planRequirement.hed__Program_Plan__c = term.Program_Plan__c;
        planRequirement.hed__Course__c = course.Id;
        planRequirement.Term__c = term.Id;
        
        // Set Account_Name__c safely
        if (term.Program_Plan__r != null && term.Program_Plan__r.hed__Account__c != null) {
            planRequirement.Account_Name__c = term.Program_Plan__r.hed__Account__c;
        } else if (term.Program_Plan__c != null) {
            planRequirement.Account_Name__c = term.Program_Plan__c;
        }
        
        // Try to fetch and set department (Program Specialization institution)
        try {
            List<Account> institutions = [
                SELECT Id 
                FROM Account 
                WHERE ParentId = :term.Program_Plan__r.hed__Account__c
                AND RecordType.DeveloperName = 'Program_Specialization'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!institutions.isEmpty()) {
                planRequirement.Institute__c = institutions[0].Id;
                System.debug('Set Institute__c to: ' + institutions[0].Id);
            }
        } catch (Exception e) {
            System.debug('Error finding Program Specialization account: ' + e.getMessage());
        }
        
        if (Schema.sObjectType.hed__Plan_Requirement__c.isCreateable()) {
    insert planRequirement;
    
}
        System.debug('Created Plan Requirement: ' + planRequirement.Id);
        
        // STEP 5: VERIFICATION - double check for duplicates
        // Check for duplicate course offerings
        Integer offeringCount = [
            SELECT COUNT() 
            FROM hed__Course_Offering__c 
            WHERE hed__Term__c = :termId 
            AND hed__Course__c = :courseId
            AND hed__Section_ID__c = :sectionId
            WITH SECURITY_ENFORCED
        ];
        
        if (offeringCount > 1) {
            System.debug('WARNING: Found ' + offeringCount + ' offerings after creation. Cleaning up duplicates...');
            
            // Keep only the newest offering and delete others
            List<hed__Course_Offering__c> duplicateOfferings = [
                SELECT Id 
                FROM hed__Course_Offering__c 
                WHERE hed__Term__c = :termId 
                AND hed__Course__c = :courseId
                AND hed__Section_ID__c = :sectionId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
            
            // Keep the first one (newest), delete the rest
            hed__Course_Offering__c keepOffering = duplicateOfferings.remove(0);
            
            if (!duplicateOfferings.isEmpty()) {
                if (Schema.sObjectType.hed__Course_Offering__c.isDeletable()) {
        delete duplicateOfferings;
    }
                System.debug('Cleaned up ' + duplicateOfferings.size() + ' duplicate offerings');
            }
        }
        
        // Check for duplicate plan requirements
        Integer planReqCount = [
            SELECT COUNT() 
            FROM hed__Plan_Requirement__c 
            WHERE Term__c = :termId 
            AND hed__Course__c = :courseId
            AND RecordTypeId = :unitRecordTypeId
            WITH SECURITY_ENFORCED
        ];
        
        if (planReqCount > 1) {
            System.debug('WARNING: Found ' + planReqCount + ' Unit plan requirements after creation. Cleaning up duplicates...');
            
            // Keep only the newest plan requirement and delete others
            List<hed__Plan_Requirement__c> duplicateReqs = [
                SELECT Id 
                FROM hed__Plan_Requirement__c 
                WHERE Term__c = :termId 
                AND hed__Course__c = :courseId
                AND RecordTypeId = :unitRecordTypeId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
            
            // Keep the first one (newest), delete the rest
            hed__Plan_Requirement__c keepReq = duplicateReqs.remove(0);
            
            if (!duplicateReqs.isEmpty()) {
                if (Schema.sObjectType.hed__Plan_Requirement__c.isDeletable()) {
        delete duplicateReqs;
    } 
                System.debug('Cleaned up ' + duplicateReqs.size() + ' duplicate plan requirements');
            }
        }
        
        return planRequirement.Id;
        
    } catch (Exception e) {
        // Roll back all changes on any error
        Database.rollback(sp);
        String errorMsg = 'Error: ' + e.getMessage() + ' at line ' + e.getLineNumber();
        System.debug('FATAL ERROR: ' + errorMsg);
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException(errorMsg);
    }
}
  

/**
 * Helper method to ensure a Plan Requirement exists for a given term and course
 * @param term The term
 * @param course The course
 * @return The existing or newly created Plan Requirement
 */
    @testVisible
private static hed__Plan_Requirement__c ensurePlanRequirementExists(hed__Term__c term, hed__Course__c course) {
    System.debug('ENTRY: ensurePlanRequirementExists for term: ' + term.Id + ', course: ' + course.Id);
    
    // Check if Plan Requirement already exists
    List<hed__Plan_Requirement__c> existingReqs = [
        SELECT Id 
        FROM hed__Plan_Requirement__c 
        WHERE Term__c = :term.Id 
        AND hed__Course__c = :course.Id
        WITH SECURITY_ENFORCED
        LIMIT 1
    ];
    
    if (!existingReqs.isEmpty()) {
        System.debug('Using existing plan requirement: ' + existingReqs[0].Id);
        return existingReqs[0];
    }
    
    System.debug('No existing plan requirement found, creating a new one...');
    
    // CREATE PLAN REQUIREMENT RECORD
    hed__Plan_Requirement__c planRequirement = new hed__Plan_Requirement__c();
    
    // Set record type to 'Unit'
    Schema.RecordTypeInfo unitRecordType = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Unit');
    if (unitRecordType != null) {
        planRequirement.RecordTypeId = unitRecordType.getRecordTypeId();
        System.debug('Set RecordTypeId to Unit: ' + unitRecordType.getRecordTypeId());
    } else {
        System.debug('WARNING: Could not find Unit record type');
    }
    
    // Set the name using Term name + Course ID
    String courseIdValue = course.hed__Course_ID__c != null ? course.hed__Course_ID__c : '';
    planRequirement.Name = term.Name + ' ' + courseIdValue;
    System.debug('Setting plan requirement name: ' + planRequirement.Name);
    
    // Set required fields
    planRequirement.hed__Category__c = 'Elective';
    planRequirement.hed__Program_Plan__c = term.Program_Plan__c;
    System.debug('Setting Program Plan: ' + term.Program_Plan__c);
    
    // CRITICAL: Make sure Account_Name__c is correctly set
    planRequirement.Account_Name__c = term.Program_Plan__r.hed__Account__c;
    System.debug('Setting Account_Name__c: ' + term.Program_Plan__r.hed__Account__c);
    
    planRequirement.hed__Course__c = course.Id;
    planRequirement.Term__c = term.Id;
    
    // Get the program specialization institution
    Account institution = null;
    try {
        List<Account> institutions = [
            SELECT Id 
            FROM Account 
            WHERE ParentId = :term.Program_Plan__r.hed__Account__c
            AND RecordType.DeveloperName = 'Program_Specialization'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        if (!institutions.isEmpty()) {
            institution = institutions[0];
            System.debug('Found institution: ' + institution.Id);
        } else {
            System.debug('No Program_Specialization account found with ParentId: ' + term.Program_Plan__r.hed__Account__c);
        }
    } catch (Exception e) {
        System.debug('Error finding Program Specialization account: ' + e.getMessage());
    }
    
    // Set Institution if found
    if (institution != null) {
        planRequirement.Institute__c = institution.Id;
        System.debug('Setting Institute__c: ' + institution.Id);
    }
    
    // Insert Plan Requirement record
    try {
        if (Schema.sObjectType.hed__Plan_Requirement__c.isCreateable()) {
    insert planRequirement;
    
}
        System.debug('Successfully inserted plan requirement: ' + planRequirement.Id);
    } catch (Exception e) {
        System.debug('ERROR inserting plan requirement: ' + e.getMessage());
        System.debug('DML Exception details: ' + e);
        throw e; // Re-throw to handle in calling method
    }
    
    return planRequirement;
}
/**
 * Helper method to create a Plan Requirement
 */
    @testVisible
private static hed__Plan_Requirement__c createPlanRequirement(hed__Term__c term, hed__Course__c course, String courseOfferingId) {
    // Check if Plan Requirement already exists
    List<hed__Plan_Requirement__c> existingReqs = [
        SELECT Id 
        FROM hed__Plan_Requirement__c 
        WHERE Term__c = :term.Id 
        AND hed__Course__c = :course.Id
        WITH SECURITY_ENFORCED
        LIMIT 1
    ];
    
    if (!existingReqs.isEmpty()) {
        return existingReqs[0];
    }
    
    // CREATE PLAN REQUIREMENT RECORD
    hed__Plan_Requirement__c planRequirement = new hed__Plan_Requirement__c();
    
    // Set record type to 'Unit'
    Schema.RecordTypeInfo unitRecordType = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Unit');
    if (unitRecordType != null) {
        planRequirement.RecordTypeId = unitRecordType.getRecordTypeId();
    }
    
    // Set the name using Term name + Course ID
    String courseIdValue = course.hed__Course_ID__c != null ? course.hed__Course_ID__c : '';
    planRequirement.Name = term.Name + ' ' + courseIdValue;
    
    // Set required fields
    planRequirement.hed__Category__c = 'Elective';
    planRequirement.hed__Program_Plan__c = term.Program_Plan__c;
    planRequirement.Account_Name__c = term.Program_Plan__r.hed__Account__c;
    planRequirement.hed__Course__c = course.Id;
    planRequirement.Term__c = term.Id;
    
    // Link to course offering if provided
    if (String.isNotBlank(courseOfferingId)) {
        // If your object model has a field to link Plan Requirement to Course Offering,
        // uncomment and set this field
        // planRequirement.Course_Offering__c = courseOfferingId;
    }
    
    // Get the program specialization institution
    Account institution = null;
    try {
        institution = [
            SELECT Id 
            FROM Account 
            WHERE ParentId = :term.Program_Plan__r.hed__Account__c
            AND RecordType.DeveloperName = 'Program_Specialization'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
    } catch (Exception e) {
        System.debug('No Program Specialization account found: ' + e.getMessage());
    }
    
    // Set Institution if found
    if (institution != null) {
        planRequirement.Institute__c = institution.Id;
    }
    
    // Insert Plan Requirement record
   if (Schema.sObjectType.hed__Plan_Requirement__c.isCreateable()) {
    insert planRequirement;
    
}
    
    return planRequirement;
}
    
    /**
     * Method to create a course offering
     * @param termId - Id of the term
     * @param courseId - Id of the course
     * @param sectionId - Section ID
     * @param startDate - Start date
     * @param endDate - End date
     * @return Id of the created Course Offering record
     */
   /* @AuraEnabled
    public static String addCourseOffering(String termId, String courseId, String sectionId, String startDate, String endDate) {
        try {
            // Create a new Course Offering record
            hed__Course_Offering__c offering = new hed__Course_Offering__c(
                hed__Term__c = termId,
                hed__Course__c = courseId,
                hed__Section_ID__c = sectionId,
                hed__Start_Date__c = Date.valueOf(startDate),
                hed__End_Date__c = Date.valueOf(endDate)
            );
            
            insert offering;
            return offering.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating course offering: ' + e.getMessage());
        }
    }

*/
    
    /**
     * Method to get master unit plan requirements
     * @param programPlanId - Id of the program plan
     * @param termId - Id of the term
     * @return List of plan requirements (master units)
     */
    /**
 * Method to get master unit plan requirements
 * @param programPlanId - Id of the program plan
 * @param termId - Id of the term
 * @return List of plan requirements (master units)
 */
@AuraEnabled
public static List<Map<String, Object>> getPlanRequirementsMasterUnits(String programPlanId, String termId) {
    System.debug('Starting getPlanRequirementsMasterUnits with programPlanId: ' + programPlanId);
    System.debug('Using termId: ' + termId);
    
    try {
        // Get the term details to extract the term number
        hed__Term__c selectedTerm = [
            SELECT Id, Name , hed__Account__c
            FROM hed__Term__c
            WHERE Id = :termId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        List<hed__Course_Offering__c> courseOffer= [SELECT hed__Course__r.Name FROM hed__Course_Offering__c WHERE hed__Term__c = :termId AND hed__Term__r.hed__Account__c = :selectedTerm.hed__Account__c WITH SECURITY_ENFORCED];
        List<String> courseNames = new List<String>();

for (hed__Course_Offering__c co : courseOffer) {
    if (co.hed__Course__r != null && !String.isBlank(co.hed__Course__r.Name)) {
        courseNames.add(co.hed__Course__r.Name);
    }
}
List<hed__Course__c> subjectCode = [SELECT hed__Course_ID__c FROM hed__Course__c WHERE hed__Account__c = :selectedTerm.hed__Account__c AND Name IN :courseNames WITH SECURITY_ENFORCED];
List<String> subCodes = new List<String>();

for (hed__Course__c co : subjectCode) {
    if (co.hed__Course_ID__c != null && !String.isBlank(co.hed__Course_ID__c)) {
        subCodes.add(co.hed__Course_ID__c);
    }
}
        if (selectedTerm == null) {
            throw new AuraHandledException('Term not found with ID: ' + termId);
        }
        
        System.debug('Selected Term: ' + selectedTerm.Name);
        
        // Extract term number from the term name
        String termName = selectedTerm.Name;
        String termNumber = '';
        
        // Try to extract the term number
        if (termName.containsIgnoreCase('Term 1') || termName.containsIgnoreCase('Sem 1') || termName.containsIgnoreCase('Semester 1')) {
            termNumber = '1';
        } else if (termName.containsIgnoreCase('Term 2') || termName.containsIgnoreCase('Sem 2') || termName.containsIgnoreCase('Semester 2')) {
            termNumber = '2';
        } else if (termName.containsIgnoreCase('Term 3') || termName.containsIgnoreCase('Sem 3') || termName.containsIgnoreCase('Semester 3')) {
            termNumber = '3';
        } else if (termName.containsIgnoreCase('Term 4') || termName.containsIgnoreCase('Sem 4') || termName.containsIgnoreCase('Semester 4')) {
            termNumber = '4';
        } else if (termName.containsIgnoreCase('Term 5') || termName.containsIgnoreCase('Sem 5') || termName.containsIgnoreCase('Semester 5')) {
            termNumber = '5';
        } else if (termName.containsIgnoreCase('Term 6') || termName.containsIgnoreCase('Sem 6') || termName.containsIgnoreCase('Semester 6')) {
            termNumber = '6';
        } else if (termName.containsIgnoreCase('Term 7') || termName.containsIgnoreCase('Sem 7') || termName.containsIgnoreCase('Semester 7')) {
            termNumber = '7';
        } else if (termName.containsIgnoreCase('Term 8') || termName.containsIgnoreCase('Sem 8') || termName.containsIgnoreCase('Semester 8')) {
            termNumber = '8';
        }
        
        System.debug('Extracted Term Number: ' + termNumber);
        
        if (String.isBlank(termNumber)) {
            throw new AuraHandledException('Could not determine term number from: ' + termName);
        }
        
        // Get master unit record type ID
        Id masterUnitRecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        
        // Try first pattern: subject codes with format "1.2", "2.1", etc.
        //String likePattern = termNumber + '.%';
        String likePattern1 ='%'+termNumber+'__';
        String likePattern2 ='%'+termNumber+'___';
        List<hed__Plan_Requirement__c> allMasterUnits = [
            SELECT Id, Name, hed__Course__c,hed__Category__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c,
                   hed__Course__r.Credits__c, hed__Course__r.hed__Credit_Hours__c,
                   Institute__c, Institute__r.Name, hed__Plan_Requirement__r.Name
            FROM hed__Plan_Requirement__c
            WHERE RecordTypeId = :masterUnitRecordTypeId
            AND hed__Course__r.hed__account__c =:selectedTerm.hed__Account__c
            AND( hed__Course__r.hed__Course_ID__c LIKE :likePattern1 
            OR hed__Course__r.hed__Course_ID__c LIKE :likePattern2)
            WITH SECURITY_ENFORCED
        ];
        
        System.debug('Found ' + allMasterUnits.size() + ' master units with subject code matching Term ' + termNumber);
        
        // If no results from first query, try alternative patterns
        if (allMasterUnits.isEmpty()) {
            // Try "1,1", "2,1" format or exact match
            allMasterUnits = [
                SELECT Id, Name, hed__Course__c,hed__Category__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c,
                       hed__Course__r.Credits__c, hed__Course__r.hed__Credit_Hours__c,
                       Institute__c, Institute__r.Name, hed__Plan_Requirement__r.Name
                FROM hed__Plan_Requirement__c
                WHERE RecordTypeId = :masterUnitRecordTypeId
                AND (hed__Course__r.hed__Course_ID__c LIKE :(termNumber + ',%') 
                     OR hed__Course__r.hed__Course_ID__c = :termNumber)
                WITH SECURITY_ENFORCED
            ];
            
            System.debug('Found ' + allMasterUnits.size() + ' master units with alternative patterns for Term ' + termNumber);
        }
        
        // If still empty, try master group name pattern as last resort
        if (allMasterUnits.isEmpty()) {
            // Create the pattern string first
            String termPattern = '%Term' + termNumber + '%';
            
            allMasterUnits = [
                SELECT Id, Name, hed__Course__c,hed__Category__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c,
                       hed__Course__r.Credits__c, hed__Course__r.hed__Credit_Hours__c,
                       Institute__c, Institute__r.Name, hed__Plan_Requirement__r.Name
                FROM hed__Plan_Requirement__c
                WHERE RecordTypeId = :masterUnitRecordTypeId
                AND hed__Plan_Requirement__r.Name LIKE :termPattern
                WITH SECURITY_ENFORCED
            ];
            
            System.debug('Found ' + allMasterUnits.size() + ' master units via master group names for Term ' + termNumber);
        }
        
        // Try one final pattern for cases we might have missed
        if (allMasterUnits.isEmpty()) {
            // Try a more specific search for subjects like "3.4.2"
            String dotPattern = termNumber + '.%';
            allMasterUnits = [
                SELECT Id, Name, hed__Course__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c,
                       hed__Course__r.Credits__c, hed__Course__r.hed__Credit_Hours__c,
                       Institute__c, Institute__r.Name, hed__Plan_Requirement__r.Name,hed__Category__c
                FROM hed__Plan_Requirement__c
                WHERE RecordTypeId = :masterUnitRecordTypeId
                AND hed__Course__r.hed__Course_ID__c LIKE :dotPattern
                WITH SECURITY_ENFORCED
            ];
            
            System.debug('Found ' + allMasterUnits.size() + ' master units via final search pattern for Term ' + termNumber);
        }
        
        // Transform to a list of maps for easier handling in LWC
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        for(hed__Plan_Requirement__c unit : allMasterUnits) {
            Map<String, Object> item = new Map<String, Object>();
            
            item.put('id', unit.Id);
            item.put('name', unit.Name);
            item.put('subjectCode', unit.hed__Course__r.hed__Course_ID__c);
            item.put('subject', unit.hed__Course__r.Name);
            item.put('credits', unit.hed__Course__r.Credits__c);
            item.put('category', unit.hed__Category__c);
            item.put('creditHours', unit.hed__Course__r.hed__Credit_Hours__c);
            item.put('specialisation', unit.Institute__r.Name);
            item.put('masterGroup', unit.hed__Plan_Requirement__r.Name);
            item.put('courseId', unit.hed__Course__c);
            item.put('instituteId', unit.Institute__c);
            item.put('checked', false); // For checkbox selection in UI
            
            result.add(item);
        }
        
        System.debug('Returning ' + result.size() + ' filtered master units for Term ' + termNumber);
        return result;
    } catch (Exception e) {
        System.debug('ERROR: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException(e.getMessage());
    }
}

@AuraEnabled
public static Integer importCurriculum(String termId, List<String> planRequirementIds) {
    Savepoint sp = Database.setSavepoint(); // Create savepoint for rollback if needed
    Integer createdOfferingsCount = 0;

    try {
        System.debug('*** START: importCurriculum for Term ID: ' + termId + ' ***');
        System.debug('Selected planRequirementIds count: ' + planRequirementIds.size());

        // STEP 1: Get the term and required information
        hed__Term__c term = [
            SELECT Id, Name, hed__Start_Date__c, hed__End_Date__c, Campus__c, 
                   Program_Plan__c, Program_Plan__r.hed__Account__c
            FROM hed__Term__c
            WHERE Id = :termId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // STEP 2: Get all unique courses from selected plan requirements
        List<hed__Plan_Requirement__c> selectedPlanReqs = [
            SELECT Id, hed__Course__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c, Institute__c
            FROM hed__Plan_Requirement__c
            WHERE Id IN :planRequirementIds
            WITH SECURITY_ENFORCED
        ];

        // Extract unique course IDs to a set (to avoid duplicate creation)
        Set<Id> uniqueCourses = new Set<Id>();
        Map<Id, hed__Plan_Requirement__c> courseToReqMap = new Map<Id, hed__Plan_Requirement__c>();

        for (hed__Plan_Requirement__c req : selectedPlanReqs) {
            if (req.hed__Course__c != null && !uniqueCourses.contains(req.hed__Course__c)) {
                uniqueCourses.add(req.hed__Course__c);
                courseToReqMap.put(req.hed__Course__c, req);
            }
        }

        System.debug('Unique courses count: ' + uniqueCourses.size());

        // STEP 3: DELETE ALL EXISTING RECORDS FOR THESE COURSES FOR THIS TERM
        // Query for existing offerings, versions, and requirements
        List<hed__Course_Offering__c> offeringsToDelete = [
            SELECT Id FROM hed__Course_Offering__c 
            WHERE hed__Term__c = :termId 
            AND hed__Course__c IN :uniqueCourses
            WITH SECURITY_ENFORCED
        ];

        List<Course_Version__c> versionsToDelete = [
            SELECT Id FROM Course_Version__c 
            WHERE Term__c = :termId 
            AND Course__c IN :uniqueCourses
            WITH SECURITY_ENFORCED
        ];

        // Get the Unit record type ID once and use it throughout the method
        @TestVisible
        Id unitRecordTypeId = getUnitRecordTypeId();
        if (unitRecordTypeId == null) {
            throw new AuraHandledException('Could not find Unit record type. Please contact your administrator.');
        }

        // IMPORTANT: Use both Term__c and hed__Course__c to find ALL plan requirements for these courses
        List<hed__Plan_Requirement__c> reqsToDelete = [
            SELECT Id, RecordTypeId, hed__Course__c 
            FROM hed__Plan_Requirement__c 
            WHERE Term__c = :termId 
            AND hed__Course__c IN :uniqueCourses
            WITH SECURITY_ENFORCED
        ];

        // Log all the plan requirements we found for better debugging
        System.debug('Found ' + reqsToDelete.size() + ' plan requirements to evaluate');
        for (hed__Plan_Requirement__c req : reqsToDelete) {
            System.debug('Plan Requirement: Id=' + req.Id + ', CourseId=' + req.hed__Course__c + 
                        ', RecordTypeId=' + req.RecordTypeId);
        }

        // Filter to keep only Unit record type (not Master Units)
        List<hed__Plan_Requirement__c> unitReqsToDelete = new List<hed__Plan_Requirement__c>();
        
        for (hed__Plan_Requirement__c req : reqsToDelete) {
            if (req.RecordTypeId == unitRecordTypeId) {
                unitReqsToDelete.add(req);
            }
        }
        
        System.debug('Found to delete: ' + offeringsToDelete.size() + ' offerings, ' + 
                     versionsToDelete.size() + ' versions, ' + unitReqsToDelete.size() + ' unit plan requirements');

        // Delete in proper order to maintain referential integrity
        if (!offeringsToDelete.isEmpty()) {
            if (Schema.sObjectType.hed__Course_Offering__c.isDeletable()) {
        delete offeringsToDelete;
    }
            System.debug('Deleted ' + offeringsToDelete.size() + ' course offerings');
        }
        
        if (!unitReqsToDelete.isEmpty()) {
            if (Schema.sObjectType.hed__Plan_Requirement__c.isDeletable()) {
        delete unitReqsToDelete;
    }
            System.debug('Deleted ' + unitReqsToDelete.size() + ' unit plan requirements');
        }
        
        if (!versionsToDelete.isEmpty()) {
            if (Schema.sObjectType.Course_Version__c.isDeletable()) {
        delete versionsToDelete;
    }
            System.debug('Deleted ' + versionsToDelete.size() + ' course versions');
        }

        // STEP 4: CREATE NEW RECORDS - EXACTLY ONE PER COURSE
        // First create course versions
        List<Course_Version__c> versionsToCreate = new List<Course_Version__c>();
        Map<Id, Id> courseToVersionId = new Map<Id, Id>();

        for (Id courseId : uniqueCourses) {
            Course_Version__c version = new Course_Version__c(
                Course__c = courseId,
                Term__c = term.Id,
                Start_Date__c = term.hed__Start_Date__c,
                End_Date__c = term.hed__End_Date__c,
                Account_Name__c = term.Program_Plan__r.hed__Account__c != null ?
                                  term.Program_Plan__r.hed__Account__c : term.Program_Plan__c
            );
            versionsToCreate.add(version);
        }

        if (!versionsToCreate.isEmpty()) {
            if (Schema.sObjectType.Course_Version__c.isCreateable()) {
    insert versionsToCreate;
    
}
            for (Course_Version__c version : versionsToCreate) {
                courseToVersionId.put(version.Course__c, version.Id);
            }
            System.debug('Created ' + versionsToCreate.size() + ' course versions');
        }

        // Prepare for creating offerings and plan requirements
        List<hed__Course_Offering__c> offeringsToCreate = new List<hed__Course_Offering__c>();
        List<hed__Plan_Requirement__c> reqsToCreate = new List<hed__Plan_Requirement__c>();

        // Create offerings and plan requirements - EXACTLY ONE PER COURSE
        for (Id courseId : uniqueCourses) {
            hed__Plan_Requirement__c sourceReq = courseToReqMap.get(courseId);
            
            // Create course offering - use a standard section ID 'A'
            hed__Course_Offering__c offering = new hed__Course_Offering__c(
                hed__Course__c = courseId,
                hed__Term__c = termId,
                Campus__c = term.Campus__c,
                hed__Start_Date__c = term.hed__Start_Date__c,
                hed__End_Date__c = term.hed__End_Date__c,
                hed__Section_ID__c = 'A',
                Course_Version__c = courseToVersionId.get(courseId),
                Name = term.Name + ' ' + sourceReq.hed__Course__r.Name + '-A'
            );
            offeringsToCreate.add(offering);

            // Create plan requirement
            hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c(
                RecordTypeId = unitRecordTypeId,
                hed__Course__c = courseId,
                Term__c = termId,
                hed__Program_Plan__c = term.Program_Plan__c,
                hed__Category__c = 'Elective',
                Account_Name__c = term.Program_Plan__r.hed__Account__c != null ? 
                                  term.Program_Plan__r.hed__Account__c : term.Program_Plan__c,
                Name = term.Name + ' ' + sourceReq.hed__Course__r.hed__Course_ID__c,
                Institute__c = sourceReq.Institute__c
            );
            reqsToCreate.add(planReq);
        }

        // Insert the records
        if (!reqsToCreate.isEmpty()) {
            if (Schema.sObjectType.hed__Plan_Requirement__c.isCreateable()) {
    insert reqsToCreate;
    
}
            System.debug('Created ' + reqsToCreate.size() + ' plan requirements');
        }

        if (!offeringsToCreate.isEmpty()) {
            if (Schema.sObjectType.hed__Course_Offering__c.isCreateable()) {
    insert offeringsToCreate;
    
}
            createdOfferingsCount = offeringsToCreate.size();
            System.debug('Created ' + offeringsToCreate.size() + ' course offerings');
        }

        // STEP 5: VERIFICATION - Ensure no duplicates were created
        // Check for duplicate course offerings
        Map<Id, Integer> offeringCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT hed__Course__c, COUNT(Id) cnt
            FROM hed__Course_Offering__c
            WHERE hed__Term__c = :termId
            AND hed__Course__c IN :uniqueCourses
            WITH SECURITY_ENFORCED
            GROUP BY hed__Course__c
        ]) {
            Id courseId = (Id)ar.get('hed__Course__c');
            Integer count = (Integer)ar.get('cnt');
            if (count > 1) {
                // Found duplicates - log but don't roll back, as we'll clean them up
                System.debug('Found ' + count + ' offerings for course ' + courseId);
                offeringCounts.put(courseId, count);
            }
        }
        
        // Check for duplicate plan requirements
        Map<Id, Integer> planReqCounts = new Map<Id, Integer>();
        // Use the already defined unitRecordTypeId variable
        for (AggregateResult ar : [
            SELECT hed__Course__c, COUNT(Id) cnt
            FROM hed__Plan_Requirement__c
            WHERE Term__c = :termId
            AND hed__Course__c IN :uniqueCourses
            AND RecordTypeId = :unitRecordTypeId
            WITH SECURITY_ENFORCED
            GROUP BY hed__Course__c
        ]) {
            Id courseId = (Id)ar.get('hed__Course__c');
            Integer count = (Integer)ar.get('cnt');
            if (count > 1) {
                // Found duplicate plan requirements
                System.debug('Found ' + count + ' plan requirements for course ' + courseId);
                planReqCounts.put(courseId, count);
            }
        }
        
        // If duplicate offerings were found, clean them up
        if (!offeringCounts.isEmpty()) {
            System.debug('Found duplicate offerings for ' + offeringCounts.size() + ' courses. Cleaning up...');
            
            // For each course with duplicates, keep only one offering
            for (Id courseId : offeringCounts.keySet()) {
                List<hed__Course_Offering__c> duplicateOfferings = [
                    SELECT Id FROM hed__Course_Offering__c
                    WHERE hed__Term__c = :termId
                    AND hed__Course__c = :courseId
                    WITH SECURITY_ENFORCED
                    ORDER BY CreatedDate DESC // Keep the most recent one
                ];
                
                // Keep the first one (most recent), delete the rest
                if (duplicateOfferings.size() > 1) {
                    hed__Course_Offering__c keepOffering = duplicateOfferings.remove(0);
                    if (Schema.sObjectType.hed__Course_Offering__c.isDeletable()) {
        delete duplicateOfferings;
    }
                    System.debug('Cleaned up duplicates for course ' + courseId + 
                                 '. Kept ' + keepOffering.Id + ', deleted ' + duplicateOfferings.size() + ' others.');
                }
            }
        }
        
        // If duplicate plan requirements were found, clean them up
        if (!planReqCounts.isEmpty()) {
            System.debug('Found duplicate plan requirements for ' + planReqCounts.size() + ' courses. Cleaning up...');
            
            // For each course with duplicates, keep only one plan requirement
            for (Id courseId : planReqCounts.keySet()) {
                List<hed__Plan_Requirement__c> duplicateReqs = [
                    SELECT Id FROM hed__Plan_Requirement__c
                    WHERE Term__c = :termId
                    AND hed__Course__c = :courseId
                    AND RecordTypeId = :unitRecordTypeId
                    WITH SECURITY_ENFORCED
                    ORDER BY CreatedDate DESC // Keep the most recent one
                ];
                
                // Keep the first one (most recent), delete the rest
                if (duplicateReqs.size() > 1) {
                    hed__Plan_Requirement__c keepReq = duplicateReqs.remove(0);
                    if (Schema.sObjectType.hed__Plan_Requirement__c.isDeletable()) {
        delete duplicateReqs;
    }
                    System.debug('Cleaned up duplicates for course ' + courseId + 
                                 '. Kept ' + keepReq.Id + ', deleted ' + duplicateReqs.size() + ' others.');
                }
            }
        }

        System.debug('*** FINISH: importCurriculum - Successfully created ' + createdOfferingsCount + ' course offerings ***');
        return createdOfferingsCount;

    } catch (Exception e) {
        // Roll back all changes on any error
        Database.rollback(sp);
        System.debug('*** ERROR in importCurriculum: ' + e.getMessage() + ' at line ' + e.getLineNumber() + ' ***');
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error importing curriculum: ' + e.getMessage());
    }
}

/**
 * Helper method to get the Unit record type ID
 * @return RecordTypeId for the Unit record type
 */
    @TestVisible
private static Id getUnitRecordTypeId() {
    try {
        return Schema.SObjectType.hed__Plan_Requirement__c
            .getRecordTypeInfosByDeveloperName().get('Unit').getRecordTypeId();
    } catch (Exception e) {
        System.debug('Error getting Unit record type: ' + e.getMessage());
        return null;
    }
}

    
    
 /**
 * Method to delete all course offerings, plan requirements, and course versions for a term
 * @param termId - Id of the term
 * @return Number of deleted course offerings
 */
@AuraEnabled
public static Integer deleteAllCourseOfferings(String termId) {
    Savepoint sp = Database.setSavepoint(); // Create savepoint for rollback if needed
    
    try {
        System.debug('Starting deleteAllCourseOfferings for Term ID: ' + termId);
        
        // First, get all course IDs for this term's course offerings
        Set<Id> courseIds = new Set<Id>();
        List<hed__Course_Offering__c> courseOfferings = [
            SELECT Id, hed__Course__c, Course_Version__c 
            FROM hed__Course_Offering__c 
            WHERE hed__Term__c = :termId
            WITH SECURITY_ENFORCED
        ];
        
        // Track all Course Versions to delete
        Set<Id> courseVersionIds = new Set<Id>();
        
        // Populate courseIds and courseVersionIds sets
        for (hed__Course_Offering__c offering : courseOfferings) {
            courseIds.add(offering.hed__Course__c);
            if (offering.Course_Version__c != null) {
                courseVersionIds.add(offering.Course_Version__c);
            }
        }
        
        // Get all Plan Requirements for these courses in this term
        List<hed__Plan_Requirement__c> planRequirements = [
            SELECT Id 
            FROM hed__Plan_Requirement__c 
            WHERE Term__c = :termId
            AND hed__Course__c IN :courseIds
            WITH SECURITY_ENFORCED
        ];
        
        // Get all Course Versions for this term
        List<Course_Version__c> courseVersions = [
            SELECT Id 
            FROM Course_Version__c 
            WHERE Term__c = :termId
            AND Course__c IN :courseIds
            WITH SECURITY_ENFORCED
        ];
        
        Integer offeringsCount = courseOfferings.size();
        
        // Delete in proper order to maintain referential integrity:
        // 1. First delete Course Offerings (they reference Course Versions)
        if (!courseOfferings.isEmpty()) {
            if (Schema.sObjectType.hed__Course_Offering__c.isDeletable()) {
        delete courseOfferings;
    }
            System.debug('Deleted ' + courseOfferings.size() + ' course offerings');
        }
        
        // 2. Delete Plan Requirements
        if (!planRequirements.isEmpty()) {
            if (Schema.sObjectType.hed__Plan_Requirement__c.isDeletable()) {
        delete planRequirements;
    }
            System.debug('Deleted ' + planRequirements.size() + ' plan requirements');
        }
        
        // 3. Finally delete Course Versions
        if (!courseVersions.isEmpty()) {
            if (Schema.sObjectType.Course_Version__c.isDeletable()) {
        delete courseVersions;
    }
            System.debug('Deleted ' + courseVersions.size() + ' course versions');
        }
        
        return offeringsCount;
    } catch (Exception e) {
        // Roll back all changes if any error occurs
        Database.rollback(sp);
        System.debug('ERROR in deleteAllCourseOfferings: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error deleting records: ' + e.getMessage());
    }
}
    
    
/**
 * Method to update course offerings from inline edits with improved date handling
 * @param updates - List of course offering updates
 * @return Boolean indicating success
 */
@AuraEnabled
public static Boolean updateCourseOfferings(List<Map<String, Object>> updates) {
    try {
        System.debug('Received updates: ' + updates);
        List<hed__Course_Offering__c> offeringsToUpdate = new List<hed__Course_Offering__c>();
        
        for (Map<String, Object> updateRecord : updates) {
            String id = (String)updateRecord.get('Id');
            
            if (String.isBlank(id)) {
                continue;
            }
            
            hed__Course_Offering__c offering = new hed__Course_Offering__c(Id = id);
            
            // Update Section ID if provided
            if (updateRecord.containsKey('sectionId')) {
                offering.hed__Section_ID__c = (String)updateRecord.get('sectionId');
            }
            
            // Update Capacity if provided
            if (updateRecord.containsKey('credits')) {
                Object creditsObj = updateRecord.get('credits');
                if (creditsObj instanceof String) {
                    String creditStr = (String)creditsObj;
                    if (String.isNotBlank(creditStr)) {
                        try {
                            Decimal creditsValue = Decimal.valueOf(creditStr);
                            offering.hed__Capacity__c = creditsValue;
                        } catch (Exception e) {
                            System.debug('Error converting credits to Decimal: ' + e.getMessage());
                        }
                    }
                } else if (creditsObj instanceof Decimal) {
                    offering.hed__Capacity__c = (Decimal)creditsObj;
                } else if (creditsObj instanceof Integer) {
                    offering.hed__Capacity__c = Decimal.valueOf((Integer)creditsObj);
                }
            }
            
            // Update Start Date if provided - ensure we're handling date-only format
            if (updateRecord.containsKey('startDate')) {
                Object startDateObj = updateRecord.get('startDate');
                if (startDateObj instanceof String) {
                    String dateStr = (String)startDateObj;
                    if (String.isNotBlank(dateStr)) {
                        try {
                            // Parse date string - should be in format YYYY-MM-DD
                            Date parsedDate = Date.valueOf(dateStr);
                            offering.hed__Start_Date__c = parsedDate;
                            System.debug('Parsed start date: ' + parsedDate);
                        } catch (Exception e) {
                            System.debug('Error parsing start date: ' + e.getMessage());
                        }
                    }
                } else if (startDateObj instanceof Date) {
                    offering.hed__Start_Date__c = (Date)startDateObj;
                }
            }
            
            // Update End Date if provided - ensure we're handling date-only format
            if (updateRecord.containsKey('endDate')) {
                Object endDateObj = updateRecord.get('endDate');
                if (endDateObj instanceof String) {
                    String dateStr = (String)endDateObj;
                    if (String.isNotBlank(dateStr)) {
                        try {
                            // Parse date string - should be in format YYYY-MM-DD
                            Date parsedDate = Date.valueOf(dateStr);
                            offering.hed__End_Date__c = parsedDate;
                            System.debug('Parsed end date: ' + parsedDate);
                        } catch (Exception e) {
                            System.debug('Error parsing end date: ' + e.getMessage());
                        }
                    }
                } else if (endDateObj instanceof Date) {
                    offering.hed__End_Date__c = (Date)endDateObj;
                }
            }
            
            offeringsToUpdate.add(offering);
        }
        
        if (!offeringsToUpdate.isEmpty()) {
            System.debug('Updating ' + offeringsToUpdate.size() + ' course offerings');
            if (Schema.sObjectType.hed__Course_Offering__c.isUpdateable()) {
        update offeringsToUpdate;
    }
            return true;
        }
        
        return false;
    } catch (Exception e) {
        System.debug('Error updating course offerings: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        throw new AuraHandledException('Error updating course offerings: ' + e.getMessage());
    }
}
    /**
 * Method to delete a course offering along with related plan requirements and course versions
 * @param courseOfferingId - Id of the course offering to delete
 * @param termId - Id of the term
 * @return Boolean indicating success or failure
 */
@AuraEnabled
public static Boolean deleteCompleteCourseOffering(String courseOfferingId, String termId) {
    Savepoint sp = Database.setSavepoint(); // Create savepoint for rollback if needed
    
    try {
        System.debug('Starting deleteCompleteCourseOffering for Course Offering ID: ' + courseOfferingId);
        
        // Get the course offering with related course
        hed__Course_Offering__c offering = [
            SELECT Id, hed__Course__c, Course_Version__c
            FROM hed__Course_Offering__c
            WHERE Id = :courseOfferingId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        Id courseId = offering.hed__Course__c;
        Id courseVersionId = offering.Course_Version__c;
        
        // Find plan requirements for this course in this term
        List<hed__Plan_Requirement__c> planRequirements = [
            SELECT Id 
            FROM hed__Plan_Requirement__c 
            WHERE Term__c = :termId
            AND hed__Course__c = :courseId
            WITH SECURITY_ENFORCED
        ];
        
        // Delete in proper order to maintain referential integrity
        // 1. First delete the Course Offering
        if (Schema.sObjectType.hed__Course_Offering__c.isDeletable()) {
        delete offering;
    } 
        System.debug('Deleted course offering: ' + courseOfferingId);
        
        // 2. Delete Plan Requirements
        if (!planRequirements.isEmpty()) {
           if (Schema.sObjectType.hed__Plan_Requirement__c.isDeletable()) {
        delete planRequirements;
    }
            System.debug('Deleted ' + planRequirements.size() + ' plan requirements');
        }
        
        // 3. Delete Course Version if it exists
        if (courseVersionId != null) {
            Course_Version__c version = new Course_Version__c(Id = courseVersionId);
            if (Schema.sObjectType.Course_Version__c.isDeletable()) {
        delete version;
    }
            System.debug('Deleted course version: ' + courseVersionId);
        }
        
        return true;
    } catch (Exception e) {
        // Roll back all changes if any error occurs
        Database.rollback(sp);
        System.debug('ERROR in deleteCompleteCourseOffering: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error deleting records: ' + e.getMessage());
    }
}
    
    
}