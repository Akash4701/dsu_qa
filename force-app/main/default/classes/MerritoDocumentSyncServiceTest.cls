@isTest
private class MerritoDocumentSyncServiceTest {

    @testSetup
    static void setup() {
        Contact applicant = new Contact(FirstName = 'Test', LastName = 'Applicant');
        insert applicant;
        insert new List<Application__c>{
            new Application__c(ContactId__c = applicant.Id, Program_Level__c = 'UG',
                               External_Application_Number__c = 'LEGACY-9999'),
            new Application__c(ContactId__c = applicant.Id, Program_Level__c = 'UG',
                               External_Application_Number__c = 'LEGACY-1000')
        };
    }

    private static Application__c app(String externalNumber) {
        return [SELECT Id FROM Application__c WHERE External_Application_Number__c = :externalNumber];
    }

    private static Map<String, Object> doc(String type, String name, String appNumber, String url) {
        return new Map<String, Object>{
            'DocumentType' => type, 'DocumentName' => name,
            'ApplicationNumber' => appNumber, 'DocumentUploadUrl' => url
        };
    }

    private static String body(List<Object> docs) {
        return JSON.serialize(new Map<String, Object>{ 'Documents' => docs });
    }

    /** Posts the body and returns the parsed response, with the status code under "statusCode". */
    private static Map<String, Object> post(String requestBody) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/MerritoDocumentSync';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        MerritoDocumentSyncService.syncDocuments();

        Map<String, Object> response =
            (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        response.put('statusCode', RestContext.response.statusCode);
        return response;
    }

    private static Map<String, Object> result(Map<String, Object> response, Integer index) {
        return (Map<String, Object>) ((List<Object>) response.get('results'))[index];
    }

    private static List<Object> sampleDocuments() {
        return new List<Object>{
            doc('PDF', 'Aadhaar front and back', 'LEGACY-9999', 'https://example.com/doc/aadhaar.pdf'),
            doc('PDF', 'Class 10 marksheet', 'LEGACY-9999', 'https://example.com/doc/class10.pdf'),
            doc('PDF', 'Graduation Part I', 'LEGACY-9999', 'https://example.com/doc/grad-1.pdf'),
            doc('PDF', 'Graduation Part II', 'LEGACY-9999', 'https://example.com/doc/grad-2.pdf'),
            doc('PDF', 'Migration certificate', 'LEGACY-9999', 'https://example.com/doc/migration.pdf')
        };
    }

    @isTest
    static void createsOneRowPerDocument() {
        Test.startTest();
        Map<String, Object> response = post(body(sampleDocuments()));
        Test.stopTest();

        System.assertEquals(200, response.get('statusCode'));
        for (Integer i = 0; i < 5; i++) {
            System.assertEquals(MerritoDocumentSyncService.STATUS_CREATED, result(response, i).get('status'));
        }
        Id appId = app('LEGACY-9999').Id;
        List<Document_Checklist__c> rows = [
            SELECT Application__c, Application_Number__c, Document_Type__c, Document_Name__c, Document_Upload_URL__c
            FROM Document_Checklist__c ORDER BY Document_Upload_URL__c
        ];
        System.assertEquals(5, rows.size());
        for (Document_Checklist__c row : rows) {
            System.assertEquals(appId, row.Application__c);
            System.assertEquals('LEGACY-9999', row.Application_Number__c);
            System.assertEquals('PDF', row.Document_Type__c);
        }
        System.assertEquals('Aadhaar front and back', rows[0].Document_Name__c);
        System.assertEquals('https://example.com/doc/aadhaar.pdf', rows[0].Document_Upload_URL__c);
    }

    /** Re-sending the same documents updates their rows instead of adding copies. */
    @isTest
    static void resendUpdatesExistingRows() {
        post(body(sampleDocuments()));

        List<Object> resent = sampleDocuments();
        ((Map<String, Object>) resent[1]).put('DocumentType', 'Class Xth/SSC Marksheet');
        ((Map<String, Object>) resent[2]).put('DocumentName', null);

        Test.startTest();
        Map<String, Object> response = post(body(resent));
        Test.stopTest();

        for (Integer i = 0; i < 5; i++) {
            System.assertEquals(MerritoDocumentSyncService.STATUS_UPDATED, result(response, i).get('status'));
        }
        System.assertEquals(5, [SELECT COUNT() FROM Document_Checklist__c]);
        System.assertEquals('Class Xth/SSC Marksheet', [
            SELECT Document_Type__c FROM Document_Checklist__c
            WHERE Document_Upload_URL__c = 'https://example.com/doc/class10.pdf'
        ].Document_Type__c);
        System.assertEquals('Graduation Part I', [
            SELECT Document_Name__c FROM Document_Checklist__c
            WHERE Document_Upload_URL__c = 'https://example.com/doc/grad-1.pdf'
        ].Document_Name__c, 'A blank value does not wipe the stored one');
    }

