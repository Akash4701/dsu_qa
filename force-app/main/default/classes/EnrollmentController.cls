public with sharing class EnrollmentController {
    
   @AuraEnabled
public static Filters getFilterOptions() {
    // Declare sets first
    Set<Id> programIdSet = new Set<Id>();
    Set<Id> programPlanIdSet = new Set<Id>();
    Set<Id> departmentIdSet = new Set<Id>();
    Set<Id> instituteIdSet = new Set<Id>();
    Set<Id> academicTermIdSet = new Set<Id>();

    // Query Terms
    List<hed__Term__c> programTerms = [
        SELECT Id, Name, Program_Plan__c, Program_Plan__r.Name,
               Program_Plan__r.hed__Account__r.Name,
               Program_Plan__r.hed__Account__c,
               Program_Plan__r.hed__Account__r.ParentId,
               Program_Plan__r.hed__Account__r.Parent.Name,
               Program_Plan__r.hed__Account__r.Parent.ParentId,
               Program_Plan__r.hed__Account__r.Parent.Parent.Name,
               Academic_Term__c, Academic_Term__r.Name
        FROM hed__Term__c
        WHERE hed__End_Date__c > TODAY
        WITH SECURITY_ENFORCED
        LIMIT 5000
    ];

    // Query Program Specializations
    Id programSpecializationRecordTypeId = 
        Schema.SObjectType.Account.getRecordTypeInfosByName()
            .get('Program Specialization')
            .getRecordTypeId();

    List<Account> programSpecializations = [
        SELECT Id, Name, ParentId
        FROM Account
        WHERE RecordTypeId = :programSpecializationRecordTypeId
        WITH SECURITY_ENFORCED
    ];

    // Query Academic Terms
    List<Academic_Term__c> academicTerms = [
        SELECT Id, Name
        FROM Academic_Term__c
        WITH SECURITY_ENFORCED
        ORDER BY Name
    ];

    // Prepare wrappers
    List<FilterOption> instituteWrappers = new List<FilterOption>();
    List<FilterOption> departmentWrappers = new List<FilterOption>();
    List<FilterOption> programWrappers = new List<FilterOption>();
    List<FilterOption> programPlanWrappers = new List<FilterOption>();
    List<FilterOption> academicTermWrappers = new List<FilterOption>();
    List<FilterOption> termWrappers = new List<FilterOption>();
    List<FilterOption> programSpecializationWrappers = new List<FilterOption>();

    // Wrap program specializations
    for (Account ac : programSpecializations) {
        FilterOption programSpecialization = new FilterOption();
        programSpecialization.id = ac.Id;
        programSpecialization.name = ac.Name;
        programSpecialization.parentId = ac.ParentId;
        programSpecializationWrappers.add(programSpecialization);
    }

    // Wrap academic terms
    for (Academic_Term__c at : academicTerms) {
        FilterOption academicTerm = new FilterOption();
        academicTerm.id = at.Id;
        academicTerm.name = at.Name;
        academicTermWrappers.add(academicTerm);
    }

    // Process program terms
    for (hed__Term__c term : programTerms) {
        FilterOption termOption = new FilterOption();
        termOption.id = term.Id;
        termOption.name = term.Name;
        termOption.parentId = term.Program_Plan__c;
        termOption.academicTermId = term.Academic_Term__c;
        termWrappers.add(termOption);

        if (!programPlanIdSet.contains(term.Program_Plan__c)) {
            FilterOption programPlan = new FilterOption();
            programPlan.id = term.Program_Plan__c;
            programPlan.name = term.Program_Plan__r.Name;
            programPlan.parentId = term.Program_Plan__r.hed__Account__c;
            programPlanWrappers.add(programPlan);
            programPlanIdSet.add(term.Program_Plan__c);
        }

        Id programId = term.Program_Plan__r.hed__Account__c;
        if (!programIdSet.contains(programId)) {
            FilterOption program = new FilterOption();
            program.id = programId;
            program.Name = term.Program_Plan__r.hed__Account__r.Name;
            program.parentId = term.Program_Plan__r.hed__Account__r.ParentId;
            programWrappers.add(program);
            programIdSet.add(programId);
        }

        Id departmentId = term.Program_Plan__r.hed__Account__r.ParentId;
        if (!departmentIdSet.contains(departmentId)) {
            FilterOption department = new FilterOption();
            department.id = departmentId;
            department.Name = term.Program_Plan__r.hed__Account__r.Parent.Name;
            department.parentId = term.Program_Plan__r.hed__Account__r.Parent.ParentId;
            departmentWrappers.add(department);
            departmentIdSet.add(departmentId);
        }

        Id instituteId = term.Program_Plan__r.hed__Account__r.Parent.ParentId;
        if (!instituteIdSet.contains(instituteId)) {
            FilterOption institute = new FilterOption();
            institute.id = instituteId;
            institute.Name = term.Program_Plan__r.hed__Account__r.Parent.Parent.Name;
            instituteWrappers.add(institute);
            instituteIdSet.add(instituteId);
        }
    }

    // Final filter object
    Filters filter = new Filters();
    filter.programs = programWrappers;
    filter.programSpecializations = programSpecializationWrappers;
    filter.programPlans = programPlanWrappers;
    filter.academicTerms = academicTermWrappers;
    filter.terms = termWrappers;
    filter.departments = departmentWrappers;
    filter.institutes = instituteWrappers;

    return filter;
}

    
@AuraEnabled(cacheable=true)
public static List<FilterOption> getProgramPathwaysByPlan(Id programPlanId) {
    List<FilterOption> pathwayOptions = new List<FilterOption>();
    
    if (String.isNotBlank(programPlanId)) {
        List<Program_Pathway__c> pathways = [
            SELECT Id, Name ,Specialization_Type__c
            FROM Program_Pathway__c 
            WHERE Program_Plan__c = :programPlanId
            WITH SECURITY_ENFORCED
        ];

        for (Program_Pathway__c pp : pathways) {
            FilterOption opt = new FilterOption();
            opt.id = pp.Id;
            opt.name = pp.Name;
            opt.parentId = programPlanId;
            opt.type = pp.Specialization_Type__c;
            pathwayOptions.add(opt);
        }
    }

    return pathwayOptions;
}

    @AuraEnabled
    public static ApplicationWrapper searchApplications(
        String programPlan,
        String termId,
        String specialisationId,
        String studentType
    ) {
        System.debug('Search parameters - Program Plan: ' + programPlan + ', Term: ' + termId +
                    ', Specialization: ' + specialisationId +
                    ', Student Type: ' + studentType);
        
        Set<Id> contactIdsToInclude = new Set<Id>();
        
        // Get all students with applications for this program plan
        Set<Id> allApplicantContactIds = new Set<Id>();
        for (Application__c app : [
            SELECT ContactId__c
            FROM Application__c
            WHERE Program_Plan__c = :programPlan
            AND Status__c = 'Admitted'
            AND ContactId__c != null
            AND Id IN (SELECT Individual_Application__c FROM hed__Affiliation__c
                      WHERE Individual_Application__c != NULL
                      AND Is_DSU_Email_Active__c = True)
            WITH SECURITY_ENFORCED          
        ]) {
            if (app.ContactId__c != null) {
                allApplicantContactIds.add(app.ContactId__c);
            }
        }
        
        System.debug('Found ' + allApplicantContactIds.size() + ' contacts with admitted applications');
        
        // Get existing program enrollments for this program plan
        Map<Id, Set<Id>> contactEnrollmentsByTerm = new Map<Id, Set<Id>>();
        for (hed__Program_Enrollment__c pe : [
            SELECT hed__Contact__c, Term__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Program_Plan__c = :programPlan AND hed__Contact__c IN :allApplicantContactIds
            WITH SECURITY_ENFORCED
        ]) {
            if (!contactEnrollmentsByTerm.containsKey(pe.Term__c)) {
                contactEnrollmentsByTerm.put(pe.Term__c, new Set<Id>());
            }
            contactEnrollmentsByTerm.get(pe.Term__c).add(pe.hed__Contact__c);
        }
        
        System.debug('Found enrollments for terms: ' + contactEnrollmentsByTerm.keySet());
        
        // Logic based on student type
        if (studentType == 'new') {
            // For "new" students: Include all contacts with applications who don't have enrollments in THIS term
            Set<Id> enrolledContactsForThisTerm = contactEnrollmentsByTerm.containsKey(termId)
                ? contactEnrollmentsByTerm.get(termId)
                : new Set<Id>();
            
            System.debug('Found ' + enrolledContactsForThisTerm.size() + ' contacts already enrolled in term ' + termId);
            
            // Include contacts NOT enrolled in this term
            for (Id contactId : allApplicantContactIds) {
                if (!enrolledContactsForThisTerm.contains(contactId)) {
                    contactIdsToInclude.add(contactId);
                }
            }
        }
        else if (studentType == 'existing') {
            // For "existing" students: Include only contacts who have enrollments in THIS term
            Set<Id> enrolledContactsForThisTerm = contactEnrollmentsByTerm.containsKey(termId)
                ? contactEnrollmentsByTerm.get(termId)
                : new Set<Id>();
            
            System.debug('Found ' + enrolledContactsForThisTerm.size() + ' contacts enrolled in term ' + termId);
            contactIdsToInclude.addAll(enrolledContactsForThisTerm);
        }
        
        System.debug('Final set of contacts to include: ' + contactIdsToInclude.size());
        
        if (contactIdsToInclude.isEmpty()) {
            // Return empty results if no contacts qualify
            ApplicationWrapper wrapper = new ApplicationWrapper();
            wrapper.studentdetails = new List<StudentDetail>();
            wrapper.majorCourseOfferings = new List<CourseOfferingDetail>();
            wrapper.minorCourseOfferings = new List<CourseOfferingDetail>();
            wrapper.specializationCourseOfferings = new List<CourseOfferingDetail>();
            wrapper.concentrationCourseOfferings = new List<CourseOfferingDetail>();
            return wrapper;
        }
        
        // Query affiliations (if needed)
        Set<Id> affiliationContactIds = new Set<Id>();
        for (hed__Affiliation__c aff : [
            SELECT hed__Contact__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c IN :contactIdsToInclude
            WITH SECURITY_ENFORCED
        ]) {
            affiliationContactIds.add(aff.hed__Contact__c);
        }
        
        System.debug('Confirmed ' + affiliationContactIds.size() + ' contacts with affiliations');
        
        // No section filtering needed anymore
        Set<Id> filteredContactIds = contactIdsToInclude;
        
        // Get the account ID from the program plan to match affiliations
        String programAccountId = '';
        if (!String.isBlank(programPlan)) {
            List<hed__Program_Plan__c> plans = [SELECT hed__Account__c FROM hed__Program_Plan__c WHERE Id = :programPlan WITH SECURITY_ENFORCED LIMIT 1];
            if (!plans.isEmpty()) {
                programAccountId = plans[0].hed__Account__c;
            }
        }
        
        // Get roll numbers from affiliations
        Map<Id, String> rollNumbersByContact = new Map<Id, String>();
        if (!filteredContactIds.isEmpty() && !String.isBlank(programAccountId)) {
            for (hed__Affiliation__c aff : [
                SELECT hed__Contact__c, Roll_Number__c
                FROM hed__Affiliation__c
                WHERE hed__Contact__c IN :filteredContactIds
                AND hed__Account__c = :programAccountId
                AND Roll_Number__c != null
                WITH SECURITY_ENFORCED
            ]) {
                rollNumbersByContact.put(aff.hed__Contact__c, aff.Roll_Number__c);
            }
        }
        
        // Get Contact details
        List<Contact> contactList = new List<Contact>();
        if (!filteredContactIds.isEmpty()) {
            contactList = [
                SELECT Id, Name, Email, Phone_Number__c
                FROM Contact
                WHERE Id IN :filteredContactIds
                WITH SECURITY_ENFORCED
            ];
        }
        
        System.debug('Retrieved ' + contactList.size() + ' contact records');
        
        // Build Student Details
        List<StudentDetail> studentDetails = new List<StudentDetail>();
        for (Contact con : contactList) {
            // Get roll number from affiliations map, or use empty string if not found
            String rollNumber = rollNumbersByContact.containsKey(con.Id) ?
                rollNumbersByContact.get(con.Id) : '';
            
            studentDetails.add(new StudentDetail(
                con.Name,
                con.Email,
                con.Phone_Number__c,
                con.Id, // Pass contact ID as the record ID
                rollNumber // Use roll number from affiliation instead of Registration_Number__c
            ));
        }
        
        System.debug('Built ' + studentDetails.size() + ' student detail records');
        
        // Query Course Offerings - Updated to remove section filtering
        String termQuery = '';
        if (String.isNotBlank(specialisationId)) {
            termQuery = 
                'SELECT Id, (SELECT Id, hed__Course__c, Name FROM hed__Course_Offerings__r WHERE Course_Specialisation__c = \'' + specialisationId + '\')';
        } else {
            termQuery = 'SELECT Id, (SELECT Id, hed__Course__c, Name FROM hed__Course_Offerings__r)';
        }
        
        termQuery += ', (SELECT Id, hed__Course__c, hed__Category__c FROM Plan_Requirements__r)' +
                    ' FROM hed__Term__c WHERE Id = \'' + termId + '\'';
        
        hed__Term__c term = Database.query(termQuery);
        
        Map<Id, String> categoryByCourseId = new Map<Id, String>();
        for (hed__Plan_Requirement__c pr : term.Plan_Requirements__r) {
            categoryByCourseId.put(pr.hed__Course__c, pr.hed__Category__c);
        }
        
        // **UPDATED SECTION: Create four separate lists instead of two**
        List<CourseOfferingDetail> majorCO = new List<CourseOfferingDetail>();
        List<CourseOfferingDetail> minorCO = new List<CourseOfferingDetail>();
        List<CourseOfferingDetail> specializationCO = new List<CourseOfferingDetail>();
        List<CourseOfferingDetail> concentrationCO = new List<CourseOfferingDetail>();
        
        for (hed__Course_Offering__c co : term.hed__Course_Offerings__r) {
            CourseOfferingDetail cod = new CourseOfferingDetail();
            cod.courseOfferingId = co.Id;
            cod.courseOfferingName = co.Name;
            
            // Only include course offerings that have plan requirements
            if (categoryByCourseId.containsKey(co.hed__Course__c)) {
                String category = categoryByCourseId.get(co.hed__Course__c);
                
                if (category == 'Major') {
                    majorCO.add(cod);
                } else if (category == 'Minor') {
                    minorCO.add(cod);
                } else if (category == 'Specialization') {
                    specializationCO.add(cod);
                } else if (category == 'Concentration') {
                    concentrationCO.add(cod);
                }
                // You can add additional handling for other categories like 'Mandatory', 'Required', 'Elective', 'Optional'
                // by mapping them to the appropriate lists above if needed
            }
        }
        
        // **UPDATED SECTION: Return the four new lists**
        ApplicationWrapper wrapper = new ApplicationWrapper();
        wrapper.studentdetails = studentDetails;
        wrapper.majorCourseOfferings = majorCO;
        wrapper.minorCourseOfferings = minorCO;
        wrapper.specializationCourseOfferings = specializationCO;
        wrapper.concentrationCourseOfferings = concentrationCO;
        
        return wrapper;
    }
    
    @AuraEnabled
    public static void createProgramEnrollments(
        List<String> contactIds,
        String termId,
        String academicTermId,
        String specializationId,
        List<String> courseOfferingIds,
        String programPathwayId
    ) {
        System.debug('Received contactIds: ' + contactIds);
        System.debug('Received termId: ' + termId);
        System.debug('Received academicTermId: ' + academicTermId);
        System.debug('Received specializationId: ' + specializationId);
        System.debug('Received courseOfferingIds: ' + courseOfferingIds);
        
        if (contactIds == null || contactIds.isEmpty()) {
            System.debug('No contactIds provided, returning');
            return;
        }
        
        // Collections
        List<hed__Program_Enrollment__c> programEnrollmentsToInsert = new List<hed__Program_Enrollment__c>();
        List<hed__Course_Enrollment__c> courseEnrollmentsToInsert = new List<hed__Course_Enrollment__c>();
        
        // Record Types
        RecordType studentPrgmEnrollRecordType = [
            SELECT Id FROM RecordType
            WHERE sObjectType = 'hed__Program_Enrollment__c'
            AND DeveloperName = 'Student'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        Id personAccountStudentRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName()
            .get('Student')
            .getRecordTypeId();
        
        System.debug('Using RecordTypeId: ' + studentPrgmEnrollRecordType.Id);
        System.debug('Using personAccountStudentRecordTypeId: ' + personAccountStudentRecordTypeId);
        
        // Get Term information including Program Plan and Academic Term
        hed__Term__c currentTerm = [
            SELECT Id, hed__Start_Date__c, hed__End_Date__c, Program_Plan__c,
                   Program_Plan__r.hed__Account__c, Academic_Term__c
            FROM hed__Term__c
            WHERE Id = :termId
            WITH SECURITY_ENFORCED
        ];
        
        System.debug('Term Data: ' + currentTerm);
        
        String currentProgramPlanId = currentTerm.Program_Plan__c;
        Id currentAccountId = currentTerm.Program_Plan__r.hed__Account__c;
        
        // Use the Academic Term from the Term record if not provided from frontend
        String finalAcademicTermId = academicTermId;
        if (String.isBlank(finalAcademicTermId) && currentTerm.Academic_Term__c != null) {
            finalAcademicTermId = currentTerm.Academic_Term__c;
        }
        
        System.debug('Current Program Plan ID: ' + currentProgramPlanId);
        System.debug('Current Account ID: ' + currentAccountId);
        System.debug('Final Academic Term ID for mapping: ' + finalAcademicTermId);
        
        // Validate Academic Term compatibility if both are provided
        if (String.isNotBlank(academicTermId) && currentTerm.Academic_Term__c != null) {
            if (currentTerm.Academic_Term__c != academicTermId) {
                throw new AuraHandledException('The selected term does not belong to the selected Academic Term. Please select a compatible term.');
            }
        }
        
        if (currentProgramPlanId == null) {
            throw new AuraHandledException('The selected term does not have a program plan. Please contact your administrator.');
        }
        
        // Check if any of these are existing students
        Boolean hasExistingStudents = false;
        Map<Id, List<hed__Program_Enrollment__c>> existingEnrollmentsByContact = new Map<Id, List<hed__Program_Enrollment__c>>();
        
        for (hed__Program_Enrollment__c pe : [
            SELECT Id, hed__Contact__c, Term__c, hed__Program_Plan__c, hed__Account__c,
                   hed__Start_Date__c, hed__End_Date__c, hed__Affiliation__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Contact__c IN :contactIds
            WITH SECURITY_ENFORCED
        ]) {
            if (!existingEnrollmentsByContact.containsKey(pe.hed__Contact__c)) {
                existingEnrollmentsByContact.put(pe.hed__Contact__c, new List<hed__Program_Enrollment__c>());
            }
            existingEnrollmentsByContact.get(pe.hed__Contact__c).add(pe);
            hasExistingStudents = true;
        }
        
        // Get Application information for these contacts
        Map<Id, List<Application__c>> applicationsByContact = new Map<Id, List<Application__c>>();
        List<Application__c> applications = [
            SELECT Id, Program_Plan__c, ContactId__c, Program_Plan__r.hed__Account__c
            FROM Application__c
            WHERE ContactId__c IN :contactIds AND Status__c = 'Admitted'
            WITH SECURITY_ENFORCED
        ];
        
        System.debug('Found Applications: ' + applications.size());
        
        for (Application__c app : applications) {
            if (!applicationsByContact.containsKey(app.ContactId__c)) {
                applicationsByContact.put(app.ContactId__c, new List<Application__c>());
            }
            applicationsByContact.get(app.ContactId__c).add(app);
        }
        
        // Collect account IDs to find existing affiliations
        Set<Id> accountIds = new Set<Id>();
        accountIds.add(currentAccountId); // Add the current account ID
        
        for (Application__c app : applications) {
            if (app.Program_Plan__r.hed__Account__c != null) {
                accountIds.add(app.Program_Plan__r.hed__Account__c);
            }
        }
        
        // Find existing affiliations for these contacts and accounts
        Map<String, hed__Affiliation__c> existingAffiliations = new Map<String, hed__Affiliation__c>();
        for (hed__Affiliation__c aff : [
            SELECT Id, hed__Contact__c, hed__Account__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c IN :contactIds
            AND hed__Account__c IN :accountIds
            WITH SECURITY_ENFORCED
        ]) {
            String key = aff.hed__Contact__c + '-' + aff.hed__Account__c;
            existingAffiliations.put(key, aff);
        }
        
        System.debug('Found existing affiliations: ' + existingAffiliations.size());
        
        // Check for existing program enrollments for this term and program plan
        Map<String, hed__Program_Enrollment__c> existingTermProgramEnrollments = new Map<String, hed__Program_Enrollment__c>();
        for (hed__Program_Enrollment__c pe : [
            SELECT Id, hed__Contact__c, Term__c, hed__Program_Plan__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Contact__c IN :contactIds
            AND Term__c = :termId
            AND hed__Program_Plan__c = :currentProgramPlanId
            WITH SECURITY_ENFORCED
        ]) {
            // Create a composite key
            String key = pe.hed__Contact__c + '-' + pe.Term__c + '-' + pe.hed__Program_Plan__c;
            existingTermProgramEnrollments.put(key, pe);
        }
        
        System.debug('Existing Program Enrollments for this term and program: ' + existingTermProgramEnrollments.size());
        
        // Map to store the program enrollment ID for each contact for THIS specific program plan
        Map<Id, hed__Program_Enrollment__c> contactToPEMap = new Map<Id, hed__Program_Enrollment__c>();
        
        // Process each contact
        for (Id contactId : contactIds) {
            // Check if contact already has a PE for this term and program plan
            String enrollmentKey = contactId + '-' + termId + '-' + currentProgramPlanId;
            hed__Program_Enrollment__c existingPE = existingTermProgramEnrollments.get(enrollmentKey);
            
            if (existingPE != null) {
                System.debug('Contact ' + contactId + ' already has PE for this term and program');
                contactToPEMap.put(contactId, existingPE);
                continue;
            }
            
            // Determine if this is an existing student with previous enrollments
            Boolean isExistingStudent = existingEnrollmentsByContact.containsKey(contactId);
            
            hed__Program_Enrollment__c newPE = new hed__Program_Enrollment__c();
            
            if (isExistingStudent) {
                // For existing students, find if they have a previous enrollment for this SPECIFIC program plan
                List<hed__Program_Enrollment__c> contactEnrollments = existingEnrollmentsByContact.get(contactId);
                hed__Program_Enrollment__c matchingProgramPE = null;
                
                for (hed__Program_Enrollment__c pe : contactEnrollments) {
                    if (pe.hed__Program_Plan__c == currentProgramPlanId) {
                        if (matchingProgramPE == null || pe.hed__Start_Date__c > matchingProgramPE.hed__Start_Date__c) {
                            matchingProgramPE = pe;
                        }
                    }
                }
                
                if (matchingProgramPE != null) {
                    // Use the matching program enrollment as a template
                    newPE.hed__Program_Plan__c = matchingProgramPE.hed__Program_Plan__c;
                    newPE.hed__Account__c = matchingProgramPE.hed__Account__c;
                    newPE.hed__Affiliation__c = matchingProgramPE.hed__Affiliation__c;
                    System.debug('Using matching program enrollment as template');
                } else {
                    // No matching program enrollment, find the application for this program plan
                    Application__c matchingApp = null;
                    if (applicationsByContact.containsKey(contactId)) {
                        for (Application__c app : applicationsByContact.get(contactId)) {
                            if (app.Program_Plan__c == currentProgramPlanId) {
                                matchingApp = app;
                                break;
                            }
                        }
                    }
                    
                    if (matchingApp != null) {
                        newPE.hed__Program_Plan__c = matchingApp.Program_Plan__c;
                        newPE.hed__Account__c = matchingApp.Program_Plan__r.hed__Account__c;
                        
                        // Look for an existing affiliation for this account
                        String affKey = contactId + '-' + matchingApp.Program_Plan__r.hed__Account__c;
                        if (existingAffiliations.containsKey(affKey)) {
                            newPE.hed__Affiliation__c = existingAffiliations.get(affKey).Id;
                        }
                        System.debug('Using matching application as template');
                    } else {
                        // No matching application found, skip this contact
                        System.debug('No matching application found for contact ' + contactId);
                        continue;
                    }
                }
            } else {
                // For new students, find the matching application
                Application__c matchingApp = null;
                if (applicationsByContact.containsKey(contactId)) {
                    for (Application__c app : applicationsByContact.get(contactId)) {
                        if (app.Program_Plan__c == currentProgramPlanId) {
                            matchingApp = app;
                            break;
                        }
                    }
                }
                
                if (matchingApp != null) {
                    newPE.hed__Program_Plan__c = matchingApp.Program_Plan__c;
                    newPE.hed__Account__c = matchingApp.Program_Plan__r.hed__Account__c;
                    
                    // Look for an existing affiliation for this account
                    String affKey = contactId + '-' + matchingApp.Program_Plan__r.hed__Account__c;
                    if (existingAffiliations.containsKey(affKey)) {
                        newPE.hed__Affiliation__c = existingAffiliations.get(affKey).Id;
                    }
                    System.debug('Using application for new student');
                } else {
                    // No matching application found, skip this contact
                    System.debug('No matching application found for new student ' + contactId);
                    continue;
                }
            }
            
            // Set common fields for the program enrollment
            newPE.Term__c = termId;
            newPE.hed__Contact__c = contactId;
            newPE.hed__Start_Date__c = currentTerm.hed__Start_Date__c;
            newPE.hed__End_Date__c = currentTerm.hed__End_Date__c;
            newPE.RecordTypeId = studentPrgmEnrollRecordType.Id;
            newPE.Is_Active__c = true;
            newPE.hed__Enrollment_Status__c = 'Active';
            
            if (String.isNotBlank(specializationId)) {
                newPE.Program_Specialization__c = specializationId;
            }
            
            // Map Academic Term using helper method
            mapAcademicTermToRecord(newPE, finalAcademicTermId, 'hed__Program_Enrollment__c');
            
            programEnrollmentsToInsert.add(newPE);
            System.debug('Created new PE for contact ' + contactId);
        }
        
        System.debug('PEs to insert: ' + programEnrollmentsToInsert.size());
        
        // Insert new program enrollments
        if (!programEnrollmentsToInsert.isEmpty()) {
            if (Schema.sObjectType.hed__Program_Enrollment__c.isCreateable()) {
    insert programEnrollmentsToInsert;
    
}
            System.debug('Inserted Program Enrollments: ' + programEnrollmentsToInsert);
            
            // Update our tracking map with the new program enrollments
            for (hed__Program_Enrollment__c pe : programEnrollmentsToInsert) {
                contactToPEMap.put(pe.hed__Contact__c, pe);
            }
        }
        
        // Check for any missing affiliations and create them if needed
        List<hed__Affiliation__c> affiliationsToInsert = new List<hed__Affiliation__c>();
        List<hed__Program_Enrollment__c> pesWithoutAffiliation = new List<hed__Program_Enrollment__c>();
        
        for (hed__Program_Enrollment__c pe : programEnrollmentsToInsert) {
            if (pe.hed__Affiliation__c == null && pe.hed__Account__c != null) {
                String affKey = pe.hed__Contact__c + '-' + pe.hed__Account__c;
                if (!existingAffiliations.containsKey(affKey)) {
                    // Create a new affiliation
                    hed__Affiliation__c newAff = new hed__Affiliation__c();
                    newAff.hed__Contact__c = pe.hed__Contact__c;
                    newAff.hed__Account__c = pe.hed__Account__c;
                    newAff.hed__Status__c = 'Current';
                    affiliationsToInsert.add(newAff);
                    
                    // Remember this PE for later update
                    pesWithoutAffiliation.add(pe);
                }
            }
        }
        
        // Insert any new affiliations
        Map<String, Id> newAffiliationIds = new Map<String, Id>();
        if (!affiliationsToInsert.isEmpty()) {
            if (Schema.sObjectType.hed__Affiliation__c.isCreateable()) {
    insert affiliationsToInsert;
    
}
            System.debug('Inserted new affiliations: ' + affiliationsToInsert.size());
            
            // Map the new affiliations
            for (hed__Affiliation__c aff : affiliationsToInsert) {
                String key = aff.hed__Contact__c + '-' + aff.hed__Account__c;
                newAffiliationIds.put(key, aff.Id);
            }
            
            // Update PEs with the new affiliations
            List<hed__Program_Enrollment__c> pesWithAffiliationsToUpdate = new List<hed__Program_Enrollment__c>();
            for (hed__Program_Enrollment__c pe : pesWithoutAffiliation) {
                String key = pe.hed__Contact__c + '-' + pe.hed__Account__c;
                if (newAffiliationIds.containsKey(key)) {
                    pe.hed__Affiliation__c = newAffiliationIds.get(key);
                    pesWithAffiliationsToUpdate.add(pe);
                }
            }
            
            if (!pesWithAffiliationsToUpdate.isEmpty()) {
                if (Schema.sObjectType.hed__Program_Enrollment__c.isUpdateable()) {
        update pesWithAffiliationsToUpdate;
    }
                System.debug('Updated PEs with new affiliations: ' + pesWithAffiliationsToUpdate.size());
            }
        }
        
        // Now create Course Enrollments for contacts that have a program enrollment
        Id studentCourseEnrollRecordTypeId = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName()
            .get('Student')
            .getRecordTypeId();
        
        // Get Course Offering details to map Course_Enrollment_Management__c
        Map<Id, hed__Course_Offering__c> courseOfferingMap = new Map<Id, hed__Course_Offering__c>();
        if (!courseOfferingIds.isEmpty()) {
            for (hed__Course_Offering__c co : [
                SELECT Id, Course_Enrollment_Management__c,hed__Course__c,hed__Course__r.Credits__c
                FROM hed__Course_Offering__c
                WHERE Id IN :courseOfferingIds
                WITH SECURITY_ENFORCED
            ]) {
                courseOfferingMap.put(co.Id, co);
            }
        }
        
        System.debug('Course Offering Map Size: ' + courseOfferingMap.size());
        
        // Check existing CE to avoid duplicates
        Set<String> existingCEKeys = new Set<String>();
        for (hed__Course_Enrollment__c ce : [
            SELECT Id, hed__Contact__c, hed__Course_Offering__c, hed__Program_Enrollment__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Contact__c IN :contactIds
            AND hed__Course_Offering__c IN :courseOfferingIds
            WITH SECURITY_ENFORCED
        ]) {
            existingCEKeys.add(ce.hed__Contact__c + '-' + ce.hed__Course_Offering__c + '-' + ce.hed__Program_Enrollment__c);
        }
        
        
        
        // Create course enrollments using the CURRENT TERM's program enrollments
        for (Id contactId : contactToPEMap.keySet()) {
            hed__Program_Enrollment__c pe = contactToPEMap.get(contactId);
            
            for (String coId : courseOfferingIds) {
    String key = contactId + '-' + coId + '-' + pe.Id;
    if (!existingCEKeys.contains(key)) {
        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c();
        ce.RecordTypeId = studentCourseEnrollRecordTypeId;
        ce.hed__Contact__c = contactId;
        ce.hed__Program_Enrollment__c = pe.Id;
        ce.hed__Course_Offering__c = coId;
        ce.hed__Status__c = 'Current';
        ce.Enrollment_Status__c = 'Enrolled';

        if (String.isNotBlank(academicTermId)) {
            ce.Academic_Term__c = academicTermId;
        }
        if (String.isNotBlank(programPathwayId)) {
            ce.Program_Pathway__c = programPathwayId;
        }

        if (courseOfferingMap.containsKey(coId)) {
            hed__Course_Offering__c co = courseOfferingMap.get(coId);

            if (co.Course_Enrollment_Management__c != null) {
                ce.Course_Enrollment_Management__c = co.Course_Enrollment_Management__c;
            }
            if (co.hed__Course__r != null && co.hed__Course__r.Credits__c != null) {
                ce.Credits__c = co.hed__Course__r.Credits__c;
            }
        }

        courseEnrollmentsToInsert.add(ce);
    }
}

        }
        
        
        
        if (!courseEnrollmentsToInsert.isEmpty()) {
            if (Schema.sObjectType.hed__Course_Enrollment__c.isCreateable()) {
    insert courseEnrollmentsToInsert;
    
}
            
        }
        
        // Update Contact record types to Student (if needed)
        List<Contact> contactsToUpdate = new List<Contact>();
        for (Id contactId : contactToPEMap.keySet()) {
            contactsToUpdate.add(new Contact(
                Id = contactId,
                RecordTypeId = personAccountStudentRecordTypeId
            ));
        }
        
        if (!contactsToUpdate.isEmpty()) {
            if (Schema.sObjectType.Contact.isUpdateable()) {
        update contactsToUpdate;
    }
            System.debug('Updated Contact Record Types to Student');
        }
        
        System.debug('Enrollment process completed successfully');
    }
    
    // Helper method to safely map Academic Term to any SObject
    private static void mapAcademicTermToRecord(SObject record, String academicTermId, String objectName) {
        if (String.isBlank(academicTermId)) return;
        
        try {
            Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
            if (objectType != null) {
                Schema.DescribeSObjectResult objectDescribe = objectType.getDescribe();
                Map<String, Schema.SObjectField> objectFields = objectDescribe.fields.getMap();
                
                // Check for common Academic Term field names
                List<String> possibleFieldNames = new List<String>{
                    'Academic_Term__c',
                    'hed__Academic_Term__c',
                    'Academic_Term_ID__c',
                    'Academic_Year__c'
                };
                
                String fieldToUse = null;
                for (String fieldName : possibleFieldNames) {
                    if (objectFields.containsKey(fieldName)) {
                        fieldToUse = fieldName;
                        break;
                    }
                }
                
                if (fieldToUse != null) {
                    record.put(fieldToUse, academicTermId);
                    System.debug('Successfully mapped Academic Term to ' + objectName + '.' + fieldToUse + ': ' + academicTermId);
                } else {
                    System.debug('No Academic Term field found on ' + objectName + ' object. Available fields checked: ' + possibleFieldNames);
                }
            }
        } catch (Exception e) {
            System.debug('Error mapping Academic Term to ' + objectName + ': ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void createFacultyEnrollments(
        List<FacultyEnrollmentDetail> facultyEnrollments,
        String termId,
        String programPlan,
        String program,
        String specializationId,
        String academicTermId
    ) {
        System.debug('Starting faculty enrollment process with input: ' + JSON.serialize(facultyEnrollments));
        System.debug('Academic Term ID: ' + academicTermId);
        
        // Get Academic Term from Term record if not provided
        String finalAcademicTermId = academicTermId;
        if (String.isBlank(finalAcademicTermId)) {
            List<hed__Term__c> termRecords = [SELECT Academic_Term__c FROM hed__Term__c WHERE Id = :termId WITH SECURITY_ENFORCED LIMIT 1];
            if (!termRecords.isEmpty() && termRecords[0].Academic_Term__c != null) {
                finalAcademicTermId = termRecords[0].Academic_Term__c;
            }
        }
        
        System.debug('Final Academic Term ID for faculty mapping: ' + finalAcademicTermId);
        
        // Get FACULTY record type ID
        Id facultyRecordTypeId = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName()
            .get('Faculty')
            .getRecordTypeId();
        
        // Get DEFAULT record type ID
        Id defaultRecordTypeId = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName()
            .get('Default')
            .getRecordTypeId();
        
        System.debug('Faculty Record Type ID: ' + facultyRecordTypeId);
        System.debug('Default Record Type ID: ' + defaultRecordTypeId);
        
        // Get program enrollment record type
        RecordType facultyPrgmEnrollRecordType = [
            SELECT Id FROM RecordType
            WHERE sObjectType = 'hed__Program_Enrollment__c' AND DeveloperName = 'Faculty'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        // Step 1: Collect all faculty IDs and course offering IDs
        Set<Id> facultyIds = new Set<Id>();
        Set<Id> courseOfferingIds = new Set<Id>();
        
        for (FacultyEnrollmentDetail fed : facultyEnrollments) {
            courseOfferingIds.add(fed.courseOfferingId);
            for (FacultyDetail faculty : fed.faculties) {
                facultyIds.add(faculty.facultyId);
            }
        }
        
        System.debug('Processing ' + facultyIds.size() + ' faculty members for ' + courseOfferingIds.size() + ' course offerings');
        
        // Get Course Offering details to map Course_Enrollment_Management__c
        Map<Id, hed__Course_Offering__c> courseOfferingMap = new Map<Id, hed__Course_Offering__c>();
        if (!courseOfferingIds.isEmpty()) {
            for (hed__Course_Offering__c co : [
                SELECT Id, Course_Enrollment_Management__c
                FROM hed__Course_Offering__c
                WHERE Id IN :courseOfferingIds
                WITH SECURITY_ENFORCED
            ]) {
                courseOfferingMap.put(co.Id, co);
            }
        }
        
        System.debug('Faculty Course Offering Map Size: ' + courseOfferingMap.size());
        
        // Step 2: Find ALL existing course enrollments for these contact/course combinations
        List<hed__Course_Enrollment__c> allExistingEnrollments = [
            SELECT Id, hed__Contact__c, hed__Course_Offering__c, hed__Program_Enrollment__c,
                   hed__Program_Enrollment__r.hed__Program_Plan__c, hed__Program_Enrollment__r.Term__c,
                   Is_Active__c, RecordTypeId, RecordType.Name
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :courseOfferingIds
            AND hed__Contact__c IN :facultyIds
            AND RecordTypeId = :facultyRecordTypeId
            WITH SECURITY_ENFORCED
        ];
        
        System.debug('Found ' + allExistingEnrollments.size() + ' existing faculty course enrollments');
        
        // Create a map to track existing enrollments by contact/course/program_plan combo
        // This is crucial - we need to match on program plan as well, not just contact+course
        Map<String, List<hed__Course_Enrollment__c>> existingEnrollmentMap = new Map<String, List<hed__Course_Enrollment__c>>();
        
        for (hed__Course_Enrollment__c ce : allExistingEnrollments) {
            // Include program plan in the key to ensure proper matching by program
            String key = ce.hed__Contact__c + '-' + ce.hed__Course_Offering__c + '-' +
                        (ce.hed__Program_Enrollment__c != null ? ce.hed__Program_Enrollment__r.hed__Program_Plan__c : 'null');
            
            if (!existingEnrollmentMap.containsKey(key)) {
                existingEnrollmentMap.put(key, new List<hed__Course_Enrollment__c>());
            }
            existingEnrollmentMap.get(key).add(ce);
            
            System.debug('Existing enrollment: ' + ce.Id + ', RecordType: ' + ce.RecordType.Name +
                        ', Program Plan: ' + ce.hed__Program_Enrollment__r.hed__Program_Plan__c);
        }
        
        // Also get DEFAULT record types to delete them
        List<hed__Course_Enrollment__c> defaultRecordTypes = [
            SELECT Id
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :courseOfferingIds
            AND hed__Contact__c IN :facultyIds
            AND RecordTypeId = :defaultRecordTypeId
            WITH SECURITY_ENFORCED
        ];
        
        // Step 3: Get or create program enrollments for each faculty member for THIS SPECIFIC program plan
        Map<Id, Id> facultyToProgramEnrollmentMap = new Map<Id, Id>();
        
        // First, get existing program enrollments FOR THIS SPECIFIC PROGRAM PLAN AND TERM
        for (hed__Program_Enrollment__c pe : [
            SELECT Id, hed__Contact__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Contact__c IN :facultyIds
            AND Term__c = :termId
            AND hed__Program_Plan__c = :programPlan
            WITH SECURITY_ENFORCED
        ]) {
            facultyToProgramEnrollmentMap.put(pe.hed__Contact__c, pe.Id);
        }
        
        // Create new program enrollments where needed
        List<hed__Program_Enrollment__c> newProgramEnrollments = new List<hed__Program_Enrollment__c>();
        for (Id facultyId : facultyIds) {
            if (!facultyToProgramEnrollmentMap.containsKey(facultyId)) {
                hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c();
                pe.Term__c = termId;
                pe.hed__Program_Plan__c = programPlan;
                pe.hed__Account__c = program;
                pe.hed__Contact__c = facultyId;
                pe.RecordTypeId = facultyPrgmEnrollRecordType.Id;
                pe.hed__Enrollment_Status__c = 'Active';
                
                if (!String.isBlank(specializationId)) {
                    pe.Program_Specialization__c = specializationId;
                }
                
                // Map Academic Term using helper method
                mapAcademicTermToRecord(pe, finalAcademicTermId, 'hed__Program_Enrollment__c');
                
                newProgramEnrollments.add(pe);
            }
        }
        
        if (!newProgramEnrollments.isEmpty()) {
            if (Schema.sObjectType.hed__Program_Enrollment__c.isCreateable()) {
    insert newProgramEnrollments;
    
}
            System.debug('Created ' + newProgramEnrollments.size() + ' new program enrollments');
            
            // Update our map with newly created enrollments
            for (hed__Program_Enrollment__c pe : newProgramEnrollments) {
                facultyToProgramEnrollmentMap.put(pe.hed__Contact__c, pe.Id);
            }
        }
        
        // Step 4: Prepare records for deletion and insertion
        List<hed__Course_Enrollment__c> courseEnrollmentsToDelete = new List<hed__Course_Enrollment__c>();
        List<hed__Course_Enrollment__c> courseEnrollmentsToUpsert = new List<hed__Course_Enrollment__c>();
        
        // Add all default record types to delete list
        courseEnrollmentsToDelete.addAll(defaultRecordTypes);
        
        // For tracking combinations we will be creating Faculty enrollments for
        Map<Id, Id> primaryFacultyByCourseOffering = new Map<Id, Id>();
        
        // Step 5: Process each faculty enrollment
        for (FacultyEnrollmentDetail fed : facultyEnrollments) {
            for (FacultyDetail faculty : fed.faculties) {
                // Skip if no program enrollment exists (shouldn't happen)
                if (!facultyToProgramEnrollmentMap.containsKey(faculty.facultyId)) {
                    System.debug('Warning: No program enrollment for faculty ' + faculty.facultyId);
                    continue;
                }
                
                Id programEnrollmentId = facultyToProgramEnrollmentMap.get(faculty.facultyId);
                
                if (faculty.isPrimary) {
                    primaryFacultyByCourseOffering.put(fed.courseOfferingId, faculty.facultyId);
                }
                
                // Create the composite key that includes program plan to ensure proper matching
                String key = faculty.facultyId + '-' + fed.courseOfferingId + '-' + programPlan;
                
                // Track whether we found a usable Faculty record type enrollment
                hed__Course_Enrollment__c enrollmentToKeep = null;
                
                // Handle existing enrollments - now matching by program plan as well
                if (existingEnrollmentMap.containsKey(key)) {
                    List<hed__Course_Enrollment__c> existingCEs = existingEnrollmentMap.get(key);
                    
                    // Look for Faculty record type to update
                    if (!existingCEs.isEmpty()) {
                        enrollmentToKeep = existingCEs[0];
                    }
                }
                
                // Create or update the Faculty record type enrollment
                if (enrollmentToKeep != null) {
                    // Update existing Faculty enrollment
                    enrollmentToKeep.hed__Program_Enrollment__c = programEnrollmentId; // Ensure linking to correct program enrollment
                    enrollmentToKeep.Is_Active__c = true;
                    enrollmentToKeep.hed__Primary__c = faculty.isPrimary;
                    enrollmentToKeep.hed__Status__c = 'Current';
                    
                    // Map Course_Enrollment_Management__c from Course Offering
                    if (courseOfferingMap.containsKey(fed.courseOfferingId) && 
                        courseOfferingMap.get(fed.courseOfferingId).Course_Enrollment_Management__c != null) {
                        enrollmentToKeep.Course_Enrollment_Management__c = courseOfferingMap.get(fed.courseOfferingId).Course_Enrollment_Management__c;
                        System.debug('Updated Faculty Course_Enrollment_Management__c: ' + enrollmentToKeep.Course_Enrollment_Management__c);
                    }
                    
                    // Map Academic Term using helper method
                    mapAcademicTermToRecord(enrollmentToKeep, finalAcademicTermId, 'hed__Course_Enrollment__c');
                    
                    courseEnrollmentsToUpsert.add(enrollmentToKeep);
                } else {
                    // Create new Faculty enrollment
                    hed__Course_Enrollment__c newCE = new hed__Course_Enrollment__c();
                    newCE.hed__Contact__c = faculty.facultyId;
                    newCE.hed__Course_Offering__c = fed.courseOfferingId;
                    newCE.hed__Program_Enrollment__c = programEnrollmentId;
                    newCE.Is_Active__c = true;
                    newCE.RecordTypeId = facultyRecordTypeId; // CRITICAL - explicitly set Faculty record type
                    newCE.hed__Primary__c = faculty.isPrimary;
                    newCE.hed__Status__c = 'Current';
                    
                    // Map Course_Enrollment_Management__c from Course Offering
                    if (courseOfferingMap.containsKey(fed.courseOfferingId) && 
                        courseOfferingMap.get(fed.courseOfferingId).Course_Enrollment_Management__c != null) {
                        newCE.Course_Enrollment_Management__c = courseOfferingMap.get(fed.courseOfferingId).Course_Enrollment_Management__c;
                        System.debug('New Faculty Course_Enrollment_Management__c: ' + newCE.Course_Enrollment_Management__c);
                    }
                    
                    // Map Academic Term using helper method
                    mapAcademicTermToRecord(newCE, finalAcademicTermId, 'hed__Course_Enrollment__c');
                    
                    courseEnrollmentsToUpsert.add(newCE);
                }
            }
        }
        
        // Step 6: Execute DML operations with explicit error handling
        Savepoint sp = Database.setSavepoint();
        
        try {
            // Delete unwanted enrollments (Default record types)
            if (!courseEnrollmentsToDelete.isEmpty()) {
                System.debug('Deleting ' + courseEnrollmentsToDelete.size() + ' Default record type course enrollments');
                if (Schema.sObjectType.hed__Course_Enrollment__c.isDeletable()) {
        delete courseEnrollmentsToDelete;
    } 
            }
            
            // Upsert the Faculty record type enrollments
            if (!courseEnrollmentsToUpsert.isEmpty()) {
                System.debug('Upserting ' + courseEnrollmentsToUpsert.size() + ' Faculty record type course enrollments');
                if (Schema.sObjectType.hed__Course_Enrollment__c.isCreateable() || 
    Schema.sObjectType.hed__Course_Enrollment__c.isUpdateable()) {
    upsert courseEnrollmentsToUpsert;
}
            }
            
            // Update primary faculty on course offerings
            if (!primaryFacultyByCourseOffering.isEmpty()) {
                List<hed__Course_Offering__c> courseOfferings = [
                    SELECT Id, hed__Faculty__c
                    FROM hed__Course_Offering__c
                    WHERE Id IN :primaryFacultyByCourseOffering.keySet()
                    WITH SECURITY_ENFORCED
                ];
                
                for (hed__Course_Offering__c co : courseOfferings) {
                    co.hed__Faculty__c = primaryFacultyByCourseOffering.get(co.Id);
                }
                
                if (Schema.sObjectType.hed__Course_Offering__c.isUpdateable()) {
        update courseOfferings;
    }
                System.debug('Updated primary faculty on ' + courseOfferings.size() + ' course offerings');
            }
            
            // Check for any Default record types that might have been created
            List<hed__Course_Enrollment__c> newDefaultEnrollments = [
                SELECT Id
                FROM hed__Course_Enrollment__c
                WHERE hed__Course_Offering__c IN :courseOfferingIds
                AND hed__Contact__c IN :facultyIds
                AND RecordTypeId = :defaultRecordTypeId
                AND CreatedDate > :System.now().addSeconds(-10) // Looking for very recent records
                WITH SECURITY_ENFORCED
            ];
            
            if (!newDefaultEnrollments.isEmpty()) {
                System.debug('Found ' + newDefaultEnrollments.size() + ' new Default record type enrollments - deleting them');
                if (Schema.sObjectType.hed__Course_Enrollment__c.isDeletable()) {
        delete newDefaultEnrollments;
    } 
            }
            
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error in faculty enrollment process: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException('Error in faculty enrollment process: ' + e.getMessage());
        }
        
        System.debug('Faculty enrollment process completed successfully');
        
        // Schedule a future cleanup to catch any default records created after transaction
        cleanupFutureDefaultRecords(facultyIds, courseOfferingIds);
    }
    
    @Future
    public static void cleanupFutureDefaultRecords(Set<Id> facultyIds, Set<Id> courseOfferingIds) {
        // Get DEFAULT record type ID
        Id defaultRecordTypeId = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName()
            .get('Default')
            .getRecordTypeId();
        
        // Find any Default record types created after our transaction
        List<hed__Course_Enrollment__c> defaultRecords = [
            SELECT Id
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :courseOfferingIds
            AND hed__Contact__c IN :facultyIds
            AND RecordTypeId = :defaultRecordTypeId
            WITH SECURITY_ENFORCED
        ];
        
        if (!defaultRecords.isEmpty()) {
            try {
                if (Schema.sObjectType.hed__Course_Enrollment__c.isDeletable()) {
        delete defaultRecords;
    }
                System.debug('Deleted ' + defaultRecords.size() + ' Default record types in future method');
            } catch (Exception e) {
                System.debug('Error deleting Default record types in future: ' + e.getMessage());
            }
        }
    }
    
    @AuraEnabled
    public static CourseOfferAndFacultyWrapper searchSubjects(
        String termId,
        String specialisationId,
        String course
    ) {
        System.debug('termId->' + termId);
        System.debug('specialisationId->' + specialisationId);
        
        // Updated query without section filtering
        String courseOfferingsQuery = 
            'SELECT Id, Name, hed__Faculty__c, ' +
            '(SELECT hed__Contact__c, hed__Primary__c FROM hed__Course_Enrollment__r WHERE RecordType.Name=\'Faculty\' AND Is_Active__c = true) ' +
            'FROM hed__Course_Offering__c ' +
            'WHERE hed__Term__c = \'' + termId + '\' ' +
            (String.isNotBlank(specialisationId) ? 'AND Course_Specialisation__c = \'' + specialisationId + '\' ' : '');
        
        List<hed__Course_Offering__c> allCourseOfferings = Database.query(courseOfferingsQuery);
        
        system.debug('>>>allCourseOfferings'+allCourseOfferings);
        
        // Change from Account to Contact for faculty list
        List<Contact> facultyContacts = [
            SELECT Id, Name
            FROM Contact
            WHERE Record_Type_Name__c = 'Faculty'
            WITH SECURITY_ENFORCED
        ];
        
        List<SelectOption> facultySelectOptions = new List<SelectOption>();
        for (Contact con : facultyContacts) {
            SelectOption option = new SelectOption(con.Name, String.valueOf(con.Id));
            facultySelectOptions.add(option);
        }
        
        Map<Id, List<String>> facultiesByCourseOffering = new Map<Id, List<String>>();
        
        for (hed__Course_Enrollment__c ce : [
            SELECT Id, hed__Contact__c, hed__Contact__r.Name, hed__Course_Offering__c
            FROM hed__Course_Enrollment__c
            WHERE 
                hed__Course_Offering__r.hed__Term__c = :termId
                AND hed__Contact__r.Record_Type_Name__c = 'Faculty'
                AND Is_Active__c = TRUE
            WITH SECURITY_ENFORCED
        ]) {
            if (facultiesByCourseOffering.containsKey(ce.hed__Course_Offering__c)) {
                facultiesByCourseOffering.get(ce.hed__Course_Offering__c)
                    .add(String.valueOf(ce.hed__Contact__c));
            } else {
                facultiesByCourseOffering.put(
                    ce.hed__Course_Offering__c,
                    new List<String>{ String.valueOf(ce.hed__Contact__c) }
                );
            }
        }
        
        System.debug('facultiesByCourseOffering-->' + facultiesByCourseOffering);
        
        List<CourseOfferingDetail> courseOfferings = new List<CourseOfferingDetail>();
        
        for (hed__Course_Offering__c co : allCourseOfferings) {
            CourseOfferingDetail cod = new CourseOfferingDetail();
            cod.courseOfferingId = co.Id;
            cod.courseOfferingName = co.Name;
            
            Map<String, List<String>> selectedFacultiesByType = new Map<String, List<String>>();
            
            List<String> primaryFaculty = new List<String>();
            if (String.isNotBlank(co.hed__Faculty__c)) {
                primaryFaculty.add(co.hed__Faculty__c); // Use Contact ID directly
            }
            
            List<String> supportingFaculties = facultiesByCourseOffering.containsKey(co.Id)
                ? facultiesByCourseOffering.get(co.Id)
                : new List<String>();
            
            System.debug('supportingFaculties==>' + supportingFaculties);
            
            if (!supportingFaculties.isEmpty() && String.isNotBlank(co.hed__Faculty__c)) {
                Integer index = supportingFaculties.indexOf(co.hed__Faculty__c);
                if (index > -1) {
                    supportingFaculties.remove(index);
                }
            }
            
            selectedFacultiesByType.put('primary', primaryFaculty);
            selectedFacultiesByType.put('supporting', supportingFaculties);
            
            cod.selectedFaculties = selectedFacultiesByType;
            courseOfferings.add(cod);
        }
        
        CourseOfferAndFacultyWrapper coursesAndFaculties = new CourseOfferAndFacultyWrapper();
        coursesAndFaculties.courseOfferings = courseOfferings;
        coursesAndFaculties.allFaculties = facultySelectOptions;
        
        return coursesAndFaculties;
    }
    
    // **INNER CLASSES WITH UPDATED ApplicationWrapper**
    
    public class Filters {
        @AuraEnabled
        public List<FilterOption> institutes { get; set; }
        @AuraEnabled
        public List<FilterOption> departments { get; set; }
        @AuraEnabled
        public List<FilterOption> programs { get; set; }
        @AuraEnabled
        public List<FilterOption> programSpecializations { get; set; }
        @AuraEnabled
        public List<FilterOption> programPlans { get; set; }
        @AuraEnabled
        public List<FilterOption> academicTerms { get; set; }
        @AuraEnabled
        public List<FilterOption> terms { get; set; }
        @AuraEnabled
        public List<FilterOption> courses { get; set; }
        @AuraEnabled
        public List<FilterOption> programPathways { get; set; }
    }
    
    public class FilterOption {
        @AuraEnabled
        public String id { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String parentId { get; set; }
        @AuraEnabled
        public String type { get; set; }
        @AuraEnabled
        public String academicTermId { get; set; }
        
        public FilterOption() {
        }
        
        public FilterOption(Account program) {
            this.id = program.id;
            this.name = program.name;
        }
        
        public FilterOption(hed__Term__c term) {
            this.id = term.id;
            this.name = term.name;
            this.parentId = term.Program_Plan__c;
        }
    }
    
    // **UPDATED ApplicationWrapper with four separate course offering lists**
    public class ApplicationWrapper {
        @AuraEnabled
        public List<StudentDetail> studentdetails { get; set; }
        @AuraEnabled 
        public List<CourseOfferingDetail> majorCourseOfferings {get;set;}
        @AuraEnabled 
        public List<CourseOfferingDetail> minorCourseOfferings {get;set;}
        @AuraEnabled 
        public List<CourseOfferingDetail> specializationCourseOfferings {get;set;}
        @AuraEnabled 
        public List<CourseOfferingDetail> concentrationCourseOfferings {get;set;}
    }
    
    public class StudentDetail {
        @AuraEnabled
        public String studentName { get; set; }
        @AuraEnabled
        public String studentEmail { get; set; }
        @AuraEnabled
        public String studentPhone { get; set; }
        @AuraEnabled
        public String applicationRecordId { get; set; }
        @AuraEnabled
        public String studentCode { get; set; }
        
        // Default constructor (required for Aura/LWC)
        public StudentDetail() {}
        
        // Custom constructor
        public StudentDetail(String name, String email, String phone, String appId, String code) {
            this.studentName = name;
            this.studentEmail = email;
            this.studentPhone = phone;
            this.applicationRecordId = appId;
            this.studentCode = code;
        }
    }
    
    public class CourseOfferAndFacultyWrapper {
        @AuraEnabled
        public List<CourseOfferingDetail> courseOfferings { get; set; }
        @AuraEnabled
        public List<SelectOption> allFaculties { get; set; }
    }
    
    public class CourseOfferingDetail {
        @AuraEnabled
        public String courseOfferingName { get; set; }
        @AuraEnabled
        public String courseOfferingId { get; set; }
        @AuraEnabled
        public String courseOffCompId { get; set; }
        @AuraEnabled
        public String primaryFaculty { get; set; }
        @AuraEnabled
        public String supportingFaculty { get; set; }
        @AuraEnabled
        public Map<String, List<String>> selectedFaculties { get; set; }
    }
    
    public class FacultyEnrollmentDetail {
        @AuraEnabled
        public String courseOfferingId { get; set; }
        @AuraEnabled
        public List<FacultyDetail> faculties { get; set; }
    }
    
    public class FacultyDetail {
        @AuraEnabled
        public String facultyId { get; set; }
        @AuraEnabled
        public Boolean isPrimary { get; set; }
    }
    
    public class SelectOption {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String value;
        @AuraEnabled
        public Boolean selected;
        
        public SelectOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}