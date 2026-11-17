public with sharing class FeeAssignmentExamHandler {
    private static final String FEE_PAID_STATUS = 'Fee Paid';

    public static void handleAfterInsert(List<Fee_Assignment__c> newFeeAssignments) {
        processFeeAssignments(newFeeAssignments, null);
    }

    public static void handleAfterUpdate(
        List<Fee_Assignment__c> newFeeAssignments,
        Map<Id, Fee_Assignment__c> oldMap
    ) {
        processFeeAssignments(newFeeAssignments, oldMap);
    }

    private static void processFeeAssignments(
        List<Fee_Assignment__c> newFeeAssignments,
        Map<Id, Fee_Assignment__c> oldMap
    ) {
        if (newFeeAssignments == null || newFeeAssignments.isEmpty()) {
            return;
        }

        Set<Id> fullyPaidFeeAssignmentIds = new Set<Id>();
        Boolean isUpdateContext = (oldMap != null);

        for (Fee_Assignment__c feeAssignment : newFeeAssignments) {
            if (feeAssignment == null || feeAssignment.Id == null) {
                continue;
            }

            if (!isFullyPaid(feeAssignment)) {
                continue;
            }

            if (isUpdateContext) {
                Fee_Assignment__c oldFeeAssignment = oldMap.get(feeAssignment.Id);
                if (oldFeeAssignment != null && isFullyPaid(oldFeeAssignment)) {
                    continue;
                }
            }

            fullyPaidFeeAssignmentIds.add(feeAssignment.Id);
        }

        if (fullyPaidFeeAssignmentIds.isEmpty()) {
            return;
        }

        List<Student_Service_Request__c> requestsToUpdate = new List<Student_Service_Request__c>();
        for (Student_Service_Request__c requestRec : [
            SELECT Id, Status__c
            FROM Student_Service_Request__c
            WHERE Fee_Assignment__c IN :fullyPaidFeeAssignmentIds
        ]) {
            if (requestRec.Status__c == FEE_PAID_STATUS) {
                continue;
            }

            requestRec.Status__c = FEE_PAID_STATUS;
            requestsToUpdate.add(requestRec);
        }

        if (!requestsToUpdate.isEmpty()) {
            update requestsToUpdate;
        }
    }

    @TestVisible
    private static Boolean isFullyPaid(Fee_Assignment__c feeAssignment) {
        return feeAssignment != null &&
            feeAssignment.Paid_Amount__c != null &&
            feeAssignment.Total_Amount_Payable__c != null &&
            feeAssignment.Paid_Amount__c == feeAssignment.Total_Amount_Payable__c;
    }
}