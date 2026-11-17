public class HallTicketBatchByExamCycle implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private Id examCycleId;
    private Set<Id> selectedContactIds;
    private String examCycleName;
    private Set<Id> processed = new Set<Id>();

    // Constructor
    public HallTicketBatchByExamCycle(Id examCycleId, List<Id> contactIds) {
        this.examCycleId = examCycleId;
        this.selectedContactIds = new Set<Id>(contactIds);

        Exam_Cycle__c ec = [SELECT Name FROM Exam_Cycle__c WHERE Id = :examCycleId LIMIT 1];
        this.examCycleName = ec.Name;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   Student_Name__c,
                   Course_Connection_ID__r.hed__Program_Enrollment__c
            FROM Exam_Connections__c
            WHERE Exam_Name__r.Exam_Cycle__c = :examCycleId
              AND Student_Name__c IN :selectedContactIds
              AND Student_Name__c != null
              AND Course_Connection_ID__r.hed__Program_Enrollment__c != null
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Exam_Connections__c> conns = (List<Exam_Connections__c>)scope;

        // Step 1: Collect unprocessed contacts with valid enrollments
        Set<Id> contactIdsToProcess = new Set<Id>();
        Map<Id, Id> contactToEnrollment = new Map<Id, Id>();
        
        for (Exam_Connections__c ec : conns) {
            Id contactId = (Id)ec.Student_Name__c;
            Id peId = ec.Course_Connection_ID__r.hed__Program_Enrollment__c;
            
            if (contactId != null && peId != null && !processed.contains(contactId)) {
                contactIdsToProcess.add(contactId);
                if (!contactToEnrollment.containsKey(contactId)) {
                    contactToEnrollment.put(contactId, peId);
                }
            }
        }

        // Step 2: Bulk query affiliations for all contacts in this scope
        Map<Id, hed__Affiliation__c> contactToAffiliation = new Map<Id, hed__Affiliation__c>();
        if (!contactIdsToProcess.isEmpty()) {
            for (hed__Affiliation__c aff : [
                SELECT Roll_Number__c, hed__Contact__r.Name, hed__Contact__c 
                FROM hed__Affiliation__c 
                WHERE hed__Contact__c IN :contactIdsToProcess
                // Assuming one active affiliation per student; 
                // add ORDER BY clause if business logic requires specific affiliation selection
            ]) {
                // Keep first affiliation encountered per contact (adjust logic if multiple affiliations need handling)
                if (!contactToAffiliation.containsKey(aff.hed__Contact__c)) {
                    contactToAffiliation.put(aff.hed__Contact__c, aff);
                }
            }
        }

        // Step 3: Generate hall tickets with enriched title
        for (Id contactId : contactToEnrollment.keySet()) {
            if (processed.contains(contactId)) continue;
            processed.add(contactId);

            Id programEnrollmentId = contactToEnrollment.get(contactId);
            hed__Affiliation__c aff = contactToAffiliation.get(contactId);
            
            // Safely extract name and roll number with fallbacks
            String studentName = (aff != null && aff.hed__Contact__r != null && aff.hed__Contact__r.Name != null) 
                ? aff.hed__Contact__r.Name 
                : 'Unknown Student';
            
            String rollNumber = (aff != null && aff.Roll_Number__c != null) 
                ? aff.Roll_Number__c 
                : 'N/A';

            try {
                PageReference pdfPage = Page.StudentHallTicket;
                pdfPage.getParameters().put('id', (String)contactId);
                pdfPage.getParameters().put('examCycleId', (String)examCycleId);
                pdfPage.setRedirect(true);

                Blob pdfBlob = Test.isRunningTest()
                    ? Blob.valueOf('Hall Ticket')
                    : pdfPage.getContentAsPDF();

                ContentVersion cv = new ContentVersion();
                // Updated title format with student name and roll number
                cv.Title = examCycleName + ' - Hall Ticket ' + studentName + ' - (' + rollNumber + ')';
                cv.PathOnClient = 'Hall_Ticket_' + contactId + '.pdf';
                cv.VersionData = pdfBlob;
                cv.ContentLocation = 'S';
                cv.Document_Type__c = 'Hall Ticket';
                insert cv;

                Id contentDocumentId = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :cv.Id
                    LIMIT 1
                ].ContentDocumentId;

                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = contentDocumentId;
                cdl.LinkedEntityId = programEnrollmentId;
                cdl.ShareType = 'V';
                insert cdl;

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'Hall ticket failed for Contact ' + contactId +
                    ' (Program Enrollment: ' + programEnrollmentId + '): ' + e.getMessage()
                );
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        // optional
    }

    // ============================================================
    // NEW METHOD: API helper (NO SAVE) - returns PDF as Blob
    // ============================================================
    public static Blob generateHallTicketPdfBlob(Id examCycleId, Id contactId) {
        if (examCycleId == null) {
            throw new AuraHandledException('Exam Cycle Id is required.');
        }
        if (contactId == null) {
            throw new AuraHandledException('Contact Id is required.');
        }

        // Validate contact belongs to the exam cycle & has program enrollment mapping
        Integer cnt = [
            SELECT COUNT()
            FROM Exam_Connections__c
            WHERE Exam_Name__r.Exam_Cycle__c = :examCycleId
              AND Student_Name__c = :contactId
              AND Course_Connection_ID__r.hed__Program_Enrollment__c != null
        ];
        if (cnt == 0) {
            throw new AuraHandledException('Student is not eligible for this Exam Cycle.');
        }

        PageReference pdfPage = Page.StudentHallTicket;
        pdfPage.getParameters().put('id', (String)contactId);
        pdfPage.getParameters().put('examCycleId', (String)examCycleId);
        pdfPage.setRedirect(true);

        if (Test.isRunningTest()) {
            return Blob.valueOf('Hall Ticket');
        }
        return pdfPage.getContentAsPDF();
    }
}