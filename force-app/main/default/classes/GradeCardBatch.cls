global with sharing class GradeCardBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Id termId;

    global Integer successCount = 0;
    global Integer failCount = 0;
    global List<String> errors = new List<String>();

    global GradeCardBatch(Id termId) {
        this.termId = termId;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id,
                   hed__Contact__r.Name,
                   hed__Affiliation__r.Roll_Number__c
            FROM hed__Program_Enrollment__c
            WHERE Term__c = :termId
            ORDER BY CreatedDate ASC
        ]);
    }

    global void execute(Database.BatchableContext bc, List<hed__Program_Enrollment__c> scope) {
        for (hed__Program_Enrollment__c pe : scope) {
            try {
                PageReference pr = Page.GradeCardPdf; // your VF page
                pr.getParameters().put('termId', String.valueOf(termId));
                pr.getParameters().put('peId', String.valueOf(pe.Id));

                Blob pdfBlob = Test.isRunningTest()
                    ? Blob.valueOf('TEST_PDF')
                    : pr.getContentAsPDF();

                GradeCardController.storePdfFromBatch(
                    pe.Id,
                    pdfBlob,
                    'E-Grade Card',
                    (pe.hed__Contact__r != null) ? pe.hed__Contact__r.Name : null,
                    (pe.hed__Affiliation__r != null) ? pe.hed__Affiliation__r.Roll_Number__c : null
                );

                successCount++;
            } catch (Exception ex) {
                failCount++;
                errors.add('PE ' + pe.Id + ': ' + ex.getMessage());
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('GradeCardBatch finished. Success=' + successCount + ', Fail=' + failCount);
        if (!errors.isEmpty()) System.debug('Errors: ' + String.join(errors, ' | '));
    }
}