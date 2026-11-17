@RestResource(urlMapping='/ApplicantServiceV3')
global with sharing class ApplicantServiceV3 {

    @HttpPost
    global static void createApplicant() {
        Boolean makeDocUploadNonMandatory = True;
        RestRequest req = RestContext.request;
        String jsonBody = req.requestBody.toString();
        system.debug(jsonBody);
        ApplicantWrapperV3 data = (ApplicantWrapperV3) JSON.deserialize(jsonBody, ApplicantWrapperV3.class);

        
        List<Schema.SObjectType> objectTypes = new List<Schema.SObjectType> {
            Contact.SObjectType,
            Application__c.SObjectType,
            Person_Education__c.SObjectType,
            Relationship__c.SObjectType,
            ContentVersion.SObjectType,
            Certification_Program__c.SObjectType,
            Entrance_Examination__c.SObjectType
        };

        fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(objectTypes);

        Contact applicant = new Contact();
        applicant.Salutation = data.Contact.Title;
        applicant.FirstName = data.Contact.FirstName;
        if(data.Contact.LastName!=Null || data.Contact.LastName == ''){
            applicant.LastName = data.Contact.LastName;
        }
        else{
            applicant.LastName = '.';
        }
        applicant.Email = data.Contact.Email;
        applicant.Contact_Phone__c = data.Contact.Phone;
        applicant.GenderIdentity = data.Contact.GenderIdentity;
        applicant.Birthdate = data.Contact.Birthdate;
        applicant.Marital_Status__c = data.Contact.MaritalStatus;
        applicant.Religion__c = data.Contact.Religion;
        applicant.Nationality__c = data.Contact.Nationality;
        applicant.Annual_Family_Income__c = data.Contact.AnnualFamilyIncome;
        applicant.Alternate_Mobile__c = data.Contact.MobilePhone;
        applicant.Contact_Email__c = data.Contact.ContactEmail;
        applicant.Blood_Group__c = data.Contact.BloodGroup;
        applicant.Student_Category__c = data.Contact.StudentCategory;
        if(!String.isBlank(data.Contact.AadharNumber)){
            applicant.Unmasked_aadhar__c = maskValue(data.Contact.AadharNumber,'Aadhar');
        }
        applicant.Aadhar_Number__c = data.Contact.AadharNumber;
        if(!String.isBlank(data.Contact.PassportNumber)){
            applicant.Unmasked_Passport_Number__c = maskValue(data.Contact.PassportNumber,'Passport');
        }
        applicant.Passport_Number__c = data.Contact.PassportNumber;
        applicant.Place_of_Issue__c = data.Contact.PlaceOfIssue;
        applicant.Date_of_Expiry__c = data.Contact.DateOfExpiry;
        applicant.Occupation__c = data.Contact.Occupation;
        applicant.DEB_ID__c = data.Contact.DebID;
        if(!String.isBlank(data.Contact.DebID)){
            applicant.unmasked_deb__c = maskValue(data.Contact.DebID,'DEB');
        }
        applicant.DEB_Name__c = data.Contact.DebName;
        applicant.DEB_Gender__c = data.Contact.DebGender;
        applicant.DEB_Date_of_birth__c = data.Contact.DebDateOfBirth;
        applicant.DEB_University__c = data.Contact.DebUniversity;
        applicant.DEB_Program__c = data.Contact.DebProgram;
        applicant.DEB_ABCID__c = data.Contact.DEBABCID;
        if(!String.isBlank(data.Contact.DEBABCID)){
            applicant.unmasked_deb_ABC__c = maskValue(data.Contact.DEBABCID,'DEBABC');
        }
        applicant.DEB_Details__c = data.Contact.DebDetails;
        applicant.DEB_Status__c = data.Contact.DebStatus;
        applicant.ABC_ID__c = data.Contact.ABCID;
        if(!String.isBlank(data.Contact.ABCID)){
            applicant.unmasked_abcId__c = maskValue(data.Contact.ABCID,'ABC');
        }
        applicant.Declaration__c = data.Contact.Declaration;
        applicant.MailingPostalCode = data.Address.PostalCode;

            applicant.OtherStreet = data.Address.MailingStreet;
 

       
            applicant.OtherPostalCode = data.Address.MailingPostalCode;
         
   
            applicant.OtherCountry = data.Address.MailingCountry;
        applicant.Locality__c = data.Address.Locality;
        applicant.MailingState = data.Address.State;
        applicant.MailingCity = data.Address.City;
        applicant.MailingStreet = data.Address.Street;
        applicant.MailingCountry = data.Address.Country;
        applicant.OtherState = data.Address.MailingState;
        applicant.District__c = data.Address.MailingDistrict;
        applicant.OtherCity = data.Address.MailingCity;
        applicant.Address_Line_2__c = data.Address.MailingAddressLine2;
        applicant.Mailing_Address_Line_2__c = data.Address.AddressLine2;
        applicant.Mailing_District__c = data.Address.District;
        applicant.AccountId = (Id) getDSUAccount();
        uow.registerNew(applicant);

        
        if (data.ParentContacts != null) {
            for (ApplicantWrapperV3.ParentInfo parent : data.ParentContacts) {
                Relationship__c parentContact = new Relationship__c();
                parentContact.Title__c = parent.Title;
                parentContact.First_Name__c = parent.FirstName;
                parentContact.Last_Name__c = parent.LastName;
                parentContact.Relationship_Type__c = parent.RelationshipType;
                parentContact.MobilePhone__c = parent.MobilePhone;
                parentContact.Contact_Email__c = parent.ContactEmail;
                parentContact.Occupation__c = parent.Occupation;
                uow.registerNew(parentContact, Relationship__c.Contact__c, applicant);
            }
        }

        
        if (data.PersonEducation != null) {
            Person_Education__c edu = new Person_Education__c();
            edu.After_Xth_SSC_Qualification__c = data.PersonEducation.QualificationAfter10th;
            edu.Class_Xth_SSC_School_Name__c = data.PersonEducation.Class10SchoolName;
            edu.Class_Xth_SSC_Board__c = data.PersonEducation.Class10Board;
            edu.Class_Xth_SSC_Year_of_Passing__c = data.PersonEducation.Class10PassingYear;
            edu.Class_Xth_SSC_Marking_Scheme__c = data.PersonEducation.Class10MarkingScheme;
            edu.Class_Xth_SSC_Percentage_CGPA__c = data.PersonEducation.Class10PercentageCGPA;
            edu.Class_XIIth_HSC_School_Name__c = data.PersonEducation.Class12SchoolName;
            edu.Class_XIIth_HSC_Board__c = data.PersonEducation.Class12Board;
            edu.Class_XIIth_HSC_Year_of_Passing__c = data.PersonEducation.Class12PassingYear;
            edu.Class_XIIth_HSC_Marking_Scheme__c = data.PersonEducation.Class12MarkingScheme;
            edu.Class_XIIth_HSC_Percentage_CGPA__c = data.PersonEducation.Class12PercentageCGPA;
            edu.Diploma_Institute_Name__c = data.PersonEducation.DiplomaInstituteName;
            edu.Diploma_Board_University__c = data.PersonEducation.DiplomaBoardUniversity;
            edu.Diploma_Year_of_Passing__c = data.PersonEducation.DiplomaPassingYear;
            edu.Diploma_Marking_Scheme__c = data.PersonEducation.DiplomaMarkingScheme;
            edu.Diploma_Percentage_CGPA__c = data.PersonEducation.DiplomaPercentageCGPA;
            edu.UG_University_Name__c = data.PersonEducation.UGUniversityName;
            edu.UG_Name_of_Degree__c = data.PersonEducation.UGDegreeName;
            edu.UG_Year_of_Passing__c = data.PersonEducation.UGPassingYear;
            edu.UG_Result_Status__c = data.PersonEducation.UGResultStatus;
            edu.UG_Marking_Scheme__c = data.PersonEducation.UGMarkingScheme;
            edu.UG_Percentage_CGPA__c = data.PersonEducation.UGPercentageCGPA;
            edu.Sem_Year_1_Obtained_Marks__c = data.PersonEducation.Sem1ObtainedMarks;
            edu.Sem_Year_1_Maximum_Marks__c = data.PersonEducation.Sem1MaximumMarks;
            edu.Sem_Year_1_Percentage__c = data.PersonEducation.Sem1Percentage;
            edu.Sem_Year_2_Obtained_Marks__c = data.PersonEducation.Sem2ObtainedMarks;
            edu.Sem_Year_2_Maximum_Marks__c = data.PersonEducation.Sem2MaximumMarks;
            edu.Sem_Year_2_Percentage__c = data.PersonEducation.Sem2Percentage;
            edu.Sem_Year_3_Obtained_Marks__c = data.PersonEducation.Sem3ObtainedMarks;
            edu.Sem_Year_3_Maximum_Marks__c = data.PersonEducation.Sem3MaximumMarks;
            edu.Sem_Year_3_Percentage__c = data.PersonEducation.Sem3Percentage;
            edu.Sem_Year_4_Obtained_Marks__c = data.PersonEducation.Sem4ObtainedMarks;
            edu.Sem_Year_4_Maximum_Marks__c = data.PersonEducation.Sem4MaximumMarks;
            edu.Sem_Year_4_Percentage__c = data.PersonEducation.Sem4Percentage;
            edu.Sem_5_Obtained_Marks__c = data.PersonEducation.Sem5ObtainedMarks;
            edu.Sem_5_Maximum_Marks__c = data.PersonEducation.Sem5MaximumMarks;
            edu.Sem_5_Percentage__c = data.PersonEducation.Sem5Percentage;
            edu.Sem_6_Obtained_Marks__c = data.PersonEducation.Sem6ObtainedMarks;
            edu.Sem_6_Maximum_Marks__c = data.PersonEducation.Sem6MaximumMarks;
            edu.Sem_6_Percentage__c = data.PersonEducation.Sem6Percentage;
            edu.Sem_7_Obtained_Marks__c = data.PersonEducation.Sem7ObtainedMarks;
            edu.Sem_7_Maximum_Marks__c = data.PersonEducation.Sem7MaximumMarks;
            edu.Sem_7_Percentage__c = data.PersonEducation.Sem7Percentage;
            edu.Sem_8_Obtained_Marks__c = data.PersonEducation.Sem8ObtainedMarks;
            edu.Sem_8_Maximum_Marks__c = data.PersonEducation.Sem8MaximumMarks;
            edu.Sem_8_Percentage__c = data.PersonEducation.Sem8Percentage;
            
            uow.registerNew(edu, Person_Education__c.Contact__c, applicant);
        }

        
        if (data.Application != null) {
            Application__c app = new Application__c();
            app.Program__c = data.Application.Program;
            app.AccountId__c = (Id) getAcademicProgramAccId(data.Application.Program);
            app.Program_Level__c = data.Application.ProgramLevel;
            app.Fee_Preference__c = data.Application.FeePreference;
            app.Have_you_given_any_Entrance_Exam__c = data.Application.EntranceExam;
            app.Declaration__c = data.Application.Declaration;
            app.Date__c = data.Application.SignDate;
            app.Place__c = data.Application.Place;
            app.Specialization__c = data.Application.Specialization;
            app.External_Application_Number__c = data.Application.ExternalApplicationNumber;
            app.Application_Owner__c=data.Application.ApplicationOwner;
            app.Registration_Campaign__c=data.Application.RegistrationCampaign;
            app.UTR_Number__c=data.Application.UTRNumber;
            app.Amount__c = data.Application.Amount;
            app.CRM_Receipt_Number__c = data.Application.CRMReceiptNumber;
            app.Transaction_ID__c = data.Application.TransactionId;
            app.Transaction_Date__c = data.Application.TransactionDate;
            app.Payment_Method__c = data.Application.ModeOfPayment;
            if(data.Application.ProgramPlanCode!=Null && data.Application.ProgramPlanCode != ''){
            app.Program_Plan__c = getProgramPlan(data.Application.ProgramPlanCode);
                }
            if( data.Contact.DebID == Null || data.Contact.DebID ==''){
                app.Status__c = 'Application on hold';
            }
            
            uow.registerNew(app, Application__c.ContactId__c, applicant);
        }
        

        
        if(!makeDocUploadNonMandatory){
            processDocuments(data, applicant, uow);
        }

        uow.commitWork();
        if(data.Address.SameAsCorrespondence !=Null){
           if(data.Address.SameAsCorrespondence !=Null){
            hed__Address__c addrs = [SELECT Id,Permanent_Address_Same_As_Correspondence__c FROM hed__Address__c WHERE hed__Parent_Contact__c = :Applicant.id LIMIT 1];
            addrs.Permanent_Address_Same_As_Correspondence__c = data.Address.SameAsCorrespondence;
            update addrs;
        }
        }
        // PKDSU-243: see ApplicantServiceV4 - a photo that cannot be published must not take the
        // whole import down with it, so an empty result simply leaves the field unset.
        String passportPhotoUrl = ken42_CreateContentVersion.createContentVersion(
            data.Application.Program + '_PassportPhoto_' + data.Contact.FirstName + '_' + data.Contact.LastName,
            data.Application.PassportPhoto,
            applicant.Id
        );
        if (String.isNotBlank(passportPhotoUrl)) {
            applicant.Passport_Size_Photo__c = passportPhotoUrl;
        }
        update applicant;
        
        RestContext.response.statusCode = 201;
        RestContext.response.responseBody = Blob.valueOf(
    'Applicant created successfully.\n' +
    'External Application Number: ' + data.Application.ExternalApplicationNumber
);
    }
    
    @testVisible
    private static void processDocuments(ApplicantWrapperV3 data, Contact applicant, fflib_SObjectUnitOfWork uow) {
        
        
            ContentVersion passport = new ContentVersion();
            passport.Title = data.Application.Program + '_PassportPhoto_' + data.Contact.FirstName + '_' + data.Contact.LastName;
            passport.PathOnClient = data.Application.Program + '_Passport_' + DateTime.now().getTime() + '.jpg';
            passport.VersionData = EncodingUtil.base64Decode(data.Application.PassportPhoto);
            passport.Origin = 'H';
            passport.FirstPublishLocationId = applicant.Id;
            uow.registerNew(passport, ContentVersion.FirstPublishLocationId, applicant);
        

        
            ContentVersion marksheet = new ContentVersion();
            marksheet.Title = data.Application.Program + '_Class10Marksheet_' + data.Contact.FirstName + '_' + data.Contact.LastName;
            marksheet.PathOnClient = data.Application.Program + '_Class10_' + DateTime.now().getTime() + '.pdf';
            marksheet.VersionData = EncodingUtil.base64Decode(data.Application.Class10Marksheet);
            marksheet.Origin = 'H';
            marksheet.FirstPublishLocationId = applicant.Id;
            uow.registerNew(marksheet, ContentVersion.FirstPublishLocationId, applicant);
        
        
        
        uploadDocumentIfPresent(data.Application.Signature, 'Signature', applicant, uow, data);
        uploadDocumentIfPresent(data.Application.AadharCard, 'AadharCard', applicant, uow, data);
        uploadDocumentIfPresent(data.Application.Class12Marksheet, 'Class12Marksheet', applicant, uow, data);
        uploadDocumentIfPresent(data.Application.GraduationMarksheet, 'GraduationMarksheet', applicant, uow, data);
        uploadDocumentIfPresent(data.Application.DiplomaMarksheet, 'DiplomaMarksheet', applicant, uow, data);
        uploadDocumentIfPresent(data.Application.EntranceExaminationScorecard, 'EntranceExamScorecard', applicant, uow, data);
        uploadDocumentIfPresent(data.Application.Passport, 'Passport', applicant, uow, data);
    }
    
    @testVisible
    private static void uploadDocumentIfPresent(String base64Content, String docType, Contact applicant, 
                                                fflib_SObjectUnitOfWork uow, ApplicantWrapperV3 data) {
        if (base64Content != null) {
            ContentVersion doc = new ContentVersion();
            doc.Title = data.Application.Program + '_' + docType + '_' + data.Contact.FirstName + '_' + data.Contact.LastName;
            doc.PathOnClient = data.Application.Program + '_' + docType + '_' + DateTime.now().getTime() + '.pdf';
            doc.VersionData = EncodingUtil.base64Decode(base64Content);
            doc.Origin = 'H';
            doc.FirstPublishLocationId = applicant.Id;
            uow.registerNew(doc, ContentVersion.FirstPublishLocationId, applicant);
        }
    }
    public static String maskValue(String input, String idType) {
    String maskedValue;
    
    if (input != null && input.length() >= 12 && idType == 'Aadhar') {
        maskedValue = 'XXXX' + input.substring(input.length() - 4);
    } else if (input != null && idType == 'DEB') {
        maskedValue = 'XXXX' + input.substring(input.length() - 4);
    } else if (input != null && idType == 'ABC') {
        maskedValue = 'XXXX' + input.substring(input.length() - 4);
    } 
      else if (input != null && idType == 'DEBABC') {
        maskedValue = 'XXXX' + input.substring(input.length() - 4);
    }else if (input != null && idType == 'Passport'){
         maskedValue = 'XXXX' + input.substring(input.length() - 4); 
      }else {
        throw new ApplicationException('Invalid or insufficient input for masking.');
    }
    
    return maskedValue;
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
    
    public static String getDSUAccount() {
        String DSUId = [SELECT Record_Id__c FROM DSU_Name__c WHERE Name = 'Dayananda Sagar University' LIMIT 1].Record_Id__c;
        Account accId = [
            SELECT Id
            FROM Account
            WHERE RecordType.Name = 'Educational Institution' 
            AND Id =:DSUId 
            LIMIT 1
        ];
        return accId.Id;
    }
    public static String getProgramPlan(String programCode){
        hed__Program_Plan__c ProgramPlan = [
            SELECT Id
            FROM 	hed__Program_Plan__c
            WHERE Program_Plan_Code__c = :programCode
            LIMIT 1
        ];
        return ProgramPlan.Id;
    }
    public class ApplicationException extends Exception {}
}