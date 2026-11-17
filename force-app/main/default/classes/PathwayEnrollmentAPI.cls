@RestResource(urlMapping='/getPathwayEnrollments/*')
global with sharing class PathwayEnrollmentAPI {

    @HttpGet
    global static List<PathwayEnrollmentResponse> getAllPathwayEnrollments() {
        String uri = RestContext.request.requestURI;
        List<String> parts = uri.split('/');
        String programPlanId = parts.size() > 0 ? parts[parts.size()-2] : null; 
        String contactId = parts.size() > 0 ? parts[parts.size()-1] : null;

        if (String.isBlank(programPlanId) || String.isBlank(contactId)) {
            RestContext.response.statusCode = 400;
            throw new AuraHandledException('Program Plan Id and Contact Id must be provided in the URL.');
        }

        // Query all enrollments for that Program Plan
        List<Pathway_Enrollment__c> enrollments = [
            SELECT Id,
                   Academic_Term__c,
                   Academic_Term__r.Name,
                   Start_Date__c,
                   End_Date__c,
                   Is_Active__c,
                   Program_Pathway__c,
                   Program_Pathway__r.Name,
                   Program_Pathway__r.Program_Plan__c,
                   Program_Pathway__r.Specialization_Type__c,
                   No_of_Pathway_Connections__c,
                   (SELECT Id,
                           Status__c,
                           Contact__c,
                           Contact__r.Name,
                           Program_Pathway__c,
                           Program_Pathway__r.Name,
                           Program_Pathway__r.Specialization_Type__c
                    FROM Pathway_Connections__r
                    WHERE Contact__c = :contactId)
            FROM Pathway_Enrollment__c
            WHERE Program_Pathway__r.Program_Plan__c = :programPlanId
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate DESC
        ];

        // Build response
        List<PathwayEnrollmentResponse> responseList = new List<PathwayEnrollmentResponse>();
        for (Pathway_Enrollment__c pem : enrollments) {
            responseList.add(new PathwayEnrollmentResponse(pem, contactId, enrollments));
        }
        return responseList;
    }

    global class PathwayEnrollmentResponse {
        public String PEMid;
        public String academicTermId;
        public String academicTermName;
        public Date startDate;
        public Date endDate;
        public Boolean isActive;
        public String programPathwayId;
        public String programPathwayName;
        public String programPathwayType;
        public Integer noOfPathwayConnections;
        public Boolean isMinorEnrollmentAllowed; 
        public List<PathwayConnectionResponse> pathwayConnections;

        public PathwayEnrollmentResponse(Pathway_Enrollment__c record, String contactId, List<Pathway_Enrollment__c> allEnrollments) {
            this.PEMid = record.Id;
            this.programPathwayId = record.Program_Pathway__c;
            this.programPathwayName = record.Program_Pathway__r != null ? record.Program_Pathway__r.Name : null;
            this.programPathwayType = record.Program_Pathway__r != null ? record.Program_Pathway__r.Specialization_Type__c : null;
            this.academicTermId = record.Academic_Term__c;
            this.academicTermName = record.Academic_Term__r != null ? record.Academic_Term__r.Name : null;
            this.startDate = record.Start_Date__c;
            this.endDate = record.End_Date__c;
            this.isActive = record.Is_Active__c;
            this.noOfPathwayConnections = record.No_of_Pathway_Connections__c != null
                ? Integer.valueOf(record.No_of_Pathway_Connections__c)
                : 0;

            this.pathwayConnections = new List<PathwayConnectionResponse>();
            for (Pathway_Connection__c conn : record.Pathway_Connections__r) {
                this.pathwayConnections.add(new PathwayConnectionResponse(conn));
            }

            // Enrollment logic
            if (this.programPathwayType == 'Major') {
                // Major pathways are always allowed
                this.isMinorEnrollmentAllowed = true;
            } else if (this.programPathwayType == 'Minor') {
                // Check if contact already has a connection to a Major of the same pathway name
                Boolean hasMajorForSamePathway = false;
                for (Pathway_Enrollment__c otherPem : allEnrollments) {
                    if (otherPem.Program_Pathway__r != null 
                        && otherPem.Program_Pathway__r.Name == this.programPathwayName
                        && otherPem.Program_Pathway__r.Specialization_Type__c == 'Major') {
                        
                        for (Pathway_Connection__c conn : otherPem.Pathway_Connections__r) {
                            if (conn.Contact__c == contactId) {
                                hasMajorForSamePathway = true;
                                break;
                            }
                        }
                    }
                    if (hasMajorForSamePathway) break;
                }
                this.isMinorEnrollmentAllowed = !hasMajorForSamePathway;
            } else {
                // Default case for other specialization types
                this.isMinorEnrollmentAllowed = true;
            }
        }
    }

    global class PathwayConnectionResponse {
        public String status;
        public String contactId;
        public String contactName;
        public String programPathwayId;
        public String programPathwayName;

        public PathwayConnectionResponse(Pathway_Connection__c conn) {
            this.status = conn.Status__c;
            this.contactId = conn.Contact__c;
            this.contactName = conn.Contact__r != null ? conn.Contact__r.Name : null;
            this.programPathwayId = conn.Program_Pathway__c;
            this.programPathwayName = conn.Program_Pathway__r != null ? conn.Program_Pathway__r.Name : null;
        }
    }
}