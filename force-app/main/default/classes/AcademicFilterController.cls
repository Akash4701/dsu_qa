public with sharing class AcademicFilterController {

    @AuraEnabled(cacheable=true)
    public static List<Academic_Term__c> getAcademicTerms() {
        return [
            SELECT Id, Name 
            FROM Academic_Term__c 
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<hed__Course__c> getCourses() {
        return [
            SELECT Id, Name 
            FROM hed__Course__c 
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<SObject>> getProgramsAndPlans(Id termId) {
        Map<String, List<SObject>> result = new Map<String, List<SObject>>();
        List<hed__Term__c> termList = [
            SELECT Id, Name,
                   hed__Account__r.Id, hed__Account__r.Name,
                   Program_Plan__r.Id, Program_Plan__r.Name
            FROM hed__Term__c
            WHERE Academic_Term__c = :termId
            WITH SECURITY_ENFORCED
        ];
        Set<Account> programSet = new Set<Account>();
        Set<hed__Program_Plan__c> planSet = new Set<hed__Program_Plan__c>();
        for (hed__Term__c term : termList) {
            if (term.hed__Account__r != null) {
                programSet.add(term.hed__Account__r);
            }
            if (term.Program_Plan__r != null) {
                planSet.add(term.Program_Plan__r);
            }
        }
        result.put('programs', new List<Account>(programSet));
        result.put('plans', new List<hed__Program_Plan__c>(planSet));
        return result;
    }

    @AuraEnabled
    public static Id createProgramPathway(
        Id pathwayMasterId,
        Id programPlanId,
        Id courseId,
        String specializationType,
        Decimal maximumCredits,
        String startingSemester,
        String endingSemester,
        String cgpaRule
    ) {
        Program_Pathway__c pathway = new Program_Pathway__c();
        if (pathwayMasterId != null) pathway.Pathway_Master__c = pathwayMasterId;
        if (programPlanId != null) pathway.Program_Plan__c = programPlanId;
        if (courseId != null) pathway.Course__c = courseId;
        if (specializationType != null) pathway.Specialization_Type__c = specializationType;
        if (maximumCredits != null) pathway.Maximum_Credits__c = maximumCredits;
        if (startingSemester != null) pathway.Starting_Semester__c = startingSemester;
        if (endingSemester != null) pathway.Ending_Semester__c = endingSemester;
        if (cgpaRule != null) pathway.CGPA_Rule__c = cgpaRule;
        if (Schema.sObjectType.Program_Pathway__c.isCreateable()) {
    insert pathway;
    
}
        return pathway.Id;
    }
    
    // Updated method to create cluster with pathway units for specific pathway and course enrollment
    @AuraEnabled
public static Id createClusterForSpecificPathway(
    String name, 
    Integer min, 
    Integer max, 
    Id termId, 
    Id programId,
    List<Id> selectedCourseIds,
    Id specificPathwayId,
    Id programPlanId,
    Id courseEnrollmentId,
    Id semesterTermId,
    String sectionId,
    String startDate,
    String endDate,
    String capacity
) {
    System.debug('=== CLUSTER CREATION START ===');
    System.debug('Name: ' + name);
    System.debug('CourseEnrollmentId: ' + courseEnrollmentId);
    System.debug('Selected Courses: ' + selectedCourseIds);
    System.debug('Specific Pathway: ' + specificPathwayId);
    
    Savepoint savePoint = Database.setSavepoint();
    
    try {
        // Validate inputs
        if (String.isBlank(name) || selectedCourseIds.isEmpty() || specificPathwayId == null || courseEnrollmentId == null) {
            throw new AuraHandledException('Missing required parameters');
        }

        // === DUPLICATE COURSE CHECK ===
List<Cluster__c> existingClusters = [
    SELECT Id, Name, Term__c, Course_Enrollment__c,Course_Enrollment__r.Name,
           (SELECT Id, Course__c, Course__r.Name FROM Pathway_Units__r)
    FROM Cluster__c
    WHERE Term__c = :semesterTermId
    AND Course_Enrollment__c != :courseEnrollmentId
    WITH SECURITY_ENFORCED
];

if (!existingClusters.isEmpty()) {
    Set<Id> selectedCourseSet = new Set<Id>(selectedCourseIds);
    List<String> duplicateMessages = new List<String>();

    for (Cluster__c existingCluster : existingClusters) {
        for (Pathway_Unit__c unit : existingCluster.Pathway_Units__r) {
            if (selectedCourseSet.contains(unit.Course__c)) {
                duplicateMessages.add(
                    '"' + unit.Course__r.Name + 
                    '" (Already present in Course Enrollment: ' + existingCluster.Course_Enrollment__r.Name + ')'
                );
            }
        }
    }

    if (!duplicateMessages.isEmpty()) {
        String errorMessage = 'The following courses have already been offered in the selected semester. '
                            + 'Duplicate courses are not allowed:\n'
                            + String.join(duplicateMessages, ', ');
        throw new AuraHandledException(errorMessage);
    }
}


        // Step 1: Create the cluster
        Cluster__c cluster = new Cluster__c();
        cluster.Name = name;
        cluster.Minimum_Courses__c = min;
        cluster.Maximum_Courses__c = max;
        cluster.Academic_Term__c = termId;
        cluster.Term__c = semesterTermId;
        cluster.Program__c = programId;
        cluster.Program_Plan__c = programPlanId;
        cluster.Course_Enrollment__c = courseEnrollmentId;
if (Schema.sObjectType.Cluster__c.isCreateable()) {
    insert cluster;
    
}
        
        System.debug('Created cluster: ' + cluster.Id);

        // Step 2: Get the specific pathway
        Program_Pathway__c pathway = [
            SELECT Id, Specialization_Type__c, Program_Plan__c
            FROM Program_Pathway__c
            WHERE Id = :specificPathwayId
            LIMIT 1
        ];

        // Step 3: Get all courses in one query
        Map<Id, hed__Course__c> courseMap = new Map<Id, hed__Course__c>([
            SELECT Id, Name, hed__Course_ID__c, Credits__c, hed__Credit_Hours__c
            FROM hed__Course__c
            WHERE Id IN :selectedCourseIds
        ]);

        // Fetch term details
        hed__Term__c term = [
            SELECT Id, Name, hed__Start_Date__c, hed__End_Date__c, Program_Plan__c, 
                   Program_Plan__r.hed__Account__c, Campus__c
            FROM hed__Term__c
            WHERE Id = :semesterTermId	
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // Prepare collections for bulk operations
        List<Pathway_Unit__c> unitsToInsert = new List<Pathway_Unit__c>();
        List<hed__Plan_Requirement__c> requirementsToInsert = new List<hed__Plan_Requirement__c>();
        List<Course_Version__c> courseVersionsToInsert = new List<Course_Version__c>();
        List<hed__Course_Offering__c> offeringsToInsert = new List<hed__Course_Offering__c>();

        Date startDateVal = String.isNotBlank(startDate) ? Date.valueOf(startDate) : term.hed__Start_Date__c;
        Date endDateVal = String.isNotBlank(endDate) ? Date.valueOf(endDate) : term.hed__End_Date__c;
        Decimal cap = String.isNotBlank(capacity) ? Decimal.valueOf(capacity) : null;

        // Create course versions first
        for (Id courseId : selectedCourseIds) {
            hed__Course__c course = courseMap.get(courseId);
            if (course == null) continue;

            Course_Version__c version = new Course_Version__c();
            version.Start_Date__c = startDateVal;
            version.End_Date__c = endDateVal;
            version.Credits__c = course.Credits__c != null ? String.valueOf(course.Credits__c) : '';
            version.Credit_hours__c = course.hed__Credit_Hours__c != null ? String.valueOf(course.hed__Credit_Hours__c) : '';
            version.Account_Name__c = term.Program_Plan__r.hed__Account__c;
            version.Course__c = course.Id;
            version.Term__c = term.Id;
            
            courseVersionsToInsert.add(version);
        }

        if (!courseVersionsToInsert.isEmpty()) {
            if (Schema.sObjectType.Course_Version__c.isCreateable()) {
    insert courseVersionsToInsert;
    
}
            System.debug('Created ' + courseVersionsToInsert.size() + ' course versions');
        }

        // Create Course Offerings and Pathway Units together with proper mapping
        Integer versionIndex = 0;
        for (Id courseId : selectedCourseIds) {
            hed__Course__c course = courseMap.get(courseId);
            if (course == null || versionIndex >= courseVersionsToInsert.size()) continue;
            
            Course_Version__c version = courseVersionsToInsert[versionIndex++];

            // Course Offering
            hed__Course_Offering__c offering = new hed__Course_Offering__c();
            offering.Course_Version__c = version.Id;
            offering.hed__Course__c = course.Id;
            offering.hed__Term__c = term.Id;
            offering.Campus__c = term.Campus__c;
            offering.hed__Section_ID__c = sectionId;
            offering.hed__Start_Date__c = version.Start_Date__c;
            offering.hed__End_Date__c = version.End_Date__c;
            offering.hed__Capacity__c = cap;
            offering.Name = term.Name + ' ' + (course.hed__Course_ID__c != null ? course.hed__Course_ID__c : course.Name);
            offering.Course_Enrollment__c = courseEnrollmentId;
            offering.Program_Pathway__c = pathway.Id;
            offering.Academic_Term__c = termId;
            offeringsToInsert.add(offering);

            // Plan Requirement
            hed__Plan_Requirement__c req = new hed__Plan_Requirement__c();
            req.Name = 'Requirement for ' + course.Name;
            req.hed__Program_Plan__c = (programPlanId != null ? programPlanId : pathway.Program_Plan__c);
            req.hed__Course__c = course.Id;
            req.hed__Category__c = pathway.Specialization_Type__c != null ? pathway.Specialization_Type__c : 'Elective';
            req.Academic_Term__c = termId;
            req.Term__c = semesterTermId;
            req.Course_Enrollment__c = courseEnrollmentId;
            requirementsToInsert.add(req);
        }

        // Insert Course Offerings first
        if (!offeringsToInsert.isEmpty()) {
            if (Schema.sObjectType.hed__Course_Offering__c.isCreateable()) {
    insert offeringsToInsert;
    
}
            System.debug('Created ' + offeringsToInsert.size() + ' course offerings');
        }

        // Now create Pathway Units with Course Offering references
        Integer offeringIndex = 0;
        for (Id courseId : selectedCourseIds) {
            hed__Course__c course = courseMap.get(courseId);
            if (course == null || offeringIndex >= offeringsToInsert.size()) continue;
            
            hed__Course_Offering__c correspondingOffering = offeringsToInsert[offeringIndex++];

            Pathway_Unit__c unit = new Pathway_Unit__c();
            unit.Cluster__c = cluster.Id;
            unit.Course__c = course.Id;
            unit.Course_Offering__c = correspondingOffering.Id;
            unit.Program_Pathway__c = pathway.Id;
            unit.Program_Plan__c = programPlanId;
            unit.Term__c = semesterTermId; 
            unit.Course_Enrollment__c = courseEnrollmentId;
            unitsToInsert.add(unit);
        }
        
        if (!unitsToInsert.isEmpty()) {
            if (Schema.sObjectType.Pathway_Unit__c.isCreateable()) {
    insert unitsToInsert;
    
}
            System.debug('Created ' + unitsToInsert.size() + ' pathway units with course offering references');
        }
        
        if (!requirementsToInsert.isEmpty()) {
            if (Schema.sObjectType.hed__Plan_Requirement__c.isCreateable()) {
    insert requirementsToInsert;
    
}
            System.debug('Created ' + requirementsToInsert.size() + ' plan requirements');
        }

        System.debug('=== CLUSTER CREATION SUCCESS ===');
        return cluster.Id;
        
    } catch (AuraHandledException auraException) {
        Database.rollback(savePoint);
        throw auraException; 
    } catch (Exception e) {
        Database.rollback(savePoint);
        System.debug('=== CLUSTER CREATION ERROR ===');
        System.debug('Error: ' + e.getMessage());
        System.debug('Stack Trace: ' + e.getStackTraceString());
        throw new AuraHandledException('Cluster creation failed: ' + e.getMessage());
    }
}


    
    // Keep the original createCluster method for backward compatibility
    @AuraEnabled
    public static Id createCluster(String name, Integer min, Integer max, Id termId, Id programId) {
        System.debug('Creating cluster with name: ' + name + ', min: ' + min + ', max: ' + max + ', termId: ' + termId + ', programId: ' + programId);
        
        Cluster__c cluster = new Cluster__c();
        cluster.Name = name;
        cluster.Minimum_Courses__c = min;
        cluster.Maximum_Courses__c = max;
        cluster.Academic_Term__c = termId;
        cluster.Program__c = programId;

         if (Schema.sObjectType.Cluster__c.isCreateable()) {
    insert cluster;
    
}
        
        System.debug('Cluster created with ID: ' + cluster.Id);

        List<Program_Pathway__c> pathways = [
            SELECT Id, Course__c, Specialization_Type__c, Program_Plan__c
            FROM Program_Pathway__c
            WHERE Program_Plan__r.hed__Account__c = :programId
                  AND Course__c != null
            WITH SECURITY_ENFORCED
        ];
        
        System.debug('Found ' + pathways.size() + ' pathways for program: ' + programId);

        List<Pathway_Unit__c> unitsToInsert = new List<Pathway_Unit__c>();
        List<hed__Plan_Requirement__c> requirementsToInsert = new List<hed__Plan_Requirement__c>();
        Set<String> existingRequirementKeys = new Set<String>();

        for (Program_Pathway__c p : pathways) {
            Pathway_Unit__c unit = new Pathway_Unit__c();
            unit.Cluster__c = cluster.Id;
            unit.Course__c = p.Course__c;
            unit.Program_Pathway__c = p.Id;
            unitsToInsert.add(unit);
            System.debug('Created pathway unit for pathway: ' + p.Id + ' and course: ' + p.Course__c);

            String uniqueKey = String.valueOf(p.Program_Plan__c) + '-' + String.valueOf(p.Course__c);
            if (!existingRequirementKeys.contains(uniqueKey)) {
                hed__Plan_Requirement__c req = new hed__Plan_Requirement__c();
                req.Name = 'Requirement for ' + String.valueOf(p.Course__c);
                req.hed__Program_Plan__c = p.Program_Plan__c;
                req.hed__Course__c = p.Course__c;
                req.hed__Category__c = p.Specialization_Type__c != null ? p.Specialization_Type__c : 'Elective';
                requirementsToInsert.add(req);
                existingRequirementKeys.add(uniqueKey);
            }
        }

        if (!unitsToInsert.isEmpty()) {
            
             if (Schema.sObjectType.Pathway_Unit__c.isCreateable()) {
    insert unitsToInsert;
    
}
            System.debug('Inserted ' + unitsToInsert.size() + ' pathway units');
        }

        if (!requirementsToInsert.isEmpty()) {
             if (Schema.sObjectType.hed__Plan_Requirement__c.isCreateable()) {
    insert requirementsToInsert;
    
}
            System.debug('Inserted ' + requirementsToInsert.size() + ' plan requirements');
        }

        return cluster.Id;
    }

    @AuraEnabled
    public static Id createPathwayUnit(Id clusterId, Id courseId, Decimal creditHours, Id pathwayId) {
        Pathway_Unit__c unit = new Pathway_Unit__c();
        unit.Cluster__c = clusterId;
        unit.Course__c = courseId;
        unit.Program_Pathway__c = pathwayId;
       if (Schema.sObjectType.Pathway_Unit__c.isCreateable()) {
    insert unit;
    
} 
        return unit.Id;
    }

    @AuraEnabled(cacheable=true)
public static Map<String, List<SObject>> getLookupOptions() {
    Map<String, List<SObject>> result = new Map<String, List<SObject>>();
    result.put('pathwayMasters', [
        SELECT Id, Name FROM Pathway_Master__c ORDER BY Name
    ]);
    result.put('courses', [
        SELECT Id, Name, hed__Course_ID__c, hed__Credit_Hours__c, Credits__c 
        FROM hed__Course__c 
        ORDER BY Name
    ]);
    return result;
}

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues() {
        Map<String, List<Map<String, String>>> result = new Map<String, List<Map<String, String>>>();

        List<Map<String, String>> specializationTypeOptions = new List<Map<String, String>>();
        Schema.DescribeFieldResult specializationTypeField = Program_Pathway__c.Specialization_Type__c.getDescribe();
        for (Schema.PicklistEntry entry : specializationTypeField.getPicklistValues()) {
            if (entry.isActive()) {
                specializationTypeOptions.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }

        List<Map<String, String>> cgpaRuleOptions = new List<Map<String, String>>();
        Schema.DescribeFieldResult cgpaRuleField = Program_Pathway__c.CGPA_Rule__c.getDescribe();
        for (Schema.PicklistEntry entry : cgpaRuleField.getPicklistValues()) {
            if (entry.isActive()) {
                cgpaRuleOptions.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }

        List<Map<String, String>> startingSemesterOptions = new List<Map<String, String>>();
        Schema.DescribeFieldResult startingSemesterField = Program_Pathway__c.Starting_Semester__c.getDescribe();
        for (Schema.PicklistEntry entry : startingSemesterField.getPicklistValues()) {
            if (entry.isActive()) {
                startingSemesterOptions.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }

        List<Map<String, String>> endingSemesterOptions = new List<Map<String, String>>();
        Schema.DescribeFieldResult endingSemesterField = Program_Pathway__c.Ending_Semester__c.getDescribe();
        for (Schema.PicklistEntry entry : endingSemesterField.getPicklistValues()) {
            if (entry.isActive()) {
                endingSemesterOptions.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }

        result.put('specializationTypes', specializationTypeOptions);
        result.put('cgpaRules', cgpaRuleOptions);
        result.put('startingSemesters', startingSemesterOptions);
        result.put('endingSemesters', endingSemesterOptions);

        return result;
    }

    // REMOVED CACHEABLE to ensure fresh data for pathway units
    @AuraEnabled
    public static List<Program_Pathway__c> getProgramPathwaysByType(String specializationType,Id courseEnrollmentId,Id programPlanId) {
        System.debug('Fetching pathways for specialization type: ' + specializationType);
        
        List<Program_Pathway__c> pathways = [
            SELECT Id, Name, Course__r.Name, Program_Plan__r.Name,Starting_Semester__c, Ending_Semester__c,
                   (SELECT Id, Name, Program_Pathway__r.Name, Course__r.Name, Cluster__r.Name 
                    FROM Pathway_Units__r WHERE Course_Enrollment__c = :courseEnrollmentId
                    ORDER BY CreatedDate DESC)
            FROM Program_Pathway__c
            WHERE Specialization_Type__c = :specializationType
            AND Program_Plan__c = :programPlanId
            WITH SECURITY_ENFORCED
            ORDER BY Name
        ];
        
        System.debug('Found ' + pathways.size() + ' pathways');
        for (Program_Pathway__c pathway : pathways) {
            System.debug('Pathway: ' + pathway.Name + ' has ' + pathway.Pathway_Units__r.size() + ' units');
        }
        
        return pathways;
    }
    
    @AuraEnabled(cacheable=true)
public static List<Pathway_Unit__c> getPathwayUnitsByPathwayId(Id pathwayId, Id courseEnrollmentId) {
    String query = 'SELECT Id, Name, Course__r.Name, Cluster__r.Name FROM Pathway_Unit__c WHERE Program_Pathway__c = :pathwayId';
    
    if (courseEnrollmentId != null) {
        query += ' AND Course_Enrollment__c = :courseEnrollmentId';
    }
    
    query += ' ORDER BY CreatedDate DESC';
    
    return Database.query(query);
}
 @AuraEnabled
public static List<Pathway_Unit__c> getPathwayUnitsByPathwayEnrollmentAndTerm(
    Id pathwayId,
    Id courseEnrollmentId,
    Id termId
) {
    // Validate inputs
    if (pathwayId == null || courseEnrollmentId == null || termId == null) {
        return new List<Pathway_Unit__c>();
    }

    return [
        SELECT Id,
               Name,
               Course__c,                   // The actual Course ID
               Course__r.Name,
               Course__r.hed__Course_ID__c, // Optional: Course ID field if you need it
               Cluster__r.Name,
               Cluster__r.Id,
               Cluster__r.Minimum_Courses__c,
               Cluster__r.Maximum_Courses__c,
               Program_Plan__r.hed__Account__c,
               CreatedDate,
               Term__c,
               Course_Enrollment__c,        // Useful for debugging
               Program_Pathway__c           // Useful for debugging
        FROM Pathway_Unit__c
        WHERE Program_Pathway__c = :pathwayId
          AND Course_Enrollment__c = :courseEnrollmentId
          AND Term__c = :termId
        ORDER BY CreatedDate DESC
    ];
}
   
@AuraEnabled
public static List<Pathway_Unit__c> getPathwayUnitsByPathwayAndEnrollment(Id pathwayId, Id courseEnrollmentId) {
    return [
        SELECT Id, 
        Name,
        Course__r.Name,
        Cluster__r.Name,
        Cluster__r.Minimum_Courses__c,
        Cluster__r.Maximum_Courses__c,
        Program_Plan__r.hed__Account__c,
        CreatedDate
        FROM Pathway_Unit__c
        WHERE Program_Pathway__c = :pathwayId
        AND Course_Enrollment__c = :courseEnrollmentId
        WITH SECURITY_ENFORCED
        ORDER BY CreatedDate DESC
    ];
}

    @AuraEnabled
    public static Id createPlanRequirement(String name, Id programPlanId, Id courseId, Decimal minCredits, String requirementType) {
        hed__Plan_Requirement__c req = new hed__Plan_Requirement__c();
        req.Name = name;
        req.hed__Program_Plan__c = programPlanId;
        if (courseId != null) req.hed__Course__c = courseId;
        req.hed__Category__c = requirementType;
        if (Schema.sObjectType.hed__Plan_Requirement__c.isCreateable()) {
    insert req;
   
} 
        return req.Id;
    }
    
@AuraEnabled
public static void updateCluster(
    String clusterId,
    String clusterName,
    Integer minCourses,
    Integer maxCourses,
    List<String> selectedCourseIds
) {
    System.debug('=== UPDATE CLUSTER START ===');
    System.debug('CourseIds ' + selectedCourseIds);

    Savepoint savePoint = Database.setSavepoint();

    try {
        if (String.isBlank(clusterId) || String.isBlank(clusterName)) {
            throw new AuraHandledException('Cluster ID and name are required.');
        }

        // Update cluster details
        Cluster__c cluster = new Cluster__c(
            Id = clusterId,
            Name = clusterName,
            Minimum_Courses__c = minCourses,
            Maximum_Courses__c = maxCourses
        );
        if (Schema.sObjectType.Cluster__c.isUpdateable()) {
        update cluster;
    }

        // Get existing pathway units for this cluster
        List<Pathway_Unit__c> existingUnits = [
            SELECT Id, Course__c, Program_Pathway__c, Program_Plan__c, Term__c, Course_Enrollment__c
            FROM Pathway_Unit__c
            WHERE Cluster__c = :clusterId
        ];

        Set<String> existingCourseIds = new Set<String>();
        Map<String, Pathway_Unit__c> courseToUnitMap = new Map<String, Pathway_Unit__c>();

        for (Pathway_Unit__c unit : existingUnits) {
            existingCourseIds.add(unit.Course__c);
            courseToUnitMap.put(unit.Course__c, unit);
        }

        // Prepare a reference "sample unit"
        Pathway_Unit__c sampleUnit;
        if (!existingUnits.isEmpty()) {
            sampleUnit = existingUnits[0];
        } else {
            // No units exist yet → pull info from the cluster itself
            Cluster__c clusterRef = [
                SELECT Program_Pathway__c, Program_Plan__c, Term__c, Course_Enrollment__c
                FROM Cluster__c
                WHERE Id = :clusterId
                LIMIT 1
            ];

            sampleUnit = new Pathway_Unit__c(
                Program_Pathway__c = clusterRef.Program_Pathway__c,
                Program_Plan__c = clusterRef.Program_Plan__c,
                Term__c = clusterRef.Term__c,
                Course_Enrollment__c = clusterRef.Course_Enrollment__c
            );
        }

        // Determine add/remove sets
        Set<String> newCourseIds = new Set<String>(selectedCourseIds);
        Set<String> coursesToAdd = new Set<String>();
        Set<String> coursesToRemove = new Set<String>();

        for (String courseId : newCourseIds) {
            if (!existingCourseIds.contains(courseId)) {
                coursesToAdd.add(courseId);
            }
        }

        for (String courseId : existingCourseIds) {
            if (!newCourseIds.contains(courseId)) {
                coursesToRemove.add(courseId);
            }
        }

        // Remove old units & requirements
        if (!coursesToRemove.isEmpty()) {
            List<Pathway_Unit__c> unitsToDelete = new List<Pathway_Unit__c>();
            List<hed__Plan_Requirement__c> reqsToDelete = new List<hed__Plan_Requirement__c>();

            for (String courseId : coursesToRemove) {
                Pathway_Unit__c unitToDelete = courseToUnitMap.get(courseId);
                if (unitToDelete != null) {
                    unitsToDelete.add(new Pathway_Unit__c(Id = unitToDelete.Id));
                    reqsToDelete.addAll([
                        SELECT Id
                        FROM hed__Plan_Requirement__c
                        WHERE hed__Course__c = :courseId
                          AND Course_Enrollment__c = :unitToDelete.Course_Enrollment__c
                          AND Term__c = :unitToDelete.Term__c
                          WITH SECURITY_ENFORCED
                    ]);
                }
            }

            if (!unitsToDelete.isEmpty()) {
                if (Schema.sObjectType.Pathway_Unit__c.isDeletable()) {
        delete unitsToDelete;
    } }
            if (!reqsToDelete.isEmpty()) {
                if (Schema.sObjectType.hed__Plan_Requirement__c.isDeletable()) {
        delete reqsToDelete;
    } 
                }
        }

        // Add new units & requirements
        if (!coursesToAdd.isEmpty() && sampleUnit.Program_Pathway__c != null) {
            List<Pathway_Unit__c> unitsToInsert = new List<Pathway_Unit__c>();
            List<hed__Plan_Requirement__c> reqsToInsert = new List<hed__Plan_Requirement__c>();

            Program_Pathway__c pathway = [
                SELECT Id, Specialization_Type__c, Program_Plan__c
                FROM Program_Pathway__c
                WHERE Id = :sampleUnit.Program_Pathway__c
                LIMIT 1
            ];

            for (String courseId : coursesToAdd) {
                // New Pathway Unit
                unitsToInsert.add(new Pathway_Unit__c(
                    Cluster__c = clusterId,
                    Course__c = courseId,
                    Program_Pathway__c = sampleUnit.Program_Pathway__c,
                    Program_Plan__c = sampleUnit.Program_Plan__c,
                    Term__c = sampleUnit.Term__c,
                    Course_Enrollment__c = sampleUnit.Course_Enrollment__c
                ));

                // Related Plan Requirement
                hed__Course__c course = [
                    SELECT Name
                    FROM hed__Course__c
                    WHERE Id = :courseId
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                    
                ];

                reqsToInsert.add(new hed__Plan_Requirement__c(
                    Name = 'Requirement for ' + course.Name,
                    hed__Program_Plan__c = sampleUnit.Program_Plan__c,
                    hed__Course__c = courseId,
                    hed__Category__c = String.isNotBlank(pathway.Specialization_Type__c)
                        ? pathway.Specialization_Type__c
                        : 'Elective',
                    Term__c = sampleUnit.Term__c,
                    Course_Enrollment__c = sampleUnit.Course_Enrollment__c
                ));
            }

            if (!unitsToInsert.isEmpty()) insert unitsToInsert;
            if (!reqsToInsert.isEmpty()) insert reqsToInsert;
        }

        System.debug('=== UPDATE CLUSTER SUCCESS ===');
    } catch (Exception ex) {
        Database.rollback(savePoint);
        System.debug('Stack Trace: ' + ex.getStackTraceString());
        throw new AuraHandledException('Error updating cluster: ' + ex.getMessage());
    }
}
@AuraEnabled
public static void deleteCluster(String clusterId) {
    try {
        if (String.isBlank(clusterId)) {
            throw new AuraHandledException('Cluster ID is required');
        }
        
        // First, delete all related Pathway Units
        List<Pathway_Unit__c> pathwayUnitsToDelete = [
            SELECT Id 
            FROM Pathway_Unit__c 
            WHERE Cluster__c = :clusterId
        ];
        
        if (!pathwayUnitsToDelete.isEmpty()) {
            delete pathwayUnitsToDelete;
        }
        
        // Then delete the Cluster itself
        Cluster__c clusterToDelete = [
            SELECT Id 
            FROM Cluster__c 
            WHERE Id = :clusterId 
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        if (Schema.sObjectType.Cluster__c.isDeletable()) {
        delete clusterToDelete;
    }
        
    } catch (Exception e) {
        System.debug('Error in deleteCluster: ' + e.getMessage());
        throw new AuraHandledException('Failed to delete cluster: ' + e.getMessage());
    }
}

  
@AuraEnabled
public static void cloneCluster(String clusterIdToClone, String newClusterName, String termId, String programPlanId) {
    try {
        if (String.isBlank(clusterIdToClone) || String.isBlank(newClusterName)) {
            throw new AuraHandledException('Cluster ID and new cluster name are required');
        }
        
        // Get the original cluster with all pathway units
        Cluster__c originalCluster = [
            SELECT Id, Name, Minimum_Courses__c, Maximum_Courses__c, 
                   Term__c, Program__c, Program_Plan__c,
                   (SELECT Id, Course__c, Program_Plan__c, Program_Pathway__c, 
                           Term__c, Course_Enrollment__c
                    FROM Pathway_Units__r)
            FROM Cluster__c 
            WHERE Id = :clusterIdToClone 
            with SECURITY_ENFORCED
            LIMIT 1
        ];
        
        // Deep clone the cluster using clone() method
        // Parameters: (preserveId, isDeepClone, preserveReadonlyTimestamps, preserveAutonumber)
        Cluster__c clonedCluster = originalCluster.clone(false, true, false, false);
        
        // Update the clone with new values
        clonedCluster.Name = newClusterName;
        if (String.isNotBlank(termId)) {
            clonedCluster.Term__c = termId;
        }
        if (String.isNotBlank(programPlanId)) {
            clonedCluster.Program_Plan__c = programPlanId;
        }
        
        insert clonedCluster;
        
        // Deep clone pathway units if they exist
        if (originalCluster.Pathway_Units__r != null && !originalCluster.Pathway_Units__r.isEmpty()) {
            List<Pathway_Unit__c> clonedPathwayUnits = new List<Pathway_Unit__c>();
            
            for (Pathway_Unit__c originalUnit : originalCluster.Pathway_Units__r) {
                // Deep clone each pathway unit
                Pathway_Unit__c clonedUnit = originalUnit.clone(false, true, false, false);
                
                // Link to the new cluster and update fields if provided
                clonedUnit.Cluster__c = clonedCluster.Id;
                if (String.isNotBlank(termId)) {
                    clonedUnit.Term__c = termId;
                }
                if (String.isNotBlank(programPlanId)) {
                    clonedUnit.Program_Plan__c = programPlanId;
                }
                
                clonedPathwayUnits.add(clonedUnit);
            }
            
            insert clonedPathwayUnits;
        }
        
    } catch (DmlException dmlEx) {
        throw new AuraHandledException('DML Error in clone cluster: ' + dmlEx.getMessage() + '\n' + dmlEx.getStackTraceString());
    } catch (QueryException queryEx) {
        throw new AuraHandledException('Query Error in clone cluster: ' + queryEx.getMessage() + '\n' + queryEx.getStackTraceString());
    } catch (Exception e) {
        throw new AuraHandledException('Failed to clone cluster: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
}



}