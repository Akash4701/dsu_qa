@isTest
private class ApplicantWrapperV2Test {

    @isTest
    static void testApplicantWrapperInitialization() {
        // Instantiate the wrapper
        ApplicantWrapperV2 wrapper = new ApplicantWrapperV2();

        // Populate ApplicationData
        ApplicantWrapperV2.ApplicationData application = new ApplicantWrapperV2.ApplicationData();
        application.Program = 'B.Tech';
        application.ProgramLevel = 'Undergraduate';
        application.FeePreference = 'One-Time';
        application.EntranceExam = 'JEE';
        application.Declaration = 'I agree';
        application.SignDate = Date.today();
        application.Place = 'Chennai';
        application.PassportPhoto = 'base64-photo-data';
        application.Class10Marksheet = 'base64-marksheet-data';
        application.ExternalApplicationNumber = 'EXT12345';

        // Populate ContactData
        ApplicantWrapperV2.ContactData contact = new ApplicantWrapperV2.ContactData();
        contact.Title = 'Mr.';
        contact.FirstName = 'John';
        contact.LastName = 'Doe';
        contact.Email = 'john.doe@example.com';
        contact.Phone = '9876543210';
        contact.GenderIdentity = 'Male';
        contact.Birthdate = Date.newInstance(2000, 1, 1);
        contact.MaritalStatus = 'Single';
        contact.Religion = 'None';
        contact.Nationality = 'Indian';
        contact.AnnualFamilyIncome = 500000;
        contact.Name = 'John Doe';
        contact.PassportPhoto = 'base64-photo';
        contact.Class10Marksheet = 'base64-marksheet';

        // Populate AddressData
        ApplicantWrapperV2.AddressData address = new ApplicantWrapperV2.AddressData();
        address.Country = 'India';
        address.Street = '123 Main St';
        address.PostalCode = '600001';
        address.SameAsCorrespondence = true;

        // Populate EducationData
        ApplicantWrapperV2.EducationData education = new ApplicantWrapperV2.EducationData();
        education.QualificationAfter10th = 'Diploma';

        // Populate ParentContacts list
        List<ApplicantWrapperV2.ParentInfo> parentList = new List<ApplicantWrapperV2.ParentInfo>();
        ApplicantWrapperV2.ParentInfo parent1 = new ApplicantWrapperV2.ParentInfo();
        parent1.RelationshipType = 'Father';
        parent1.Title = 'Mr.';
        parent1.FirstName = 'Robert';
        parent1.LastName = 'Doe';
        parentList.add(parent1);

        ApplicantWrapperV2.ParentInfo parent2 = new ApplicantWrapperV2.ParentInfo();
        parent2.RelationshipType = 'Mother';
        parent2.Title = 'Mrs.';
        parent2.FirstName = 'Mary';
        parent2.LastName = 'Doe';
        parentList.add(parent2);

        // Assign all to wrapper
        wrapper.Application = application;
        wrapper.Contact = contact;
        wrapper.Address = address;
        wrapper.PersonEducation = education;
        wrapper.ParentContacts = parentList;

        // Assertions just to avoid unused variable warnings (not mandatory for coverage)
        System.assertEquals('B.Tech', wrapper.Application.Program);
        System.assertEquals('John', wrapper.Contact.FirstName);
        System.assertEquals('India', wrapper.Address.Country);
        System.assertEquals('Diploma', wrapper.PersonEducation.QualificationAfter10th);
        System.assertEquals(2, wrapper.ParentContacts.size());
    }
}