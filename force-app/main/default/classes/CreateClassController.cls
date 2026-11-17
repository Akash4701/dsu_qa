public with sharing class CreateClassController {

    @AuraEnabled(cacheable=true)
    public static Integer getCourseConnectionCount(Id ipcId) {
        system.debug('IPC ID in courseConnectionCount = '+ipcId);
        system.debug('get courseConnectionCount called');
        if (ipcId == null) return 0;
        List<hed__Course_Offering__c> courseOfferings = [SELECT Id,Name FROM hed__Course_Offering__c 
                                         WHERE Interpathway_Capacity_Planner__c = :ipcId
                                        WITH SECURITY_ENFORCED];
        List<AggregateResult> results = [
            SELECT COUNT(Id) total
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :courseOfferings
             WITH SECURITY_ENFORCED
        ];
         system.debug('Course Offering count '+ courseOfferings);
         system.debug('Course connection Count '+ results);
          
        if (!results.isEmpty()) {
            return (Integer) results[0].get('total');
        }
        return 0;
    }

    @AuraEnabled
    public static void createClassAllocationsAndAssignEnrollments(Id ipcId, Integer numClasses, Integer studentsPerClass) {
        system.debug('createClassAllocationsAndAssignEnrollments called');
        if (ipcId == null || numClasses <= 0 || studentsPerClass <= 0) {
            throw new AuraHandledException('Invalid input.');
        }

        // Step 1: Fetch course enrollments for this IPC
        List<hed__Course_Enrollment__c> enrollments = [
            SELECT Id, hed__Course_Offering__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN (
                SELECT Id
                FROM hed__Course_Offering__c
                WHERE Interpathway_Capacity_Planner__c = :ipcId
            )
            WITH SECURITY_ENFORCED
            ORDER BY CreatedDate ASC
        ];

        Integer totalConnections = enrollments.size();
        Integer totalCapacity = numClasses * studentsPerClass;

        if (totalCapacity < totalConnections) {
            Integer shortage = totalConnections - totalCapacity;
            throw new AuraHandledException('Not enough capacity. You are short by ' + shortage + ' students.');
        }

        // Step 2: Create Class Allocation records
        List<Class_Allocation__c> classAllocations = new List<Class_Allocation__c>();
        for (Integer i = 0; i < numClasses; i++) {
            classAllocations.add(new Class_Allocation__c(
                
                Max_Students__c = studentsPerClass,
                Students_Allocated__c = 0
            ));
        }
        if (Schema.sObjectType.Class_Allocation__c.isCreateable()) {
    insert classAllocations;
    
}

        // Step 3: Assign enrollments to class allocations
        List<hed__Course_Enrollment__c> enrollmentsToUpdate = new List<hed__Course_Enrollment__c>();
        Integer classIndex = 0;
        Integer studentsInCurrentClass = 0;

        for (hed__Course_Enrollment__c enrollment : enrollments) {
            if (studentsInCurrentClass >= studentsPerClass) {
                classIndex++;
                studentsInCurrentClass = 0;
            }

            if (classIndex >= classAllocations.size()) break;

            Class_Allocation__c currentClass = classAllocations[classIndex];

            // Update the enrollment to reference the class
            enrollmentsToUpdate.add(new hed__Course_Enrollment__c(
                Id = enrollment.Id,
                Class_Allocation__c = currentClass.Id
            ));

            // Update the count in memory
            currentClass.Students_Allocated__c++;
            studentsInCurrentClass++;
        }

        // Step 4: Update class allocations and enrollments
        if (Schema.sObjectType.hed__Course_Enrollment__c.isUpdateable()) {
        update enrollmentsToUpdate;
    }
        if (Schema.sObjectType.Class_Allocation__c.isUpdateable()) {
        update classAllocations;
    }
    }
}