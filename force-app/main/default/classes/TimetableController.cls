/**
 * Apex controller for the timetable LWC component
 * Provides methods to fetch academic programs, plans, terms, sections, and courses from Salesforce
 * Customized for use with the Higher Education Data Architecture (HEDA)
 */
public with sharing class TimetableController {
    
    /**
     * Get academic programs from Account object where recordType is 'Academic Program'
     * @return List of ComboboxOption wrapper objects for LWC combobox
     */
    @AuraEnabled(cacheable=true)
    public static List<ComboboxOption> getAcademicPrograms() {
        List<ComboboxOption> options = new List<ComboboxOption>();
        
        try {
            // In HEDA, Academic Programs are typically Accounts with a specific Record Type
            // First try to get the Record Type Id for 'Academic Program'
            Id academicProgramRecordTypeId;
            try {
                academicProgramRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                    .get('Academic_Program').getRecordTypeId();
            } catch (Exception e) {
                // If 'Academic_Program' is not found, try 'Educational_Institution'
                try {
                    academicProgramRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                        .get('Educational_Institution').getRecordTypeId();
                } catch (Exception ex) {
                    // If still not found, get all accounts
                    academicProgramRecordTypeId = null;
                }
            }
            
            // Query accounts with this record type
            List<Account> academicPrograms;
            if(academicProgramRecordTypeId != null) {
                academicPrograms = [
                    SELECT Id, Name
                    FROM Account
                    WHERE RecordTypeId = :academicProgramRecordTypeId
                    ORDER BY Name ASC
                ];
            } else {
                // If no specific record type was found, get all accounts
                academicPrograms = [
                    SELECT Id, Name
                    FROM Account
                    ORDER BY Name ASC
                    LIMIT 100
                ];
            }
            
            // Convert to combobox options
            for(Account prog : academicPrograms) {
                options.add(new ComboboxOption(prog.Name, prog.Id));
            }
        } catch(Exception e) {
            System.debug('Error fetching academic programs: ' + e.getMessage());
            throw new AuraHandledException('Error fetching academic programs: ' + e.getMessage());
        }
        
        return options;
    }
    
    /**
     * Get program plans related to the selected academic program
     * @param academicProgramId The Id of the selected academic program
     * @return List of ComboboxOption wrapper objects for LWC combobox
     */
    @AuraEnabled(cacheable=true)
    public static List<ComboboxOption> getProgramPlans(String academicProgramId) {
        List<ComboboxOption> options = new List<ComboboxOption>();
        
        if(String.isBlank(academicProgramId)) {
            return options;
        }
        
        try {
            // In HEDA, Program Plans are typically represented by hed__Program_Plan__c
            List<hed__Program_Plan__c> programPlans = [
                SELECT Id, Name, hed__Description__c
                FROM hed__Program_Plan__c
                WHERE hed__Account__c = :academicProgramId
                ORDER BY Name ASC
            ];
            
            // Convert to combobox options
            for(hed__Program_Plan__c plan : programPlans) {
                options.add(new ComboboxOption(plan.Name, plan.Id));
            }
            
            // If no program plans found, check if there are any program plans in the system
            if(options.isEmpty()) {
                List<hed__Program_Plan__c> allProgramPlans = [
                    SELECT Id, Name, hed__Description__c
                    FROM hed__Program_Plan__c
                    ORDER BY Name ASC
                    LIMIT 100
                ];
                
                for(hed__Program_Plan__c plan : allProgramPlans) {
                    options.add(new ComboboxOption(plan.Name, plan.Id));
                }
            }
        } catch(Exception e) {
            System.debug('Error fetching program plans: ' + e.getMessage());
            throw new AuraHandledException('Error fetching program plans: ' + e.getMessage());
        }
        
        return options;
    }
    
    /**
     * Get terms related to the selected program plan
     * @param programPlanId The Id of the selected program plan
     * @return List of ComboboxOption wrapper objects for LWC combobox
     */
    @AuraEnabled(cacheable=true)
    public static List<ComboboxOption> getTerms(String programPlanId) {
        List<ComboboxOption> options = new List<ComboboxOption>();
        
        if(String.isBlank(programPlanId)) {
            return options;
        }
        
        try {
            // In HEDA, Terms are typically represented by hed__Term__c
            
            // First, try to find terms related to the program plan through plan requirements
            Set<Id> termIds = new Set<Id>();
            
            // Get plan requirements associated with the program plan
            List<hed__Plan_Requirement__c> planRequirements = [
                SELECT Id, Term__c
                FROM hed__Plan_Requirement__c
                WHERE hed__Program_Plan__c = :programPlanId AND Term__c != null
            ];
            
            // Collect term IDs from plan requirements
            for(hed__Plan_Requirement__c req : planRequirements) {
                if(req.Term__c != null) {
                    termIds.add(req.Term__c);
                }
            }
            
            // If we found terms through plan requirements, query those terms
            if(!termIds.isEmpty()) {
                List<hed__Term__c> terms = [
                    SELECT Id, Name, hed__Start_Date__c
                    FROM hed__Term__c
                    WHERE Id IN :termIds
                    ORDER BY hed__Start_Date__c DESC
                ];
                
                // Convert to combobox options
                for(hed__Term__c term : terms) {
                    options.add(new ComboboxOption(term.Name, term.Id));
                }
            } else {
                // If no terms found through plan requirements, get all active terms
                List<hed__Term__c> allTerms = [
                    SELECT Id, Name, hed__Start_Date__c
                    FROM hed__Term__c
                    WHERE hed__Start_Date__c <= TODAY AND 
                          (hed__End_Date__c >= TODAY OR hed__End_Date__c = null)
                    ORDER BY hed__Start_Date__c DESC
                ];
                
                // Convert to combobox options
                for(hed__Term__c term : allTerms) {
                    options.add(new ComboboxOption(term.Name, term.Id));
                }
                
                // If still no terms found, get all terms
                if(options.isEmpty()) {
                    List<hed__Term__c> allHistoricalTerms = [
                        SELECT Id, Name, hed__Start_Date__c
                        FROM hed__Term__c
                        ORDER BY hed__Start_Date__c DESC
                        LIMIT 100
                    ];
                    
                    // Convert to combobox options
                    for(hed__Term__c term : allHistoricalTerms) {
                        options.add(new ComboboxOption(term.Name, term.Id));
                    }
                }
            }
        } catch(Exception e) {
            System.debug('Error fetching terms: ' + e.getMessage());
            throw new AuraHandledException('Error fetching terms: ' + e.getMessage());
        }
        
        return options;
    }
    
    /**
     * Get sections related to the selected term
     * @param termId The Id of the selected term
     * @return List of ComboboxOption wrapper objects for LWC combobox
     */
    @AuraEnabled(cacheable=true)
    public static List<ComboboxOption> getSections(String termId) {
        List<ComboboxOption> options = new List<ComboboxOption>();
        
        if(String.isBlank(termId)) {
            return options;
        }
        
        try {
            // Query all course offerings related to the term
            List<hed__Course_Offering__c> allOfferings = [
                SELECT Id, hed__Section_ID__c, Name
                FROM hed__Course_Offering__c
                WHERE hed__Term__c = :termId
                ORDER BY hed__Section_ID__c ASC
            ];
            
            // Create a map to collect unique sections with their IDs
            Map<String, List<Id>> sectionToOfferingIds = new Map<String, List<Id>>();
            
            // Process all offerings to collect unique section IDs
            for(hed__Course_Offering__c offering : allOfferings) {
                String sectionId = offering.hed__Section_ID__c;
                
                // If no section ID is defined, use the first character of the name
                if(String.isBlank(sectionId) && offering.Name != null && offering.Name.length() > 0) {
                    sectionId = offering.Name.substring(0, 1);
                }
                
                // If we still don't have a section ID, skip this record
                if(String.isBlank(sectionId)) {
                    continue;
                }
                
                // Add this offering ID to the list for this section
                if(!sectionToOfferingIds.containsKey(sectionId)) {
                    sectionToOfferingIds.put(sectionId, new List<Id>());
                }
                sectionToOfferingIds.get(sectionId).add(offering.Id);
            }
            
            // Convert the map to combobox options
            for(String sectionId : sectionToOfferingIds.keySet()) {
                // Use section ID (A, B, C, etc.) as the label
                // Store the JSON string of all offering IDs for this section as the value
                options.add(new ComboboxOption(sectionId, JSON.serialize(sectionToOfferingIds.get(sectionId))));
            }
            
            // Sort options alphabetically
            options.sort();
        } catch(Exception e) {
            System.debug('Error fetching sections: ' + e.getMessage());
            throw new AuraHandledException('Error fetching sections: ' + e.getMessage());
        }
        
        return options;
    }
    
    /**
     * Get subjects (courses) related to the selected term and section
     * @param termId The Id of the selected term
     * @param sectionIdsList A serialized list of course offering IDs for the selected section
     * @return List of SubjectOption wrapper objects
     */
    @AuraEnabled(cacheable=true)
    public static List<SubjectOption> getSubjects(String termId, String sectionIdsList) {
        List<SubjectOption> options = new List<SubjectOption>();
        
        if(String.isBlank(termId) || String.isBlank(sectionIdsList)) {
            return options;
        }
        
        try {
            // Deserialize the list of course offering IDs
            List<Id> offeringIds = (List<Id>)JSON.deserialize(sectionIdsList, List<Id>.class);
            
            // Get all course offerings for this section
            List<hed__Course_Offering__c> offerings = [
                SELECT Id, hed__Course__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c
                FROM hed__Course_Offering__c 
                WHERE Id IN :offeringIds AND hed__Term__c = :termId
            ];
            
            // Set to track unique course IDs (to avoid duplicates)
            Set<Id> processedCourseIds = new Set<Id>();
            
            // Process each offering and get the associated course
            for(hed__Course_Offering__c offering : offerings) {
                if(offering.hed__Course__c != null && !processedCourseIds.contains(offering.hed__Course__c)) {
                    // Add each unique course to the options list
                    options.add(new SubjectOption(
                        offering.hed__Course__c, 
                        offering.hed__Course__r.Name, 
                        offering.hed__Course__r.hed__Course_ID__c
                    ));
                    
                    // Mark this course as processed
                    processedCourseIds.add(offering.hed__Course__c);
                }
            }
            
            // If no courses found for the offerings, we might need to query all courses
            if(options.isEmpty()) {
                // Get all courses without trying to filter by Term
                List<hed__Course__c> allCourses = [
                    SELECT Id, Name, hed__Course_ID__c
                    FROM hed__Course__c
                    ORDER BY Name ASC
                    LIMIT 100 // Limit to avoid performance issues
                ];
                
                for(hed__Course__c course : allCourses) {
                    options.add(new SubjectOption(course.Id, course.Name, course.hed__Course_ID__c));
                }
                
                // If still no courses, get all available courses
                if(options.isEmpty()) {
                    List<hed__Course__c> availableCourses = [
                        SELECT Id, Name, hed__Course_ID__c
                        FROM hed__Course__c
                        ORDER BY Name ASC
                        LIMIT 100 // Limit to avoid performance issues
                    ];
                    
                    for(hed__Course__c course : availableCourses) {
                        options.add(new SubjectOption(course.Id, course.Name, course.hed__Course_ID__c));
                    }
                }
            }
        } catch(Exception e) {
            System.debug('Error fetching subjects: ' + e.getMessage());
            throw new AuraHandledException('Error fetching subjects: ' + e.getMessage());
        }
        
        return options;
    }
    
    /**
     * Inner class for combobox options
     */
    public class ComboboxOption implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public ComboboxOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
        
        // Implement the compareTo method for sorting
        public Integer compareTo(Object compareTo) {
            ComboboxOption compareToOption = (ComboboxOption)compareTo;
            if (label == null || compareToOption.label == null) {
                return 0;
            }
            return label.compareTo(compareToOption.label);
        }
    }
    
    /**
     * Inner class for subject options which include code
     */
    public class SubjectOption {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String code;
        @AuraEnabled public Boolean selected;
        
        public SubjectOption(String id, String name, String code) {
            this.id = id;
            this.name = name;
            this.code = code != null ? code : '';
            this.selected = false;
        }
    }
    
    /**
 * Get activity types from Session__c object (Type_of_Activity__c picklist)
 * @return List of ComboboxOption wrapper objects for LWC combobox
 */