    @isTest
    static void sameUrlOnAnotherApplicationIsSeparate() {
        post(body(new List<Object>{ doc('PDF', 'Aadhaar', 'LEGACY-9999', 'https://example.com/doc/a.pdf') }));

        Test.startTest();
        Map<String, Object> response = post(body(new List<Object>{
            doc('PDF', 'Aadhaar', 'LEGACY-1000', 'https://example.com/doc/a.pdf'),
            doc('PDF', 'Aadhaar', 'LEGACY-1000', 'https://example.com/doc/a.pdf')
        }));
        Test.stopTest();

        System.assertEquals(MerritoDocumentSyncService.STATUS_CREATED, result(response, 0).get('status'));
        System.assertEquals(MerritoDocumentSyncService.STATUS_CREATED, result(response, 1).get('status'));
        System.assertEquals(result(response, 0).get('documentChecklistId'), result(response, 1).get('documentChecklistId'),
            'A document repeated in one request shares its row');
        System.assertEquals(1, [SELECT COUNT() FROM Document_Checklist__c WHERE Application__c = :app('LEGACY-1000').Id]);
    }

    @isTest
    static void documentWithoutUrlIsAlwaysNew() {
        Test.startTest();
        post(body(new List<Object>{ doc('Signature', 'Signature', 'LEGACY-9999', null) }));
        Map<String, Object> response = post(body(new List<Object>{ doc('Signature', 'Signature', 'LEGACY-9999', null) }));
        Test.stopTest();

        System.assertEquals(MerritoDocumentSyncService.STATUS_CREATED, result(response, 0).get('status'));
        System.assertEquals(2, [SELECT COUNT() FROM Document_Checklist__c]);
    }

    @isTest
    static void unknownApplicationReturns404AndSavesTheRest() {
        Test.startTest();
        Map<String, Object> response = post(body(new List<Object>{
            doc('PDF', 'Aadhaar', 'NO-SUCH-APP', 'https://example.com/doc/x.pdf'),
            doc('PDF', 'Aadhaar', ' LEGACY-9999 ', 'https://example.com/doc/y.pdf')
        }));
        Test.stopTest();

        System.assertEquals(404, response.get('statusCode'));
        System.assertEquals(MerritoDocumentSyncService.STATUS_APPLICATION_NOT_FOUND, result(response, 0).get('status'));
        System.assertEquals(MerritoDocumentSyncService.STATUS_CREATED, result(response, 1).get('status'));
        System.assertEquals(1, [SELECT COUNT() FROM Document_Checklist__c]);
    }

    @isTest
    static void invalidDocumentsAreReported() {
        Test.startTest();
        Map<String, Object> response = post(body(new List<Object>{
            doc('PDF', 'Aadhaar', null, 'https://example.com/doc/x.pdf'),
            doc(null, null, 'LEGACY-9999', null),
            doc('PDF', 'Aadhaar', 'LEGACY-9999', 'https://example.com/' + 'x'.repeat(250))
        }));
        Test.stopTest();

        System.assertEquals(200, response.get('statusCode'));
        for (Integer i = 0; i < 3; i++) {
            System.assertEquals(MerritoDocumentSyncService.STATUS_INVALID, result(response, i).get('status'));
            System.assertEquals(i, result(response, i).get('index'));
        }
        System.assertEquals(0, [SELECT COUNT() FROM Document_Checklist__c]);
    }

    private static String contactPhoto() {
        return [SELECT Passport_Size_Photo__c FROM Contact LIMIT 1].Passport_Size_Photo__c;
    }

    @isTest
    static void passportPhotoSetsContactPhoto() {
        Test.startTest();
        post(body(new List<Object>{
            doc('PDF', 'Class 10 marksheet', 'LEGACY-9999', 'https://example.com/doc/class10.pdf'),
            doc('JPG', ' passport size photo ', 'LEGACY-9999', 'https://example.com/doc/photo.jpg')
        }));
        Test.stopTest();

        System.assertEquals('https://example.com/doc/photo.jpg', contactPhoto(),
            'The name is matched ignoring case and surrounding spaces');
    }

    /** A re-sent photo with a new URL is a new row, and replaces the Contact's photo. */
    @isTest
    static void newerPassportPhotoReplacesContactPhoto() {
        post(body(new List<Object>{
            doc('JPG', 'Passport Size Photo', 'LEGACY-9999', 'https://example.com/doc/photo-1.jpg')
        }));

        Test.startTest();
        post(body(new List<Object>{
            doc('JPG', 'Passport Size Photo', 'LEGACY-1000', 'https://example.com/doc/photo-2.jpg'),
            doc('JPG', 'Passport Size Photo', 'LEGACY-9999', 'https://example.com/doc/photo-3.jpg')
        }));
        Test.stopTest();

        System.assertEquals('https://example.com/doc/photo-3.jpg', contactPhoto(),
            'The last photo in the request wins');
    }

