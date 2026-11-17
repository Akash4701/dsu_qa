@isTest
private class ApplicantServiceV4_Test {

    static Account createAcademicProgramAccount() {
        Account acc = new Account(
            Name = 'Test Academic Program',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Academic Program').getRecordTypeId(),
            Program_Alias__c = 'MBA'
        );
        
        insert acc;
        return acc;
    }
    @testSetup
    static void createEducationInstituteAccount(){
        Account acc = new Account(
            Name = 'Dayananda Sagar University - Online',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Educational Institution').getRecordTypeId()

        );
       Insert acc;
        
        DSU_Name__c DSU = new DSU_Name__c(Name = 'Dayananda Sagar University',Record_Id__c = acc.Id);
        insert DSU;
    }
    @isTest
    static void testWithClass12Only() {
        Account acc = createAcademicProgramAccount();
        String json = generateJSONWithClass12(acc.Id);
        executeTest(json);
    }

    @isTest
    static void testWithDiplomaOnly() {
        Account acc = createAcademicProgramAccount();
        String json = generateJSONWithDiploma(acc.Id);
        executeTest(json);
    }

    @isTest
    static void testWithUGOnly() {
        Account acc = createAcademicProgramAccount();
        String json = generateJSONWithUGOnly(acc.Id);
        executeTest(json);
    }

    @isTest
    static void testWithProfessionalCourseOnly() {
        Account acc = createAcademicProgramAccount();
        String json = generateJSONWithProfessionalOnly(acc.Id);
        executeTest(json);
    }

    /**
     * The point of the Documents list is that one application can carry several
     * documents, including more than one of the same type — so this sends two
     * Graduation Marksheets alongside other types and checks both survive.
     */
    @isTest
    static void testMultipleDocumentsPerApplication() {
        Account acc = createAcademicProgramAccount();
        String json = baseJSONPrefix(acc.Id) + ',' +
            '"Documents":[' +
                '{"DocumentType":"Aadhaar Card","DocumentName":"Aadhaar front and back","DocumentUploadUrl":"https://example.com/doc/aadhaar.pdf"},' +
                '{"DocumentType":"Graduation Marksheet","DocumentName":"Graduation Part I","DocumentUploadUrl":"https://example.com/doc/grad-1.pdf"},' +
                '{"DocumentType":"Graduation Marksheet","DocumentName":"Graduation Part II","DocumentUploadUrl":"https://example.com/doc/grad-2.pdf"},' +
                '{"DocumentType":"Migration Certificate","DocumentName":"Migration","DocumentUploadUrl":"https://example.com/doc/migration.pdf"}' +
            '],' +
            '"PersonEducation":{"QualificationAfter10th":"PUC"}' +
        '}';

        Test.startTest();
        executeTest(json);
        Test.stopTest();

        Application__c app = [SELECT Id FROM Application__c LIMIT 1];
        List<Document_Checklist__c> rows = [
            SELECT Document_Type__c, Document_Name__c, Document_Upload_URL__c,
                   Application__c, Application_Number__c
            FROM Document_Checklist__c
            ORDER BY Document_Name__c
        ];

        System.assertEquals(4, rows.size(), 'Every submitted document should become its own checklist row.');
        for (Document_Checklist__c row : rows) {
            System.assertEquals(app.Id, row.Application__c, 'Each row must point at the Application just created.');
        }

        Integer graduationRows = 0;
        for (Document_Checklist__c row : rows) {
            if (row.Document_Type__c == 'Graduation Marksheet') { graduationRows++; }
        }
        System.assertEquals(2, graduationRows,
            'Two documents of the same type must both be kept — that is the whole reason this is a list.');

        System.assertEquals('Aadhaar front and back', rows[0].Document_Name__c);
        System.assertEquals('https://example.com/doc/aadhaar.pdf', rows[0].Document_Upload_URL__c);

        for (Document_Checklist__c row : rows) {
            System.assertEquals('6r397fqtego', row.Application_Number__c,
                'Every row should inherit the Application Number rather than needing it repeated per document.');
        }

        Boolean sawUnlistedType = false;
        for (Document_Checklist__c row : rows) {
            if (row.Document_Type__c == 'Migration Certificate') { sawUnlistedType = true; }
        }
        System.assert(sawUnlistedType,
            'Document_Type__c is unrestricted, so a type outside the picklist should store as sent.');
    }