@AuraEnabled(cacheable=true)
public static List<ComboboxOption> getActivityTypes() {
    List<ComboboxOption> options = new List<ComboboxOption>();
    
    try {
        // Get the describe result for the Session__c object
        Schema.DescribeSObjectResult describeResult = Schema.SObjectType.Session__c;
        
        // Check if the object is accessible
        if(describeResult.isAccessible()) {
            // Get the field describe result for the Type_of_Activity__c field
            Schema.DescribeFieldResult fieldResult = describeResult.fields.getMap().get('Type_of_Activity__c').getDescribe();
            
            // Get the picklist values
            List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();
            
            // Convert to combobox options
            for(Schema.PicklistEntry entry : picklistValues) {
                if(entry.isActive()) {
                    options.add(new ComboboxOption(entry.getLabel(), entry.getValue()));
                }
            }
        }
    } catch(Exception e) {
        System.debug('Error fetching activity types: ' + e.getMessage());
        throw new AuraHandledException('Error fetching activity types: ' + e.getMessage());
    }
    
    return options;
}

/**
 * Get facilities from hed__Facility__c object
 * @return List of ComboboxOption wrapper objects for LWC combobox
 */
@AuraEnabled(cacheable=true)
public static List<ComboboxOption> getFacilities() {
    List<ComboboxOption> options = new List<ComboboxOption>();
    
    try {
        // Query facilities from hed__Facility__c
        List<hed__Facility__c> facilities = [
            SELECT Id, Name, hed__Facility_Type__c
            FROM hed__Facility__c
            ORDER BY Name ASC
            LIMIT 100
        ];
        
        // Convert to combobox options
        for(hed__Facility__c facility : facilities) {
            options.add(new ComboboxOption(facility.Name, facility.Id));
        }
    } catch(Exception e) {
        System.debug('Error fetching facilities: ' + e.getMessage());
        throw new AuraHandledException('Error fetching facilities: ' + e.getMessage());
    }
    
    return options;
}

/**
 * Get faculty members (Contact records with Record Type = Faculty)
 * @return List of ComboboxOption wrapper objects for LWC combobox
 */
@AuraEnabled(cacheable=true)
public static List<ComboboxOption> getFacultyMembers() {
    List<ComboboxOption> options = new List<ComboboxOption>();
    
    try {
        // Try to get faculty contacts from course enrollments
        List<Contact> facultyContacts = [
            SELECT Id, Name
            FROM Contact
            WHERE Id IN (
                SELECT hed__Contact__c 
                FROM hed__Course_Enrollment__c 
                WHERE hed__Course_Offering__c != null
            )
            ORDER BY Name ASC
            LIMIT 100
        ];
        
        // If no faculty found in course enrollments, try to find by record type
        if(facultyContacts.isEmpty()) {
            // Try to get the Record Type Id for 'Faculty'
            Id facultyRecordTypeId;
            try {
                facultyRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                    .get('Faculty').getRecordTypeId();
                    
                facultyContacts = [
                    SELECT Id, Name
                    FROM Contact
                    WHERE RecordTypeId = :facultyRecordTypeId
                    ORDER BY Name ASC
                    LIMIT 100
                ];
            } catch(Exception e) {
                // If no faculty record type, get all contacts
                facultyContacts = [
                    SELECT Id, Name
                    FROM Contact
                    ORDER BY Name ASC
                    LIMIT 100
                ];
            }
        }
        
        // Convert to combobox options
        for(Contact faculty : facultyContacts) {
            options.add(new ComboboxOption(faculty.Name, faculty.Id));
        }
    } catch(Exception e) {
        System.debug('Error fetching faculty members: ' + e.getMessage());
        throw new AuraHandledException('Error fetching faculty members: ' + e.getMessage());
    }
    
    return options;
}
  /**
 * Create a new Session__c record from the session data
 * @param sessionData JSON string representation of the session data
 * @return Id of the newly created Session__c record
 */

    /**
 * Create a new Session__c record from the session data
 * @param sessionData JSON string representation of the session data
 * @return Id of the newly created Session__c record
 */
