public with sharing class HallTicketService {

    public class StudentRow {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String rollNo;
    }

    @AuraEnabled(cacheable=true)
    public static List<StudentRow> getStudents(Id examCycleId) {
        if (examCycleId == null) {
            throw new AuraHandledException('Exam Cycle Id is required.');
        }

        // Query 1: exam connections -> contact + program enrollment (we mainly need contacts for UI)
        List<Exam_Connections__c> conns = [
            SELECT Id,
                   Student_Name__c,
                   Course_Connection_ID__r.hed__Program_Enrollment__c,
					Exam_Type__c
            FROM Exam_Connections__c
            WHERE Exam_Name__r.Exam_Cycle__c = :examCycleId
              AND Student_Name__c != null
              AND Course_Connection_ID__r.hed__Program_Enrollment__c != null
        ];

        Set<Id> contactIds = new Set<Id>();
        for (Exam_Connections__c ec : conns) {
            contactIds.add((Id)ec.Student_Name__c);
        }
        if (contactIds.isEmpty()) return new List<StudentRow>();

        // Query 2: affiliation to display in datatable (latest per contact)
        Map<Id, hed__Affiliation__c> latestAff = new Map<Id, hed__Affiliation__c>();
        for (hed__Affiliation__c aff : [
            SELECT Id,
                   hed__Contact__c,
                   hed__Contact__r.Name,
                   DSU_Email__c,
                   Roll_Number__c,
                   hed__Contact__r.Phone_Number__c,
                   CreatedDate
            FROM hed__Affiliation__c
            WHERE hed__Contact__c IN :contactIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!latestAff.containsKey(aff.hed__Contact__c)) {
                latestAff.put(aff.hed__Contact__c, aff);
            }
        }

        List<StudentRow> rows = new List<StudentRow>();
        for (Id cId : contactIds) {
            hed__Affiliation__c aff = latestAff.get(cId);
            StudentRow r = new StudentRow();
            r.contactId = cId;

            if (aff != null) {
                r.name  = aff.hed__Contact__r != null ? aff.hed__Contact__r.Name : null;
                r.email = aff.DSU_Email__c;
                r.rollNo = aff.Roll_Number__c;
                r.phone = aff.hed__Contact__r != null ? String.valueOf(aff.hed__Contact__r.Phone_Number__c) : null;
            }
            rows.add(r);
        }
        return rows;
    }

    // Keep name generateHallTickets (as you already have), but overload it with selection
    @AuraEnabled
    public static void generateHallTickets(Id examCycleId, List<Id> contactIds) {
        if (examCycleId == null) {
            throw new AuraHandledException('Exam Cycle Id is required.');
        }
        if (contactIds == null || contactIds.isEmpty()) {
            throw new AuraHandledException('Please select at least one student.');
        }

        try {
            // Set checkbox TRUE when clicking Generate (your requirement)
            Exam_Cycle__c ec = [
                SELECT Id, Name, Generate_HallTicket__c
                FROM Exam_Cycle__c
                WHERE Id = :examCycleId
                LIMIT 1
            ];
            ec.Generate_HallTicket__c = true;
            update ec;

            // Start batch (same class name)
            HallTicketBatchByExamCycle batch = new HallTicketBatchByExamCycle(examCycleId, contactIds);
            Database.executeBatch(batch, 10);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}