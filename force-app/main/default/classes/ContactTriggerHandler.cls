public with sharing class ContactTriggerHandler extends TriggerHandler {
	public override void processBeforeInsert() {
		populateAccountField();
	}
    
    public override void processBeforeDelete(){
    //    deleteBBUser(Trigger.old);
    }

	private static void populateAccountField() {
		List<Account> houseHoldAccount = [SELECT Id FROM Account WHERE RecordType.Name = 'Household Account' LIMIT 1];

		if(houseHoldAccount.isEmpty()) return;

		for(Contact con : (List<Contact>)Trigger.New) {
			con.AccountId = houseHoldAccount[0].Id;
		}
	}
    

    public static void changeRecordTypeOfContact(List<Contact> contacts){
        List<Contact> contactsToUpdate = new List<Contact>();
        for(Contact eachContact : contacts){
            if(eachContact.RecordTypeId == Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Individual').getRecordTypeId()){
                eachContact.RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Household').getRecordTypeId();
                contactsToUpdate.add(eachContact);
            }
        }
        if(!contactsToUpdate.isEmpty()){
            update contactsToUpdate;
        }
    }
}