/**
 * Create a new Session__c record from the session data
 * @param sessionData JSON string representation of the session data
 * @return Id of the newly created Session__c record
 */
@AuraEnabled
public static Id createSession(String sessionData) {
    System.debug('Starting createSession with data: ' + sessionData);
    
    try {
        // Parse the session data
        Map<String, Object> sessionMap = (Map<String, Object>)JSON.deserializeUntyped(sessionData);
        
        // Create the Session__c record
        Session__c session = new Session__c();
        System.debug('Creating Session__c record');
        
        // Map session data to Session__c fields
        session.Type_of_Activity__c = (String)sessionMap.get('activityType');
        
        // Handle subject (Course__c)
        String subjectId = (String)sessionMap.get('subject');
        if (String.isNotBlank(subjectId)) {
            // Uncomment this line if Course__c field exists
            // session.Course__c = subjectId;
            System.debug('Set Course__c: ' + subjectId);
        }
        
        // Handle faculty (Faculty__c)
        String facultyId = (String)sessionMap.get('faculty');
        if (String.isNotBlank(facultyId)) {
            session.Faculty__c = facultyId;
            System.debug('Set Faculty__c: ' + facultyId);
        }
        
        // Handle facility (Facility__c)
        String facilityId = (String)sessionMap.get('facility');
        if (String.isNotBlank(facilityId)) {
            session.Facility__c = facilityId;
            System.debug('Set Facility__c: ' + facilityId);
        }
        
        // Handle academic program (Account_Name__c)
        String accountId = (String)sessionMap.get('accountId');
        if (String.isNotBlank(accountId)) {
            session.Account_Name__c = accountId;
            System.debug('Set Account_Name__c: ' + accountId);
        }

        // Set default values for Mode_of_Delivery__c and TimeZone__c
        session.Mode_of_Delivery__c = 'Face to Face';
        session.TimeZone__c = 'Asia/Kolkata';
        
        // Handle course offering
        String sectionIdsList = (String)sessionMap.get('sectionId');
        if (String.isNotBlank(sectionIdsList) && String.isNotBlank(subjectId)) {
            try {
                List<Id> offeringIds;
                try {
                    offeringIds = (List<Id>)JSON.deserialize(sectionIdsList, List<Id>.class);
                } catch (Exception e) {
                    offeringIds = new List<Id>{ sectionIdsList };
                }
                
                List<hed__Course_Offering__c> offerings = [
                    SELECT Id 
                    FROM hed__Course_Offering__c 
                    WHERE Id IN :offeringIds AND hed__Course__c = :subjectId
                    LIMIT 1
                ];
                
                if (!offerings.isEmpty()) {
                    session.Course_Offering__c = offerings[0].Id;
                    System.debug('Set Course_Offering__c: ' + offerings[0].Id);
                }
            } catch (Exception e) {
                System.debug('Error finding course offering: ' + e.getMessage());
            }
        }
        
        // Get start and end dates
        String startDateStr = (String)sessionMap.get('startDate');
        String endDateStr = (String)sessionMap.get('endDate');
        
        // Check if we should skip holidays
        Boolean skipHolidays = Boolean.valueOf(sessionMap.get('skipHolidays'));
        System.debug('Skip holidays: ' + skipHolidays);
        
        // Check if this is a recurring session
        Boolean isRecurrent = (Boolean)sessionMap.get('isRecurrent');
        
        // Handle recurring sessions
        if (isRecurrent) {
            // Get the selected days and their time ranges
            List<Object> selectedDays = (List<Object>)sessionMap.get('selectedDays');
            
            // Use a placeholder session ID to return to the frontend
            // We will create all sessions and return the ID of the first one
            Id firstSessionId = null;
            
            // Create recurring sessions
            if (selectedDays != null && !selectedDays.isEmpty()) {
                List<Session__c> sessionsToCreate = new List<Session__c>();
                
                // Process each selected day
                for (Object dayObj : selectedDays) {
                    Map<String, Object> dayData = (Map<String, Object>)dayObj;
                    String dayName = (String)dayData.get('day');
                    String startTime = (String)dayData.get('startTime');
                    String endTime = (String)dayData.get('endTime');
                    
                    if (String.isBlank(dayName) || String.isBlank(startTime) || String.isBlank(endTime)) {
                        continue; // Skip if any required data is missing
                    }
                    
                    // Create sessions for this day between start and end dates
                    List<Session__c> daySessions = createRecurringDaySessions(
                        session, 
                        dayName, 
                        startTime, 
                        endTime, 
                        startDateStr, 
                        endDateStr,
                        skipHolidays
                    );
                    
                    if (!daySessions.isEmpty()) {
                        sessionsToCreate.addAll(daySessions);
                    }
                }
                
                // Insert all sessions
                if (!sessionsToCreate.isEmpty()) {
                    insert sessionsToCreate;
                    
                    // Create faculty bookings for all sessions
                    createFacultyBookings(sessionsToCreate);
                    
                    // Create facility bookings for all sessions
                    createFacilityBookings(sessionsToCreate);
                    
                    // Return the ID of the first session
                    firstSessionId = sessionsToCreate[0].Id;
                    System.debug('Created ' + sessionsToCreate.size() + ' recurring sessions. First ID: ' + firstSessionId);
                }
                
                // Return the ID of the first session
                return firstSessionId;
            }
        } else {
            // Handle single session
            
            // Handle start date and time
            String startTimeStr = (String)sessionMap.get('startTime');
            
            if (String.isNotBlank(startDateStr)) {
                Date startDate = Date.valueOf(startDateStr);
                
                // Check if this date is a holiday and we should skip it
                if (skipHolidays) {
                    Map<String, String> holidayMap = getHolidays(startDateStr, startDateStr);
                    if (!holidayMap.isEmpty()) {
                        // This is a holiday, so don't create the session
                        System.debug('Skipping single session on holiday: ' + startDateStr);
                        throw new AuraHandledException('Cannot create session on ' + startDateStr + '. It is a holiday: ' + holidayMap.get(startDateStr));
                    }
                }
                
                if (String.isNotBlank(startTimeStr)) {
                    List<String> startTimeParts = startTimeStr.split(':');
                    if (startTimeParts.size() >= 2) {
                        Integer startHour = Integer.valueOf(startTimeParts[0]);
                        Integer startMinute = Integer.valueOf(startTimeParts[1]);
                        
                        session.Start_Date_Time__c = DateTime.newInstance(
                            startDate.year(), 
                            startDate.month(), 
                            startDate.day(),
                            startHour,
                            startMinute,
                            0
                        );
                        System.debug('Set Start_Date_Time__c: ' + session.Start_Date_Time__c);
                    }
                } else {
                    session.Start_Date_Time__c = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
                    System.debug('Set Start_Date_Time__c (no time): ' + session.Start_Date_Time__c);
                }
            }
            
            // Handle end date and time
            String endTimeStr = (String)sessionMap.get('endTime');
            
            if (String.isNotBlank(endDateStr)) {
                Date endDate = Date.valueOf(endDateStr);
                
                if (String.isNotBlank(endTimeStr)) {
                    List<String> endTimeParts = endTimeStr.split(':');
                    if (endTimeParts.size() >= 2) {
                        Integer endHour = Integer.valueOf(endTimeParts[0]);
                        Integer endMinute = Integer.valueOf(endTimeParts[1]);
                        
                        session.End_Date_Time__c = DateTime.newInstance(
                            endDate.year(), 
                            endDate.month(), 
                            endDate.day(),
                            endHour,
                            endMinute,
                            0
                        );
                        System.debug('Set End_Date_Time__c: ' + session.End_Date_Time__c);
                    }
                } else {
                    session.End_Date_Time__c = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));
                    System.debug('Set End_Date_Time__c (no time): ' + session.End_Date_Time__c);
                }
            }
            
            // Print out the session object before insert
            System.debug('Session object before insert: ' + session);
            
            // Insert the session
            insert session;
            System.debug('Session created with ID: ' + session.Id);
            
            // Create a faculty booking record for this session
            createFacultyBooking(session);
            
            // Create a facility booking record for this session
            createFacilityBooking(session);
            
            return session.Id;
        }
        
        return null;
    } catch (Exception e) {
        System.debug('Exception in createSession: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error creating session: ' + e.getMessage());
    }
}

