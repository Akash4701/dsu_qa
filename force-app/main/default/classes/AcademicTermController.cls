public with sharing class AcademicTermController {
    
    @AuraEnabled(cacheable = true)
    public static List<Account> getAcademicPrograms() {
        try {
            return [
                SELECT Id, Name
                FROM Account
                WHERE RecordType.DeveloperName = 'Academic_Program'
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Academic Programs: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable = true)
    public static List<hed__Program_Plan__c> getProgramPlans(Id accountId) {
        try {
            if (accountId == null) {
                return new List<hed__Program_Plan__c>();
            }
            
            return [
                SELECT Id, Name
                FROM hed__Program_Plan__c
                WHERE hed__Account__c = :accountId
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Program Plans: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable = true)
    public static List<hed__Term__c> getterms(Id programPlanId) {
        try {
            if (programPlanId == null) {
                return new List<hed__Term__c>();
            }
            
            return [
                SELECT Id, Name 
                FROM hed__Term__c 
                WHERE Program_Plan__c = :programPlanId
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Terms: ' + e.getMessage());
        }
    }
    
    /**
     * Enhanced method to get terms with their Academic Term mappings
     */
    @AuraEnabled(cacheable = true)
    public static List<hed__Term__c> getTermsWithAcademicTerms(Id programPlanId) {
        try {
            if (programPlanId == null) {
                return new List<hed__Term__c>();
            }
            
            return [
                SELECT Id, Name, Academic_Term__c,
                       Academic_Term__r.Id,
                       Academic_Term__r.Name,
                       Academic_Term__r.Academic_Year__c,
                       Academic_Term__r.Season__c,
                       Academic_Term__r.Start_Date__c,
                       Academic_Term__r.End_Date__c,
                       Academic_Term__r.Registration_Open_Date__c,
                       Academic_Term__r.Registration_Close_Date__c,
                       Academic_Term__r.Late_Registration_Date__c,
                       Academic_Term__r.IsActive__c,
                       Academic_Term__r.Description__c
                FROM hed__Term__c 
                WHERE Program_Plan__c = :programPlanId
                WITH SECURITY_ENFORCED
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Terms with Academic Terms: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable = true)
    public static List<Academic_Term__c> getAcademicTerms() {
        try {
            return [
                SELECT Id, Name, Academic_Year__c, Season__c, Start_Date__c, End_Date__c, 
                       Registration_Open_Date__c, Registration_Close_Date__c, 
                       Last_Modified_Date__c, Late_Registration_Date__c, Description__c,
                       External_Id__c, IsActive__c
                FROM Academic_Term__c
                WITH SECURITY_ENFORCED
                ORDER BY Academic_Year__c DESC, Season__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Academic Terms: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable = true)
    public static Academic_Term__c getAcademicTermById(Id termId) {
        try {
            if (termId == null) {
                throw new AuraHandledException('Term ID cannot be null');
            }
            
            List<Academic_Term__c> terms = [
                SELECT Id, Name, Academic_Year__c, Season__c, Start_Date__c, End_Date__c, 
                       Registration_Open_Date__c, Registration_Close_Date__c, 
                       Last_Modified_Date__c, Late_Registration_Date__c, Description__c,
                       External_Id__c, IsActive__c
                FROM Academic_Term__c
                WHERE Id = :termId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (terms.isEmpty()) {
                throw new AuraHandledException('Academic Term not found');
            }
            
            return terms[0];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Academic Term: ' + e.getMessage());
        }
    }
    
    /**
     * Enhanced method to map an Academic Term to a Term
     */
    @AuraEnabled
    public static String mapAcademicTermToTerm(Id termId, Id academicTermId) {
        try {
            if (termId == null || academicTermId == null) {
                throw new AuraHandledException('Term ID and Academic Term ID cannot be null');
            }
            
            // Verify the term exists
            List<hed__Term__c> terms = [SELECT Id FROM hed__Term__c WHERE Id = :termId WITH SECURITY_ENFORCED LIMIT 1];
            if (terms.isEmpty()) {
                throw new AuraHandledException('Term not found');
            }
            
            // Verify the academic term exists
            List<Academic_Term__c> academicTerms = [SELECT Id FROM Academic_Term__c WHERE Id = :academicTermId WITH SECURITY_ENFORCED LIMIT 1];
            if (academicTerms.isEmpty()) {
                throw new AuraHandledException('Academic Term not found');
            }
            
            // Update the term with the academic term mapping
            hed__Term__c termToUpdate = new hed__Term__c(
                Id = termId,
                Academic_Term__c = academicTermId
            );
            
            if (Schema.sObjectType.hed__Term__c.isUpdateable()) {
        update termToUpdate;
    }
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error mapping Academic Term to Term: ' + e.getMessage());
        }
    }
    
    /**
     * Method to remove Academic Term mapping from a Term
     */
    @AuraEnabled
    public static String removeAcademicTermMapping(Id termId) {
        try {
            if (termId == null) {
                throw new AuraHandledException('Term ID cannot be null');
            }
            
            // Verify the term exists
            List<hed__Term__c> terms = [SELECT Id FROM hed__Term__c WHERE Id = :termId WITH SECURITY_ENFORCED LIMIT 1];
            if (terms.isEmpty()) {
                throw new AuraHandledException('Term not found');
            }
            
            // Remove the academic term mapping
            hed__Term__c termToUpdate = new hed__Term__c(
                Id = termId,
                Academic_Term__c = null
            );
            
            if (Schema.sObjectType.hed__Term__c.isUpdateable()) {
        update termToUpdate;
    } 
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error removing Academic Term mapping: ' + e.getMessage());
        }
    }
    
    /**
     * Enhanced method to create Academic Term with better validation and error handling
     */
    @AuraEnabled
    public static Id createAcademicTerm(String termData, Id selectedTermId) {
        Savepoint sp = Database.setSavepoint();
        
        try {
            if (String.isBlank(termData)) {
                throw new AuraHandledException('Term data cannot be empty');
            }
            
            Map<String, Object> termMap = (Map<String, Object>) JSON.deserializeUntyped(termData);
            
            // Validate required fields
            if (String.isBlank((String) termMap.get('Academic_Year__c'))) {
                throw new AuraHandledException('Academic Year is required');
            }
            if (String.isBlank((String) termMap.get('Season__c'))) {
                throw new AuraHandledException('Season is required');
            }
            if (String.isBlank((String) termMap.get('Start_Date__c'))) {
                throw new AuraHandledException('Start Date is required');
            }
            if (String.isBlank((String) termMap.get('End_Date__c'))) {
                throw new AuraHandledException('End Date is required');
            }
            
            // Create the Academic Term
            Academic_Term__c newAcademicTerm = new Academic_Term__c();
            newAcademicTerm.Name = (String) termMap.get('Name');
            newAcademicTerm.Academic_Year__c = (String) termMap.get('Academic_Year__c');
            newAcademicTerm.Season__c = (String) termMap.get('Season__c');
            newAcademicTerm.Start_Date__c = Date.valueOf((String) termMap.get('Start_Date__c'));
            newAcademicTerm.End_Date__c = Date.valueOf((String) termMap.get('End_Date__c'));
            newAcademicTerm.IsActive__c = (Boolean) termMap.get('IsActive__c');
            newAcademicTerm.Description__c = (String) termMap.get('Description__c');
            newAcademicTerm.External_Id__c = (String) termMap.get('External_Id__c');
            
            // Handle optional date fields
            String regOpenDate = (String) termMap.get('Registration_Open_Date__c');
            if (String.isNotBlank(regOpenDate)) {
                newAcademicTerm.Registration_Open_Date__c = Date.valueOf(regOpenDate);
            }
            
            String regCloseDate = (String) termMap.get('Registration_Close_Date__c');
            if (String.isNotBlank(regCloseDate)) {
                newAcademicTerm.Registration_Close_Date__c = Date.valueOf(regCloseDate);
            }
            
            String lastModDate = (String) termMap.get('Last_Modified_Date__c');
            if (String.isNotBlank(lastModDate)) {
                newAcademicTerm.Last_Modified_Date__c = Date.valueOf(lastModDate);
            }
            
            String lateRegDate = (String) termMap.get('Late_Registration_Date__c');
            if (String.isNotBlank(lateRegDate)) {
                newAcademicTerm.Late_Registration_Date__c = Date.valueOf(lateRegDate);
            }
            
            // Validate date logic
            if (newAcademicTerm.Start_Date__c >= newAcademicTerm.End_Date__c) {
                throw new AuraHandledException('Start Date must be before End Date');
            }
            
            // Check for duplicate Academic Terms
            List<Academic_Term__c> existingTerms = [
                SELECT Id 
                FROM Academic_Term__c 
                WHERE Academic_Year__c = :newAcademicTerm.Academic_Year__c 
                AND Season__c = :newAcademicTerm.Season__c 
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!existingTerms.isEmpty()) {
                throw new AuraHandledException('An Academic Term with this Academic Year and Season already exists');
            }
            
           if (Schema.sObjectType.Academic_Term__c.isCreateable()) {
    insert newAcademicTerm;
    
}
            
            // If a specific term was selected, map the new academic term to it
            if (selectedTermId != null) {
                // Verify the term exists
                List<hed__Term__c> terms = [SELECT Id FROM hed__Term__c WHERE Id = :selectedTermId WITH SECURITY_ENFORCED LIMIT 1];
                if (!terms.isEmpty()) {
                    hed__Term__c selectedTerm = new hed__Term__c(
                        Id = selectedTermId,
                        Academic_Term__c = newAcademicTerm.Id
                    );
                    if (Schema.sObjectType.hed__Term__c.isUpdateable()) {
        update selectedTerm;
    } 
                }
            }
            
            return newAcademicTerm.Id;
        } catch (Exception e) {
    Database.rollback(sp);

    // Capture original stack trace BEFORE wrapping
    String stackTrace = e.getStackTraceString();
    system.debug('This is the stack trace '+ stackTrace);
    throw new AuraHandledException(
        'Error creating Academic Term: ' + e.getMessage() +
        '\nStack Trace:\n' + stackTrace
    );
}
    }
    
    /**
     * Enhanced method to update Academic Term with better validation and error handling
     */
    @AuraEnabled
    public static String updateAcademicTerm(String termData, Id academicTermId) {
        Savepoint sp = Database.setSavepoint();
        
        try {
            if (String.isBlank(termData)) {
                throw new AuraHandledException('Term data cannot be empty');
            }
            if (academicTermId == null) {
                throw new AuraHandledException('Academic Term ID cannot be null');
            }
            
            Map<String, Object> termMap = (Map<String, Object>) JSON.deserializeUntyped(termData);
            
            // Validate required fields
            if (String.isBlank((String) termMap.get('Academic_Year__c'))) {
                throw new AuraHandledException('Academic Year is required');
            }
            if (String.isBlank((String) termMap.get('Season__c'))) {
                throw new AuraHandledException('Season is required');
            }
            if (String.isBlank((String) termMap.get('Start_Date__c'))) {
                throw new AuraHandledException('Start Date is required');
            }
            if (String.isBlank((String) termMap.get('End_Date__c'))) {
                throw new AuraHandledException('End Date is required');
            }
            
            // Verify the academic term exists
            List<Academic_Term__c> existingTerms = [
                SELECT Id 
                FROM Academic_Term__c 
                WHERE Id = :academicTermId
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            
            if (existingTerms.isEmpty()) {
                throw new AuraHandledException('Academic Term not found');
            }
            
            Academic_Term__c academicTermToUpdate = new Academic_Term__c();
            academicTermToUpdate.Id = academicTermId;
            academicTermToUpdate.Name = (String) termMap.get('Name');
            academicTermToUpdate.Academic_Year__c = (String) termMap.get('Academic_Year__c');
            academicTermToUpdate.Season__c = (String) termMap.get('Season__c');
            academicTermToUpdate.Start_Date__c = Date.valueOf((String) termMap.get('Start_Date__c'));
            academicTermToUpdate.End_Date__c = Date.valueOf((String) termMap.get('End_Date__c'));
            academicTermToUpdate.IsActive__c = (Boolean) termMap.get('IsActive__c');
            academicTermToUpdate.Description__c = (String) termMap.get('Description__c');
            academicTermToUpdate.External_Id__c = (String) termMap.get('External_Id__c');
            
            // Handle optional date fields
            String regOpenDate = (String) termMap.get('Registration_Open_Date__c');
            if (String.isNotBlank(regOpenDate)) {
                academicTermToUpdate.Registration_Open_Date__c = Date.valueOf(regOpenDate);
            } else {
                academicTermToUpdate.Registration_Open_Date__c = null;
            }
            
            String regCloseDate = (String) termMap.get('Registration_Close_Date__c');
            if (String.isNotBlank(regCloseDate)) {
                academicTermToUpdate.Registration_Close_Date__c = Date.valueOf(regCloseDate);
            } else {
                academicTermToUpdate.Registration_Close_Date__c = null;
            }
            
            String lastModDate = (String) termMap.get('Last_Modified_Date__c');
            if (String.isNotBlank(lastModDate)) {
                academicTermToUpdate.Last_Modified_Date__c = Date.valueOf(lastModDate);
            } else {
                academicTermToUpdate.Last_Modified_Date__c = null;
            }
            
            String lateRegDate = (String) termMap.get('Late_Registration_Date__c');
            if (String.isNotBlank(lateRegDate)) {
                academicTermToUpdate.Late_Registration_Date__c = Date.valueOf(lateRegDate);
            } else {
                academicTermToUpdate.Late_Registration_Date__c = null;
            }
            
            // Validate date logic
            if (academicTermToUpdate.Start_Date__c >= academicTermToUpdate.End_Date__c) {
                throw new AuraHandledException('Start Date must be before End Date');
            }
            
            // Check for duplicate Academic Terms (excluding current record)
            List<Academic_Term__c> duplicateTerms = [
                SELECT Id 
                FROM Academic_Term__c 
                WHERE Academic_Year__c = :academicTermToUpdate.Academic_Year__c 
                AND Season__c = :academicTermToUpdate.Season__c 
                AND Id != :academicTermId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!duplicateTerms.isEmpty()) {
                throw new AuraHandledException('Another Academic Term with this Academic Year and Season already exists');
            }
            
            if (Schema.sObjectType.Academic_Term__c.isUpdateable()) {
        update academicTermToUpdate;
    } 
            
            return 'Success';
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error updating Academic Term: ' + e.getMessage());
        }
    }
    
    /**
     * Utility method to get Academic Terms that are not mapped to any term in a specific program plan
     */
    @AuraEnabled(cacheable = true)
    public static List<Academic_Term__c> getUnmappedAcademicTerms(Id programPlanId) {
        try {
            if (programPlanId == null) {
                return getAcademicTerms();
            }
            
            // Get all academic term IDs that are already mapped to terms in this program plan
            Set<Id> mappedAcademicTermIds = new Set<Id>();
            for (hed__Term__c term : [
                SELECT Academic_Term__c 
                FROM hed__Term__c 
                WHERE Program_Plan__c = :programPlanId 
                AND Academic_Term__c != null
                WITH SECURITY_ENFORCED
            ]) {
                mappedAcademicTermIds.add(term.Academic_Term__c);
            }
            
            // Return academic terms that are not mapped
            return [
                SELECT Id, Name, Academic_Year__c, Season__c, Start_Date__c, End_Date__c, 
                       Registration_Open_Date__c, Registration_Close_Date__c, 
                       Last_Modified_Date__c, Late_Registration_Date__c, Description__c,
                       External_Id__c, IsActive__c
                FROM Academic_Term__c
                WHERE Id NOT IN :mappedAcademicTermIds
                WITH SECURITY_ENFORCED
                ORDER BY Academic_Year__c DESC, Season__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching unmapped Academic Terms: ' + e.getMessage());
        }
    }
}