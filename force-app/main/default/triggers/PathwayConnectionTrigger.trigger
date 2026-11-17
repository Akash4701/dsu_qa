trigger PathwayConnectionTrigger on Pathway_Connection__c (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        Set<Id> contactIds = new Set<Id>();
        Set<Id> programPathwayIds = new Set<Id>();
        
        for (Pathway_Connection__c pc : Trigger.new) {
            if (pc.Contact__c != null && pc.Program_Pathway__c != null) {
                contactIds.add(pc.Contact__c);
                programPathwayIds.add(pc.Program_Pathway__c);
            }
        }

        if (!contactIds.isEmpty() && !programPathwayIds.isEmpty()) {
            Map<Id, Program_Pathway__c> pathwayMap = new Map<Id, Program_Pathway__c>();
            
            
                for (Program_Pathway__c pp : [
                    SELECT Id, Name, Specialization_Type__c
                    FROM Program_Pathway__c
                    WHERE Id IN :programPathwayIds
                    WITH SECURITY_ENFORCED
                ]) {
                    pathwayMap.put(pp.Id, pp);
                }
            
            
            List<Pathway_Connection__c> existingConnections = new List<Pathway_Connection__c>();
            
            if (Schema.sObjectType.Pathway_Connection__c.isAccessible()) 
                existingConnections = [
                    SELECT Id, Contact__c, Program_Pathway__c, Program_Pathway__r.Name, Program_Pathway__r.Specialization_Type__c
                    FROM Pathway_Connection__c
                    WHERE Contact__c IN :contactIds
                    WITH SECURITY_ENFORCED
                ];
            
            
            Map<String, List<Pathway_Connection__c>> contactPathwayMap = new Map<String, List<Pathway_Connection__c>>();
            for (Pathway_Connection__c ex : existingConnections) {
                String key = ex.Contact__c + '::' + ex.Program_Pathway__r.Name;
                if (!contactPathwayMap.containsKey(key)) {
                    contactPathwayMap.put(key, new List<Pathway_Connection__c>());
                }
                contactPathwayMap.get(key).add(ex);
            }
            
            for (Pathway_Connection__c newPc : Trigger.new) {
                if (newPc.Contact__c == null || newPc.Program_Pathway__c == null) {
                    continue;
                }
                
                Program_Pathway__c pp = pathwayMap.get(newPc.Program_Pathway__c);
                if (pp == null || String.isBlank(pp.Name)) {
                    continue;
                }
                
                String key = newPc.Contact__c + '::' + pp.Name;
                
                if (contactPathwayMap.containsKey(key)) {
                    for (Pathway_Connection__c ex : contactPathwayMap.get(key)) {
                        if (ex.Program_Pathway__r.Specialization_Type__c == 'Major') {
                            newPc.addError(
                                'Enrollment blocked: Student is already enrolled in a Major for this Pathway and cannot enroll in a Minor.'
                            );
                            break;
                        }
                    }
                }
            }
        }
    }
}