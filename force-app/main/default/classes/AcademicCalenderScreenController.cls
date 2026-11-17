/**
 * Controller for Academic Program Plan LWC
 */
public with sharing class AcademicCalenderScreenController {
    
    /**
     * Get Academic Programs (Accounts with recordtype = 'Academic Program')
     * @return List of Academic Program accounts
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> getAcademicPrograms() {
        try {
            Id academicProgramRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('Academic_Program')
                .getRecordTypeId();
                
            return [
                SELECT Id, Name
                FROM Account
                WHERE RecordTypeId = :academicProgramRecordTypeId
                WITH SECURITY_ENFORCED
                ORDER BY Name
                
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving academic programs: ' + e.getMessage());
        }
    }
    
    /**
     * Get Program Plans related to the selected Academic Program
     * @param academicProgramId The ID of the selected Academic Program
     * @return List of Program Plan records
     */
    
     @AuraEnabled(cacheable=true)
    public static List<hed__Program_Plan__c> getProgramPlans(String academicProgramId) {
        try {
            return [
                SELECT Id, Name, Working_Days__c
                FROM hed__Program_Plan__c
                WHERE hed__Account__c = :academicProgramId
                WITH SECURITY_ENFORCED
                ORDER BY Name
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving program plans: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<	Academic_Term__c> getAcademicTerm() {
        try {
            return [
                SELECT Id, Name
                FROM Academic_Term__c
                WITH SECURITY_ENFORCED
                ORDER BY Name
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving program plans: ' + e.getMessage());
        }
    }
    /**
     * Get Terms and Program Plan details for the selected Program Plan
     * @param programPlanId The ID of the selected Program Plan
     * @return Map containing program plan details and terms
     */
    @AuraEnabled(cacheable=true)
public static Map<String, Object> getTerms(String programPlanId) {
    try {
        // Get program plan details
        hed__Program_Plan__c programPlan = [
            SELECT Id, Name, Working_Days__c
            FROM hed__Program_Plan__c
            WHERE Id = :programPlanId
            WITH SECURITY_ENFORCED
        ];
        
        // Get terms for the program plan - UPDATED to include Academic Term
        List<hed__Term__c> terms = [
            SELECT Id, Name, Term_Duration__c, hed__Start_Date__c, hed__End_Date__c,
                   Academic_Term__c  // Add this field
            FROM hed__Term__c
            WHERE Program_Plan__c = :programPlanId
            WITH SECURITY_ENFORCED
            ORDER BY Name ASC
        ];
        
        terms = customSortTerms(terms);
        
        // Create and return the result map
        Map<String, Object> result = new Map<String, Object>();
        result.put('programPlanDetail', programPlan);
        result.put('terms', terms);
        
        return result;
    } catch (Exception e) {
        throw new AuraHandledException('Error retrieving terms: ' + e.getMessage());
    }
}
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCourseConnections(){
        try {
            
            
            // Get Course Connections
            List<Course_Enrollment__c> courseConnections = [
                SELECT Id, Name,Active__c
                FROM Course_Enrollment__c
                WITH SECURITY_ENFORCED
                  ORDER BY Order_of_Priority__c ASC
                  
            ];
            
            
            // Create and return the result map
            Map<String, Object> result = new Map<String, Object>();
            
            result.put('courseConnections', courseConnections);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Course Connections: ' + e.getMessage());
        }
    }
    @AuraEnabled(cacheable=true)
public static Map<String, Object> getTermsWithMultipleAcademicTerms(List<String> academicTermIds, String programPlanId) {
    try {
        List<hed__Term__c> terms;

        if (academicTermIds == null || academicTermIds.isEmpty()) {
            // No filter: return all terms for the selected program plan
            terms = [
                SELECT Id, Name, Term_Duration__c, hed__Start_Date__c, hed__End_Date__c, Academic_Term__c
                FROM hed__Term__c
                WHERE Program_Plan__c = :programPlanId
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } else {
            // Filtered: return terms for selected academic terms only
            terms = [
                SELECT Id, Name, Term_Duration__c, hed__Start_Date__c, hed__End_Date__c, Academic_Term__c
                FROM hed__Term__c
                WHERE Program_Plan__c = :programPlanId
                AND Academic_Term__c IN :academicTermIds
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        }

        terms = customSortTerms(terms);
        System.debug('Terms returned: ' + terms.size() + ' - ' + terms);
        return new Map<String, Object>{ 'terms' => terms };
        
    } catch (Exception e) {
        throw new AuraHandledException('Error retrieving terms: ' + e.getMessage());
    }
}

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTermsWithAcademicTerm(String academicTermId,String programPlanId) {
        try {
            
            
            // Get terms for the program plan
            List<hed__Term__c> terms = [
                SELECT Id, Name, Term_Duration__c, hed__Start_Date__c, hed__End_Date__c
                FROM hed__Term__c
                WHERE Academic_Term__c = :academicTermId AND
                Program_Plan__c = :programPlanId
                WITH SECURITY_ENFORCED
                  ORDER BY Name ASC
            ];
            
                 terms = customSortTerms(terms);
            
            // Create and return the result map
            Map<String, Object> result = new Map<String, Object>();
            
            result.put('terms', terms);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving terms: ' + e.getMessage());
        }
    }
    
    /**
 * Custom sorting method for terms
 * @param terms The list of terms to sort
 * @return Sorted list of terms
 */
private static List<hed__Term__c> customSortTerms(List<hed__Term__c> terms) {
    Map<Integer, hed__Term__c> termMap = new Map<Integer, hed__Term__c>();
    List<Integer> semesterNumbers = new List<Integer>();
    
    // Extract semester numbers and create a map
    for (hed__Term__c term : terms) {
        Integer semNumber = getSemesterNumberFromName(term.Name);
        termMap.put(semNumber, term);
        semesterNumbers.add(semNumber);
    }
    
    // Sort the semester numbers
    semesterNumbers.sort();
    
    // Rebuild the list in sorted order
    List<hed__Term__c> sortedTerms = new List<hed__Term__c>();
    for (Integer semNum : semesterNumbers) {
        if (termMap.containsKey(semNum)) {
            sortedTerms.add(termMap.get(semNum));
        }
    }
    
    return sortedTerms;
}

/**
 * Extract semester number from term name
 * @param termName The term name
 * @return The semester number
 */
private static Integer getSemesterNumberFromName(String termName) {
    if (String.isBlank(termName)) {
        return 999; // Put unmatched items at the end
    }
    
    // Look for patterns like "Sem 1", "Sem 2", etc.
    List<String> parts = termName.split('-');
    for (String part : parts) {
        if (part.toLowerCase().contains('sem')) {
            // Extract the number after 'sem'
            String semPart = part.toLowerCase().replace('sem', '').trim();
            try {
                return Integer.valueOf(semPart);
            } catch (Exception e) {
                // Try to extract just the numbers
                String numbers = semPart.replaceAll('[^0-9]', '');
                if (String.isNotBlank(numbers)) {
                    return Integer.valueOf(numbers);
                }
            }
        }
    }
    
    return 999; // Default for unmatched patterns
}
    
    /**
     * Update term dates
     * @param termId The ID of the term to update
     * @param startDate The new start date
     * @param endDate The new end date
     * @return Success message
     */
  /*  @AuraEnabled
    public static String updateTermDates(String termId, Date startDate, Date endDate) {
        try {
            // Get the term record
            hed__Term__c term = [SELECT Id FROM hed__Term__c WHERE Id = :termId];
            
            // Update the term dates
            term.hed__Start_Date__c = startDate;
            term.hed__End_Date__c = endDate;
            
            // Save the term
            update term;
            
            return 'Term dates updated successfully';
        } catch (Exception e) {
            throw new AuraHandledException('Error updating term dates: ' + e.getMessage());
        }
    } */
    
    /**
 * FIXED: Update term dates and duration
 * @param termId The ID of the term to update
 * @param startDate The new start date
 * @param endDate The new end date
 * @param numberOfWeeks The semester duration in weeks
 * @return Success message
 */
@AuraEnabled
public static String updateTermDates(String termId, Date startDate, Date endDate, Integer numberOfWeeks) {
    try {
        System.debug('=== updateTermDates Parameters ===');
        System.debug('Term ID: ' + termId);
        System.debug('Start Date: ' + startDate);
        System.debug('End Date: ' + endDate);
        System.debug('Number of Weeks: ' + numberOfWeeks);
        
        // Validate required parameters
        if (String.isBlank(termId)) {
            throw new AuraHandledException('Term ID is required');
        }
        
        if (startDate == null) {
            throw new AuraHandledException('Start Date is required');
        }
        
        if (endDate == null) {
            throw new AuraHandledException('End Date is required');
        }
        
        if (numberOfWeeks == null || numberOfWeeks <= 0) {
            throw new AuraHandledException('Valid semester duration is required');
        }
        
        // Get the term record
        hed__Term__c term = [
            SELECT Id, Name, hed__Start_Date__c, hed__End_Date__c, Term_Duration__c
            FROM hed__Term__c 
            WHERE Id = :termId 
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        System.debug('=== Before Update ===');
        System.debug('Current Start Date: ' + term.hed__Start_Date__c);
        System.debug('Current End Date: ' + term.hed__End_Date__c);
        System.debug('Current Duration: ' + term.Term_Duration__c);
        
        // Update the term with all three fields
        term.hed__Start_Date__c = startDate;
        term.hed__End_Date__c = endDate;
        term.Term_Duration__c = String.valueOf(numberOfWeeks); // Convert Integer to String
        
        // Save the term
        if (Schema.sObjectType.hed__Term__c.isUpdateable()) {
        update term;
    } else {
        throw new AuraHandledException('You do not have permission to update this record.');
    }
        
        System.debug('=== After Update ===');
        System.debug('Updated Start Date: ' + term.hed__Start_Date__c);
        System.debug('Updated End Date: ' + term.hed__End_Date__c);
        System.debug('Updated Duration: ' + term.Term_Duration__c);
        
        // Verify the update by querying again
        hed__Term__c updatedTerm = [
            SELECT Id, Name, hed__Start_Date__c, hed__End_Date__c, Term_Duration__c
            FROM hed__Term__c 
            WHERE Id = :termId 
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        System.debug('=== Verification Query ===');
        System.debug('Verified Start Date: ' + updatedTerm.hed__Start_Date__c);
        System.debug('Verified End Date: ' + updatedTerm.hed__End_Date__c);
        System.debug('Verified Duration: ' + updatedTerm.Term_Duration__c);
        
        return 'Term dates and duration updated successfully';
        
    } catch (Exception e) {
        System.debug('Error in updateTermDates: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error updating term dates: ' + e.getMessage());
    }
}
    
    /**
     * Add activity to a term
     * @param termId The ID of the term
     * @param activityData The activity data to add
     * @return The ID of the created activity
     */
  // AcademicProgramPlanController.cls
   @AuraEnabled
public static String addActivity(Id termId, String typeOfActivity, String durationType, Integer numberOfWeeks, String description, Date startDate, Date endDate, String accountName) {
    System.debug('Adding activity with parameters:');
    System.debug('- Term ID: ' + termId);
    System.debug('- Type of Activity: ' + typeOfActivity);
    System.debug('- Duration Type: ' + durationType);
    System.debug('- Number of Weeks: ' + numberOfWeeks);
    System.debug('- Start Date: ' + startDate);
    System.debug('- End Date: ' + endDate);
    
    try {
        // Validate required parameters
        if (termId == null) {
            throw new AuraHandledException('Term ID is required');
        }
        
        if (String.isBlank(typeOfActivity)) {
            throw new AuraHandledException('Type of Activity is required');
        }
        
        if (startDate == null) {
            throw new AuraHandledException('Start Date is required');
        }
        
        if (endDate == null) {
            throw new AuraHandledException('End Date is required');
        }
        
        // Fetch the Term__c record along with its related Account Name
        hed__Term__c term = [
            SELECT Id, Name, hed__Account__r.Name 
            FROM hed__Term__c 
            WHERE Id = :termId
            WITH SECURITY_ENFORCED
        ];

        // Extract the Term Name and Account Name
        String termName = term.Name;
        String fetchedAccountName = term.hed__Account__r?.Name; // Use safe navigation operator

        // If no Account Name is found, fallback to the provided accountName parameter
        if (String.isBlank(fetchedAccountName)) {
            fetchedAccountName = accountName;
        }

        // Generate the Name field as a combination of Account Name and Term Name
        String recordName = fetchedAccountName + ' - ' + termName;

        // Create a new Academic_Calendar__c record
        Academic_Calendar__c newActivity = new Academic_Calendar__c();
        newActivity.Name = recordName;
        newActivity.Term__c = termId;
        newActivity.Account_Name__c = fetchedAccountName;
        newActivity.Type_of_Activity__c = typeOfActivity;
        newActivity.Duration_Type__c = durationType;
        newActivity.Duration__c = String.valueOf(numberOfWeeks);
        newActivity.Description__c = description;
        newActivity.Start_Date__c = startDate;
        newActivity.End_Date__c = endDate;

        // Insert the record
        if (Schema.sObjectType.Academic_Calendar__c.isCreateable()) {
    insert newActivity;
    System.debug('New record Id: ' + newActivity.Id);
} else {
    throw new AuraHandledException('You do not have permission to create Academic Calendar records.');
}
        System.debug('New activity created with ID: ' + newActivity.Id);
        
        // Return the ID of the newly created record
        return newActivity.Id;
    } catch (Exception e) {
        System.debug('Error adding activity: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error adding activity: ' + e.getMessage());
    }
}

  
    
    
    @AuraEnabled(cacheable=true)
public static Map<String, Object> getTermActivities(Id termId) {
    try {
        // Fetch activities related to the term
        List<Academic_Calendar__c> activities = [
            SELECT 
                Id, 
                Name, 
                Type_of_Activity__c, 
                Duration_Type__c, 
                Duration__c, 
                Description__c, 
                Start_Date__c, 
                End_Date__c
            FROM Academic_Calendar__c
            WHERE Term__c = :termId
            WITH SECURITY_ENFORCED
            ORDER BY Start_Date__c
        ];

        // Prepare the result map
        Map<String, Object> result = new Map<String, Object>();
        result.put('activities', activities);

        return result;
    } catch (Exception e) {
        throw new AuraHandledException('Error retrieving term activities: ' + e.getMessage());
    }
}


        @AuraEnabled
public static void updateActivity(String activityId, String typeOfActivity, String durationType, 
                                 Integer numberOfWeeks, String description, 
                                 Date startDate, Date endDate) {
    System.debug('Updating activity with parameters:');
    System.debug('- Activity ID: ' + activityId);
    System.debug('- Type of Activity: ' + typeOfActivity);
    System.debug('- Duration Type: ' + durationType);
    System.debug('- Number of Weeks: ' + numberOfWeeks);
    System.debug('- Start Date: ' + startDate);
    System.debug('- End Date: ' + endDate);
    
    try {
        // Validate required parameters
        if (String.isBlank(activityId)) {
            throw new AuraHandledException('Activity ID is required');
        }
        
        if (String.isBlank(typeOfActivity)) {
            throw new AuraHandledException('Type of Activity is required');
        }
        
        if (startDate == null) {
            throw new AuraHandledException('Start Date is required');
        }
        
        if (endDate == null) {
            throw new AuraHandledException('End Date is required');
        }
        
        // Query for the activity to ensure it exists
        Academic_Calendar__c activity = [
            SELECT Id, Name
            FROM Academic_Calendar__c 
            WHERE Id = :activityId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        System.debug('Found activity to update: ' + activity.Name);

        // Update the fields
        activity.Type_of_Activity__c = typeOfActivity;
        activity.Duration_Type__c = durationType;
        activity.Duration__c = String.valueOf(numberOfWeeks);
        activity.Description__c = description;
        activity.Start_Date__c = startDate;
        activity.End_Date__c = endDate;

        // Perform the update
        if (Schema.sObjectType.Academic_Calendar__c.isUpdateable()) {
        update activity;
    } else {
        throw new AuraHandledException('You do not have permission to update this record.');
    }
        System.debug('Activity updated successfully');
    } catch (Exception e) {
        System.debug('Error updating activity: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error updating activity: ' + e.getMessage());
    }
}
    
    
    /**
 * Method to delete an activity from Academic Calendar
 * @param activityId - The Id of the activity to delete
 * @return void
 */
@AuraEnabled
public static void deleteActivity(String activityId) {
    try {
        // Query the activity to ensure it exists and user has access
        Academic_Calendar__c activity = [SELECT Id FROM Academic_Calendar__c WHERE Id = :activityId WITH SECURITY_ENFORCED LIMIT 1];
        
        if (Schema.sObjectType.Academic_Calendar__c.isDeletable()) {
        delete activity;
    } else {
        throw new AuraHandledException('You do not have permission to delete this record.');
    }
    } catch(Exception e) {
        // Log the error and throw AuraHandledException for the client to handle
        System.debug('Error deleting activity: ' + e.getMessage());
        throw new AuraHandledException('Error deleting activity: ' + e.getMessage());
    }
}


/** <<<<<<<<<<<<<<<<getCoursesByAcademicProgram>>>>>>>>>>>>>>>>>>>> **/

@AuraEnabled(cacheable=true)
public static List<hed__Course__c> getCoursesByAcademicProgram(Id academicProgramId) {
    if (academicProgramId == null) {
        throw new AuraHandledException('Academic Program ID cannot be null');
    }

    try {
        System.debug( '>>>>>>>>>>>>>>'+[SELECT  Name,hed__Course_ID__c
        FROM hed__Course__c
        WHERE hed__Account__c = :academicProgramId]);
        return [
            SELECT Id, Name,hed__Course_ID__c
            FROM hed__Course__c
            WHERE hed__Account__c = :academicProgramId
            WITH SECURITY_ENFORCED
            
        ];
    } catch (Exception ex) {
        throw new AuraHandledException('Error retrieving courses: ' + ex.getMessage());
    }
}

/** ==========getCourseIdBySubject==========**/

@AuraEnabled(cacheable=true)
public static String getCourseIdBySubject(Id subjectId) {
    if (subjectId == null) {
        throw new AuraHandledException('Subject ID cannot be null');
    }

    try {
        hed__Course__c course = [
            SELECT hed__Course_ID__c
            FROM hed__Course__c
            WHERE Id = :subjectId
            WITH SECURITY_ENFORCED
            LIMIT 1
            
        ];
        return course.hed__Course_ID__c;
    } catch (Exception ex) {
        throw new AuraHandledException('Error fetching Course ID: ' + ex.getMessage());
    }
}

}