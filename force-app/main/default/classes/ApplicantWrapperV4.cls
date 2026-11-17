public class ApplicantWrapperV4 {
    public ApplicationData Application;
    public ContactData Contact;
    public List<ParentInfo> ParentContacts;
    public AddressData Address;
    public EducationData PersonEducation;
    /**
     * Documents submitted with the application, as a list because one application can
     * carry many — including several of the same Document Type (two marksheets for a
     * two-part qualification, a re-upload, a multi-page scan). The ApplicationData
     * fields below hold at most one URL per type and cannot express that; each entry
     * here becomes its own Document_Checklist__c row against the Application.
     */
    public List<DocumentInfo> Documents;
    
    public class ApplicationData {
        public String Program;
        public String ProgramLevel;
        public String Elective;
        public String FeePreference;
        public String EntranceExam;
        public String Declaration;
        public Date SignDate;
        public String Place;
        public String PassportPhoto;
        public String Class10Marksheet;
        public String Specialization;
        public String Signature;
        public String AadharCard;
        public String Class12Marksheet;
        public String GraduationMarksheet;
        public String DiplomaMarksheet;
        public String EntranceExaminationScorecard;
        public String Passport;
        public String ExternalApplicationNumber;
        public String ProgramPlanCode;
        public Decimal Amount;
        public String TransactionId;
        public Date TransactionDate;
        public String ModeOfPayment;
        public String CRMReceiptNumber;
        public String ApplicationOwner;
        public String RegistrationCampaign;
        public String UTRNumber;

        // Document URLs mapped to the Url fields on Application__c
        public String AadharCardUrl;
        public String Class12MarksheetUrl;
        public String Class10MarksheetUrl;
        public String DiplomaMarksheetUrl;
        public String EntranceExaminationScorecardUrl;
        public String GraduationMarksheetUrl;
        public String PassportUrl;
        //public String PassportPhotoUrl;
        public String SignatureUrl;

    }

    public class ContactData {
        public String Title;
        public String FirstName;
        public String LastName;
        public String Email;
        public String Phone;
        public String GenderIdentity;
        public Date Birthdate;
        public String MaritalStatus;
        public String Religion;
        public String Nationality;
        public Decimal AnnualFamilyIncome;
        public String Name;
        public String PassportPhoto;
        public String Class10Marksheet;
        public String MobilePhone;
        public String ContactEmail;
        public String BloodGroup;
        public String StudentCategory;
        public String AadharNumber;
        public String PassportNumber;
        public String PlaceOfIssue;
        public Date DateOfExpiry;
        public String Occupation;
        public String DebID;
        public String DebName;
        public String DebGender;
        public Date DebDateOfBirth;
        public String DebUniversity;
        public String DebProgram;
        public String DebABCID;
        public String DebDetails;
        public String DebStatus;
        public String Signature;
        public String AadharCard;
        public String Class12Marksheet;
        public String GraduationMarksheet;
        public String DiplomaMarksheet;
        public String EntranceExaminationScorecard;
        public String Passport;
        public String Declaration;
        public String ABCID;
    }
    
    public class AddressData {
        public String Country;
        public String Street;
        public String PostalCode;
        public Boolean SameAsCorrespondence;
        public String State;
        public String District;
        public String City;
        public String AddressLine2;
        public String Locality;
        public String MailingState;
        public String MailingDistrict;
        public String MailingCity;
        public String MailingAddressLine2;
        public String MailingStreet;
        public String MailingPostalCode;
        public String MailingCountry;
    }
    
    /** One submitted document → one Document_Checklist__c row. */
    public class DocumentInfo {
        public String DocumentType;
        public String DocumentName;
        public String DocumentUploadUrl;
        /**
         * Optional. Left out, the row inherits the Application's
         * ExternalApplicationNumber — which is what a caller sending documents alongside
         * a new application wants. Set it only to override that for a single document.
         */
        public String ApplicationNumber;
    }

    public class ParentInfo {
        public String RelationshipType;
        public String Title;
        public String FirstName;
        public String LastName;
        public String MobilePhone;
        public String ContactEmail;
        public String Occupation;
    }
    
    public class EducationData {
        public String QualificationAfter10th;
        public String Class10SchoolName;
        public String Class10Board;
        public String Class10PassingYear;
        public String Class10MarkingScheme;
        public String Class10PercentageCGPA;
        public String Class12SchoolName;
        public String Class12Board;
        public String Class12PassingYear;
        public String Class12MarkingScheme;
        public String Class12PercentageCGPA;
        public String DiplomaInstituteName;
        public String DiplomaBoardUniversity;
        public String DiplomaPassingYear;
        public String DiplomaMarkingScheme;
        public String DiplomaPercentageCGPA;
        public String UGUniversityName;
        public String UGDegreeName;
        public String UGPassingYear;
        public String UGResultStatus;
        public String UGMarkingScheme;
        public String UGPercentageCGPA;
        public String Sem1ObtainedMarks;
        public String Sem1MaximumMarks;
        public String Sem1Percentage;
        public String Sem2ObtainedMarks;
        public String Sem2MaximumMarks;
        public String Sem2Percentage;
        public String Sem3ObtainedMarks;
        public String Sem3MaximumMarks;
        public String Sem3Percentage;
        public String Sem4ObtainedMarks;
        public String Sem4MaximumMarks;
        public String Sem4Percentage;
        public String Sem5ObtainedMarks;
        public String Sem5MaximumMarks;
        public String Sem5Percentage;
        public String Sem6ObtainedMarks;
        public String Sem6MaximumMarks;
        public String Sem6Percentage;
        public String Sem7ObtainedMarks;
        public String Sem7MaximumMarks;
        public String Sem7Percentage;
        public String Sem8ObtainedMarks;
        public String Sem8MaximumMarks;
        public String Sem8Percentage;
    }
}