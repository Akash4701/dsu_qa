@RestResource(urlMapping='/eventpicklistvalues')
global without sharing class EventPicklistValuesRestApi {

    @HttpGet
    global static void getEventPicklistValues() {
        try {		
            DataBlock dataBlock = new DataBlock();
            dataBlock.values = getPicklistValues('Event_Master__c','Event_Type__c');
            dataBlock.languages = getPicklistValues('Event_Master__c','Language__c');
            dataBlock.targetAudience = getPicklistValues('Event_Master__c','Target_Audience_Applicable__c');
            dataBlock.eventTimezone = getPicklistValues('Event_Master__c','Timezone__c');

            RestApiUtility.createSuccessGetResponse(dataBlock);
        } catch (Exception e) {
            RestApiUtility.addError(RestApiUtility.HTTP_INTERNAL_SERVER_ERROR, 'Error: '+e.getmessage());
            return;
        }
    }
    
    @TestVisible
    private static List<ValueEntry> getPicklistValues(String objectName, String fieldName){
        List<ValueEntry> picklistValues = new List<ValueEntry>();
        
        if(String.isBlank(objectName) || String.isBlank(fieldName)){
            return picklistValues;
        }
        
        for(PicklistValueInfo picklist : [SELECT Label,Value FROM PicklistValueInfo WHERE EntityParticle.EntityDefinition.QualifiedApiName = :objectName AND EntityParticle.QualifiedApiName = :fieldName and isActive = true LIMIT 200])
                {
                    picklistValues.add(new ValueEntry(picklist.label, picklist.value));
                }
        return picklistValues;
    }

    global class DataBlock {
        public List<ValueEntry> values;
        public List<ValueEntry> languages;
        public List<ValueEntry> targetAudience;
        public List<ValueEntry> eventTimezone;
    }
    
    global class ValueEntry {
        public String label;
        public String value;
        
        public ValueEntry(String label, String value){
            this.label = label;
            this.value = value;
        }
    }
}