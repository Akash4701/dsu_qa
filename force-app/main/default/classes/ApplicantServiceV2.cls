@RestResource(urlMapping='/ApplicantServiceV2')
global with sharing class ApplicantServiceV2 {

    @HttpPost
    global static void createApplicant() {
        RestRequest req = RestContext.request;
        String jsonBody = req.requestBody.toString();

        ApplicantWrapperV2 data = (ApplicantWrapperV2) JSON.deserialize(jsonBody, ApplicantWrapperV2.class);

        // Set of sObject types involved in the transaction
        List<Schema.SObjectType> objectTypes = new List<Schema.SObjectType> {
            Contact.SObjectType,
            Application__c.SObjectType,
            Person_Education__c.SObjectType,
            Relationship__c.SObjectType,
            ContentVersion.SObjectType
        };

        fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(objectTypes);

        // 1. Applicant Contact
        Contact applicant = new Contact();
        applicant.Salutation = data.Contact.Title;
        applicant.FirstName = data.Contact.FirstName;
        applicant.LastName = data.Contact.LastName;
        applicant.Email = data.Contact.Email;
        applicant.Phone = data.Contact.Phone;
        applicant.GenderIdentity = data.Contact.GenderIdentity;
        applicant.Birthdate = data.Contact.Birthdate;
        applicant.Marital_Status__c = data.Contact.MaritalStatus;
        applicant.Religion__c = data.Contact.Religion;
        applicant.Nationality__c = data.Contact.Nationality;
        applicant.Annual_Family_Income__c = data.Contact.AnnualFamilyIncome;
        applicant.MailingStreet = data.Address.Street;
        applicant.MailingPostalCode = data.Address.PostalCode;
        applicant.MailingCountry = data.Address.Country;
        applicant.AccountId = (Id) getAcademicProgramAccId(data.Application.Program);
        uow.registerNew(applicant);

        // 2. Parent Contacts
        if (data.ParentContacts != null) {
            for (ApplicantWrapperV2.ParentInfo parent : data.ParentContacts) {
                Relationship__c parentContact = new Relationship__c();
                parentContact.Title__c = parent.Title;
                parentContact.First_Name__c = parent.FirstName;
                parentContact.Last_Name__c = parent.LastName;
                parentContact.Relationship_Type__c = parent.RelationshipType;
                uow.registerNew(parentContact, Relationship__c.Contact__c, applicant);
            }
        }

        // 3. Education
        if (data.PersonEducation != null) {
            Person_Education__c edu = new Person_Education__c();
            edu.After_Xth_SSC_Qualification__c = data.PersonEducation.QualificationAfter10th;
            uow.registerNew(edu, Person_Education__c.Contact__c, applicant);
        }

        // 4. Application
        if (data.Application != null) {
            Application__c app = new Application__c();
            app.Program__c = data.Application.Program;
            app.Program_Level__c = data.Application.ProgramLevel;
            app.Fee_Preference__c = data.Application.FeePreference;
            app.Have_you_given_any_Entrance_Exam__c = data.Application.EntranceExam;
            app.Declaration__c = data.Application.Declaration;
            app.Date__c = data.Application.SignDate;
            app.Place__c = data.Application.Place;
            app.External_Application_Number__c = data.Application.ExternalApplicationNumber;
            uow.registerNew(app, Application__c.ContactId__c, applicant);
        }
        
        // 5. Upload Files as ContentVersion (linked to applicant Contact)
        if (data.Application.PassportPhoto != null) {
            ContentVersion passport = new ContentVersion();
            passport.Title = data.Application.Program + '_PassportPhoto_' + data.Contact.FirstName + '_' + data.Contact.LastName;
            passport.PathOnClient = data.Application.Program + '_Passport_' + DateTime.now().getTime() + '.jpg';
            passport.VersionData = EncodingUtil.base64Decode(data.Application.PassportPhoto);
            passport.Origin = 'H';
            passport.FirstPublishLocationId = applicant.Id;
            uow.registerNew(passport, ContentVersion.FirstPublishLocationId,applicant);
        }

        if (data.Application.Class10Marksheet != null) {
            ContentVersion marksheet = new ContentVersion();
            marksheet.Title = data.Application.Program + '_Class10Marksheet_' + data.Contact.FirstName + '_' + data.Contact.LastName;
            marksheet.PathOnClient = data.Application.Program + '_Class10_' + DateTime.now().getTime() + '.pdf';
            marksheet.VersionData = EncodingUtil.base64Decode(data.Application.Class10Marksheet);
            marksheet.Origin = 'H';
            marksheet.FirstPublishLocationId = applicant.Id;
            uow.registerNew(marksheet, ContentVersion.FirstPublishLocationId,applicant);
        }

        // Commit the Unit of Work
        uow.commitWork();

        RestContext.response.statusCode = 201;
        RestContext.response.responseBody = Blob.valueOf('Applicant created successfully');
    }
    
    public static String getAcademicProgramAccId(String programAlias) {
        Account accId = [
            SELECT Id
            FROM Account
            WHERE RecordType.Name = 'Academic Program' 
            AND Program_Alias__c = :programAlias
            LIMIT 1
        ];
        return accId.Id;
    }
    
}