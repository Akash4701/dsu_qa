@RestResource(urlMapping='/programEnrollments/*')
global with sharing class ProgramEnrollmentAPI {

    @HttpGet
    global static void doGet() {
        RestResponse res = RestContext.response;

        try {
            String programEnrollmentId = RestContext.request.requestURI.substring(RestContext.request.requestURI.lastIndexOf('/') + 1);

            List<hed__Program_Enrollment__c> programEnrollments = [
    SELECT Id, Name,
        (SELECT Id,
                Name,
                hed__Status__c,
                hed__Course_Offering__c,
                hed__Course_Offering__r.Course_Enrollment__c,
                hed__Course_Offering__r.Course_Enrollment__r.Name,
                hed__Course_Offering__r.Program_Pathway__c,
                hed__Course_Offering__r.Program_Pathway__r.Maximum_Credits__c,
                hed__Course_Offering__r.Program_Pathway__r.Name,
                hed__Course_Offering__r.Program_Pathway__r.Specialization_Type__c,
                hed__Course_Offering__r.Course_Pre_requisites__c,
                hed__Course_Offering__r.Interpathway_Capacity_Planner__c,
                hed__Course_Offering__r.Interpathway_Capacity_Planner__r.Capacity__c,
                hed__Course_Offering__r.hed__Course__c,
                hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                hed__Course_Offering__r.hed__Course__r.Name,
                hed__Course_Offering__r.hed__Course__r.Credits__c
         FROM hed__Course_Enrollments__r
        )
    FROM hed__Program_Enrollment__c
    WHERE Id = :programEnrollmentId
    WITH SECURITY_ENFORCED
];


            List<ProgramEnrollmentWrapper> responseList = new List<ProgramEnrollmentWrapper>();

            for (hed__Program_Enrollment__c pe : programEnrollments) {

                ProgramEnrollmentWrapper peWrap = new ProgramEnrollmentWrapper();
                peWrap.programEnrollmentName = pe.Name;
                peWrap.programEnrollmentId = pe.Id;

                for (hed__Course_Enrollment__c ce : pe.hed__Course_Enrollments__r) {
                    hed__Course_Offering__c co = ce.hed__Course_Offering__r;

                    if (co == null) continue;

                    CourseConnectionWrapper coWrap = new CourseConnectionWrapper();
                    coWrap.courseOffId = co.Id;
                    coWrap.courseCode = co.hed__Course__r?.hed__Course_ID__c;
                    coWrap.courseName = co.hed__Course__r?.Name;
                    coWrap.courseCredits = co.hed__Course__r?.Credits__c;
                    coWrap.maximumCredits = co.Program_Pathway__r?.Maximum_Credits__c;
                    coWrap.totalSeats = co.Interpathway_Capacity_Planner__r?.Capacity__c;
                    coWrap.preRequisiteCourses = co.Course_Pre_requisites__c;
                    coWrap.programPathwayName = co.Program_Pathway__r?.Name;
                    coWrap.specializationType = co.Program_Pathway__r?.Specialization_Type__c;
                    coWrap.programPathwayId = co.Program_Pathway__c;
                    coWrap.courseEnrollmentName = co.Course_Enrollment__r.Name;
                    peWrap.courseConnections.add(coWrap);
                }

                responseList.add(peWrap);
            }

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(responseList));

        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
        }
    }

    global class CourseConnectionWrapper {
        public String courseOffId;
        public String courseCode;
        public String courseName;
        public Decimal courseCredits;
        public Decimal maximumCredits;
        public Decimal totalSeats;
        public String preRequisiteCourses;
        public String programPathwayName;
        public String specializationType;
        public String programPathwayId;
        public String courseEnrollmentName;
    }

    global class ProgramEnrollmentWrapper {
        public String programEnrollmentName;
        public String programEnrollmentId;
        public List<CourseConnectionWrapper> courseConnections = new List<CourseConnectionWrapper>();
    }
}