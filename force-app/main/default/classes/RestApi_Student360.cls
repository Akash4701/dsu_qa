@RestResource(urlMapping='/ContactDetail/*')
global class RestApi_Student360 {
  @HttpGet
  global static void doGet() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    res.addHeader('Content-Type', 'application/json');
    String response = '';
    string jsonResponse;
    String jsonResponses;
    try {
      System.debug('req is:::' + req);  
      String ContactID = req.requestURI.substring(
        req.requestURI.lastIndexOf('/') + 1
      );
      system.debug('The requested ContactId' + ContactID);
      Contact[] cc = [
        SELECT Id, Name
        FROM Contact
        WHERE Id = :ContactID
        LIMIT 1
      ];
      List<Contact> contactList = new List<Contact>();
      Set<Id> courseOfferingIds = new Set<Id>();
      Map<Id, List<Attachment>> mapAtt = new Map<Id, List<Attachment>>();
      Attachment[] attachment = [
        SELECT Id, Name, Body, ContentType, ParentId
        FROM Attachment
        WHERE ParentId = :cc
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];

      /*List<EduHisWrapper> lData = new  List<EduHisWrapper>();
            EduHisWrapper edHistory;
            List<RelationshipWrapper> resData = new  List<RelationshipWrapper>();
            RelationshipWrapper reswapperObj;*/
      List<AddressWrapper> addData = new List<AddressWrapper>();
      AddressWrapper addwapperObj;
      List<CourseWrapper> addDataCourse = new List<CourseWrapper>();
      CourseWrapper CourseObj;
      list<AffliationWrapper> addDataAffilation = new List<AffliationWrapper>();
      AffliationWrapper AffliaObj;
      List<string> jsonreponse = new List<string>();
      if (string.isNotBlank(ContactID) && !cc.isEmpty()) {
          System.debug('cc id:::' + cc[0].Id);
        Contact con = [
          SELECT
            Id,
            Name,
            Department,
            Role__c,
            Course_Offering__r.Name,
            Registration_Number__c,
            Courses__c,
            Status__c,
            Middle_Name__c,
            Health_Info_Others__c,
            Blood_Group__c,
            Allergies_Others__c,
            /*Employee_ID__c,*/
            FirstName,
            LastName,
            hed__Gender__c,
            Birthdate,
            ABC_ID__c,
            Phone,
            VisaStatus__c,
            Email,
            hed__Country_of_Origin__c,
            Nationality__c,
            Birth_Place__c,
            Passport_Number__c,
            National_ID__c,
            TAX_File_Number__c,
            Emirates_Id_Number__c,
            Name_on_invoice__c,
            Emirates_City__c,
            OtherPhone,
            hed__AlternateEmail__c,
            hed__UniversityEmail__c,
            Campus__r.Name,
            MiddleName,
            Interviewer__c,
            Faculty_Role__c,
             LMS_ID__c,
            Passport_Size_Photo__c,

          (SELECT Id FROM hed__Student_Course_Enrollments__r WHERE hed__Program_Enrollment__r.Term__r.Term_Status__c = 'Upcoming' AND hed__Program_Enrollment__r.hed__Affiliation__r.hed__Status__c = 'Current')
          FROM Contact
          WHERE Id = :ContactID
          //WHERE Email = :ContactID
        ];
          
          //System.debug('Contact==> '+ con.hed__Student_Course_Enrollments__r);
          System.debug('Contact==> '+ con);
        String termName;
        String programName;
        contactsWrapper conWrapObj = new contactsWrapper();
        conWrapObj.firstName = con.FirstName;
        conWrapObj.VISASTATUS = con.VisaStatus__c;
        conWrapObj.lastName = con.LastName;
        conWrapObj.Gender = con.hed__Gender__c;
        conWrapObj.BloodGroup = con.Blood_Group__c;
        conWrapObj.ABCId = con.ABC_ID__c;
          
        conWrapObj.BirthDate = String.valueOf(con.Birthdate);
        conWrapObj.Phone = con.Phone;
        conWrapObj.alternatePhone = con.OtherPhone;
        conWrapObj.MiddleName = con.MiddleName;
        conWrapObj.Email = con.Email;
        conWrapObj.alternateEmail = con.hed__UniversityEmail__c;
        conWrapObj.Allergy = con.Allergies_Others__c;
        /*conWrapObj.EmployeeId = con.Employee_ID__c;*/
        conWrapObj.Others = con.Health_Info_Others__c;
        conWrapObj.Nationality = con.Nationality__c;
        conWrapObj.BirthPlace = con.Birth_Place__c;
        conWrapObj.CountryOfResidence = con.hed__Country_of_Origin__c;
        conWrapObj.PassportNumber = con.Passport_Number__c;
        conWrapObj.NationalIdNumber = con.National_ID__c;
        conWrapObj.TaxFileNum = con.TAX_File_Number__c;
        conWrapObj.EmiratesCity = con.Emirates_City__c;
        conWrapObj.EmiratesIdNum = con.Emirates_Id_Number__c;
        conWrapObj.NameOnInvoice = con.Name_on_invoice__c;
        conWrapObj.Role = con.Role__c;
        conWrapObj.interviewer = String.valueOf(con.Interviewer__c);
        conWrapObj.facultyRole = con.Faculty_Role__c;
        conWrapObj.IDNUmber = con.Registration_Number__c;
        conWrapObj.Courses = Integer.Valueof(con.Courses__c);//con.hed__Student_Course_Enrollments__r.size();
        conWrapObj.Status = con.Status__c; // has to be fixed
        //conWrapObj.Status = 'Active';
        conWrapObj.Type = con.Course_Offering__r.Name;
        conWrapObj.Campus = con.Campus__r.Name;
        conWrapObj.LMSID = con.LMS_ID__c; 
        conWrapObj.profilePicture = con.Passport_Size_Photo__c;

        System.debug('conWrapObj:::' + conWrapObj);  
        List<attachmentWrapper> attachmentWrapperList = new List<attachmentWrapper>();
        if (!attachment.isEmpty()) {
          attachmentWrapper attchWrapperObj = new attachmentWrapper();
          attchWrapperObj.attachmentId = attachment[0].Id;
          attchWrapperObj.attachmentName = attachment[0].Name;
          attchWrapperObj.attachmentContentType = attachment[0].ContentType;
          attchWrapperObj.attachmentBody = attachment[0].body;

          attachmentWrapperList.add(attchWrapperObj);
        } else {
          system.debug('con.Id--' + con.Id);
          Set<Id> eventIds = new Set<Id>(
            new Map<Id, Contact>([SELECT Id FROM Contact WHERE Id = :con.Id])
              .keySet()
          );
          system.debug('eventIds' + eventIds);
          List<contentDocumentLink> CDLink = [
            SELECT LinkedEntityid, ContentDocumentid
            FROM contentDocumentLink
            WHERE LinkedEntityid IN :eventIds
            LIMIT 1
          ];
          system.debug('cdLink==>' + CDLink);
          if (CDLink != null && CDLink.size() > 0) {
            ContentVersion cv = [
              SELECT title, PathOnClient, FileType, versiondata
              FROM contentversion
              WHERE ContentDocumentId = :CDLink[0].ContentDocumentid LIMIT 1
            ];
            attachmentWrapper attchWrapperObj = new attachmentWrapper();
            attchWrapperObj.attachmentId = cv.Id;
            attchWrapperObj.attachmentName = cv.Title;
            attchWrapperObj.attachmentContentType = cv.FileType;
            attchWrapperObj.attachmentBody = cv.VersionData;

            attachmentWrapperList.add(attchWrapperObj);
          }
        }
        conWrapObj.attachment = attachmentWrapperList;
        /*for(hed__Education_History__c eduHis:[select id,Name,Level__c,Country__c,Year_of_Passing__c,HED__EDUCATIONAL_INSTITUTION_NAME__C from hed__Education_History__c where hed__Contact__c=:con.Id]){
                        edHistory = new EduHisWrapper(eduHis);
                        lData.add(edHistory);
                    }
                    for(hed__Relationship__c resObj:[Select Id,Name,hed__Contact__c,Parent__c,hed__Type__c,hed__Status__c,CurrencyIsoCode,Language_Spoken_at_Home__c from hed__Relationship__c where hed__Contact__c=:con.Id]){
                        reswapperObj = new RelationshipWrapper(resObj);
                        resData.add(reswapperObj);
                    }*/
        for (hed__Address__c addObj : [
          SELECT
            Id,
            Name,
            hed__Address_Type__c,
            hed__MailingCountry__c,
            hed__MailingPostalCode__c,
            hed__MailingStreet__c,
            House_Flat_No__c,
            hed__Parent_Account__c,
            hed__Parent_Contact__c,
            Mailing_District__c,
            hed__MailingState__c
          FROM hed__Address__c
          WHERE hed__Parent_Contact__c = :con.Id
        ]) {
          addwapperObj = new AddressWrapper(addObj);
          addwapperObj.addressRecordId = addObj.Id;
          addwapperObj.pin = addObj.hed__MailingPostalCode__c;
          addwapperObj.country = addObj.hed__MailingCountry__c;
          addwapperObj.road = addObj.hed__MailingStreet__c;
          addwapperObj.flat = addObj.House_Flat_No__c;
          addwapperObj.state = addObj.hed__MailingState__c;
          addwapperObj.city = addObj.Mailing_District__c;

          addData.add(addwapperObj);
        }
        for (hed__Course_Enrollment__c addCourse : [
          SELECT
            id,
            Semesters__c,
            hed__Grade__c,
            Course_Name__c,
            hed__Contact__c,
            hed__Status__c,
            Attendacne__c,
            Term_Name__c,hed__Course_Offering__r.hed__Term__r.Term_Reference__c,
            hed__Course_Offering__c
          FROM hed__Course_Enrollment__c
          WHERE hed__Contact__c = :con.Id AND hed__Status__c ='Current'//Term_Status__c = 'Ongoing'
        ]) {
          CourseObj = new CourseWrapper(addCourse);
          addDataCourse.add(CourseObj);
          courseOfferingIds.add(addCourse.hed__Course_Offering__c);
          termName = addCourse.hed__Course_Offering__r.hed__Term__r.Term_Reference__c;
        }
          system.debug('addDataCoursesize'+addDataCourse.size());
        for (hed__Affiliation__c addAff : [
          SELECT
            id,
            hed__Status__c,
            hed__Contact__c,
            hed__Account__c,
            hed__Account__r.Name
          FROM hed__Affiliation__c
          WHERE hed__Contact__c = :con.id
        ]) {
          AffliaObj = new AffliationWrapper(addAff);
          addDataAffilation.add(AffliaObj);
          programName = addAff.hed__Account__r.Name; // has to be fixed
          //programName = 'Master of Business Administration';
        }
        List<hed__Attendance_Event__c> allAttEvntList = [
          SELECT
            Id,
            Name,
            Attendance_Status__c,
            Session__c,
            Session__r.Course_Offering__c,
            Session__r.Course_Offering__r.Id
          FROM hed__Attendance_Event__c
          WHERE
            hed__Contact__c = :ContactID
            AND Session__r.Course_Offering__c IN :courseOfferingIds
        ];
        List<hed__Attendance_Event__c> presentAttEvntList = [
          SELECT
            Id,
            Name,
            Attendance_Status__c,
            Session__c,
            Session__r.Course_Offering__c,
            Session__r.Course_Offering__r.Id
          FROM hed__Attendance_Event__c
          WHERE
            hed__Contact__c = :ContactID
            AND Session__r.Course_Offering__c IN :courseOfferingIds
            AND Attendance_Status__c = 'Present'
        ];
        conWrapObj.totalClass = allAttEvntList.size();
        conWrapObj.presentClass = presentAttEvntList.size();
        // Calculate Total Percentage
        if (conWrapObj.totalClass != 0) {
          conWrapObj.overallPresentPercentage =
            (decimal) conWrapObj.presentClass /
            (decimal) conWrapObj.totalClass *
            100;
            conWrapObj.overallPresentPercentage =conWrapObj.overallPresentPercentage.setScale(2);
        } else {
          conWrapObj.overallPresentPercentage = 0; // Set the percentage to 0 if totalClass is 0
        } //conWrapObj.educationHistory = lData;
        //conWrapObj.relationship = resData;
        conWrapObj.address = addData;
        conWrapObj.Courses = addDataCourse.size();
        con.Courses__c = addDataCourse.size();
        conWrapObj.semester = termName; // has to be fixed
        //conWrapObj.semester = 'Term 1';
        //conWrapObj.Affilation = addDataAffilation;
        conWrapObj.departmnt = programName;

        jsonreponse.add(JSON.serialize(conWrapObj));

        update con;
		
          System.debug('final jsonreponse::' + jsonreponse);
        jsonResponses = String.join(jsonreponse, ',');
        jsonResponse = jsonResponses;
        if (jsonResponse != null) {
          res.responseBody = Blob.valueOf(jsonResponse);
        } else {
          res.responseBody = Blob.valueOf('[]');
        }
      } else {
        res.statusCode = 400;
        res.responseBody = Blob.valueOf(
          '{ "success": "false" , "message": "Invalid Parameters"  }'
        );
      }
    } catch (Exception e) {
      res.statusCode = 400;
      //system.debug(e.getMessage()+'at Line Number'+e.getLineNumber());
      res.responseBody = Blob.valueOf(
        '{ "success": "false" , "message": "bad request", "errors": "' +
          e.getMessage() +
          'at Line Number' +
          e.getLineNumber() +
          '" }'
      );
    }
  }
  global class contactsWrapper {
    public string firstName;
    public string middleName;
    public String VISASTATUS;
    public string lastName;
    public string Gender;
    public string BirthDate;
    public string Phone;
    public string alternatePhone;
    public string Email;
    public string alternateEmail;
    public String departmnt;
    public String Role;
    public String IDNUmber;
    //public Integer Courses;
    public String Status;
    public String Type;
    public String Allergy;
      public String EmployeeId;
    public String Others;
    public String BloodGroup;
    public string CountryOfResidence;
    public string Nationality;
    public string BirthPlace;
    public string EmiratesCity;
    public string PassportNumber;
    public string NationalIdNumber;
    public string TaxFileNum;
    public string EmiratesIdNum;
    public string NameOnInvoice;
    public string semester;
    public Integer Courses;
    public Integer totalClass;
    public Integer presentClass;
    public decimal overallPresentPercentage;
    public string Campus;
      public String interviewer;
    public String facultyRole;
    //Public List<EduHisWrapper> educationHistory;
    //public List<RelationshipWrapper> relationship;
    public List<AddressWrapper> address;
    //public list<AffliationWrapper>Affilation;
    public List<attachmentWrapper> attachment;
    public String LMSID;
    public String profilePicture;
     public string ABCId;
   

  }
  global class attachmentWrapper {
    public string attachmentId;
    public string attachmentName;
    public string attachmentContentType;
    public Blob attachmentBody;
  }
  global class AddressWrapper {
    public String flat;
    public String country;
    public String road;
    public String pin;
    public String addressRecordId;
    public String state;
    public String city;
    global hed__Address__c add;
    global AddressWrapper(hed__Address__c add) {
      this.add = add;
    }
  }
  /*global class EduHisWrapper
    {        
        global hed__Education_History__c edHis;
        global EduHisWrapper(hed__Education_History__c edHis){           
            this.edHis=edHis;
        }
    }*/
  /*global class RelationshipWrapper
    {        
        global hed__Relationship__c res;
        global RelationshipWrapper(hed__Relationship__c res){           
            this.res=res;
        }
    }*/
  global class CourseWrapper {
    global hed__Course_Enrollment__c cou;
    global CourseWrapper(hed__Course_Enrollment__c cou) {
      this.cou = cou;
    }
  }
  global class AffliationWrapper {
    global hed__Affiliation__c affili;
    global AffliationWrapper(hed__Affiliation__c affili) {
      this.affili = affili;
    }
  }
  /*global class AddressWrapper
    {        
        global hed__Address__c add;
        global AddressWrapper(hed__Address__c add){           
            this.add=add;
        }
    }*/

  @HttpPost
  global static void createContact() {
    System.debug('Contact');
    RestRequest req = RestContext.request;
    RestResponse res = Restcontext.response;
    List<Account> contactList = new List<Account>();
    List<hed__Relationship__c> relation = new List<hed__Relationship__c>();
    List<RelationshipWrapperPost> evsPost = new List<RelationshipWrapperPost>();
    List<hed__Address__c> adddress = new List<hed__Address__c>();
    List<AddressWrapperPost> addressPost = new List<AddressWrapperPost>();
    try {
      List<ContactWrapperPost> evPost = (List<ContactWrapperPost>) JSON.deserialize(
        RestContext.request.requestBody.toString(),
        List<ContactWrapperPost>.class
      );
        set<Id> allContactIds = new set<Id>();
        for(ContactWrapperPost emp : evPost){
            allContactIds.add(emp.contactId);
        }
        Map<Id,Id> contactIdByAccountId = new Map<Id,Id>();
        Map<Id,Id> accountIdByContactId= new Map<Id,Id>();
        List<Account> accList = [SELECT Id,PersonContactId FROM Account WHERE PersonContactId IN:allContactIds];
        for(Account acc : accList){
            accountIdByContactId.put(acc.personContactId, acc.Id);
            contactIdByAccountId.put(acc.Id,acc.personContactId);
        }
        
      for (ContactWrapperPost emPost : evPost) {
        Account con = new Account();          
        con.Id = accountIdByContactId.get(emPost.contactId);
        con.FirstName = emPost.firstName;
        con.Middle_Name__pc = emPost.middleName;
        con.LastName = emPost.lastName;
        con.PersonBirthdate = emPost.BirthDate;
        con.Birth_Place__pc = emPost.BirthPlace;
        con.hed__Country_of_Origin__pc = emPost.CountryOfResidence;
        con.PersonEmail = emPost.Email;
        con.hed__UniversityEmail__pc = emPost.alternateEmail;
        con.Emirates_Id_Number__pc = emPost.EmiratesIdNum;
        con.hed__Gender__pc = emPost.Gender;
        con.National_ID__pc = emPost.NationalIdNumber;
        con.Nationality__pc = emPost.Nationality;
        con.Passport_Number__pc = emPost.PassportNumber;
        con.Phone = emPost.Phone;
        con.TAX_File_Number__pc = emPost.TaxFileNum;
        con.Name_on_invoice__pc = emPost.NameOnInvoice;
        con.Blood_Group__pc = emPost.BloodGroup;
        con.PersonOtherPhone = emPost.AlternateContact;
        con.Health_Info_Others__pc = emPost.Others;
        con.Allergies_Others__pc = emPost.Allergy;
        con.ABC_ID__pc = emPost.ABCId;
        /*con.Employee_ID__c = emPost.EmployeeId;*/
          
        //con.hed__AlternateEmail__c = emPost.AlternateEmail;
        system.debug(con);
        contactList.add(con);
        System.debug(contactList);
      }
      Database.UpsertResult[] srList;
      if (!contactList.isEmpty()) {
        srList = database.upsert(contactList, false);
      }
      id compId;
      for (Database.UpsertResult ids : srList) {
        compId = ids.getId();
        //compId.add(newId);
      }
      system.debug(compId);
      for (ContactWrapperPost emPost : evPost) {
        for (RelationshipWrapperPost emPosts : emPost.RELATIONSHIP) {
          hed__Relationship__c rel = new hed__Relationship__c();
          rel.Mother_Occupation__c = emPosts.MotherOccupation;
          rel.Parent_Gaurdian_occupation_details__c = emPosts.FatherOccupation;
          rel.Emergency_Contact__c = emPosts.EmergencyContactNo;
          rel.Annual_income__c = emPosts.AnnualIncome;
          rel.hed__Contact__c = contactIdByAccountId.get(compId);
          rel.hed__RelatedContact__c = contactIdByAccountId.get(compId);
          rel.hed__Status__c = emPosts.Status;
          relation.add(rel);
        }
      }
      if (!relation.isEmpty()) {
        system.debug(relation);
        database.insert(relation);
      }
      for (ContactWrapperPost addPost : evPost) {
        for (AddressWrapperPost addPosts : addPost.ADDRESS) {
          hed__Address__c add = new hed__Address__c();
          add.Id = addPosts.addressRecordId;
          add.hed__MailingCountry__c = addPosts.country;
          add.hed__MailingState__c = addPosts.state;
          add.Mailing_District__c = addPosts.city;
          add.hed__MailingStreet__c = addPosts.road;
          add.hed__MailingPostalCode__c = addPosts.pin;
          add.House_Flat_No__c = addPosts.flat;
          add.hed__Parent_Contact__c = addPost.contactId;
          adddress.add(add);
        }
      }
      if (!adddress.isEmpty()) {
        system.debug(adddress);
        database.upsert(adddress);
      }
      res.responseBody = Blob.valueOf(
        '{ "success": "true" , "message": "Data Updated/Inserted Successfully"}'
      );
      res.statusCode = 200;
    } catch (exception e) {
      res.statusCode = 400;
      res.responseBody = Blob.valueOf(
        '{ "success": "false" , "message": "bad request", "errors": "' +
          e.getMessage() +
          'at Line Number' +
          e.getLineNumber() +
          '" }'
      );
        System.debug('Message: ' + e.getMessage());    
            System.debug('Cause: ' + e.getCause());    
            System.debug('Line number: ' + e.getLineNumber());    
            System.debug('Stack trace: ' + e.getStackTraceString());
    }
  }
  public class ContactWrapperPost {
    public id contactId;
    public string firstName;
    public string middleName;
    public string lastName;
    public Date BirthDate;
    public string BirthPlace;
    public string CountryOfResidence;
    public string Email;
    public String EmiratesIdNum;
    public string Gender;
    public string NationalIdNumber;
    public string Nationality;
    public String PassportNumber;
    public String Phone;
    public String Others;
    public String AlternateContact;
    public String alternateEmail;
    public String TaxFileNum;
    public string NameOnInvoice;
    public string BloodGroup;
    public string Allergy;
      public String ABCId;
      public string EmployeeId;
    
    public list<RelationshipWrapperPost> RELATIONSHIP;
    public list<AddressWrapperPost> ADDRESS;
  }
  public class RelationshipWrapperPost {
    public String AnnualIncome;
    public String MotherOccupation;
    public String FatherOccupation;
    public String EmergencyContactNo;
    public String Status;
  }
  public class AddressWrapperPost {
    public String flat;
    public String country;
    public String road;
    public String pin;
    public String addressRecordId;
    public String state;
    public String city;
  }
}