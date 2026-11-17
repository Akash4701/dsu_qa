public class ContactHandler {
    
    public static void handleDEBIDUpdate(List<Contact> newContacts, Map<Id, Contact> oldContactMap) {
        Set<Id> contactsWithNewDEBID = new Set<Id>();
        
        // Find contacts where DEB_ID__c changed from blank to having a value
        for (Contact contact : newContacts) {
            Contact oldContact = oldContactMap.get(contact.Id);
            
            if (String.isBlank(oldContact.DEB_ID__c) && String.isNotBlank(contact.DEB_ID__c)) {
                contactsWithNewDEBID.add(contact.Id);
            }
        }
        
        if (!contactsWithNewDEBID.isEmpty()) {
            // Find related affiliations that need roll numbers
            List<hed__Affiliation__c> affiliationsToUpdate = [
                SELECT Id, hed__Contact__c, Program_Plan__c, Roll_Number__c, DSU_Email__c, DEB_ID__c,Individual_Application__r.Status__c
                FROM hed__Affiliation__c 
                WHERE hed__Contact__c IN :contactsWithNewDEBID 
                AND Program_Plan__c != null 
                AND Roll_Number__c = null
                AND Individual_Application__r.Status__c = 'Approved for USN'
            ];
            
            if (!affiliationsToUpdate.isEmpty()) {
                AffiliationHandler.generateRollNumbers(affiliationsToUpdate);
                update affiliationsToUpdate;
            }
        }
    }
}