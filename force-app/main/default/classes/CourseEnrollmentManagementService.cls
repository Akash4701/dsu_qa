public with sharing class CourseEnrollmentManagementService {

    /**
     * Propagates CEM (Course_Enrollment_Management__c) Id & Academic_Term__c to:
     *  1. hed__Course_Offering__c (matched by Academic_Term__c)
     *  2. Course_Version__c (matched by related hed__Course_Offering__c)
     *
     * Handles:
     *  - after insert (when Academic_Term__c is non-null)
     *  - after update (only when Academic_Term__c actually changes to a new non-null value)
     *
     * NOTE: This code does NOT "undo" the old term’s links if a CEM is moved
     * to another term. If you need to clear / re-point old term records, ask for the
     * “clear old term” variant.
     */
    public static void afterInsertOrTermSet(List<Course_Enrollment_Management__c> newList,
                                            Map<Id, Course_Enrollment_Management__c> oldMap) {

        // Collect term->CEM for newly set or changed terms.
        Map<Id, Id> termIdToCemId = new Map<Id, Id>();

        for (Course_Enrollment_Management__c cem : newList) {
            Id newTerm = cem.Academic_Term__c;
            Id oldTerm = (oldMap == null || oldMap.get(cem.Id) == null)
                         ? null
                         : oldMap.get(cem.Id).Academic_Term__c;

            Boolean termChanged = oldMap != null && newTerm != oldTerm;

            // Insert: include if newTerm not null
            // Update: include only if changed and not null
            if ((oldMap == null && newTerm != null) ||
                (oldMap != null && termChanged && newTerm != null)) {

                // Last one wins if multiple CEMs for same term in this batch
                termIdToCemId.put(newTerm, cem.Id);
            }
        }

        if (termIdToCemId.isEmpty()) {
            return;
        }

        // ------------------------------------------------------------------
        // 1) Update hed__Course_Offering__c for those terms
        // ------------------------------------------------------------------
        List<hed__Course_Offering__c> offeringRecords = [
            SELECT Id, Academic_Term__c, Course_Enrollment_Management__c,Course_Version__c
            FROM hed__Course_Offering__c
            WHERE Academic_Term__c IN :termIdToCemId.keySet()
            WITH SECURITY_ENFORCED
        ];

        List<hed__Course_Offering__c> offeringUpdates = new List<hed__Course_Offering__c>();

        // Keep a map offeringId -> cem + term (used for versions)
        Map<Id, Id> mapofferingIdToCemId = new Map<Id, Id>();
        Map<Id, Id> mapofferingIdToTermId = new Map<Id, Id>();
        set<Id> setofferingCvIdToCourseOfferingId = new set<Id>();
        Map<Id, Id> mapofferingCvIdToCemId = new Map<Id, Id>();
        Map<Id, Id> mapofferingCvIdToTermId = new Map<Id, Id>();                                        
        for (hed__Course_Offering__c off : offeringRecords) {
            Id targetCem = termIdToCemId.get(off.Academic_Term__c);
            mapofferingIdToCemId.put(off.Id, targetCem);
            mapofferingIdToTermId.put(off.Id, off.Academic_Term__c);
            setofferingCvIdToCourseOfferingId.add(off.Course_Version__c);
            mapofferingCvIdToCemId.put(off.Course_Version__c,targetCem);
            
            mapofferingCvIdToTermId.put(off.Course_Version__c,off.Academic_Term__c);
            
           
            if (off.Course_Enrollment_Management__c != targetCem) {
                offeringUpdates.add(new hed__Course_Offering__c(
                    Id = off.Id,
                    Course_Enrollment_Management__c = targetCem
                ));
            }
        }

        List<Course_Version__c> versionRecords = new List<Course_Version__c>();

        if (!mapofferingIdToCemId.isEmpty()) {
            versionRecords = [
                SELECT Id,
                       Course_Offering__c,
                       Academic_Term__c,
                       Course_Enrollment_Management__c
                FROM Course_Version__c
                WHERE Id IN :setofferingCvIdToCourseOfferingId
                WITH SECURITY_ENFORCED
            ];
        }

       system.debug('size '+ versionRecords.size());
       system.debug('Course Version Id '+setofferingCvIdToCourseOfferingId);
        List<Course_Version__c> versionUpdates = new List<Course_Version__c>();

        for (Course_Version__c cv : versionRecords) {
            
            Id targetTerm = mapofferingCvIdToTermId.get(cv.Id);
            Id targetCem  = mapofferingCvIdToCemId.get(cv.Id);

            Boolean needs = false;
            Course_Version__c upd = new Course_Version__c(Id = cv.Id);
            upd.Course_Enrollment_Management__c = targetCem;
             upd.Academic_Term__c = targetTerm;
           versionUpdates.add(upd);
            

           
        }

        // ------------------------------------------------------------------
        // 3) Perform DML (offerings first, versions second)
        // ------------------------------------------------------------------
        if (!offeringUpdates.isEmpty()) {
            if (Schema.sObjectType.hed__Course_Offering__c.isUpdateable()) {
        update offeringUpdates;
    } 
        }
        if (!versionUpdates.isEmpty()) {
           if (Schema.sObjectType.Course_Version__c.isUpdateable()) {
        update versionUpdates;
    } 
        }
    }
}