public with sharing class CourseConnectionHandler {
 public static void handleCourseConnectionInsert(List<hed__Course_Enrollment__c> connections) {
        List<Subject_Scores__c> scoresToInsert = new List<Subject_Scores__c>();
        for (hed__Course_Enrollment__c connection : connections) {
            // Check if the Course Connection has a Course Offering and a Student
            if (connection.hed__Course_Offering__c != null && connection.hed__Contact__c!= null) {
                // Create a new Subject Score record
                Subject_Scores__c score = new Subject_Scores__c();
                score.Course_Offering__c = connection.hed__Course_Offering__c;
                score.Student_Name__c	 = connection.hed__Contact__c;
                scoresToInsert.add(score);
            }
        }
        if (Schema.sObjectType.Subject_Scores__c.isCreateable()) {
    insert scoresToInsert;
    
}
    }
    public static void validateSeats(List<hed__Course_Enrollment__c> newEnrollments) {
        // Collect Course Offering Ids from new enrollments
        Set<Id> courseOfferingIds = new Set<Id>();
        for (hed__Course_Enrollment__c ce : newEnrollments) {
            if (ce.hed__Course_Offering__c != null) {
                courseOfferingIds.add(ce.hed__Course_Offering__c);
            }
        }

        if (courseOfferingIds.isEmpty()) {
            return; // nothing to check
        }

        // Query Course Offerings with their linked planner and remaining seats
        Map<Id, hed__Course_Offering__c> offeringMap = new Map<Id, hed__Course_Offering__c>(
            [SELECT Id,
                    Interpathway_Capacity_Planner__r.Id,
                    Interpathway_Capacity_Planner__r.Remaining_Seats__c
             FROM hed__Course_Offering__c
             WHERE Id IN :courseOfferingIds]
        );

        // Validate each enrollment
        for (hed__Course_Enrollment__c ce : newEnrollments) {
            hed__Course_Offering__c offering = offeringMap.get(ce.hed__Course_Offering__c);
            if (offering != null && offering.Interpathway_Capacity_Planner__r != null) {
                if (offering.Interpathway_Capacity_Planner__r.Remaining_Seats__c == 0) {
                    ce.addError('No seats remaining in this course. Enrollment not allowed.');
                }
            }
        }
    }
    
    public static void updateRemainingSeats(Set<Id> courseOfferingIds) {
        if (courseOfferingIds.isEmpty()) return;

        // Step 1: Query offerings and planners
        List<hed__Course_Offering__c> offerings = [
            SELECT Id, Total_Enrolled__c,
                   Interpathway_Capacity_Planner__c,
                   Interpathway_Capacity_Planner__r.Capacity__c,
                   Interpathway_Capacity_Planner__r.Capacity_Type__c
            FROM hed__Course_Offering__c
            WHERE Id IN :courseOfferingIds
            WITH SECURITY_ENFORCED
        ];

        Set<Id> plannerIds = new Set<Id>();
        Map<Id, hed__Course_Offering__c> offeringMap = new Map<Id, hed__Course_Offering__c>();
        for (hed__Course_Offering__c o : offerings) {
            if (o.Interpathway_Capacity_Planner__c != null) {
                plannerIds.add(o.Interpathway_Capacity_Planner__c);
            }
            offeringMap.put(o.Id, o);
        }

        if (plannerIds.isEmpty()) return;

        // Step 2: Query all planners with their offerings if needed
        Map<Id, Interpathway_Capacity_Planner__c> planners = new Map<Id, Interpathway_Capacity_Planner__c>(
            [SELECT Id, Capacity__c, Capacity_Type__c,
                    (SELECT Id, Total_Enrolled__c FROM Course_Offerings__r)
             FROM Interpathway_Capacity_Planner__c
             WHERE Id IN :plannerIds]
        );

        List<Interpathway_Capacity_Planner__c> plannersToUpdate = new List<Interpathway_Capacity_Planner__c>();

        // Step 3: Calculate remaining seats based on capacity type
        for (Interpathway_Capacity_Planner__c planner : planners.values()) {
            Decimal remainingSeats = 0;
            if (planner.Capacity_Type__c == 'Combined Capacity') {
                // SUM across all course offerings under this planner
                Decimal totalEnrolled = 0;
                for (hed__Course_Offering__c o : planner.Course_Offerings__r) {
                    totalEnrolled += (o.Total_Enrolled__c == null ? 0 : o.Total_Enrolled__c);
                }
                remainingSeats = planner.Capacity__c - totalEnrolled;
            } else {
                // Individual capacity → just use the first offering (the trigger ones)
                // (We can safely pick one of the offerings passed in)
                for (hed__Course_Offering__c o : offerings) {
                    if (o.Interpathway_Capacity_Planner__c == planner.Id) {
                        remainingSeats = planner.Capacity__c - (o.Total_Enrolled__c == null ? 0 : o.Total_Enrolled__c);
                    }
                }
            }

            plannersToUpdate.add(new Interpathway_Capacity_Planner__c(
                Id = planner.Id,
                Remaining_Seats__c = remainingSeats
            ));
        }

        // Step 4: Update planners
        if (!plannersToUpdate.isEmpty()) {
            if (Schema.sObjectType.Interpathway_Capacity_Planner__c.isUpdateable()) {
        update plannersToUpdate;
    } 
        }
    }


    // Default remaining seats when IPC is created
    public static void setDefaultRemainingSeats(List<Interpathway_Capacity_Planner__c> newPlanners) {
        for (Interpathway_Capacity_Planner__c planner : newPlanners) {
            if (planner.Remaining_Seats__c == null && planner.Capacity__c != null) {
                planner.Remaining_Seats__c = planner.Capacity__c;
            }
        }
    }
    public static void preventSameCourseEnrollment(List<hed__Course_Enrollment__c> newEnrollments) {
    if (newEnrollments.isEmpty()) return;
    Set<Id> offeringIds = new Set<Id>();
    Set<Id> programEnrollmentIds = new Set<Id>();
    Map<Id, hed__Course_Enrollment__c> enrollmentMap = new Map<Id, hed__Course_Enrollment__c>();
    for (hed__Course_Enrollment__c ce : newEnrollments) {
        if (ce.hed__Course_Offering__c != null) {
            offeringIds.add(ce.hed__Course_Offering__c);
            enrollmentMap.put(ce.Id, ce);
        }
        if (ce.hed__Program_Enrollment__c != null) {
            programEnrollmentIds.add(ce.hed__Program_Enrollment__c);
        }
    }
    if (offeringIds.isEmpty() || programEnrollmentIds.isEmpty()) return;
    Map<Id, String> offeringToParentCourseMap = new Map<Id, String>();
    for (hed__Course_Offering__c off : [
        SELECT Id, Parent_Course_Code__c
        FROM hed__Course_Offering__c
        WHERE Id IN :offeringIds
        WITH SECURITY_ENFORCED
    ]) {
        offeringToParentCourseMap.put(off.Id, off.Parent_Course_Code__c);
    }
    Set<Id> affiliationIds = new Set<Id>();
    for (hed__Program_Enrollment__c pe : [
        SELECT Id, hed__Affiliation__c
        FROM hed__Program_Enrollment__c
        WHERE Id IN :programEnrollmentIds
        WITH SECURITY_ENFORCED
    ]) {
        if (pe.hed__Affiliation__c != null) {
            affiliationIds.add(pe.hed__Affiliation__c);
        }
    }
    if (affiliationIds.isEmpty()) return;
    Set<Id> allProgramEnrollmentIds = new Set<Id>();
    for (hed__Program_Enrollment__c pe : [
        SELECT Id
        FROM hed__Program_Enrollment__c
        WHERE hed__Affiliation__c IN :affiliationIds
        WITH SECURITY_ENFORCED
    ]) {
        allProgramEnrollmentIds.add(pe.Id);
    }
    if (allProgramEnrollmentIds.isEmpty()) return;
    Map<Id, String> existingEnrollmentsParentCourseCodes = new Map<Id, String>();
    for (hed__Course_Enrollment__c ce : [
        SELECT Id, hed__Course_Offering__r.Parent_Course_Code__c
        FROM hed__Course_Enrollment__c
        WHERE hed__Program_Enrollment__c IN :allProgramEnrollmentIds
        WITH SECURITY_ENFORCED
    ]) {
        if (ce.hed__Course_Offering__r.Parent_Course_Code__c != null) {
            existingEnrollmentsParentCourseCodes.put(
                ce.Id,
                ce.hed__Course_Offering__r.Parent_Course_Code__c
            );
        }
    }
    for (hed__Course_Enrollment__c ce : newEnrollments) {
        if (ce.hed__Course_Offering__c != null) {
            String newParentCourseCode = offeringToParentCourseMap.get(ce.hed__Course_Offering__c);
            if (newParentCourseCode != null && existingEnrollmentsParentCourseCodes.values().contains(newParentCourseCode)) {
                ce.addError('This student is already enrolled in course with Parent Course Code: ' + newParentCourseCode);
            }
        }
    }
}



}