/**
 * Create recurring sessions for a specific day between start and end dates
 * @param baseSession Base Session record to clone
 * @param dayName Name of the weekday (Monday, Tuesday, etc.)
 * @param startTime Start time for sessions on this day (HH:MM format)
 * @param endTime End time for sessions on this day (HH:MM format)
 * @param startDateStr Start date for the date range (yyyy-MM-dd format)
 * @param endDateStr End date for the date range (yyyy-MM-dd format)
 * @return List of Session__c records to be inserted
 */
 /*private static List<Session__c> createRecurringDaySessions(
    Session__c baseSession, 
    String dayName, 
    String startTime, 
    String endTime, 
    String startDateStr, 
    String endDateStr
)  {
    List<Session__c> sessionsToCreate = new List<Session__c>();
    try {
        // Parse start and end dates
        Date startDate = Date.valueOf(startDateStr);
        Date endDate = Date.valueOf(endDateStr);
        
        // Create a map of day names to their numeric values (0 = Sunday, 1 = Monday, etc.)
        Map<String, Integer> dayToNumber = new Map<String, Integer>{
            'Sunday' => 0,
            'Monday' => 1,
            'Tuesday' => 2,
            'Wednesday' => 3,
            'Thursday' => 4,
            'Friday' => 5,
            'Saturday' => 6
        };
        
        // Get the day number (0-6, with 0 being Sunday)
        Integer targetDayNumber = dayToNumber.get(dayName);
        if (targetDayNumber == null) {
            return sessionsToCreate; // Return empty list if day name is invalid
        }
        
        // Parse the time strings
        List<String> startTimeParts = startTime.split(':');
        List<String> endTimeParts = endTime.split(':');
        if (startTimeParts.size() < 2 || endTimeParts.size() < 2) {
            return sessionsToCreate; // Return empty list if time format is invalid
        }
        Integer startHour = Integer.valueOf(startTimeParts[0]);
        Integer startMinute = Integer.valueOf(startTimeParts[1]);
        Integer endHour = Integer.valueOf(endTimeParts[0]);
        Integer endMinute = Integer.valueOf(endTimeParts[1]);
        
        // Find the first occurrence of this day of the week on or after startDate
        Date currentDate = startDate;
        
        // Use a reference date with a known day of the week
        // January 1, 2024, was a Tuesday (day 2)
        Date referenceTuesday = Date.newInstance(2024, 1, 1);
        
        // Calculate the day of the week for currentDate
        Integer daysSinceReference = currentDate.daysBetween(referenceTuesday);
        Integer currentDayOfWeek = Math.mod(daysSinceReference + 2, 7); // Adjust for Tuesday reference
        
        // Calculate days to add to get to the target day
        Integer daysToAdd = Math.mod((targetDayNumber - currentDayOfWeek + 7), 7);
        
        // If we're already on the target day, don't add 7 days
        if (daysToAdd == 7) {
            daysToAdd = 0;
        }
        
        // Advance to the first occurrence of the target day
        currentDate = currentDate.addDays(daysToAdd);
        
        // Create sessions for each occurrence of this day between start and end dates
        while (currentDate <= endDate) {
            // Clone the base session
            Session__c newSession = baseSession.clone(false, true, false, false);
            
            // Set the Mode_of_Delivery__c and TimeZone__c fields for each new session

            newSession.Mode_of_Delivery__c = 'Face to Face';

            newSession.TimeZone__c = 'Asia/Kolkata';
            // Set DateTime fields for this specific day and time
            newSession.Start_Date_Time__c = DateTime.newInstance(
                currentDate.year(),
                currentDate.month(),
                currentDate.day(),
                startHour,
                startMinute,
                0
            );
            newSession.End_Date_Time__c = DateTime.newInstance(
                currentDate.year(),
                currentDate.month(),
                currentDate.day(),
                endHour,
                endMinute,
                0
            );
            sessionsToCreate.add(newSession);
            // Move to the next occurrence (7 days later)
            currentDate = currentDate.addDays(7);
        }
        System.debug('Created ' + sessionsToCreate.size() + ' sessions for ' + dayName);
    } catch (Exception e) {
        System.debug('Error creating recurring sessions: ' + e.getMessage());
    }
    return sessionsToCreate;
}*/
    
    /**
 * Create recurring sessions for a specific day between start and end dates
 * @param baseSession Base Session record to clone
 * @param dayName Name of the weekday (Monday, Tuesday, etc.)
 * @param startTime Start time for sessions on this day (HH:MM format)
 * @param endTime End time for sessions on this day (HH:MM format)
 * @param startDateStr Start date for the date range (yyyy-MM-dd format)
 * @param endDateStr End date for the date range (yyyy-MM-dd format)
 * @param skipHolidays Boolean to indicate whether to skip holidays
 * @return List of Session__c records to be inserted
 */
private static List<Session__c> createRecurringDaySessions(
    Session__c baseSession, 
    String dayName, 
    String startTime, 
    String endTime, 
    String startDateStr, 
    String endDateStr,
    Boolean skipHolidays
) {
    List<Session__c> sessionsToCreate = new List<Session__c>();
    try {
        // Parse start and end dates
        Date startDate = Date.valueOf(startDateStr);
        Date endDate = Date.valueOf(endDateStr);
        
        // Create a map of day names to their numeric values (0 = Sunday, 1 = Monday, etc.)
        Map<String, Integer> dayToNumber = new Map<String, Integer>{
            'Sunday' => 0,
            'Monday' => 1,
            'Tuesday' => 2,
            'Wednesday' => 3,
            'Thursday' => 4,
            'Friday' => 5,
            'Saturday' => 6
        };
        
        // Get the day number (0-6, with 0 being Sunday)
        Integer targetDayNumber = dayToNumber.get(dayName);
        if (targetDayNumber == null) {
            return sessionsToCreate; // Return empty list if day name is invalid
        }
        
        // Parse the time strings
        List<String> startTimeParts = startTime.split(':');
        List<String> endTimeParts = endTime.split(':');
        if (startTimeParts.size() < 2 || endTimeParts.size() < 2) {
            return sessionsToCreate; // Return empty list if time format is invalid
        }
        Integer startHour = Integer.valueOf(startTimeParts[0]);
        Integer startMinute = Integer.valueOf(startTimeParts[1]);
        Integer endHour = Integer.valueOf(endTimeParts[0]);
        Integer endMinute = Integer.valueOf(endTimeParts[1]);
        
        // Find the first occurrence of this day of the week on or after startDate
        Date currentDate = startDate;
        
        // Use a reference date with a known day of the week
        // January 1, 2024, was a Tuesday (day 2)
        Date referenceTuesday = Date.newInstance(2024, 1, 1);
        
        // Calculate the day of the week for currentDate
        Integer daysSinceReference = currentDate.daysBetween(referenceTuesday);
        Integer currentDayOfWeek = Math.mod(daysSinceReference + 2, 7); // Adjust for Tuesday reference
        
        // Calculate days to add to get to the target day
        Integer daysToAdd = Math.mod((targetDayNumber - currentDayOfWeek + 7), 7);
        
        // If we're already on the target day, don't add 7 days
        if (daysToAdd == 7) {
            daysToAdd = 0;
        }
        
        // Advance to the first occurrence of the target day
        currentDate = currentDate.addDays(daysToAdd);
        
        // If we need to skip holidays, get all holidays between start and end dates
        Map<String, String> holidayMap = new Map<String, String>();
        if (skipHolidays) {
            holidayMap = getHolidays(startDateStr, endDateStr);
        }
        
        // Create sessions for each occurrence of this day between start and end dates
        while (currentDate <= endDate) {
            // Format current date as string for holiday checking
            String currentDateStr = currentDate.year() + '-' + 
                                  String.valueOf(currentDate.month()).leftPad(2, '0') + '-' + 
                                  String.valueOf(currentDate.day()).leftPad(2, '0');
            
            // Skip this date if it's a holiday and we're supposed to skip holidays
            if (skipHolidays && holidayMap.containsKey(currentDateStr)) {
                System.debug('Skipping holiday: ' + currentDateStr + ' - ' + holidayMap.get(currentDateStr));
                // Move to the next occurrence (7 days later)
                currentDate = currentDate.addDays(7);
                continue;
            }
            
            // Clone the base session
            Session__c newSession = baseSession.clone(false, true, false, false);
            
            // Set the Mode_of_Delivery__c and TimeZone__c fields for each new session
            newSession.Mode_of_Delivery__c = 'Face to Face';
            newSession.TimeZone__c = 'Asia/Kolkata';
            
            // Set DateTime fields for this specific day and time
            newSession.Start_Date_Time__c = DateTime.newInstance(
                currentDate.year(),
                currentDate.month(),
                currentDate.day(),
                startHour,
                startMinute,
                0
            );
            newSession.End_Date_Time__c = DateTime.newInstance(
                currentDate.year(),
                currentDate.month(),
                currentDate.day(),
                endHour,
                endMinute,
                0
            );
            sessionsToCreate.add(newSession);
            
            // Move to the next occurrence (7 days later)
            currentDate = currentDate.addDays(7);
        }
        System.debug('Created ' + sessionsToCreate.size() + ' sessions for ' + dayName);
    } catch (Exception e) {
        System.debug('Error creating recurring sessions: ' + e.getMessage());
    }
    return sessionsToCreate;
}
  /**
 * Get sessions within a date range
 * @param startDate The start date for the range (yyyy-MM-dd format)
 * @param endDate The end date for the range (yyyy-MM-dd format)
 * @return List of Session__c records
 */