    @isTest
    static void testDocumentCanOverrideTheApplicationNumber() {
        Account acc = createAcademicProgramAccount();
        String json = baseJSONPrefix(acc.Id) + ',' +
            '"Documents":[' +
                '{"DocumentType":"Passport","DocumentName":"Passport","DocumentUploadUrl":"https://example.com/doc/p.pdf"},' +
                '{"DocumentType":"Passport","DocumentName":"Old passport","DocumentUploadUrl":"https://example.com/doc/p-old.pdf","ApplicationNumber":"LEGACY-9999"}' +
            '],' +
            '"PersonEducation":{"QualificationAfter10th":"PUC"}' +
        '}';

        Test.startTest();
        executeTest(json);
        Test.stopTest();

        Map<String, String> numberByDocument = new Map<String, String>();
        for (Document_Checklist__c row : [
            SELECT Document_Name__c, Application_Number__c FROM Document_Checklist__c
        ]) {
            numberByDocument.put(row.Document_Name__c, row.Application_Number__c);
        }
        System.assertEquals('6r397fqtego', numberByDocument.get('Passport'),
            'A document that sends no Application Number inherits the Application\'s.');
        System.assertEquals('LEGACY-9999', numberByDocument.get('Old passport'),
            'A document that sends its own Application Number keeps it.');
    }

    @isTest
    static void testBlankAndMissingDocumentEntriesAreIgnored() {
        Account acc = createAcademicProgramAccount();
        String json = baseJSONPrefix(acc.Id) + ',' +
            '"Documents":[' +
                '{"DocumentType":"Passport","DocumentName":"Passport","DocumentUploadUrl":"https://example.com/doc/passport.pdf"},' +
                '{"DocumentType":"","DocumentName":"","DocumentUploadUrl":""},' +
                '{}' +
            '],' +
            '"PersonEducation":{"QualificationAfter10th":"PUC"}' +
        '}';

        Test.startTest();
        executeTest(json);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Document_Checklist__c],
            'An entry carrying no type, name or URL is noise and should not create a blank row.');
    }

    @isTest
    static void testApplicantWithoutDocumentsStillSucceeds() {
        Account acc = createAcademicProgramAccount();

        Test.startTest();
        executeTest(generateJSONWithClass12(acc.Id));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Document_Checklist__c],
            'A payload with no Documents list must not create checklist rows.');
        System.assertEquals(1, [SELECT COUNT() FROM Application__c],
            'and must still create the applicant exactly as before.');
    }

    static void executeTest(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        req.requestBody = Blob.valueOf(jsonBody);
        ApplicantServiceV4.createApplicant();
    }

    static String baseJSONPrefix(String accountId) {
        return '{' +
            '"Contact":{"FirstName":"Test","LastName":"Student","Email":"test@example.com","Phone":"9999999999","GenderIdentity":"Male","Birthdate":"1995-01-01"},' +
            '"ParentContacts":[{"RelationshipType":"Father","FirstName":"John","LastName":"Doe"}],' +
            '"Address":{"Country":"India","City":"Bangalore"},' +
            '"Application":{"Program":"MBA","SignDate":"2024-12-01","Place":"Bangalore","ProgramLevel":"UG","ExternalApplicationNumber":"6r397fqtego","PassportPhoto":"base64string==",' +
                '"AadharCardUrl":"https://example.com/aadhar.pdf",' +
                '"Class12MarksheetUrl":"https://example.com/class12.pdf",' +
                '"Class10MarksheetUrl":"https://example.com/class10.pdf",' +
                '"DiplomaMarksheetUrl":"https://example.com/diploma.pdf",' +
                '"EntranceExaminationScorecardUrl":"https://example.com/entrance.pdf",' +
                '"GraduationMarksheetUrl":"https://example.com/graduation.pdf",' +
                '"PassportUrl":"https://example.com/passport.pdf",' +
                '"PassportPhotoUrl":"https://example.com/photo.jpg",' +
                '"SignatureUrl":"https://example.com/signature.png"},' +
            '"Certifications":[],' +
            '"EntranceExams":[]';
    }

    static String generateJSONWithClass12(String accountId) {
        return baseJSONPrefix(accountId) + ',' +
            '"PersonEducation":{' +
                '"QualificationAfter10th":"PUC",' +
                '"Class12SchoolName":"Delhi Public School",' +
                '"Class12Board":"Central Board Of Secondary Education (CBSE)",' +
                '"Class12PassingYear":"2012",' +
                '"Class12MarkingScheme":"Percentage",' +
                '"Class12PercentageCGPA":"89.8"' +
            '}' +
        '}';
    }

    static String generateJSONWithDiploma(String accountId) {
        return baseJSONPrefix(accountId) + ',' +
            '"PersonEducation":{' +
                '"QualificationAfter10th":"Diploma",' +
                '"DiplomaInstituteName":"Polytechnic College",' +
                '"DiplomaBoardUniversity":"State Board",' +
                '"DiplomaPassingYear":"2013",' +
                '"DiplomaMarkingScheme":"Percentage",' +
                '"DiplomaPercentageCGPA": "78.0"' +
            '}' +
        '}';
    }

    static String generateJSONWithUGOnly(String accountId) {
        return baseJSONPrefix(accountId) + ',' +
            '"PersonEducation":{' +
                '"UGUniversityName":"XYZ University",' +
                '"UGDegreeName":"B.Sc",' +
                '"UGPassingYear":"2016",' +
                '"UGResultStatus":"Pass",' +
                '"UGMarkingScheme":"Percentage",' +
                '"UGPercentageCGPA":"76.5"' +
            '}' +
        '}';
    }

    static String generateJSONWithProfessionalOnly(String accountId) {
        return baseJSONPrefix(accountId) + ',' +
            '"PersonEducation":{' +
                '"ProfessionalCourseName":"AI Certification",' +
                '"ProfessionalCoursePassingYear":"2021",' +
                '"ProfessionalCourseResultStatus":"Completed",' +
                '"ProfessionalCoursePercentage":"88.5"' +
            '}' +
        '}';
    }
    
    @isTest
