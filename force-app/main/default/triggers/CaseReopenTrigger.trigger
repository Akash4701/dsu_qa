trigger CaseReopenTrigger on Case (before update, after insert) {
    
    // ========== BEFORE UPDATE LOGIC ==========
    if (Trigger.isBefore && Trigger.isUpdate) {
        for (Case c : Trigger.new) {
            Case oldCase = Trigger.oldMap.get(c.Id); //  Safe: oldMap exists in update

            String timestamp = Datetime.now().format('dd-MM-yyyy hh:mm a');

            // --- Handle "Reopened" logic ---
            Boolean isNowReopened = c.Status == 'Reopened' && oldCase.Status != 'Reopened';
            if (isNowReopened) {
                Decimal prevCount = oldCase.Reopen_Count__c != null ? oldCase.Reopen_Count__c : 0;
                c.Reopen_Count__c = prevCount + 1;

                String oldText = oldCase.Reason_for_Reopened__c != null ? oldCase.Reason_for_Reopened__c.trim() : '';
                String newText = c.Reason_for_Reopened__c != null ? c.Reason_for_Reopened__c.trim() : '';

                String latestReason = newText;
                if (newText.startsWith(oldText)) {
                    latestReason = newText.substring(oldText.length()).trim();
                }
                latestReason = latestReason.replaceAll('(\\d{2}-\\d{2}-\\d{4} \\d{2}:\\d{2} [APap][Mm])', '').trim();

                if (String.isNotBlank(latestReason)) {
                    String newEntry = timestamp + ' ' + latestReason;
                    c.Reason_for_Reopened__c = String.isNotBlank(oldText) ? oldText + '\n' + newEntry : newEntry;
                } else {
                    c.Reason_for_Reopened__c = oldText;
                }
            } else {
                c.Reason_for_Reopened__c = oldCase.Reason_for_Reopened__c;
                c.Reopen_Count__c = oldCase.Reopen_Count__c;
            }

            // --- Handle "In Progress" logic ---
            Boolean isNowInProgress = c.Status == 'In Progress' && oldCase.Status != 'In Progress';
            if (isNowInProgress) {
                String oldComment = oldCase.Reson_Comments__c != null ? oldCase.Reson_Comments__c.trim() : '';
                String newComment = c.Reson_Comments__c != null ? c.Reson_Comments__c.trim() : '';

                String latestComment = newComment;
                if (newComment.startsWith(oldComment)) {
                    latestComment = newComment.substring(oldComment.length()).trim();
                }
                latestComment = latestComment.replaceAll('(\\d{2}-\\d{2}-\\d{4} \\d{2}:\\d{2} [APap][Mm])', '').trim();

                if (String.isNotBlank(latestComment)) {
                    String commentEntry = timestamp + ' ' + latestComment;
                    c.Reson_Comments__c = String.isNotBlank(oldComment) ? oldComment + '\n' + commentEntry : commentEntry;
                } else {
                    c.Reson_Comments__c = oldComment;
                }
            } else {
                c.Reson_Comments__c = oldCase.Reson_Comments__c;
            }
        }
    }

    // ========== AFTER INSERT LOGIC ==========
    if (Trigger.isAfter && Trigger.isInsert) {
        CaseTriggerHandler.handleAfterInsert(Trigger.new);
    }
}