/**
 * Get sessions within a date range
 * @param startDate The start date for the range (yyyy-MM-dd format)
 * @param endDate The end date for the range (yyyy-MM-dd format)
 * @return List of Session__c records
 */
@AuraEnabled
public static List<Session__c> getSessions(String startDate, String endDate) {
    try {
        System.debug('Getting sessions between ' + startDate + ' and ' + endDate);
        Date start = Date.valueOf(startDate);
        Date endd = Date.valueOf(endDate);
        
        // Convert dates to DateTime for comparison with DateTime fields
        DateTime startDateTime = DateTime.newInstance(start.year(), start.month(), start.day(), 0, 0, 0);
        DateTime endDateTime = DateTime.newInstance(endd.year(), endd.month(), endd.day(), 23, 59, 59);
        
        // Query sessions within the date range with related records
        List<Session__c> sessions = [
            SELECT Id, Type_of_Activity__c, 
                    
                   Course_Offering__c, Course_Offering__r.hed__Course__c, Course_Offering__r.hed__Course__r.Name,
                   Faculty__c, Faculty__r.Name, 
                   Facility__c, Facility__r.Name,
                   Account_Name__c, Start_Date_Time__c, 
                   End_Date_Time__c
            FROM Session__c
            WHERE Start_Date_Time__c >= :startDateTime
            AND Start_Date_Time__c <= :endDateTime
            ORDER BY Start_Date_Time__c ASC
        ];
        
        return sessions;
    } catch (Exception e) {
        System.debug('Error getting sessions: ' + e.getMessage());
        throw new AuraHandledException('Error getting sessions: ' + e.getMessage());
    }
}

/**
 * Private helper method to create recurring sessions
 * @param baseSession The base Session__c record to clone
 * @param selectedDaysObj List of selected days with their times
 * @param startDateStr Start date string
 * @param endDateStr End date string
 */
private static void createRecurringSessions(Session__c baseSession, List<Object> selectedDaysObj, String startDateStr, String endDateStr) {
    try {
        // Parse start and end dates
        Date startDate = Date.valueOf(startDateStr);
        Date endDate = Date.valueOf(endDateStr);
        
        // Create a map of day names to their numeric values (1 = Monday, 2 = Tuesday, ..., 7 = Sunday)
        // Note: Apex doesn't have a dayOfWeek() method, so we need to use a different approach
        Map<String, Integer> dayToNumber = new Map<String, Integer>{
            'Monday' => 1,
            'Tuesday' => 2,
            'Wednesday' => 3,
            'Thursday' => 4,
            'Friday' => 5,
            'Saturday' => 6,
            'Sunday' => 0
        };
        
        // List to hold all sessions to be created
        List<Session__c> sessionsToCreate = new List<Session__c>();
        
        // Process each selected day
        for (Object dayObj : selectedDaysObj) {
            Map<String, Object> dayData = (Map<String, Object>)dayObj;
            String dayName = (String)dayData.get('day');
            String startTime = (String)dayData.get('startTime');
            String endTime = (String)dayData.get('endTime');
            
            if (String.isBlank(dayName) || String.isBlank(startTime) || String.isBlank(endTime)) {
                continue; // Skip if any required data is missing
            }
            
            // Get the day number (0-6, with 0 being Sunday)
            Integer targetDayNumber = dayToNumber.get(dayName);
            if (targetDayNumber == null) {
                continue; // Skip if day name is invalid
            }
            
            // Find the first occurrence of this day of the week after startDate
            Date currentDate = startDate;
            
            // Create a reference to a known Sunday (January 7, 2024 was a Sunday)
            Date referenceSunday = Date.newInstance(2024, 1, 7);
            
            // Calculate the day of week for the current date
            // Formula: (days since reference Sunday) mod 7 gives day of week (0=Sunday, 1=Monday, etc.)
            Integer currentDayOfWeek = Math.mod(referenceSunday.daysBetween(currentDate), 7);
            
            // Calculate days to add to get to the target day
            Integer daysToAdd = Math.mod((targetDayNumber - currentDayOfWeek + 7), 7);
            
            // If daysToAdd is 0 but the target day isn't today, then we mean next week
            if (daysToAdd == 0 && currentDayOfWeek != targetDayNumber) {
                daysToAdd = 7;
            }
            
            // Advance to the first occurrence of the target day
            currentDate = currentDate.addDays(daysToAdd);
            
            // Parse the time strings
            List<String> startTimeParts = startTime.split(':');
            List<String> endTimeParts = endTime.split(':');
            
            if (startTimeParts.size() < 2 || endTimeParts.size() < 2) {
                continue; // Skip if time format is invalid
            }
            
            Integer startHour = Integer.valueOf(startTimeParts[0]);
            Integer startMinute = Integer.valueOf(startTimeParts[1]);
            Integer endHour = Integer.valueOf(endTimeParts[0]);
            Integer endMinute = Integer.valueOf(endTimeParts[1]);
            
            // Create sessions for each occurrence of this day between start and end dates
            while (currentDate <= endDate) {
                // Clone the base session
                Session__c newSession = baseSession.clone(false, true, false, false);
                
                // Set DateTime fields for this specific day and time
                newSession.Start_Date_Time__c = DateTime.newInstance(
                    currentDate.year(),
                    currentDate.month(),
                    currentDate.day(),
                    startHour,
                    startMinute,
                    0
                );
                
                newSession.End_Date_Time__c = DateTime.newInstance(
                    currentDate.year(),
                    currentDate.month(),
                    currentDate.day(),
                    endHour,
                    endMinute,
                    0
                );
                
                sessionsToCreate.add(newSession);
                
                // Move to the next occurrence (7 days later)
                currentDate = currentDate.addDays(7);
            }
        }
        
        // Insert all recurring sessions
        if (!sessionsToCreate.isEmpty()) {
            insert sessionsToCreate;
        }
    } catch (Exception e) {
        System.debug('Error creating recurring sessions: ' + e.getMessage());
    }
}
    
    @AuraEnabled(cacheable=true)
    public static String getWorkingDays(Id programPlanId) {
        hed__Program_Plan__c plan = [
            SELECT Working_Days__c 
            FROM hed__Program_Plan__c 
            WHERE Id = :programPlanId 
            LIMIT 1
        ];
        return plan.Working_Days__c;
    }
    
  /**
 * Creates a Faculty_Booking__c record from a Session__c record
 * @param session The Session__c record to create a booking for
 * @return The Faculty_Booking__c record ID
 */
