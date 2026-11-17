public with sharing class InterpathwayPlannerController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInitialData(Id cemId) {
        try {
            Course_Enrollment_Management__c cem = [
                SELECT Id, Name, Academic_Term__c, Academic_Term__r.Name
                FROM Course_Enrollment_Management__c
                WHERE Id = :cemId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            Map<String, Object> result = new Map<String, Object>();
            result.put('selectedCemId', cem.Id);
            result.put('selectedCemName', cem.Name);
            result.put('selectedTermId', cem.Academic_Term__c);
            result.put('selectedTermName', cem.Academic_Term__r.Name);

            List<hed__Course_Offering__c> courseOfferings = [
                SELECT Id, Name, hed__Course__c, hed__Course__r.Name, hed__Course__r.hed__Course_ID__c,
                       Academic_Term__c, Academic_Term__r.Name,
                       Interpathway_Capacity_Planner__c
                FROM hed__Course_Offering__c
                WHERE Academic_Term__c = :cem.Academic_Term__c
                WITH SECURITY_ENFORCED
            ];

            List<Map<String, Object>> tableData = new List<Map<String, Object>>();
            for (hed__Course_Offering__c co : courseOfferings) {
                if (co.Interpathway_Capacity_Planner__c != null) {
                    continue; // skip those already assigned to ICP
                }

                Map<String, Object> rowData = new Map<String, Object>();
                rowData.put('Id', co.Id);
                rowData.put('Name', co.Name);
                rowData.put('CourseCode', co.hed__Course__r != null ? co.hed__Course__r.hed__Course_ID__c : '');
                rowData.put('CourseName', co.hed__Course__r != null ? co.hed__Course__r.Name : '');
                rowData.put('AcademicTermName', co.Academic_Term__r != null ? co.Academic_Term__r.Name : '');
                rowData.put('hasICP', false);
                rowData.put('Course__c', co.hed__Course__c);
                rowData.put('Academic_Term__c', co.Academic_Term__c);

                tableData.add(rowData);
            }

            result.put('courseOfferings', tableData);
            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createInterpathwayCapacityPlanner(
        List<Id> selectedCourseOfferingIds,
        Id cemId,
        Id academicTermId,
        Decimal capacity
    ) {
        try {
            List<hed__Course_Offering__c> selectedCourseOfferings = [
                SELECT Id, hed__Course__c, Interpathway_Capacity_Planner__c
                FROM hed__Course_Offering__c
                WHERE Id IN :selectedCourseOfferingIds
                WITH SECURITY_ENFORCED
            ];

            List<String> conflicts = new List<String>();
            for (hed__Course_Offering__c co : selectedCourseOfferings) {
                if (co.Interpathway_Capacity_Planner__c != null) {
                    conflicts.add(co.Id);
                }
            }

            if (!conflicts.isEmpty()) {
                return 'Error: One or more Course Offerings already have Interpathway Capacity Planner assigned.';
            }

            String capacityType = selectedCourseOfferings.size() == 1 ? 'Individual Capacity' : 'Combined Capacity';

            Interpathway_Capacity_Planner__c icp = new Interpathway_Capacity_Planner__c();
            icp.Course_Enrollment_Management__c = cemId;
            icp.Academic_Term__c = academicTermId;
            icp.Capacity__c = capacity;
            icp.Capacity_Type__c = capacityType;
            icp.Active__c = true;

            if (selectedCourseOfferings.size() == 1) {
                icp.Course__c = selectedCourseOfferings[0].hed__Course__c;
            }

            if (Schema.sObjectType.Interpathway_Capacity_Planner__c.isCreateable()) {
    insert icp;
    
}

            List<hed__Course_Offering__c> offeringsToUpdate = new List<hed__Course_Offering__c>();
            for (hed__Course_Offering__c co : selectedCourseOfferings) {
                co.Interpathway_Capacity_Planner__c = icp.Id;
                offeringsToUpdate.add(co);
            }

            if (Schema.sObjectType.hed__Course_Offering__c.isUpdateable()) {
        update offeringsToUpdate;
    }

            return 'Success: Created Interpathway Capacity Planner and linked to ' +
                   offeringsToUpdate.size() + ' Course Offering(s).';

        } catch (Exception e) {
            throw new AuraHandledException('Error creating ICP: ' + e.getMessage());
        }
    }
}