    /** Re-sending a photo row with its name left blank still counts it as the photo. */
    @isTest
    static void resentPhotoWithoutNameKeepsContactPhoto() {
        post(body(new List<Object>{
            doc('JPG', 'Passport Size Photo', 'LEGACY-9999', 'https://example.com/doc/photo.jpg')
        }));
        update new Contact(Id = [SELECT Id FROM Contact LIMIT 1].Id, Passport_Size_Photo__c = null);

        Test.startTest();
        post(body(new List<Object>{ doc('JPG', null, 'LEGACY-9999', 'https://example.com/doc/photo.jpg') }));
        Test.stopTest();

        System.assertEquals('https://example.com/doc/photo.jpg', contactPhoto());
    }

    @isTest
    static void otherDocumentsLeaveContactPhotoAlone() {
        Test.startTest();
        post(body(sampleDocuments()));
        post(body(new List<Object>{ doc('JPG', 'Passport Size Photo', 'LEGACY-9999', null) }));
        Test.stopTest();

        System.assertEquals(null, contactPhoto(), 'A photo without a URL has nothing to show');
    }

    private static String applicationStatus(String externalNumber) {
        return [SELECT Status__c FROM Application__c WHERE External_Application_Number__c = :externalNumber].Status__c;
    }

    private static void setApplicationStatus(String externalNumber, String status) {
        update new Application__c(Id = app(externalNumber).Id, Status__c = status);
    }

    private static Application__c syncFields(String externalNumber) {
        return [
            SELECT Documents_Synced__c, Documents_Synced_On__c FROM Application__c
            WHERE External_Application_Number__c = :externalNumber
        ];
    }

    @isTest
    static void crmEnrolledMovesToEnrolledWithDocuments() {
        setApplicationStatus('LEGACY-9999', MerritoDocumentSyncService.APPLICATION_STATUS_CRM_ENROLLED);
        setApplicationStatus('LEGACY-1000', MerritoDocumentSyncService.APPLICATION_STATUS_CRM_ENROLLED);

        Test.startTest();
        post(body(sampleDocuments()));
        Test.stopTest();

        System.assertEquals(MerritoDocumentSyncService.APPLICATION_STATUS_ENROLLED_WITH_DOCUMENTS,
            applicationStatus('LEGACY-9999'));
        System.assertEquals(true, syncFields('LEGACY-9999').Documents_Synced__c);
        System.assertNotEquals(null, syncFields('LEGACY-9999').Documents_Synced_On__c);

        System.assertEquals(MerritoDocumentSyncService.APPLICATION_STATUS_CRM_ENROLLED,
            applicationStatus('LEGACY-1000'), 'An application that received no documents keeps its status');
        System.assertEquals(false, syncFields('LEGACY-1000').Documents_Synced__c);
        System.assertEquals(null, syncFields('LEGACY-1000').Documents_Synced_On__c);
    }

    /**
     * Only CRM Enrolled moves; an application on hold or further along keeps its status but
     * still records that its documents were synced.
     */
    @isTest
    static void otherStatusesAreLeftAlone() {
        setApplicationStatus('LEGACY-9999', 'Application on hold');

        Test.startTest();
        post(body(sampleDocuments()));
        Test.stopTest();

        System.assertEquals('Application on hold', applicationStatus('LEGACY-9999'));
        System.assertEquals(true, syncFields('LEGACY-9999').Documents_Synced__c);
        System.assertNotEquals(null, syncFields('LEGACY-9999').Documents_Synced_On__c);
    }

    /** A re-send moves the timestamp forward and keeps the box ticked. */
    @isTest
    static void resendRefreshesSyncedOn() {
        post(body(sampleDocuments()));
        Datetime earlier = Datetime.now().addDays(-1);
        update new Application__c(Id = app('LEGACY-9999').Id, Documents_Synced_On__c = earlier);

        Test.startTest();
        post(body(sampleDocuments()));
        Test.stopTest();

        Application__c synced = syncFields('LEGACY-9999');
        System.assertEquals(true, synced.Documents_Synced__c);
        System.assert(synced.Documents_Synced_On__c > earlier, 'The timestamp is the latest sync');
    }

    @isTest
    static void rejectedDocumentsLeaveStatusAlone() {
        setApplicationStatus('LEGACY-9999', MerritoDocumentSyncService.APPLICATION_STATUS_CRM_ENROLLED);

        Test.startTest();
        post(body(new List<Object>{
            doc(null, null, 'LEGACY-9999', null),
            doc('PDF', 'Aadhaar', 'NO-SUCH-APP', 'https://example.com/doc/x.pdf')
        }));
        Test.stopTest();

        System.assertEquals(MerritoDocumentSyncService.APPLICATION_STATUS_CRM_ENROLLED,
            applicationStatus('LEGACY-9999'));
        System.assertEquals(false, syncFields('LEGACY-9999').Documents_Synced__c);
        System.assertEquals(null, syncFields('LEGACY-9999').Documents_Synced_On__c);
    }

    @isTest
    static void badRequestBodyReturns400() {
        System.assertEquals(400, post('not json').get('statusCode'));
        System.assertEquals(400, post('{"Documents":[]}').get('statusCode'));
        System.assertEquals(400, post('{}').get('statusCode'));
        System.assertEquals(400, post('{"Documents":[null]}').get('statusCode'));
    }
}