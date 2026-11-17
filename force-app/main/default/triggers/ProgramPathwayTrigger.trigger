trigger ProgramPathwayTrigger on Program_Pathway__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        List<Pathway_Enrollment__c> enrollmentsToInsert = new List<Pathway_Enrollment__c>();

        for (Program_Pathway__c pp : Trigger.new) {
            if (pp.Is_Core__c == false) {
            enrollmentsToInsert.add(new Pathway_Enrollment__c(
                Program_Pathway__c = pp.Id
            ));
            }
        }

        if (!enrollmentsToInsert.isEmpty()) {
            insert enrollmentsToInsert;
        }
    }
}