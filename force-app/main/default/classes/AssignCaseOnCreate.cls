public with sharing class AssignCaseOnCreate {
    @InvocableMethod(label='Assign Case to Available User')
    public static void assign(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) return;

        List<Case> caseList = [SELECT Id, OwnerId, Status FROM Case WHERE Id IN :caseIds];
        if (caseList.isEmpty()) return;

        Case newCase = caseList[0]; // Since we expect only one

        // List your 2 user Ids here
        List<Hd_Counsellor_Users__c> Users = [SELECT User_Id__c FROM Hd_Counsellor_Users__c];
        List<Id> roundRobinUsers = new List<Id>();
        for (Hd_Counsellor_Users__c userID : Users) {
            if (userID.User_Id__c != null) {
                roundRobinUsers.add(userID.User_Id__c);
            }
        }

        // Get current open case counts
        Map<Id, Integer> userOpenCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OwnerId, COUNT(Id) total
            FROM Case 
            WHERE OwnerId IN :roundRobinUsers AND Status != 'Closed' 
            GROUP BY OwnerId
        ]) {
            userOpenCounts.put((Id)ar.get('OwnerId'), (Integer)ar.get('total'));
        }

        // Pick first user with < 10 open cases
        Id assignTo = null;
        Integer minOpenCases = 999999;

        for (Id eachUserId : roundRobinUsers) {
            Integer count = userOpenCounts.containsKey(eachUserId) ? userOpenCounts.get(eachUserId) : 0;
            if (count < 10 && count < minOpenCases) {
                minOpenCases = count;
                assignTo = eachUserId;
            }
        }

        if (assignTo != null) {
            newCase.OwnerId = assignTo;
            update newCase;
        }
    }
}