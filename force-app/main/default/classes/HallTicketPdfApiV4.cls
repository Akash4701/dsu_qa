@RestResource(urlMapping='/hallticket/v4/pdf')
global with sharing class HallTicketPdfApiV4 {

    @HttpGet
global static void getPdf() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    try {
        String examCycleIdStr = req.params.get('examCycleId');
        String contactIdStr   = req.params.get('contactId');

        if (String.isBlank(examCycleIdStr) || String.isBlank(contactIdStr)) {
            res.statusCode = 400;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf('{"message":"Missing examCycleId or contactId"}');
            return;
        }

        // Validate Exam_Cycle__c exists and has Publish_Hall_Ticket__c = true
        Exam_Cycle__c examCycle = [
            SELECT Id, Publish_Hall_Ticket__c 
            FROM Exam_Cycle__c 
            WHERE Id = :examCycleIdStr AND Publish_Hall_Ticket__c = true 
            LIMIT 1
        ];

        if (examCycle == null) {
            res.statusCode = 400;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf('{"message":"Invalid or unpublished exam cycle"}');
            return;
        }

        Blob pdf = HallTicketBatchByExamCycle.generateHallTicketPdfBlob(
            (Id) examCycleIdStr,
            (Id) contactIdStr
        );

        res.statusCode = 200;
        res.addHeader('Content-Type', 'application/pdf');
        res.addHeader('Content-Disposition', 'inline; filename="HallTicket_' + contactIdStr + '.pdf"');
        res.responseBody = pdf;

    } catch (QueryException qe) {
        // Handles case where no record is found or invalid ID format
        RestContext.response.statusCode = 400;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf('{"message":"Invalid or unpublished exam cycle"}');
    } catch (Exception e) {
        res.statusCode = 500;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(new Map<String,Object>{
            'message' => 'Failed to generate hall ticket',
            'detail'  => e.getMessage()
        }));
    }
}
}