static void testProcessDocuments() {
    // Create test contact
    Contact testContact = new Contact(
        FirstName = 'John',
        LastName = 'Doe'
    );
    insert testContact;
    
    // Create test data wrapper
    ApplicantWrapperV4 data = new ApplicantWrapperV4();
    data.Contact = new ApplicantWrapperV4.ContactData();
    data.Contact.FirstName = 'John';
    data.Contact.LastName = 'Doe';
    
    data.Application = new ApplicantWrapperV4.ApplicationData();
    data.Application.Program = 'MBA';
    data.Application.PassportPhoto = EncodingUtil.base64Encode(Blob.valueOf('test passport photo data'));
    data.Application.Class10Marksheet = EncodingUtil.base64Encode(Blob.valueOf('test marksheet data'));
    data.Application.Signature = EncodingUtil.base64Encode(Blob.valueOf('test signature data'));
    data.Application.AadharCard = EncodingUtil.base64Encode(Blob.valueOf('test aadhar data'));
    data.Application.Class12Marksheet = EncodingUtil.base64Encode(Blob.valueOf('test class12 data'));
    data.Application.GraduationMarksheet = EncodingUtil.base64Encode(Blob.valueOf('test graduation data'));
    data.Application.DiplomaMarksheet = EncodingUtil.base64Encode(Blob.valueOf('test diploma data'));
    data.Application.EntranceExaminationScorecard = EncodingUtil.base64Encode(Blob.valueOf('test entrance data'));
    data.Application.Passport = EncodingUtil.base64Encode(Blob.valueOf('test passport data'));
    
    fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] { ContentVersion.SObjectType });
    
    Test.startTest();
    ApplicantServiceV4.processDocuments(data, testContact, uow);
    uow.commitWork();
    Test.stopTest();
}

