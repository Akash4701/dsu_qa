public with sharing class IntakeScreenController {

    @AuraEnabled(cacheable=true)
    public static List<IdNameWrapper> getAcademicTerms() {
        List<IdNameWrapper> options = new List<IdNameWrapper>();
        for (Academic_Term__c term : [SELECT Id, Name FROM Academic_Term__c WITH SECURITY_ENFORCED ORDER BY Name ]) {
            options.add(new IdNameWrapper(term.Id, term.Name));
        }
        return options;
    }
        
    @AuraEnabled(cacheable=true)
    public static List<IdNameWrapper> getAcademicPrograms() {
        List<IdNameWrapper> options = new List<IdNameWrapper>();
        
        for (Account acc : [SELECT Id, Name FROM Account WHERE RecordType.DeveloperName = 'Academic_Program' WITH SECURITY_ENFORCED]) {
            options.add(new IdNameWrapper(acc.Id, acc.Name));
        }
        
        return options;
    }

    // NEW: Method to fetch picklist values for Academic_Year__c
    @AuraEnabled(cacheable=true)
    public static List<String> getAcademicYearPicklistValues() {
        List<String> picklistValues = new List<String>();
        Schema.DescribeFieldResult fieldResult = hed__Program_Plan__c.Academic_Year__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();
        
        for(Schema.PicklistEntry entry : entries) {
            if(entry.isActive()) { // Only include active picklist values
                picklistValues.add(entry.getValue());
            }
        }
        
        return picklistValues;
    }

    @AuraEnabled(cacheable=true)
    public static List<Academic_Term__c> getAcademicTermss() {
        return [SELECT Id, Name FROM Academic_Term__c WITH SECURITY_ENFORCED];
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getProgramAliases() {
        Map<String, String> aliasMap = new Map<String, String>();

        for (Account acc : [SELECT Id, Alias__c FROM Account WHERE RecordType.DeveloperName = 'Academic_Program' WITH SECURITY_ENFORCED]) {
            aliasMap.put(acc.Id, acc.Alias__c);
        }
        
        return aliasMap;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getNoofTerms() {
        Map<String, String> noOfTermMap = new Map<String, String>();

        for (Account acc : [SELECT Id, Number_of_Terms__c FROM Account WHERE RecordType.DeveloperName = 'Academic_Program' WITH SECURITY_ENFORCED]) {
            noOfTermMap.put(acc.Id, acc.Number_of_Terms__c != null ? String.valueOf(acc.Number_of_Terms__c) : '');
        }
        
        return noOfTermMap;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getTotalDuration() {
        Map<String, String> totalDurationMap = new Map<String, String>();

        for (Account acc : [SELECT Id, Program_Duration_in_Weeks__c FROM Account WHERE RecordType.DeveloperName = 'Academic_Program' WITH SECURITY_ENFORCED]) {
            totalDurationMap.put(acc.Id, acc.Program_Duration_in_Weeks__c != null ? String.valueOf(acc.Program_Duration_in_Weeks__c) : '');
        }
        
        return totalDurationMap;
    }
            
    @AuraEnabled(cacheable=true)
    public static List<IdNameWrapper> getCampusFormats() {
        List<IdNameWrapper> campusOptions = new List<IdNameWrapper>();
        
        for (Campus__c campus : [SELECT Id, Name FROM Campus__c WITH SECURITY_ENFORCED]) {
            campusOptions.add(new IdNameWrapper(campus.Id, campus.Name));
        }
        
        return campusOptions;
    }
    
    // Fetch Program Plans based on Academic Program
    @AuraEnabled(cacheable=true)
    public static List<hed__Program_Plan__c> getProgramPlans(String academicProgramName) {
        // Fetch Account Id using the provided Academic Program Name
        Account academicProgram = [
            SELECT Id FROM Account 
            WHERE Name = :academicProgramName 
            AND RecordType.DeveloperName = 'Academic_Program' 
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // Fetch related Program Plans
        return [
            SELECT Id, Name, Working_Days__c 
            FROM hed__Program_Plan__c 
            WHERE hed__Account__c = :academicProgram.Id
            WITH SECURITY_ENFORCED
        ];
    }

    // Check if Program Plan with same name exists
    @AuraEnabled(cacheable=true)
    public static Boolean checkDuplicateProgramPlan(String startingYear, String intake, String programAlias) {
        // Generate the program plan name that would be created
        String programPlanName = startingYear + '-' + intake + '-' + programAlias;
        
        // Check if a program plan with this name already exists
        List<hed__Program_Plan__c> existingPlans = [
            SELECT Id, Name 
            FROM hed__Program_Plan__c 
            WHERE Name = :programPlanName 
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        // Return true if a duplicate exists, false otherwise
        return !existingPlans.isEmpty();
    }

    @AuraEnabled(cacheable=false)
    public static Boolean saveProgramPlan(Map<String, Object> formData) {
        System.debug('saveProgramPlan Start ::: ' + formData);
        try {
            // Extract values from formData
            String academicProgramId = (String) formData.get('academicProgramId');
            String startingYear = (String) formData.get('startingYear');
            String intake = (String) formData.get('intake');
            String programAlias = (String) formData.get('programAlias');
            String workingDays = (String) formData.get('workingDays');
            String intakeStrengthStr = (String) formData.get('intakeStrength');
            String startDateStr = (String) formData.get('startDate');
            String endDateStr = (String) formData.get('endDate');
            String campusFormat = (String) formData.get('campusFormat');
            // NEW: Extract new fields
            String academicYear = (String) formData.get('academicYear');
            String maxDurationStr = (String) formData.get('maximumProgramDuration');

            // Generate Program Plan Name: "2028-Nov-MBA"
            String programPlanName = startingYear + '-' + intake + '-' + programAlias;

            // Check for duplicate program plan
            List<hed__Program_Plan__c> existingPlans = [
                SELECT Id, Name 
                FROM hed__Program_Plan__c 
                WHERE Name = :programPlanName 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!existingPlans.isEmpty()) {
                throw new AuraHandledException('Program Plan "' + programPlanName + '" already exists. Please use a different combination of Year, Intake, and Program.');
            }

            // Fetch campus name dynamically
            String campusName = 'Unknown Campus';
            if (String.isNotBlank(campusFormat)) {
                List<Campus__c> campuses = [SELECT Name FROM Campus__c WHERE Id = :campusFormat WITH SECURITY_ENFORCED LIMIT 1];
                if (!campuses.isEmpty()) {
                    campusName = campuses[0].Name;
                }
            }

            // Convert date values
            Date startDate = String.isNotBlank(startDateStr) ? Date.valueOf(startDateStr) : null;
            Date endDate = String.isNotBlank(endDateStr) ? Date.valueOf(endDateStr) : null;
            // NEW: Convert Maximum Program Duration date
            Date maxDurationDate = String.isNotBlank(maxDurationStr) ? Date.valueOf(maxDurationStr) : null;

            // Convert Intake Strength
            Decimal intakeStrength = String.isNotBlank(intakeStrengthStr) ? Decimal.valueOf(intakeStrengthStr) : null;

            // Create Program Plan record - NEW: Include the new fields
            hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
                Name = programPlanName,
                hed__Account__c = academicProgramId,
                Account_Name__c = academicProgramId,
                hed__Start_Date__c = startDate,
                hed__End_Date__c = endDate,
                Working_Days__c = workingDays.replace(',', ';'),
                Intake_Number__c = intakeStrength,
                Batch__c = startingYear,
                Intake__c = intake,
                // NEW: Add the new fields to the record
                Academic_Year__c = academicYear,
                Maximum_Program_Duration__c = maxDurationDate
            );
            if (Schema.sObjectType.hed__Program_Plan__c.isCreateable()) {
                insert programPlan;
            }
            System.debug('Program Plan Created ::: ' + programPlan.Id);
            
            // UPDATED: Fetch ALL master terms for the Academic Program and create a map
            Map<String, Id> masterTermMap = new Map<String, Id>();
            for (hed__Term__c masterTerm : [
                SELECT Id, Term_Reference__c 
                FROM hed__Term__c 
                WHERE hed__Account__c = :academicProgramId 
                AND RecordType.DeveloperName = 'Master_Record'
                WITH SECURITY_ENFORCED
            ]) {
                // Map "Term 1" -> Master Term Id, "Term 2" -> Master Term Id, etc.
                // (Note: Term_Reference__c returns API Name values like "Term 1", "Term 2", not "Semester 1", "Semester 2")
                if (String.isNotBlank(masterTerm.Term_Reference__c)) {
                    masterTermMap.put(masterTerm.Term_Reference__c, masterTerm.Id);
                }
            }
            
            System.debug('Master Term Map: ' + masterTermMap);
            
            // Get the term durations from the form data
            List<Object> termDurationsObj = (List<Object>) formData.get('termDurations');
            System.debug('termDurationsObj----------'+termDurationsObj);

            if (termDurationsObj != null && !termDurationsObj.isEmpty()) {
                // Create a list to hold all semester records
                List<hed__Term__c> semesters = new List<hed__Term__c>();
                
                // Process each term duration and create semester records
                for (Object termObj : termDurationsObj) {
                    try {
                        // Explicitly cast each termObj to Map<String, Object>
                        Map<String, Object> term = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(termObj));

                        String termNumber = (String) term.get('termNumber');
                        String duration = (String) term.get('duration');
                        String termStartDate = (String) term.get('startDate');
                        String termEndDate = (String) term.get('endDate');
                        String academicTermId = (String) term.get('academicTermId');
                        
                        // UPDATED: Handle credit fields with proper null checks and conversion
                        Decimal minimumCredit = null;
                        Decimal maximumCredit = null;
                        
                        // Extract and convert minCredit
                        Object minCreditObj = term.get('minCredit');
                        if (minCreditObj != null) {
                            if (minCreditObj instanceof String) {
                                String minCreditStr = (String) minCreditObj;
                                if (String.isNotBlank(minCreditStr)) {
                                    try {
                                        minimumCredit = Decimal.valueOf(minCreditStr);
                                    } catch (Exception ex) {
                                        System.debug('Error converting minCredit to Decimal: ' + minCreditStr + ' - ' + ex.getMessage());
                                    }
                                }
                            } else if (minCreditObj instanceof Decimal) {
                                minimumCredit = (Decimal) minCreditObj;
                            } else if (minCreditObj instanceof Integer) {
                                minimumCredit = Decimal.valueOf((Integer) minCreditObj);
                            }
                        }
                        
                        // Extract and convert maxCredit
                        Object maxCreditObj = term.get('maxCredit');
                        if (maxCreditObj != null) {
                            if (maxCreditObj instanceof String) {
                                String maxCreditStr = (String) maxCreditObj;
                                if (String.isNotBlank(maxCreditStr)) {
                                    try {
                                        maximumCredit = Decimal.valueOf(maxCreditStr);
                                    } catch (Exception ex) {
                                        System.debug('Error converting maxCredit to Decimal: ' + maxCreditStr + ' - ' + ex.getMessage());
                                    }
                                }
                            } else if (maxCreditObj instanceof Decimal) {
                                maximumCredit = (Decimal) maxCreditObj;
                            } else if (maxCreditObj instanceof Integer) {
                                maximumCredit = Decimal.valueOf((Integer) maxCreditObj);
                            }
                        }
                        
                        System.debug('Term ' + termNumber + ' - Min Credit: ' + minimumCredit + ', Max Credit: ' + maximumCredit);

                        // Create semester name
                        String semesterName = startingYear + '-' + intake.toUpperCase() + '-' + programAlias + 
                                         '-Sem ' + termNumber + '-' + campusName;

                        // UPDATED: Find the specific master term for this term number
                        // Match with picklist API Name values: "Term 1", "Term 2", etc.
                        String masterTermKey = 'Term ' + termNumber;
                        Id parentTermId = masterTermMap.get(masterTermKey);
                        
                        System.debug('Term ' + termNumber + ' mapped to Master Term: ' + parentTermId);

                        // Create the semester record with credit fields
                        hed__Term__c semester = new hed__Term__c(
                            Name = semesterName,
                            hed__Account__c = academicProgramId,
                            Term_Reference__c = 'Semester ' + termNumber,
                            Term_Duration__c = String.valueOf(duration),
                            hed__Start_Date__c = String.isBlank(termStartDate) ? null : Date.valueOf(termStartDate),
                            hed__End_Date__c = String.isBlank(termEndDate) ? null : Date.valueOf(termEndDate),
                            Minimum_Credit__c = minimumCredit,  // UPDATED: Now properly handles credit values
                            Maximum_Credit__c = maximumCredit,  // UPDATED: Now properly handles credit values
                            Program_Plan__c = programPlan.Id, // Link to the program plan
                            hed__Type__c = 'Semester',
                            hed__Parent_Term__c = parentTermId  // UPDATED: Now each term gets its specific parent
                        );

                        // Only set Academic_Term__c if academicTermId has a value
                        if (String.isNotBlank(academicTermId)) {
                            semester.Academic_Term__c = academicTermId;
                        }

                        System.debug('Semester record created for Term ' + termNumber + ': ' + semester);
                        System.debug('Academic Term ID: ' + semester.Academic_Term__c);
                        System.debug('Min Credit: ' + semester.Minimum_Credit__c + ', Max Credit: ' + semester.Maximum_Credit__c);
                        
                        semesters.add(semester);
                    } catch (Exception ex) {
                        System.debug('Error processing term object: ' + ex.getMessage());
                        System.debug('Term object causing error: ' + JSON.serialize(termObj));
                        // Continue processing other terms even if one fails
                    }
                }
                
                // Insert all semester records
                // Always insert all semesters regardless of Academic_Term__c
                if (!semesters.isEmpty()) {
                    if (Schema.sObjectType.hed__Term__c.isCreateable()) {
                        insert semesters;
                    }
                    System.debug('Created ' + semesters.size() + ' semester records (including those without Academic Term)');
                    
                    // Additional debug for each created semester
                    for (hed__Term__c semester : semesters) {
                        System.debug('Inserted Semester: ' + semester.Name + ' (ID: ' + semester.Id + ')');
                        System.debug('  - Min Credit: ' + semester.Minimum_Credit__c);
                        System.debug('  - Max Credit: ' + semester.Maximum_Credit__c);
                        System.debug('  - Academic Term: ' + semester.Academic_Term__c);
                    }
                } else {
                    System.debug('No semester records to insert');
                }
                System.debug('Semester records to insert: ' + semesters);
            }
            
            // Fetch Record Type Id for Program_Plan_Level_Campus_Combination
            RecordType programCampusRecordType = [
                SELECT Id FROM RecordType 
                WHERE DeveloperName = 'Program_Plan_Level_Campus_Combination' 
                AND SObjectType = 'Program_Campus_Relationship__c' 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            // Fetch Master Program Campus Combination
            List<Program_Campus_Relationship__c> masterCampusRelList = [
                SELECT Id 
                FROM Program_Campus_Relationship__c 
                WHERE Account_Name__c = :academicProgramId  // Ensure correct field name
                AND RecordType.DeveloperName = 'Program_Level_Campus_Combination'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            String masterCampusId = masterCampusRelList.isEmpty() ? null : masterCampusRelList[0].Id;

            // Create Program_Campus_Relationship__c record
            Program_Campus_Relationship__c programCampusRel = new Program_Campus_Relationship__c(
                RecordTypeId = programCampusRecordType.Id,
                Master_Program_Campus_Combination__c = masterCampusId,
                Combination_Name__c = campusName, // Ensure the correct value
                Program_Plan__c = programPlan.Id
            );

            if (Schema.sObjectType.Program_Campus_Relationship__c.isCreateable()) {
                insert programCampusRel;
            }
            System.debug('Created Program_Campus_Relationship__c record with Id: ' + programCampusRel.Id);
             
            //tcr records
            // Fetch all semesters (terms) related to the created Program Plan
            List<hed__Term__c> termList = [
                SELECT Id, Name 
                FROM hed__Term__c 
                WHERE Program_Plan__c = :programPlan.Id
                WITH SECURITY_ENFORCED  // Corrected filter
            ];

            List<Term_Campus_Relationship__c> termCampusRelList = new List<Term_Campus_Relationship__c>();

            for (hed__Term__c term : termList) {
                Term_Campus_Relationship__c termCampusRel = new Term_Campus_Relationship__c(
                    Campus__c = campusFormat,  // Use campus ID instead of Name
                    Term__c = term.Id,  // Link to the Term
                    Program_Campus_Combination__c = programCampusRel.Id  // Link to Program Campus Relationship
                );
                termCampusRelList.add(termCampusRel);
            }

            // Insert Term_Campus_Relationship__c records
            if (!termCampusRelList.isEmpty()) {
                if (Schema.sObjectType.Term_Campus_Relationship__c.isCreateable()) {
                    insert termCampusRelList;
                }
                System.debug('Created Term_Campus_Relationship__c records: ' + termCampusRelList.size());
            } else {
                System.debug('No terms found for Term_Campus_Relationship__c creation.');
            }

            return true;
        } catch (Exception e) {
            System.debug('Error in saveProgramPlan ::: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving Program Plan: ' + e.getMessage());
        }
    }

    public class IdNameWrapper {
        @AuraEnabled public String value;
        @AuraEnabled public String label;

        public IdNameWrapper(String id, String name) {
            this.value = id;
            this.label = name;
        }
    } 

}