private static Id createFacultyBooking(Session__c session) {
    try {
        // Create the Faculty_Booking__c record
        Faculty_Booking__c booking = new Faculty_Booking__c();
        
        // Map fields from Session__c to Faculty_Booking__c
        booking.Activity_Type__c = session.Type_of_Activity__c;
        booking.Start_Date_Time__c = session.Start_Date_Time__c;
        booking.End_Date_Time__c = session.End_Date_Time__c;
        booking.Account_Name__c = session.Account_Name__c;
        booking.Booked_By__c = session.Faculty__c;
        booking.Facility__c = session.Facility__c;
        
        // For Course_Version__c, we need to query Course_Offering__c to get Course_Version__c
        if (session.Course_Offering__c != null) {
            try {
                // Query to get the Course_Version__c from Course_Offering__c
                hed__Course_Offering__c courseOffering = [
                    SELECT Id, Course_Version__c 
                    FROM hed__Course_Offering__c 
                    WHERE Id = :session.Course_Offering__c
                    LIMIT 1
                ];
                
                if (courseOffering != null && courseOffering.Course_Version__c != null) {
                    booking.Course_Version__c = courseOffering.Course_Version__c;
                }
            } catch (Exception e) {
                System.debug('Error fetching Course_Version__c: ' + e.getMessage());
                // Continue creating the booking without Course_Version__c
            }
        }
        
        // Insert the booking record
        insert booking;
        System.debug('Created Faculty_Booking__c record with ID: ' + booking.Id);
        
        return booking.Id;
    } catch (Exception e) {
        System.debug('Error creating Faculty_Booking__c record: ' + e.getMessage());
        return null;
    }
}

/**
 * Creates Faculty_Booking__c records for multiple sessions
 * @param sessions List of Session__c records to create bookings for
 * @return List of Faculty_Booking__c record IDs
 */
private static List<Id> createFacultyBookings(List<Session__c> sessions) {
    List<Id> bookingIds = new List<Id>();
    
    try {
        // Create a list to hold all the booking records
        List<Faculty_Booking__c> bookingsToCreate = new List<Faculty_Booking__c>();
        
        // Collect all Course Offering IDs to query once
        Set<Id> courseOfferingIds = new Set<Id>();
        for (Session__c session : sessions) {
            if (session.Course_Offering__c != null) {
                courseOfferingIds.add(session.Course_Offering__c);
            }
        }
        
        // Query all needed Course Offerings at once for efficiency
        Map<Id, hed__Course_Offering__c> courseOfferingsMap = new Map<Id, hed__Course_Offering__c>();
        if (!courseOfferingIds.isEmpty()) {
            for (hed__Course_Offering__c offering : [
                SELECT Id, Course_Version__c 
                FROM hed__Course_Offering__c 
                WHERE Id IN :courseOfferingIds
            ]) {
                courseOfferingsMap.put(offering.Id, offering);
            }
        }
        
        // Create booking records for each session
        for (Session__c session : sessions) {
            Faculty_Booking__c booking = new Faculty_Booking__c();
            
            // Map fields from Session__c to Faculty_Booking__c
            booking.Activity_Type__c = session.Type_of_Activity__c;
            booking.Start_Date_Time__c = session.Start_Date_Time__c;
            booking.End_Date_Time__c = session.End_Date_Time__c;
            booking.Account_Name__c = session.Account_Name__c;
            booking.Booked_By__c = session.Faculty__c;
            booking.Facility__c = session.Facility__c;
            
            // Set Course_Version__c from the map if available
            if (session.Course_Offering__c != null && 
                courseOfferingsMap.containsKey(session.Course_Offering__c) && 
                courseOfferingsMap.get(session.Course_Offering__c).Course_Version__c != null) {
                booking.Course_Version__c = courseOfferingsMap.get(session.Course_Offering__c).Course_Version__c;
            }
            
            bookingsToCreate.add(booking);
        }
        
        // Insert all booking records in one operation
        if (!bookingsToCreate.isEmpty()) {
            insert bookingsToCreate;
            
            // Collect all booking IDs
            for (Faculty_Booking__c booking : bookingsToCreate) {
                bookingIds.add(booking.Id);
            }
            
            System.debug('Created ' + bookingsToCreate.size() + ' Faculty_Booking__c records');
        }
    } catch (Exception e) {
        System.debug('Error creating Faculty_Booking__c records: ' + e.getMessage());
    }
    
    return bookingIds;
}
    
    /**
 * Creates a Facility_Booking__c record from a Session__c record
 * @param session The Session__c record to create a booking for
 * @return The Facility_Booking__c record ID
 */
private static Id createFacilityBooking(Session__c session) {
    try {
        // Create the Facility_Booking__c record
        Facility_Booking__c booking = new Facility_Booking__c();
        
        // Map fields from Session__c to Facility_Booking__c
        booking.Activity_type__c = session.Type_of_Activity__c;
        booking.FacilityID__c = session.Facility__c;
        booking.Booked_By__c = session.Faculty__c;
        booking.Start_Date_and_Time__c = session.Start_Date_Time__c;
        booking.End_Date_and_Time__c = session.End_Date_Time__c;
        
        // Insert the booking record
        insert booking;
        System.debug('Created Facility_Booking__c record with ID: ' + booking.Id);
        
        return booking.Id;
    } catch (Exception e) {
        System.debug('Error creating Facility_Booking__c record: ' + e.getMessage());
        return null;
    }
}

/**
 * Creates Facility_Booking__c records for multiple sessions
 * @param sessions List of Session__c records to create bookings for
 * @return List of Facility_Booking__c record IDs
 */
private static List<Id> createFacilityBookings(List<Session__c> sessions) {
    List<Id> bookingIds = new List<Id>();
    
    try {
        // Create a list to hold all the booking records
        List<Facility_Booking__c> bookingsToCreate = new List<Facility_Booking__c>();
        
        // Create booking records for each session
        for (Session__c session : sessions) {
            Facility_Booking__c booking = new Facility_Booking__c();
            
            // Map fields from Session__c to Facility_Booking__c
            booking.Activity_type__c = session.Type_of_Activity__c;
            booking.FacilityID__c = session.Facility__c;
            booking.Booked_By__c = session.Faculty__c;
            booking.Start_Date_and_Time__c = session.Start_Date_Time__c;
            booking.End_Date_and_Time__c = session.End_Date_Time__c;
            
            bookingsToCreate.add(booking);
        }
        
        // Insert all booking records in one operation
        if (!bookingsToCreate.isEmpty()) {
            insert bookingsToCreate;
            
            // Collect all booking IDs
            for (Facility_Booking__c booking : bookingsToCreate) {
                bookingIds.add(booking.Id);
            }
            
            System.debug('Created ' + bookingsToCreate.size() + ' Facility_Booking__c records');
        }
    } catch (Exception e) {
        System.debug('Error creating Facility_Booking__c records: ' + e.getMessage());
    }
    
    return bookingIds;
}
    
    /**
 * Update an existing Session__c record
 * @param sessionData JSON string representation of the session data
 * @param sessionId The Id of the session to update
 * @return Id of the updated Session__c record
 */
