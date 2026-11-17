/**
* @description       : 
* @author            : ChangeMeIn@UserSettingsUnder.SFDoc
* @group             : 
* @last modified on  : 06-14-2024
* @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public class termEnrollmentCtrl {
    
    @auraEnabled
public static ApplicationWrapper fetchRecords(
    String programPlan,
    String termId,
    String sectionName,
    String specialisationId,
    string nextTerm
) {
    ApplicationWrapper appWrapper = new ApplicationWrapper();
    if (nextTerm == null || String.isBlank(nextTerm)) {
        return appWrapper;
    }
    
    List<hed__Course_Enrollment__c> courseEnrollment = [
        SELECT Id, hed__Contact__c, hed__Course_Offering__c, hed__Program_Enrollment__c, 
               hed__Course_Offering__r.hed__Section_ID__c 
        FROM hed__Course_Enrollment__c 
        WHERE hed__Course_Offering__r.hed__Section_ID__c =: sectionName 
        AND RecordType.Name = 'Student'
    ];
    
    Set<Id> programPlanIdSet = new Set<Id>();
    for(hed__Course_Enrollment__c courseSection : courseEnrollment){
        programPlanIdSet.add(courseSection.hed__Contact__c);
    }
    
    Set<Contact> existingEnrollmentContacts = new Set<Contact>();
    for (hed__Program_Enrollment__c pe : [
        SELECT Id, hed__Contact__c,hed__Contact__r.Name,hed__Contact__r.Email,
               hed__Contact__r.Phone ,hed__Contact__r.Registration_Number__c
        FROM hed__Program_Enrollment__c
        WHERE Term__c  =:termId AND hed__Program_Plan__c = :programPlan 
        AND RecordType.Name ='Student' AND Affiliation_Status__c = 'Current' 
        AND hed__Contact__c IN :programPlanIdSet AND Is_Active__c = true
    ]) {
        existingEnrollmentContacts.add(pe.hed__Contact__r);
    }
    
    List<StudentDetail> studentDetails = new List<StudentDetail>();
    for (Contact con : existingEnrollmentContacts) {
        if(con != null){
            StudentDetail student = new StudentDetail();
            student.studentName = con.Name;
            student.studentEmail = con.Email;
            student.studentPhone = con.Phone;
            student.registrationNumber = con.Registration_Number__c;
            student.applicationRecordId = con.Id;
            studentDetails.add(student);
        }
    }
    
    // **UPDATED: Create four separate lists instead of two**
    List<CourseOfferingDetail> majorCO = new List<CourseOfferingDetail>();
    List<CourseOfferingDetail> minorCO = new List<CourseOfferingDetail>();
    List<CourseOfferingDetail> specializationCO = new List<CourseOfferingDetail>();
    List<CourseOfferingDetail> concentrationCO = new List<CourseOfferingDetail>();
    
    Map<Id, String> categoryByCourseId = new Map<Id, String>();
    
    String termQuery =
        'SELECT Id, (SELECT Id, hed__Course__c, Name FROM hed__Course_Offerings__r' +
        (String.isNotBlank(specialisationId)
            ? ' WHERE Course_Specialisation__c = :specialisationId'
            : '') +
        '),(SELECT Id, hed__Course__c, hed__Category__c FROM Plan_Requirements__r)' +
        ' FROM hed__Term__c WHERE Id = :nextTerm';
    
    hed__Term__c term = Database.query(termQuery);
    
    for (hed__Plan_Requirement__c pr : term.Plan_Requirements__r) {
        categoryByCourseId.put(pr.hed__Course__c, pr.hed__Category__c);
    }
    
    // **UPDATED: New categorization logic matching EnrollmentController**
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
    
    // **UPDATED: Return the four new lists**
    appWrapper.studentdetails = studentDetails;
    appWrapper.majorCourseOfferings = majorCO;
    appWrapper.minorCourseOfferings = minorCO;
    appWrapper.specializationCourseOfferings = specializationCO;
    appWrapper.concentrationCourseOfferings = concentrationCO;
    
    return appWrapper;
}

    
    @AuraEnabled
public static void createProgramEnrollments(
    List<String> contactIds,
    String termId,
    String specializationId,
    List<String> courseOfferingIds,
    String prevTerm
) {
    // Retrieve the student record type ID for Contact
    Id contactStudentRecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName()
        .get('Student')
        .getRecordTypeId();
    
    // Retrieve previous program enrollments with their affiliations
    List<hed__Program_Enrollment__c> prevProgEnrollments = [
        SELECT
        Id, hed__Contact__c, hed__Program_Plan__c, hed__Account__c, Program_Specialization__c, Program_Campus_Combination__c,
        hed__Affiliation__c, RecordTypeId, hed__Affiliation__r.hed__Status__c, hed__Affiliation__r.hed__Contact__c, hed__Affiliation__r.hed__Account__c,
        (SELECT Id, Name, hed__Status__c FROM hed__Course_Enrollments__r)
        FROM hed__Program_Enrollment__c
        WHERE hed__Contact__c IN :contactIds AND Term__c = :prevTerm AND Affiliation_Status__c = 'Current'
    ];
    
    if (prevProgEnrollments.isEmpty()) return;
    
    // Update previous program enrollments affiliation status
    List<hed__Course_Enrollment__c> courseEnrollmentToUpdate = new List<hed__Course_Enrollment__c>();
    Map<Id, hed__Affiliation__c> affiliationByContactId = new Map<Id, hed__Affiliation__c>();
    
    // Instead of changing affiliations to 'Former' and creating new ones,
    // just store the existing affiliations to reuse them
    for (hed__Program_Enrollment__c prevProgEnrollment : prevProgEnrollments) {
        if (termId != prevTerm) {
            prevProgEnrollment.Is_Active__c = false;
            for(hed__Course_Enrollment__c ce : prevProgEnrollment.hed__Course_Enrollments__r){
                courseEnrollmentToUpdate.add(new hed__Course_Enrollment__c(Id = ce.Id, hed__Status__c = 'Former'));
            }
        }
        
        // Store the existing affiliation to reuse it
        if (prevProgEnrollment.hed__Affiliation__c != null) {
            affiliationByContactId.put(
                prevProgEnrollment.hed__Contact__c,
                new hed__Affiliation__c(
                    Id = prevProgEnrollment.hed__Affiliation__c,
                    hed__Contact__c = prevProgEnrollment.hed__Contact__c,
                    hed__Status__c = 'Current'  // Keep the status as 'Current'
                )
            );
        }
    }
    
    if (termId != prevTerm) {
        update prevProgEnrollments;
        update courseEnrollmentToUpdate;
    }
    
    // Retrieve the new term record
    hed__Term__c termRecord = [
        SELECT Id, hed__Start_Date__c, hed__End_Date__c 
        FROM hed__Term__c 
        WHERE Id = :termId
    ];
    
    // Retrieve existing program enrollments for the new term
    Map<Id, hed__Program_Enrollment__c> existingProgEnrollmentsMap = new Map<Id, hed__Program_Enrollment__c>();
    for (hed__Program_Enrollment__c pe : [
        SELECT Id, hed__Contact__c, Term__c 
        FROM hed__Program_Enrollment__c 
        WHERE hed__Contact__c IN :contactIds AND Term__c = :termId
    ]) {
        existingProgEnrollmentsMap.put(pe.hed__Contact__c, pe);
    }
    
    List<hed__Program_Enrollment__c> programEnrollmentsToInsert = new List<hed__Program_Enrollment__c>();
    List<hed__Program_Enrollment__c> programEnrollmentsToUpdate = new List<hed__Program_Enrollment__c>();
    Set<Id> processedContacts = new Set<Id>(); // To track processed contacts
    
    for (hed__Program_Enrollment__c prevProgEnrollment : prevProgEnrollments) {
        if (processedContacts.contains(prevProgEnrollment.hed__Contact__c)) {
            // Skip if already processed
            continue;
        }
        processedContacts.add(prevProgEnrollment.hed__Contact__c);
        
        hed__Program_Enrollment__c programEnrollment;
        if (existingProgEnrollmentsMap.containsKey(prevProgEnrollment.hed__Contact__c)) {
            // Existing record: Prepare for update
            programEnrollment = existingProgEnrollmentsMap.get(prevProgEnrollment.hed__Contact__c);
            programEnrollment.hed__Program_Plan__c = prevProgEnrollment.hed__Program_Plan__c;
            programEnrollment.Program_Campus_Combination__c = prevProgEnrollment.Program_Campus_Combination__c;
            programEnrollment.hed__Account__c = prevProgEnrollment.hed__Account__c;
            programEnrollment.hed__Start_Date__c = termRecord.hed__Start_Date__c;
            programEnrollment.hed__End_Date__c = termRecord.hed__End_Date__c;
            
            programEnrollment.Is_Active__c = true;
            programEnrollment.hed__Enrollment_Status__c = 'Active';
            
            if (!String.isBlank(specializationId)) {
                programEnrollment.Program_Specialization__c = specializationId;
            }
            
            // Use the existing affiliation instead of creating a new one
            if (affiliationByContactId.containsKey(prevProgEnrollment.hed__Contact__c)) {
                programEnrollment.hed__Affiliation__c = affiliationByContactId.get(prevProgEnrollment.hed__Contact__c).Id;
            }
            
            // Add to update list
            programEnrollmentsToUpdate.add(programEnrollment);
        } else {
            // New record: Prepare for insert
            programEnrollment = new hed__Program_Enrollment__c(
                Term__c = termId,
                hed__Program_Plan__c = prevProgEnrollment.hed__Program_Plan__c,
                Program_Campus_Combination__c = prevProgEnrollment.Program_Campus_Combination__c,
                hed__Account__c = prevProgEnrollment.hed__Account__c,
                hed__Start_Date__c = termRecord.hed__Start_Date__c,
                hed__End_Date__c = termRecord.hed__End_Date__c,
                Program_Enrollment__c = prevProgEnrollment.Id,
               
                hed__Contact__c = prevProgEnrollment.hed__Contact__c,
                Is_Active__c = true,
                 hed__Enrollment_Status__c = 'Active', 
                Program_Specialization__c = !String.isBlank(specializationId) ? specializationId : prevProgEnrollment.Program_Specialization__c
            );
            
            // Use the existing affiliation instead of creating a new one
            if (affiliationByContactId.containsKey(prevProgEnrollment.hed__Contact__c)) {
                programEnrollment.hed__Affiliation__c = affiliationByContactId.get(prevProgEnrollment.hed__Contact__c).Id;
            }
            
            // Add to insert list
            programEnrollmentsToInsert.add(programEnrollment);
        }
    }
    
    // Perform DML operations
    if (!programEnrollmentsToInsert.isEmpty()) {
        insert programEnrollmentsToInsert;
    }
    
    if (!programEnrollmentsToUpdate.isEmpty()) {
        update programEnrollmentsToUpdate;
    }
    
    Map<Id, Id> peIdByContactId = new Map<Id, Id>();
    for (hed__Program_Enrollment__c pe : programEnrollmentsToInsert) {
        peIdByContactId.put(pe.hed__Contact__c, pe.Id);
    }
    for (hed__Program_Enrollment__c pe : programEnrollmentsToUpdate) {
        peIdByContactId.put(pe.hed__Contact__c, pe.Id);
    }
    
    // Retrieve existing course enrollments for the specified course offerings
    List<hed__Course_Enrollment__c> existingCourseEnrollments = [
        SELECT Id, hed__Contact__c, hed__Course_Offering__c 
        FROM hed__Course_Enrollment__c 
        WHERE hed__Contact__c IN :contactIds AND hed__Course_Offering__c IN :courseOfferingIds
    ];
    
    Map<Id, Map<Id, hed__Course_Enrollment__c>> existingCourseEnrollmentsMap = new Map<Id, Map<Id, hed__Course_Enrollment__c>>();
    for (hed__Course_Enrollment__c ce : existingCourseEnrollments) {
        if (!existingCourseEnrollmentsMap.containsKey(ce.hed__Contact__c)) {
            existingCourseEnrollmentsMap.put(ce.hed__Contact__c, new Map<Id, hed__Course_Enrollment__c>());
        }
        existingCourseEnrollmentsMap.get(ce.hed__Contact__c).put(ce.hed__Course_Offering__c, ce);
    }
    
    Id studentRecordTypeId = Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName().get('Student').getRecordTypeId();
    List<hed__Course_Enrollment__c> courseEnrollmentsToUpsert = new List<hed__Course_Enrollment__c>();
    for (Id contactId : peIdByContactId.keySet()) {
        for (String coId : courseOfferingIds) {
            hed__Course_Enrollment__c courseEnrollment;
            if (existingCourseEnrollmentsMap.containsKey(contactId) && existingCourseEnrollmentsMap.get(contactId).containsKey(coId)) {
                courseEnrollment = existingCourseEnrollmentsMap.get(contactId).get(coId);
                courseEnrollment.hed__Program_Enrollment__c = peIdByContactId.get(contactId);
                courseEnrollment.hed__Status__c = 'Current';
                courseEnrollment.Enrollment_Status__c = 'Enrolled';
            } else {
                courseEnrollment = new hed__Course_Enrollment__c(
                    RecordTypeId = studentRecordTypeId,
                    hed__Contact__c = contactId,
                    hed__Program_Enrollment__c = peIdByContactId.get(contactId),
                    hed__Course_Offering__c = coId,
                    hed__Status__c = 'Current',
                    Enrollment_Status__c = 'Enrolled'
                );
            }
            courseEnrollmentsToUpsert.add(courseEnrollment);
        }
    }
    upsert courseEnrollmentsToUpsert;
}
    
    
    
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
    
    // Constructor to initialize lists and avoid null pointer exceptions
    public ApplicationWrapper() {
        this.studentdetails = new List<StudentDetail>();
        this.majorCourseOfferings = new List<CourseOfferingDetail>();
        this.minorCourseOfferings = new List<CourseOfferingDetail>();
        this.specializationCourseOfferings = new List<CourseOfferingDetail>();
        this.concentrationCourseOfferings = new List<CourseOfferingDetail>();
    }
}

    
    public class StudentDetail {
        @AuraEnabled
        public String studentName { get; set; }
        @AuraEnabled
        public String studentEmail { get; set; }
        @AuraEnabled
        public String registrationNumber { get; set; }
        @AuraEnabled
        public String studentPhone { get; set; }
        @AuraEnabled
        public String applicationRecordId { get; set; }
    }
    public class CourseOfferingDetail {
        @AuraEnabled
        public String courseOfferingName { get; set; }
        @AuraEnabled
        public String courseOfferingId { get; set; }
    }

       
}