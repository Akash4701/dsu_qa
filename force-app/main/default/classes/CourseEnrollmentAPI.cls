@RestResource(urlMapping='/courseenrollments/*')
global with sharing class CourseEnrollmentAPI {
    
    @HttpGet
    global static void doGet() {
        RestResponse res = RestContext.response;
        
        try {
            // Get URL query parameters
            String termIdStr = RestContext.request.params.get('termId');
            String contactIdStr = RestContext.request.params.get('contactId');
            
            // Validate presence
            if (String.isBlank(termIdStr) || String.isBlank(contactIdStr)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf('Error: Both termId and contactId must be provided as query parameters ?termId=...&contactId=...');
                return;
            }
            
            // Validate IDs
            Id termId;
            Id contactId;
            try {
                termId = (Id) termIdStr;
            } catch (Exception e) {
                throw new AuraHandledException('Invalid Term ID: ' + termIdStr);
            }
            try {
                contactId = (Id) contactIdStr;
            } catch (Exception e) {
                throw new AuraHandledException('Invalid Contact ID: ' + contactIdStr);
            }
            
            List<Pathway_Connection__c> enrolledPathways = [
    SELECT Id, Program_Pathway__c
    FROM Pathway_Connection__c
    WHERE Contact__c = :contactId
    WITH SECURITY_ENFORCED
];

Set<Id> programPathwayIds = new Set<Id>();
for (Pathway_Connection__c conn : enrolledPathways) {
    if (conn.Program_Pathway__c != null) {
        programPathwayIds.add(conn.Program_Pathway__c);
    }
}

List<Program_Pathway__c> allPathways = [
    SELECT Id, Name, Pathway_Master__c, Pathway_Master__r.Name
    FROM Program_Pathway__c
    WITH SECURITY_ENFORCED
];
system.debug('all Pathways '+ allPathways);
List<Program_Pathway__c> eligiblePathways = new List<Program_Pathway__c>();
for (Program_Pathway__c pp : allPathways) {
    if (programPathwayIds.contains(pp.Id) || pp.Name == pp.Pathway_Master__r.Name) {
        eligiblePathways.add(pp);
    }
}

            // Fetch term details
            hed__Term__c term = [
                SELECT Id, Minimum_Credit__c, Maximum_Credit__c
                FROM hed__Term__c 
                WHERE Id = :termId 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            // Fetch all enrolled course offerings for this contact
            Set<Id> enrolledOfferingIds = new Set<Id>();
            
            for (hed__Course_Enrollment__c ce : [
                SELECT hed__Course_Offering__c
                FROM hed__Course_Enrollment__c
                WHERE hed__Contact__c = :contactId
                AND hed__Course_Offering__c != null
                WITH SECURITY_ENFORCED
            ]) {
                enrolledOfferingIds.add(ce.hed__Course_Offering__c);
            }
            
            List<Course_Enrollment__c> enrollments = [
                SELECT Id, Name, Order_of_Priority__c,
                
                (SELECT Id,
                 Course_Pre_requisites__c,
                 Academic_Term__c,
                 Course_Enrollment_Management__c,
                 Interpathway_Capacity_Planner__c,
                 Interpathway_Capacity_Planner__r.Capacity__c,
                 Program_Pathway__c,
                 Program_Pathway__r.Maximum_Credits__c,
                 Program_Pathway__r.Name,
                 Program_Pathway__r.Specialization_Type__c,
                 hed__Course__c,
                 hed__Course__r.Name,
                 hed__Course__r.hed__Course_ID__c,
                 hed__Course__r.Credits__c,
                 hed__Term__c
                 FROM Course_Offerings__r
                 WHERE hed__Term__c = :termId),
                
                (SELECT Id, Name, Minimum_Courses__c, Maximum_Courses__c,Program_Pathway__c,Program_Pathway__r.Specialization_Type__c,
                 (SELECT Id, Course__c, Course__r.Name, Course__r.Credits__c, Course__r.hed__Course_ID__c, 
                  Program_Pathway__c, Program_Pathway__r.Name, Course_Offering__c,Program_Pathway__r.Specialization_Type__c, 
                  Course_Offering__r.Course_Enrollment_Management__c,
                  Course_Offering__r.Interpathway_Capacity_Planner__c,
                  Course_Offering__r.Interpathway_Capacity_Planner__r.Remaining_Seats__c,
                  Course_Offering__r.Course_Pre_requisites__c
                  FROM Pathway_Units__r
                  WHERE Program_Pathway__c IN :eligiblePathways) 
                 FROM Clusters__r
                 WHERE Term__c = :termId)
                
                FROM Course_Enrollment__c
                WITH SECURITY_ENFORCED
                ORDER BY Order_of_Priority__c
            ];
            
            List<CourseEnrollmentWrapper> responseList = new List<CourseEnrollmentWrapper>();
            
            for (Course_Enrollment__c ce : enrollments) {
                CourseEnrollmentWrapper ceWrap = new CourseEnrollmentWrapper();
                ceWrap.courseEnrollmentName = ce.Name;
                ceWrap.courseEnrollmentId = ce.Id;
                
                for (hed__Course_Offering__c co : ce.Course_Offerings__r) {
                    CourseOfferingWrapper coWrap = new CourseOfferingWrapper();
                    coWrap.courseOffId = co.Id;
                    coWrap.courseCode = co.hed__Course__r?.hed__Course_ID__c;
                    coWrap.courseName = co.hed__Course__r?.Name;
                    coWrap.courseCredits = co.hed__Course__r?.Credits__c;
                    coWrap.maximumCredits = co.Program_Pathway__r?.Maximum_Credits__c;
                    coWrap.totalSeats = co.Interpathway_Capacity_Planner__r?.Capacity__c;
                    coWrap.preRequisiteCourses = co.Course_Pre_requisites__c;
                    coWrap.academicTermId = co.Academic_Term__c;
                    coWrap.courseEnrollmentManagementId = co.Course_Enrollment_Management__c;
                    coWrap.programPathwayName = co.Program_Pathway__r?.Name;
                    coWrap.specializationType = co.Program_Pathway__r?.Specialization_Type__c;
                    coWrap.programPathwayId = co.Program_Pathway__c;
                    coWrap.courseTermId = co.hed__Term__c;
                    ceWrap.courseOfferings.add(coWrap);
                }
                
                for (Cluster__c cl : ce.Clusters__r) {
                    ClusterWrapper clWrap = new ClusterWrapper();
                    clWrap.clusterId = cl.Id;
                    clWrap.clusterName = cl.Name;
                    clWrap.minimumCourses = cl.Minimum_Courses__c;
                    clWrap.maximumCourses = cl.Maximum_Courses__c;
                    
                    for (Pathway_Unit__c pu : cl.Pathway_Units__r) {
                        PathwayUnitWrapper puWrap = new PathwayUnitWrapper();
                        puWrap.unitId = pu.Id;
                        puWrap.pathwayType = pu.Program_Pathway__r?.Specialization_Type__c;
                        puWrap.courseId = pu.Course__c;
                        puWrap.courseName = pu.Course__r?.Name;
                        puWrap.courseCredits = pu.Course__r?.Credits__c;
                        puWrap.courseCode = pu.Course__r?.hed__Course_ID__c;
                        puWrap.clusterprogramPathwayName = pu.Program_Pathway__r?.Name;
                        puWrap.courseOfferingId = pu.Course_Offering__c;
                        puWrap.courseEnrollmentManagementID = pu.Course_Offering__r?.Course_Enrollment_Management__c;
                        puWrap.remainingSeats = pu.Course_Offering__r?.Interpathway_Capacity_Planner__r?.Remaining_Seats__c;
                        puWrap.preRequisiteCourses = pu.Course_Offering__r?.Course_Pre_requisites__c;
                        puWrap.enrolled = enrolledOfferingIds.contains(pu.Course_Offering__c);
                        clWrap.pathwayUnits.add(puWrap);
                    }
                    
                    ceWrap.clusters.add(clWrap);
                }
                
                responseList.add(ceWrap);
            }
            
            // Prepare final wrapper
            FinalWrapper finalWrapper = new FinalWrapper();
            finalWrapper.termDetails = new TermWrapper();
            finalWrapper.termDetails.termId = term.Id;
            finalWrapper.termDetails.minimumTermCredits = term.Minimum_Credit__c;
            finalWrapper.termDetails.maximumTermCredits = term.Maximum_Credit__c;
            finalWrapper.courseEnrollments = responseList;
            
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(finalWrapper));
            
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }
    
    global class FinalWrapper {
        public TermWrapper termDetails;
        public List<CourseEnrollmentWrapper> courseEnrollments;
    }
    
    global class TermWrapper {
        public String termId;
        public Decimal minimumTermCredits;
        public Decimal maximumTermCredits;
    }
    
    global class CourseOfferingWrapper {
        public String courseOffId;
        public String courseCode;
        public String courseName;
        public Decimal courseCredits;
        public Decimal maximumCredits;
        public Decimal totalSeats;
        public String preRequisiteCourses;
        public String academicTermId;
        public String courseEnrollmentManagementId;
        public String programPathwayName;
        public String specializationType;
        public String programPathwayId;
        public String courseTermId; 
    }
    
    global class PathwayUnitWrapper {
        public String unitId;
        public String courseId;
        public String courseName;
        public Decimal courseCredits;
        public String courseCode;
        public String clusterprogramPathwayName;
        public String courseOfferingId;
        public String courseEnrollmentManagementID;
        public Decimal remainingSeats;
        public String preRequisiteCourses;
        public Boolean enrolled;
        public String pathwayType;
    }
    
    global class ClusterWrapper {
        public String clusterId;
        public String clusterName;
        public Decimal minimumCourses;
        public Decimal maximumCourses;
        
        public List<PathwayUnitWrapper> pathwayUnits = new List<PathwayUnitWrapper>();
    }
    
    global class CourseEnrollmentWrapper {
        public String courseEnrollmentName;
        public String courseEnrollmentId;
        public List<CourseOfferingWrapper> courseOfferings = new List<CourseOfferingWrapper>();
        public List<ClusterWrapper> clusters = new List<ClusterWrapper>();
    }
    
    
}