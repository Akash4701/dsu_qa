public with sharing class PathwayEnrollmentController {
    
    @AuraEnabled(cacheable=true)
    public static List<ProgramPathwayWrapper> getProgramPathways(Id programPlanId, Boolean checkForEnrollments) {
        List<ProgramPathwayWrapper> wrappers = new List<ProgramPathwayWrapper>();
        
        // Query Program Pathway records related to the Program Plan
        List<Program_Pathway__c> programPathways = [
            SELECT Id, Name, Program_Plan__c
            FROM Program_Pathway__c 
            WHERE Program_Plan__c = :programPlanId
        ];
        
        if (checkForEnrollments) {
            // Get all Pathway Enrollment records for these Program Pathways
            Set<Id> pathwayIds = new Set<Id>();
            for (Program_Pathway__c pathway : programPathways) {
                pathwayIds.add(pathway.Id);
            }
            
            // Changed: Use List instead of Map to handle multiple enrollments per pathway
            Map<Id, List<Pathway_Enrollment__c>> enrollmentMap = new Map<Id, List<Pathway_Enrollment__c>>();
            if (!pathwayIds.isEmpty()) {
                List<Pathway_Enrollment__c> enrollments = [
                    SELECT Id, Academic_Term__c, Academic_Term__r.Name, Start_Date__c, End_Date__c, 
                           Is_Active__c, No_of_Pathway_Connections__c, 
                           Program_Pathway__c, CreatedDate
                    FROM Pathway_Enrollment__c 
                    WHERE Program_Pathway__c IN :pathwayIds
                    ORDER BY CreatedDate DESC
                ];
                
                // Group enrollments by Program_Pathway__c
                for (Pathway_Enrollment__c enrollment : enrollments) {
                    if (!enrollmentMap.containsKey(enrollment.Program_Pathway__c)) {
                        enrollmentMap.put(enrollment.Program_Pathway__c, new List<Pathway_Enrollment__c>());
                    }
                    enrollmentMap.get(enrollment.Program_Pathway__c).add(enrollment);
                }
            }
            
            // Create wrappers - now handling multiple enrollments per pathway
            for (Program_Pathway__c pathway : programPathways) {
                if (enrollmentMap.containsKey(pathway.Id)) {
                    // Create one wrapper for each enrollment
                    List<Pathway_Enrollment__c> pathwayEnrollments = enrollmentMap.get(pathway.Id);
                    for (Pathway_Enrollment__c enrollment : pathwayEnrollments) {
                        ProgramPathwayWrapper wrapper = new ProgramPathwayWrapper();
                        wrapper.Id = pathway.Id;
                        wrapper.Name = pathway.Name;
                        wrapper.programPlanId = pathway.Program_Plan__c;
                        wrapper.hasEnrollment = true;
                        wrapper.enrollment = enrollment;
                        wrapper.enrollmentId = enrollment.Id; // Add unique identifier
                        wrappers.add(wrapper);
                    }
                } else {
                    // No enrollment exists
                    ProgramPathwayWrapper wrapper = new ProgramPathwayWrapper();
                    wrapper.Id = pathway.Id;
                    wrapper.Name = pathway.Name;
                    wrapper.programPlanId = pathway.Program_Plan__c;
                    wrapper.hasEnrollment = false;
                    wrapper.enrollment = null;
                    wrappers.add(wrapper);
                }
            }
        } else {
            // Just create basic wrappers
            for (Program_Pathway__c pathway : programPathways) {
                ProgramPathwayWrapper wrapper = new ProgramPathwayWrapper();
                wrapper.Id = pathway.Id;
                wrapper.Name = pathway.Name;
                wrapper.programPlanId = pathway.Program_Plan__c;
                wrapper.hasEnrollment = false;
                wrapper.enrollment = null;
                wrappers.add(wrapper);
            }
        }
        
        return wrappers;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Academic_Term__c> getAcademicTerms() {
        return [
            SELECT Id, Name 
            FROM Academic_Term__c 
            ORDER BY Name
        ];
    }
    
    @AuraEnabled
    public static List<Pathway_Enrollment__c> createPathwayEnrollments(List<Pathway_Enrollment__c> enrollments) {
        try {
            // Validate data before insert
            for (Pathway_Enrollment__c enrollment : enrollments) {
                system.debug('This is enrollment '+ enrollment);
                if (enrollment.Start_Date__c == null) {
                    throw new AuraHandledException('Start Date is required.');
                }
                if (enrollment.End_Date__c == null) {
                    throw new AuraHandledException('End Date is required.');
                }
                if (enrollment.Start_Date__c > enrollment.End_Date__c) {
                    throw new AuraHandledException('Start Date cannot be after End Date.');
                }
                if (enrollment.Program_Pathway__c == null) {
                    throw new AuraHandledException('Program Pathway is required.');
                }
            }
            
            insert enrollments;
            return enrollments;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating pathway enrollments: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<Pathway_Enrollment__c> updatePathwayEnrollments(List<Pathway_Enrollment__c> enrollments) {
        try {
            // Validate data before update
            for (Pathway_Enrollment__c enrollment : enrollments) {
                if (enrollment.Id == null) {
                    throw new AuraHandledException('Record ID is required for update.');
                }
                if (enrollment.Start_Date__c != null && enrollment.End_Date__c != null && 
                    enrollment.Start_Date__c > enrollment.End_Date__c) {
                    throw new AuraHandledException('Start Date cannot be after End Date.');
                }
            }
            
            // Ensure we're only updating Start_Date__c and End_Date__c
            List<Pathway_Enrollment__c> updates = new List<Pathway_Enrollment__c>();
            for (Pathway_Enrollment__c enrollment : enrollments) {
                Pathway_Enrollment__c updateRecord = new Pathway_Enrollment__c(
                    Id = enrollment.Id,
                    Start_Date__c = enrollment.Start_Date__c,
                    End_Date__c = enrollment.End_Date__c
                );
                updates.add(updateRecord);
            }
            
            update updates;
            return updates;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating pathway enrollments: ' + e.getMessage());
        }
    }
    
    // Wrapper class for Program Pathway with enrollment info
    public class ProgramPathwayWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public Id programPlanId;
        @AuraEnabled public Boolean hasEnrollment;
        @AuraEnabled public Pathway_Enrollment__c enrollment;
        @AuraEnabled public Id enrollmentId; // Add unique identifier for multiple enrollments
        
        public ProgramPathwayWrapper() {
            hasEnrollment = false;
            enrollment = null;
        }
    }
}