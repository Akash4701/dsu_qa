trigger UpdateCourseOfferingEnrollmentCount on hed__Course_Enrollment__c (after insert, after update, after delete , before insert) {
    
    Set<Id> courseOfferingIds = new Set<Id>();

    // Collect Course Offering IDs from inserted/updated/deleted records
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            for (hed__Course_Enrollment__c ce : Trigger.new) {
                if (ce.hed__Course_Offering__c != null) {
                    courseOfferingIds.add(ce.hed__Course_Offering__c);
                }
            }
        } else if (Trigger.isDelete) {
            for (hed__Course_Enrollment__c ce : Trigger.old) {
                if (ce.hed__Course_Offering__c != null) {
                    courseOfferingIds.add(ce.hed__Course_Offering__c);
                }
            }
        }

        if (!courseOfferingIds.isEmpty()) {
            List<hed__Course_Offering__c> offeringsToUpdate = new List<hed__Course_Offering__c>();
            
            // Query all counts at once using AggregateResult
            Map<Id, Integer> offeringCountsMap = new Map<Id, Integer>();
            
             Id recordTypeId =
  Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByName()
    .get('Student').getRecordTypeId();
            
            for (AggregateResult ar : [
                SELECT hed__Course_Offering__c offeringId, COUNT(Id) enrollmentCount
                FROM hed__Course_Enrollment__c
                WHERE hed__Course_Offering__c IN :courseOfferingIds and RecordTypeId=: recordTypeId
                GROUP BY hed__Course_Offering__c
            ]) {
                Id offeringId = (Id)ar.get('offeringId');
                Integer count = (Integer)ar.get('enrollmentCount');
                offeringCountsMap.put(offeringId, count);
            }

            // Build list of Course Offerings to update
            for (Id offeringId : courseOfferingIds) {
                Integer count = offeringCountsMap.get(offeringId); // Will be null if no enrollments
                offeringsToUpdate.add(new hed__Course_Offering__c(
                    Id = offeringId,
                    Total_Enrolled__c = count != null ? count : 0
                ));
            }

            try {
                update offeringsToUpdate;
            } catch (DmlException e) {
                System.debug('Error updating hed__Course_Offering__c records: ' + e.getMessage());
            }
        }
    }
    if (Trigger.isAfter && Trigger.isInsert) {
        Set<Id> offeringIds = new Set<Id>();
        for (hed__Course_Enrollment__c ce : Trigger.new) {
            if (ce.hed__Course_Offering__c != null) {
                offeringIds.add(ce.hed__Course_Offering__c);
            }
        }
        CourseConnectionHandler.updateRemainingSeats(offeringIds);
    }
    if (Trigger.isBefore && Trigger.isInsert) {
        CourseConnectionHandler.validateSeats(Trigger.new);
        CourseConnectionHandler.preventSameCourseEnrollment(Trigger.new);
    }


}