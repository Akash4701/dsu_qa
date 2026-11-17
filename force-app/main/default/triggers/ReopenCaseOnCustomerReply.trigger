trigger ReopenCaseOnCustomerReply on EmailMessage (after insert) {
    Set<Id> relatedCaseIds = new Set<Id>();

    for (EmailMessage em : Trigger.New) {
        // Only process incoming emails linked to a Case
        System.debug('----Inside EmailMessage');
        if (em.Incoming != true) {
            continue;
        }

        // Which field holds the parent Case Id depends on how Email-to-Case
        // is configured in the org: legacy/On-Demand Email-to-Case populates
        // RelatedToId, while ParentId (used by Enhanced Email / Case Feed)
        // may be the one that's actually set instead. Checking both keeps
        // this trigger working the same way regardless of that org setting.
        if (em.ParentId != null && String.valueOf(em.ParentId).startsWith('500')) {
            System.debug('----Inside Incoming,ParentId,startsWith');
            relatedCaseIds.add(em.ParentId);
        } else if (em.RelatedToId != null && String.valueOf(em.RelatedToId).startsWith('500')) {
            System.debug('----Inside Incoming,RelatedToId,startsWith');
            relatedCaseIds.add(em.RelatedToId);
        }
        System.debug('----OUtside EmailMessage');
    }
    System.debug('relatedCaseIds'+relatedCaseIds);

    if (!relatedCaseIds.isEmpty()) {
        List<Case> casesToUpdate = [
            SELECT Id, Status 
            FROM Case 
            WHERE Id IN :relatedCaseIds AND Status = 'Resolved'
        ];
		System.debug('casesToUpdate'+casesToUpdate);
        for (Case c : casesToUpdate) {
            System.debug('----Before Change');
            System.debug('----Before Change'+c.status);
            c.Status = 'Reopened'; // Or your org-specific reopened status
            System.debug('----After Change');
            System.debug('----After Change'+c.status);
        }

        if (!casesToUpdate.isEmpty()) {
            System.debug('----After Update');
            update casesToUpdate;
             System.debug('----After Update');
        }
        
    }
}