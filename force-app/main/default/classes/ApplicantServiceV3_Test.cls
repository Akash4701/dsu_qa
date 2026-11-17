@isTest
private class ApplicantServiceV3_Test {

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

    static void executeTest(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        req.requestBody = Blob.valueOf(jsonBody);
        ApplicantServiceV3.createApplicant();
    }

    static String baseJSONPrefix(String accountId) {
        return '{' +
            '"Contact":{"FirstName":"Test","LastName":"Student","Email":"test@example.com","Phone":"9999999999","GenderIdentity":"Male","Birthdate":"1995-01-01"},' +
            '"ParentContacts":[{"RelationshipType":"Father","FirstName":"John","LastName":"Doe"}],' +
            '"Address":{"Country":"India","City":"Bangalore"},' +
            '"Application":{"Program":"MBA","SignDate":"2024-12-01","Place":"Bangalore","ProgramLevel":"UG","ExternalApplicationNumber":"6r397fqtego","PassportPhoto":"base64string=="},' +
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
    ApplicantWrapperV3 data = new ApplicantWrapperV3();
    data.Contact = new ApplicantWrapperV3.ContactData();
    data.Contact.FirstName = 'John';
    data.Contact.LastName = 'Doe';
    
    data.Application = new ApplicantWrapperV3.ApplicationData();
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
    ApplicantServiceV3.processDocuments(data, testContact, uow);
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
    ApplicantWrapperV3 data = new ApplicantWrapperV3();
    data.Contact = new ApplicantWrapperV3.ContactData();
    data.Contact.FirstName = 'Jane';
    data.Contact.LastName = 'Smith';
    
    data.Application = new ApplicantWrapperV3.ApplicationData();
    data.Application.Program = 'BCA';
    data.Application.PassportPhoto = EncodingUtil.base64Encode(Blob.valueOf('test passport photo data'));
    data.Application.Class10Marksheet = EncodingUtil.base64Encode(Blob.valueOf('test marksheet data'));
    // Leave other optional fields as null to test uploadDocumentIfPresent with null values
    
    fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] { ContentVersion.SObjectType });
    
    Test.startTest();
    ApplicantServiceV3.processDocuments(data, testContact, uow);
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
    ApplicantWrapperV3 data = new ApplicantWrapperV3();
    data.Contact = new ApplicantWrapperV3.ContactData();
    data.Contact.FirstName = 'Test';
    data.Contact.LastName = 'User';
    
    data.Application = new ApplicantWrapperV3.ApplicationData();
    data.Application.Program = 'MCA';
    
    String base64Content = EncodingUtil.base64Encode(Blob.valueOf('test document content'));
    fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] { ContentVersion.SObjectType });
    
    Test.startTest();
    ApplicantServiceV3.uploadDocumentIfPresent(base64Content, 'TestDocument', testContact, uow, data);
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
    ApplicantWrapperV3 data = new ApplicantWrapperV3();
    data.Contact = new ApplicantWrapperV3.ContactData();
    data.Contact.FirstName = 'Test';
    data.Contact.LastName = 'User';
    
    data.Application = new ApplicantWrapperV3.ApplicationData();
    data.Application.Program = 'MCA';
    
    fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] { ContentVersion.SObjectType });
    
    Test.startTest();
    ApplicantServiceV3.uploadDocumentIfPresent(null, 'TestDocument', testContact, uow, data);
    uow.commitWork();
    Test.stopTest();
}

@isTest
static void testMaskValueAadhar() {
    Test.startTest();
    String result = ApplicantServiceV3.maskValue('123456789012', 'Aadhar');
    Test.stopTest();
}

@isTest
static void testMaskValueDEB() {
    Test.startTest();
    String result = ApplicantServiceV3.maskValue('ABCD1234', 'DEB');
    Test.stopTest();
}

@isTest
static void testMaskValueABC() {
    Test.startTest();
    String result = ApplicantServiceV3.maskValue('ABCD5678', 'ABC');
    Test.stopTest();
}

@isTest
static void testMaskValueDEBABC() {
    Test.startTest();
    String result = ApplicantServiceV3.maskValue('ABCD9876', 'DEBABC');
    Test.stopTest();
}

@isTest
static void testMaskValuePassport() {
    Test.startTest();
    String result = ApplicantServiceV3.maskValue('A1234567', 'Passport');
    Test.stopTest();
}

@isTest
static void testMaskValueInvalidInput() {
    Test.startTest();
    try {
        ApplicantServiceV3.maskValue('123', 'InvalidType');
    } catch (ApplicantServiceV3.ApplicationException e) {
        // Expected exception
    }
    Test.stopTest();
}

@isTest
static void testMaskValueNullInput() {
    Test.startTest();
    try {
        ApplicantServiceV3.maskValue(null, 'Aadhar');
    } catch (ApplicantServiceV3.ApplicationException e) {
        // Expected exception
    }
    Test.stopTest();
}

@isTest
static void testMaskValueShortAadhar() {
    Test.startTest();
    try {
        ApplicantServiceV3.maskValue('12345', 'Aadhar');
    } catch (ApplicantServiceV3.ApplicationException e) {
        // Expected exception for insufficient length
    }
    Test.stopTest();
}

}