@isTest
static void testProcessDocumentsWithNullOptionalFields() {
    // Create test contact
    Contact testContact = new Contact(
        FirstName = 'Jane',
        LastName = 'Smith'
    );
    insert testContact;
    
    // Create test data wrapper with minimal required fields
    ApplicantWrapperV4 data = new ApplicantWrapperV4();
    data.Contact = new ApplicantWrapperV4.ContactData();
    data.Contact.FirstName = 'Jane';
    data.Contact.LastName = 'Smith';
    
    data.Application = new ApplicantWrapperV4.ApplicationData();
    data.Application.Program = 'BCA';
    data.Application.PassportPhoto = EncodingUtil.base64Encode(Blob.valueOf('test passport photo data'));
    data.Application.Class10Marksheet = EncodingUtil.base64Encode(Blob.valueOf('test marksheet data'));
    // Leave other optional fields as null to test uploadDocumentIfPresent with null values
    
    fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] { ContentVersion.SObjectType });
    
    Test.startTest();
    ApplicantServiceV4.processDocuments(data, testContact, uow);
    uow.commitWork();
    Test.stopTest();
}

@isTest
static void testUploadDocumentIfPresentWithContent() {
    // Create test contact
    Contact testContact = new Contact(
        FirstName = 'Test',
        LastName = 'User'
    );
    insert testContact;
    
    // Create test data wrapper
    ApplicantWrapperV4 data = new ApplicantWrapperV4();
    data.Contact = new ApplicantWrapperV4.ContactData();
    data.Contact.FirstName = 'Test';
    data.Contact.LastName = 'User';
    
    data.Application = new ApplicantWrapperV4.ApplicationData();
    data.Application.Program = 'MCA';
    
    String base64Content = EncodingUtil.base64Encode(Blob.valueOf('test document content'));
    fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] { ContentVersion.SObjectType });
    
    Test.startTest();
    ApplicantServiceV4.uploadDocumentIfPresent(base64Content, 'TestDocument', testContact, uow, data);
    uow.commitWork();
    Test.stopTest();
}

@isTest
static void testUploadDocumentIfPresentWithNullContent() {
    // Create test contact
    Contact testContact = new Contact(
        FirstName = 'Test',
        LastName = 'User'
    );
    insert testContact;
    
    // Create test data wrapper
    ApplicantWrapperV4 data = new ApplicantWrapperV4();
    data.Contact = new ApplicantWrapperV4.ContactData();
    data.Contact.FirstName = 'Test';
    data.Contact.LastName = 'User';
    
    data.Application = new ApplicantWrapperV4.ApplicationData();
    data.Application.Program = 'MCA';
    
    fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] { ContentVersion.SObjectType });
    
    Test.startTest();
    ApplicantServiceV4.uploadDocumentIfPresent(null, 'TestDocument', testContact, uow, data);
    uow.commitWork();
    Test.stopTest();
}

@isTest
static void testMaskValueAadhar() {
    Test.startTest();
    String result = ApplicantServiceV4.maskValue('123456789012', 'Aadhar');
    Test.stopTest();
}

@isTest
static void testMaskValueDEB() {
    Test.startTest();
    String result = ApplicantServiceV4.maskValue('ABCD1234', 'DEB');
    Test.stopTest();
}

@isTest
static void testMaskValueABC() {
    Test.startTest();
    String result = ApplicantServiceV4.maskValue('ABCD5678', 'ABC');
    Test.stopTest();
}

@isTest
static void testMaskValueDEBABC() {
    Test.startTest();
    String result = ApplicantServiceV4.maskValue('ABCD9876', 'DEBABC');
    Test.stopTest();
}

@isTest
static void testMaskValuePassport() {
    Test.startTest();
    String result = ApplicantServiceV4.maskValue('A1234567', 'Passport');
    Test.stopTest();
}

@isTest
static void testMaskValueInvalidInput() {
    Test.startTest();
    try {
        ApplicantServiceV4.maskValue('123', 'InvalidType');
    } catch (ApplicantServiceV4.ApplicationException e) {
        // Expected exception
    }
    Test.stopTest();
}

@isTest
static void testMaskValueNullInput() {
    Test.startTest();
    try {
        ApplicantServiceV4.maskValue(null, 'Aadhar');
    } catch (ApplicantServiceV4.ApplicationException e) {
        // Expected exception
    }
    Test.stopTest();
}

@isTest
static void testMaskValueShortAadhar() {
    Test.startTest();
    try {
        ApplicantServiceV4.maskValue('12345', 'Aadhar');
    } catch (ApplicantServiceV4.ApplicationException e) {
        // Expected exception for insufficient length
    }
    Test.stopTest();
}

}