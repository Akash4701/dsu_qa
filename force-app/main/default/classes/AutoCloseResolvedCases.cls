global class AutoCloseResolvedCases implements Database.Batchable<SObject> {

    // Get the default business hours set in the org
    Id businessHoursId = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1].Id;

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, Status, LastModifiedDate
            FROM Case
            WHERE Status = 'Resolved'
        ]);
    }

    global void execute(Database.BatchableContext BC, List<Case> scope) {
        List<Case> toUpdate = new List<Case>();

        for (Case c : scope) {
            Long businessHourDiff = BusinessHours.diff(
                businessHoursId,
                c.LastModifiedDate,
                System.now()
            );

            // 45 business hours = 162000000 ms*
            if (businessHourDiff != null && businessHourDiff >= 162000000) {
                c.Status = 'Closed';
                toUpdate.add(c);
            }
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    global void finish(Database.BatchableContext BC) {
        // Optional logging or email summary
    }
}