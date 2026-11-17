public class ApplicantWrapperV2 {
    public ApplicationData Application;
    public ContactData Contact;
    public List<ParentInfo> ParentContacts;
    public AddressData Address;
    public EducationData PersonEducation;
    
    public class ApplicationData {
        public String Program;
        public String ProgramLevel;
        public String FeePreference;
        public String EntranceExam;
        public String Declaration;
        public Date SignDate;
        public String Place;
        public String PassportPhoto;
        public String Class10Marksheet;
        public String ExternalApplicationNumber;
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
    }
    
    public class AddressData {
        public String Country;
        public String Street;
        public String PostalCode;
        public Boolean SameAsCorrespondence;
    }
    
    public class ParentInfo {
        public String RelationshipType;
        public String Title;
        public String FirstName;
        public String LastName;
    }
    
    public class EducationData {
        public String QualificationAfter10th;
    }
}