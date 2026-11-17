public with sharing class ExamCycleHallTicketController {

    @AuraEnabled
    public static void publishHallTicket(Id examCycleId) {
        if (examCycleId == null) {
            throw new AuraHandledException('Exam Cycle ID is required.');
        }

        Exam_Cycle__c ec = [
            SELECT Id, Publish_Hall_Ticket__c
            FROM Exam_Cycle__c
            WHERE Id = :examCycleId
            LIMIT 1
            FOR UPDATE
        ];

        // If already published, stop (optional behavior)
        if (ec.Publish_Hall_Ticket__c == true) {
            throw new AuraHandledException('Hall ticket is already published for this exam cycle.');
        }

        ec.Publish_Hall_Ticket__c = true;
        update ec;
    }
}