@AuraEnabled
public static Id updateSession(String sessionData, Id sessionId) {
    System.debug('Starting updateSession with data: ' + sessionData + ' for session ID: ' + sessionId);
    
    try {
        // Parse the session data
        Map<String, Object> sessionMap = (Map<String, Object>)JSON.deserializeUntyped(sessionData);
        
        // Query the existing session
        Session__c session = [SELECT Id, Type_of_Activity__c, Faculty__c, Facility__c, 
                               Account_Name__c, Course_Offering__c, Start_Date_Time__c, 
                               End_Date_Time__c, Mode_of_Delivery__c, TimeZone__c 
                               FROM Session__c WHERE Id = :sessionId LIMIT 1];
        
        // Update session fields
        session.Type_of_Activity__c = (String)sessionMap.get('activityType');
        
        // Handle faculty (Faculty__c)
        String facultyId = (String)sessionMap.get('faculty');
        if (String.isNotBlank(facultyId)) {
            session.Faculty__c = facultyId;
        }
        
        // Handle facility (Facility__c)
        String facilityId = (String)sessionMap.get('facility');
        if (String.isNotBlank(facilityId)) {
            session.Facility__c = facilityId;
        }
        
        // Handle subject (Course__c) and course offering
        String subjectId = (String)sessionMap.get('subject');
        String sectionIdsList = (String)sessionMap.get('sectionId');
        
        if (String.isNotBlank(subjectId) && String.isNotBlank(sectionIdsList)) {
            try {
                List<Id> offeringIds;
                try {
                    offeringIds = (List<Id>)JSON.deserialize(sectionIdsList, List<Id>.class);
                } catch (Exception e) {
                    offeringIds = new List<Id>{ sectionIdsList };
                }
                
                List<hed__Course_Offering__c> offerings = [
                    SELECT Id 
                    FROM hed__Course_Offering__c 
                    WHERE Id IN :offeringIds AND hed__Course__c = :subjectId
                    LIMIT 1
                ];
                
                if (!offerings.isEmpty()) {
                    session.Course_Offering__c = offerings[0].Id;
                }
            } catch (Exception e) {
                System.debug('Error finding course offering: ' + e.getMessage());
            }
        }
        
        // Handle start date and time
        String startDateStr = (String)sessionMap.get('startDate');
        String startTimeStr = (String)sessionMap.get('startTime');
        
        if (String.isNotBlank(startDateStr)) {
            Date startDate = Date.valueOf(startDateStr);
            
            if (String.isNotBlank(startTimeStr)) {
                List<String> startTimeParts = startTimeStr.split(':');
                if (startTimeParts.size() >= 2) {
                    Integer startHour = Integer.valueOf(startTimeParts[0]);
                    Integer startMinute = Integer.valueOf(startTimeParts[1]);
                    
                    session.Start_Date_Time__c = DateTime.newInstance(
                        startDate.year(), 
                        startDate.month(), 
                        startDate.day(),
                        startHour,
                        startMinute,
                        0
                    );
                }
            } else {
                session.Start_Date_Time__c = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
            }
        }
        
        // Handle end date and time
        String endDateStr = (String)sessionMap.get('endDate');
        String endTimeStr = (String)sessionMap.get('endTime');
        
        if (String.isNotBlank(endDateStr)) {
            Date endDate = Date.valueOf(endDateStr);
            
            if (String.isNotBlank(endTimeStr)) {
                List<String> endTimeParts = endTimeStr.split(':');
                if (endTimeParts.size() >= 2) {
                    Integer endHour = Integer.valueOf(endTimeParts[0]);
                    Integer endMinute = Integer.valueOf(endTimeParts[1]);
                    
                    session.End_Date_Time__c = DateTime.newInstance(
                        endDate.year(), 
                        endDate.month(), 
                        endDate.day(),
                        endHour,
                        endMinute,
                        0
                    );
                }
            } else {
                session.End_Date_Time__c = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));
            }
        }
        
        // Update the session
        update session;
        
        // Update the Faculty_Booking__c record
        updateFacultyBooking(session);
        
        // Update the Facility_Booking__c record
        updateFacilityBooking(session);
        
        return session.Id;
    } catch (Exception e) {
        System.debug('Exception in updateSession: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error updating session: ' + e.getMessage() + ' On line number ' + e.getLineNumber());
    }
}

/**
 * Update the Faculty_Booking__c record associated with a session
 * @param session The Session__c record
 */
private static void updateFacultyBooking(Session__c session) {
    try {
        // Find the Faculty_Booking__c record for this session
        List<Faculty_Booking__c> bookings = [
            SELECT Id, Activity_Type__c, Start_Date_Time__c, End_Date_Time__c, 
                   Account_Name__c, Booked_By__c, Facility__c, Course_Version__c
            FROM Faculty_Booking__c 
            WHERE Booked_By__c = :session.Faculty__c
            AND Start_Date_Time__c = :session.Start_Date_Time__c
            LIMIT 1
        ];
        
        if (bookings.isEmpty()) {
            // No existing booking found, create a new one
            createFacultyBooking(session);
            return;
        }
        
        // Update the existing booking
        Faculty_Booking__c booking = bookings[0];
        booking.Activity_Type__c = session.Type_of_Activity__c;
        booking.Start_Date_Time__c = session.Start_Date_Time__c;
        booking.End_Date_Time__c = session.End_Date_Time__c;
        booking.Account_Name__c = session.Account_Name__c;
        booking.Booked_By__c = session.Faculty__c;
        booking.Facility__c = session.Facility__c;
        
        // For Course_Version__c, we need to query Course_Offering__c to get Course_Version__c
        if (session.Course_Offering__c != null) {
            try {
                hed__Course_Offering__c courseOffering = [
                    SELECT Id, Course_Version__c 
                    FROM hed__Course_Offering__c 
                    WHERE Id = :session.Course_Offering__c
                    LIMIT 1
                ];
                
                if (courseOffering != null && courseOffering.Course_Version__c != null) {
                    booking.Course_Version__c = courseOffering.Course_Version__c;
                }
            } catch (Exception e) {
                System.debug('Error fetching Course_Version__c: ' + e.getMessage());
            }
        }
        
        update booking;
    } catch (Exception e) {
        System.debug('Error updating Faculty_Booking__c record: ' + e.getMessage());
    }
}

/**
 * Update the Facility_Booking__c record associated with a session
 * @param session The Session__c record
 */
private static void updateFacilityBooking(Session__c session) {
    try {
        // Find the Facility_Booking__c record for this session
        List<Facility_Booking__c> bookings = [
            SELECT Id, Activity_type__c, FacilityID__c, Booked_By__c,
                   Start_Date_and_Time__c, End_Date_and_Time__c
            FROM Facility_Booking__c 
            WHERE FacilityID__c = :session.Facility__c
            AND Start_Date_and_Time__c = :session.Start_Date_Time__c
            LIMIT 1
        ];
        
        if (bookings.isEmpty()) {
            // No existing booking found, create a new one
            createFacilityBooking(session);
            return;
        }
        
        // Update the existing booking
        Facility_Booking__c booking = bookings[0];
        booking.Activity_type__c = session.Type_of_Activity__c;
        booking.FacilityID__c = session.Facility__c;
        booking.Booked_By__c = session.Faculty__c;
        booking.Start_Date_and_Time__c = session.Start_Date_Time__c;
        booking.End_Date_and_Time__c = session.End_Date_Time__c;
        
        update booking;
    } catch (Exception e) {
        System.debug('Error updating Facility_Booking__c record: ' + e.getMessage());
    }
}

/**
 * Delete a Session__c record and its associated bookings
 * @param sessionId The Id of the session to delete
 * @return Boolean indicating success or failure
 */
