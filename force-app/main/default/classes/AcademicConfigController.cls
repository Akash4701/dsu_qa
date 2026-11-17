/**
 * @description Controller to fetch Academic Program Configuration from Custom Metadata
 * @author Your Name
 * @date Today's Date
 */
public with sharing class AcademicConfigController {
    
    /**
     * @description Fetches academic configuration based on institution type
     * @param institutionType Type of institution (University, College, etc.)
     * @return Academic_Program_Config__mdt configuration record
     */
    @AuraEnabled(cacheable=true)
    public static Academic_Program_Config__mdt getAcademicConfiguration(String institutionType) {
        try {
            // Query custom metadata based on institution type
            List<Academic_Program_Config__mdt> configs = [
                SELECT Id, Label, DeveloperName, 
                       Requirement_Mode__c, 
                       Institution_Type__c,
                       Default_Working_Days__c,
                       Auto_Calculate_Terms__c
                FROM Academic_Program_Config__mdt 
                WHERE Institution_Type__c = :institutionType
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            
            if (!configs.isEmpty()) {
                return configs[0];
            }
            
            // Fallback to default configuration if specific type not found
            return getDefaultConfiguration();
            
        } catch (Exception e) {
            System.debug('Error fetching academic configuration: ' + e.getMessage());
            throw new AuraHandledException('Unable to fetch academic configuration: ' + e.getMessage());
        }
    }
    
    /**
     * @description Gets all available configurations for selection
     * @return List of available configurations
     */
    @AuraEnabled(cacheable=true)
    public static List<Academic_Program_Config__mdt> getAllConfigurations() {
        try {
            return [
                SELECT Id, Label, DeveloperName,
                       Requirement_Mode__c,
                       Institution_Type__c,
                       Default_Working_Days__c,
                       Auto_Calculate_Terms__c
                FROM Academic_Program_Config__mdt
                WITH SECURITY_ENFORCED
                ORDER BY Institution_Type__c
            ];
        } catch (Exception e) {
            System.debug('Error fetching all configurations: ' + e.getMessage());
            throw new AuraHandledException('Unable to fetch configurations: ' + e.getMessage());
        }
    }
    
    /**
     * @description Gets default configuration when no specific match found
     * @return Default Academic_Program_Config__mdt record
     */
    private static Academic_Program_Config__mdt getDefaultConfiguration() {
        List<Academic_Program_Config__mdt> defaultConfigs = [
            SELECT Id, Label, DeveloperName,
                   Requirement_Mode__c,
                   Institution_Type__c, 
                   Default_Working_Days__c,
                   Auto_Calculate_Terms__c
            FROM Academic_Program_Config__mdt
            WHERE DeveloperName = 'University_Standard'
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        
        return !defaultConfigs.isEmpty() ? defaultConfigs[0] : null;
    }
    
    /**
     * @description Helper method to parse working days string into list
     * @param workingDaysString Comma-separated working days
     * @return List of working days
     */
    @AuraEnabled(cacheable=true)
    public static List<String> parseWorkingDays(String workingDaysString) {
        if (String.isBlank(workingDaysString)) {
            return new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
        }
        
        return workingDaysString.split(',');
    }
}