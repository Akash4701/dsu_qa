public with sharing class CaseQueueReassignment {
    @InvocableMethod(label='Assign Cases from Queue')
    public static void assign(List<Id> closedCaseIds) {
        if (closedCaseIds.isEmpty()) return;

        List<Case> closedCases = [SELECT Id, OwnerId FROM Case WHERE Id IN :closedCaseIds];

        Set<Id> userIds = new Set<Id>();
        for (Case c : closedCases) {
            if (c.OwnerId != null) {
                userIds.add(c.OwnerId);
            }
        }

        if (userIds.isEmpty()) return;

        Map<Id, Integer> openCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT OwnerId, COUNT(Id) total
            FROM Case 
            WHERE OwnerId IN :userIds AND Status != 'Closed' 
            GROUP BY OwnerId
        ]) {
            openCounts.put((Id)ar.get('OwnerId'), (Integer)ar.get('total'));
        }

        Group queue = [SELECT Id FROM Group WHERE Name = 'Case Pipeline Queue' LIMIT 1];

        List<Case> queuedCases = [
            SELECT Id 
            FROM Case 
            WHERE OwnerId = :queue.Id 
            ORDER BY CreatedDate ASC 
            LIMIT 20
        ];

        Integer nextCaseIndex = 0;
        List<Case> casesToUpdate = new List<Case>();

        for (Id userId : userIds) {
            Integer currentCount = openCounts.containsKey(userId) ? openCounts.get(userId) : 0;
            while (currentCount < 10 && nextCaseIndex < queuedCases.size()) {
                Case assignable = queuedCases[nextCaseIndex];
                assignable.OwnerId = userId;
                casesToUpdate.add(assignable);
                currentCount++;
                nextCaseIndex++;
            }
        }

        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }
}