@AuraEnabled
public static Boolean deleteSession(Id sessionId) {
    System.debug('Starting deleteSession for session ID: ' + sessionId);
    
    try {
        // Query the session first to get related information
        Session__c session = [
            SELECT Id, Faculty__c, Facility__c, Start_Date_Time__c
            FROM Session__c
            WHERE Id = :sessionId
            LIMIT 1
        ];
        
        // Delete associated Faculty_Booking__c records
        List<Faculty_Booking__c> facultyBookings = [
            SELECT Id 
            FROM Faculty_Booking__c 
            WHERE Booked_By__c = :session.Faculty__c
            AND Start_Date_Time__c = :session.Start_Date_Time__c
        ];
        
        if (!facultyBookings.isEmpty()) {
            delete facultyBookings;
            System.debug('Deleted ' + facultyBookings.size() + ' Faculty_Booking__c records');
        }
        
        // Delete associated Facility_Booking__c records
        List<Facility_Booking__c> facilityBookings = [
            SELECT Id 
            FROM Facility_Booking__c 
            WHERE FacilityID__c = :session.Facility__c
            AND Start_Date_and_Time__c = :session.Start_Date_Time__c
        ];
        
        if (!facilityBookings.isEmpty()) {
            delete facilityBookings;
            System.debug('Deleted ' + facilityBookings.size() + ' Facility_Booking__c records');
        }
        
        // Delete the session
        delete session;
        System.debug('Session deleted successfully');
        
        return true;
    } catch (Exception e) {
        System.debug('Exception in deleteSession: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
        System.debug('Stack trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Error deleting session: ' + e.getMessage());
    }
}
    
    /**
 * Get detailed information for a specific session
 * @param sessionId The Id of the session to retrieve
 * @return JSON string containing detailed session information
 */
/**
/**
 * Enhanced version of getSessionDetails method to correctly fetch all session data
 * @param sessionId The Id of the session to retrieve
 * @return JSON string containing detailed session information
 */
@AuraEnabled
public static String getSessionDetails(Id sessionId) {
    try {
        // Query the session with all needed fields and relationships
        Session__c session = [
            SELECT Id, Type_of_Activity__c, 
                   Faculty__c, Facility__c, 
                   Start_Date_Time__c, End_Date_Time__c,
                   Account_Name__c, Course_Offering__c
            FROM Session__c
            WHERE Id = :sessionId
            LIMIT 1
        ];
        
        // Create a map to store session details
        Map<String, Object> sessionDetails = new Map<String, Object>();
        
        // Populate basic session data
        sessionDetails.put('id', session.Id);
        sessionDetails.put('activityType', session.Type_of_Activity__c);
        
        // Format date and time values
        DateTime startDateTime = session.Start_Date_Time__c;
        DateTime endDateTime = session.End_Date_Time__c;
        
        // Handle start date and time
        if (startDateTime != null) {
            Date startDate = startDateTime.date();
            Time startTime = startDateTime.time();
            
            sessionDetails.put('startDate', startDate.year() + '-' + 
                              String.valueOf(startDate.month()).leftPad(2, '0') + '-' + 
                              String.valueOf(startDate.day()).leftPad(2, '0'));
            
            String startHour = String.valueOf(startTime.hour()).leftPad(2, '0');
            String startMinute = String.valueOf(startTime.minute()).leftPad(2, '0');
            sessionDetails.put('startTime', startHour + ':' + startMinute);
        }
        
        // Handle end date and time
        if (endDateTime != null) {
            Date endDate = endDateTime.date();
            Time endTime = endDateTime.time();
            
            sessionDetails.put('endDate', endDate.year() + '-' + 
                           String.valueOf(endDate.month()).leftPad(2, '0') + '-' + 
                           String.valueOf(endDate.day()).leftPad(2, '0'));
            
            String endHour = String.valueOf(endTime.hour()).leftPad(2, '0');
            String endMinute = String.valueOf(endTime.minute()).leftPad(2, '0');
            sessionDetails.put('endTime', endHour + ':' + endMinute);
        }
        
        // Handle faculty - Query faculty details
        if (session.Faculty__c != null) {
            sessionDetails.put('faculty', session.Faculty__c);
            
            List<Contact> faculty = [SELECT Id, Name FROM Contact WHERE Id = :session.Faculty__c LIMIT 1];
            if (!faculty.isEmpty()) {
                sessionDetails.put('facultyLabel', faculty[0].Name);
            }
        }
        
        // Handle facility - Query facility details
        if (session.Facility__c != null) {
            sessionDetails.put('facility', session.Facility__c);
            
            List<hed__Facility__c> facility = [SELECT Id, Name FROM hed__Facility__c WHERE Id = :session.Facility__c LIMIT 1];
            if (!facility.isEmpty()) {
                sessionDetails.put('facilityLabel', facility[0].Name);
            }
        }
        
        // Handle account (academic program)
        if (session.Account_Name__c != null) {
            sessionDetails.put('accountId', session.Account_Name__c);
            
            List<Account> account = [SELECT Id, Name FROM Account WHERE Id = :session.Account_Name__c LIMIT 1];
            if (!account.isEmpty()) {
                sessionDetails.put('accountLabel', account[0].Name);
            }
        }
        
        // Handle subject and course offering
        if (session.Course_Offering__c != null) {
            sessionDetails.put('sectionId', session.Course_Offering__c);
            
            List<hed__Course_Offering__c> courseOffering = [
                SELECT Id, hed__Course__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c
                FROM hed__Course_Offering__c
                WHERE Id = :session.Course_Offering__c
                LIMIT 1
            ];
            
            if (!courseOffering.isEmpty() && courseOffering[0].hed__Course__c != null) {
                sessionDetails.put('subject', courseOffering[0].hed__Course__c);
                sessionDetails.put('subjectLabel', courseOffering[0].hed__Course__r.Name);
                
                if (courseOffering[0].hed__Course__r.hed__Course_ID__c != null) {
                    sessionDetails.put('courseCode', courseOffering[0].hed__Course__r.hed__Course_ID__c);
                }
            }
        }
        
        // Add activity type label
        sessionDetails.put('activityTypeLabel', session.Type_of_Activity__c);
        
        System.debug('Session details: ' + JSON.serialize(sessionDetails));
        return JSON.serialize(sessionDetails);
    } catch (Exception e) {
        System.debug('Exception in getSessionDetails: ' + e.getMessage());
        throw new AuraHandledException('Error getting session details: ' + e.getMessage());
    }
}

    /**
 * Get holidays between two dates
 * @param startDate The start date for the range (yyyy-MM-dd format)
 * @param endDate The end date for the range (yyyy-MM-dd format)
 * @return Map of holiday dates (Date as key) to holiday names (String as value)
 */
@AuraEnabled(cacheable=true)
public static Map<String, String> getHolidays(String startDateStr, String endDateStr) {
    Map<String, String> holidayMap = new Map<String, String>();
    
    try {
        // Parse start and end dates
        Date startDate = Date.valueOf(startDateStr);
        Date endDate = Date.valueOf(endDateStr);
        
        // Query holidays from K42_Holiday__c where:
        // - Holiday start date is less than or equal to the end date of our range AND
        // - Holiday end date is greater than or equal to the start date of our range
        // This captures any holiday that overlaps with our date range
        List<K42_Holiday__c> holidays = [
            SELECT Id, Name, K42_Hol_Start_Date__c, K42_Hol_End_Date__c
            FROM K42_Holiday__c
            WHERE K42_Hol_Start_Date__c <= :endDate AND K42_Hol_End_Date__c >= :startDate
        ];
        
        System.debug('Found ' + holidays.size() + ' holidays between ' + startDateStr + ' and ' + endDateStr);
        
        // Process each holiday and generate all dates within the holiday range
        for (K42_Holiday__c holiday : holidays) {
            if (holiday.K42_Hol_Start_Date__c != null && holiday.K42_Hol_End_Date__c != null) {
                // Get the holiday start and end dates
                Date holidayStart = holiday.K42_Hol_Start_Date__c;
                Date holidayEnd = holiday.K42_Hol_End_Date__c;
                
                // Make sure we're only looking at dates within our search range
                if (holidayStart < startDate) {
                    holidayStart = startDate;
                }
                if (holidayEnd > endDate) {
                    holidayEnd = endDate;
                }
                
                // Add each date in the holiday range to our map
                Date currentDate = holidayStart;
                while (currentDate <= holidayEnd) {
                    // Format as yyyy-MM-dd to match the format used in the component
                    String dateKey = currentDate.year() + '-' + 
                                   String.valueOf(currentDate.month()).leftPad(2, '0') + '-' + 
                                   String.valueOf(currentDate.day()).leftPad(2, '0');
                    
                    holidayMap.put(dateKey, holiday.Name);
                    
                    // Move to next day
                    currentDate = currentDate.addDays(1);
                }
            }
        }
        
        System.debug('Generated ' + holidayMap.size() + ' holiday dates');
    } catch (Exception e) {
        System.debug('Error fetching holidays: ' + e.getMessage());
        throw new AuraHandledException('Error fetching holidays: ' + e.getMessage());
    }
    
    return holidayMap;
}

}