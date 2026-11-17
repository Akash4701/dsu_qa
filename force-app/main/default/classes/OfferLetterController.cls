public class OfferLetterController {

    public hed__Affiliation__c affiliationRecord { get; set; }
    public String formattedSession { get; set; }
    public String userCredentials { get; set; }

    public OfferLetterController(ApexPages.StandardController stdController) {
        this.affiliationRecord = (hed__Affiliation__c) stdController.getRecord();

        this.affiliationRecord = [
            SELECT Id, Roll_Number__c,
                Program_Plan__r.Intake__c,
                Program_Plan__r.Batch__c
            FROM hed__Affiliation__c
            WHERE Id = :affiliationRecord.Id
            LIMIT 1
        ];
        try {
            DSU_Name__c cs = [
                SELECT Id, User_Credentials__c
                FROM DSU_Name__c
                WHERE Name = 'Dayananda Sagar University'  
                LIMIT 1
            ];
            userCredentials = cs.User_Credentials__c;
        } catch (Exception e) {
            userCredentials = 'Not Configured'; // fallback
        }
        String intakeAbbrev = affiliationRecord.Program_Plan__r.Intake__c;
        String intakeMonth = normalizeMonth(intakeAbbrev);
        String year = affiliationRecord.Program_Plan__r.Batch__c;

        Map<String, String> nextMonthMap = new Map<String, String>{
            'JAN' => 'FEB', 'FEB' => 'MAR', 'MAR' => 'APR',
    'APR' => 'MAY', 'MAY' => 'JUN', 'JUN' => 'JUL',
    'JUL' => 'AUG', 'AUG' => 'SEP', 'SEP' => 'OCT',
    'OCT' => 'NOV', 'NOV' => 'DEC', 'DEC' => 'JAN'
        };

        if (String.isNotBlank(intakeAbbrev) && String.isNotBlank(year)) {
            String nextMonth = nextMonthMap.get(intakeAbbrev);

            if (intakeAbbrev == 'DEC') {
                Integer currentYear = Integer.valueOf(year);
                Integer nextYear = currentYear + 1;
                formattedSession = intakeAbbrev + ' - ' + currentYear + ' / ' + nextMonth + ' - ' + nextYear;
            } else {
                formattedSession = intakeAbbrev + '/' + nextMonth + ' - ' + year;
            }
        } else {
            formattedSession = intakeAbbrev + ' - ' + year;
        }
    }

    private String normalizeMonth(String abbrev) {
        Map<String, String> monthMap = new Map<String, String>{
            'JAN' => 'January', 'FEB' => 'February', 'MAR' => 'March',
            'APR' => 'April', 'MAY' => 'May', 'JUN' => 'June',
            'JUL' => 'July', 'AUG' => 'August', 'SEP' => 'September',
            'OCT' => 'October', 'NOV' => 'November', 'DEC' => 'December'
        };
        String key = abbrev != null ? abbrev.trim().toUpperCase() : '';
        return monthMap.containsKey(key) ? monthMap.get(key) : abbrev;
    }

    @AuraEnabled
    public static void generateAndAttachPDF(Id affiliationId) {
        if (String.isBlank(affiliationId)) {
            throw new AuraHandledException('Affiliation Id is required');
        }

        hed__Affiliation__c affiliation = [
            SELECT Id, Roll_Number__c
            FROM hed__Affiliation__c
            WHERE Id = :affiliationId
            LIMIT 1
        ];

        String fileName = affiliation.Roll_Number__c + '_LetterOfAdmission.pdf';

        PageReference pdfPage = Page.OfferLetterPage;
        pdfPage.getParameters().put('id', affiliationId);

        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Mock PDF content');
        } else {
            pdfBlob = pdfPage.getContentAsPDF();
        }

        ContentVersion contentVersion = new ContentVersion();
        contentVersion.Title = fileName;
        contentVersion.PathOnClient = fileName;
        contentVersion.VersionData = pdfBlob;
        insert contentVersion;

        contentVersion = [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id = :contentVersion.Id
        ];

        ContentDocumentLink docLink = new ContentDocumentLink();
        docLink.ContentDocumentId = contentVersion.ContentDocumentId;
        docLink.LinkedEntityId = affiliationId;
        docLink.ShareType = 'V';
        insert docLink;
    }
}