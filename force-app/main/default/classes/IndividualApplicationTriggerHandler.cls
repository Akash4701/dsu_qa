public class IndividualApplicationTriggerHandler {
    
    
    
  
    private static final Id STUDENT_RECORD_TYPE_ID = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Student').getRecordTypeId();
    
   
    public static void handleAfterUpdate(List<Application__c> newRecords, Map<Id, Application__c> oldRecordsMap) {
        List<hed__Affiliation__c> affiliationsToInsert = new List<hed__Affiliation__c>();
        List<Contact> contactsToUpdate = new List<Contact>();

        // Query the Program Plans once for the whole batch, and only for Applications whose plan changed.
        // A query per Application here made bulk enrollments hit the 100-query limit.
        Set<Id> changedPlanIds = new Set<Id>();
        for (Application__c app : newRecords) {
            if (app.Program_Plan__c != null && oldRecordsMap.get(app.Id).Program_Plan__c != app.Program_Plan__c) {
                changedPlanIds.add(app.Program_Plan__c);
            }
        }
        Map<Id, hed__Program_Plan__c> programPlansById = changedPlanIds.isEmpty()
            ? new Map<Id, hed__Program_Plan__c>()
            : new Map<Id, hed__Program_Plan__c>([SELECT hed__Start_Date__c, hed__End_Date__c FROM hed__Program_Plan__c WHERE Id IN :changedPlanIds]);

        for (Application__c app : newRecords) {
            hed__Program_Plan__c programPlan = programPlansById.get(app.Program_Plan__c);
            Application__c oldApp = oldRecordsMap.get(app.Id);
            System.debug('oldUpdateProgram plan' +oldApp.Program_Plan__c );
            // Check if Status changed to 'Admitted'
                // Validate required fields are present.
                if (oldApp.Program_Plan__c!=app.Program_Plan__c &&app.Program_Plan__c != null && programPlan != null && app.AccountId__c != null && app.ContactId__c != null) {
                    System.debug(programPlan.hed__Start_Date__c + '*****' + programPlan.hed__End_Date__c);
                    // To Create new Affiliation record.
                    hed__Affiliation__c newAffiliation = new hed__Affiliation__c(
                        Program_Plan__c = app.Program_Plan__c,
                        hed__Account__c = app.AccountId__c,
                        hed__Contact__c = app.ContactId__c,
                        hed__Status__c = 'Current',
                        Individual_Application__c = app.Id,  // Store reference to application
                        hed__StartDate__c = programPlan.hed__Start_Date__c,
                    	hed__EndDate__c = programPlan.hed__End_Date__c
                    );
                    
                    affiliationsToInsert.add(newAffiliation);
                    
                    // Create Contact update for RecordType change
                    Contact contactToUpdate = new Contact(
                        Id = app.ContactId__c,
                        RecordTypeId = STUDENT_RECORD_TYPE_ID
                    );
                    
                    contactsToUpdate.add(contactToUpdate);
                }
            
        }
        
        // Insert new Affiliation records
        if (!affiliationsToInsert.isEmpty()) {
            try {
                insert affiliationsToInsert;
            } catch (Exception e) {
                
                System.debug('Error creating Affiliation records: ' + e.getMessage());
               
            }
        }
        
        // Update Contact record types
        if (!contactsToUpdate.isEmpty()) {
            try {
                update contactsToUpdate;
            } catch (Exception e) {
                
                System.debug('Error updating Contact record types: ' + e.getMessage()); 
               
            }
        }
    }
   public static void handleDEBIDUpdate(List<Application__c> newRecords, Map<Id, Application__c> oldMap) {
    Set<Id> contactIdsToGenerate = new Set<Id>();

    for (Application__c app : newRecords) {
        Application__c oldApp = oldMap.get(app.Id);
        
        // Check if status changed to 'Approved for USN'
        if (oldApp.Status__c != 'Approved for USN' && app.Status__c == 'Approved for USN') {
            if (app.ContactId__c != null) {
                contactIdsToGenerate.add(app.ContactId__c);
            }
        }
    }

    if (!contactIdsToGenerate.isEmpty()) {
        List<hed__Affiliation__c> affiliationsToUpdate = [
            SELECT Id, hed__Contact__c, Program_Plan__c, Roll_Number__c, DSU_Email__c, DEB_ID__c,
                   Individual_Application__r.Status__c
            FROM hed__Affiliation__c 
            WHERE hed__Contact__c IN :contactIdsToGenerate
              AND Program_Plan__c != null
              AND Roll_Number__c = null
              AND DEB_ID__c != null
              AND Individual_Application__r.Status__c = 'Approved for USN'
        ];

        if (!affiliationsToUpdate.isEmpty()) {
            AffiliationHandler.generateRollNumbers(affiliationsToUpdate);
            update affiliationsToUpdate;
        }
    }
}
    
    public static void validateDEBIDBeforeApproval(List<Application__c> newRecords, Map<Id, Application__c> oldMap) {
    Set<Id> contactIdsToCheck = new Set<Id>();

    for (Application__c app : newRecords) {
        Application__c oldApp = oldMap.get(app.Id);

        // If status is changing to 'Approved for USN'
        if (app.Status__c == 'Approved for USN' && oldApp.Status__c != 'Approved for USN' && app.ContactId__c != null) {
            contactIdsToCheck.add(app.ContactId__c);
        }
    }

    if (!contactIdsToCheck.isEmpty()) {
        Map<Id, Contact> contactMap = new Map<Id, Contact>([
            SELECT Id, DEB_ID__c FROM Contact WHERE Id IN :contactIdsToCheck
        ]);

        for (Application__c app : newRecords) {
            if (app.Status__c == 'Approved for USN' && contactMap.containsKey(app.ContactId__c)) {
                Contact c = contactMap.get(app.ContactId__c);
                if (String.isBlank(c.DEB_ID__c)) {
                    app.addError('DEB ID is required before setting status to "Approved for USN".');
                }
            }
        }
    }
}
    
    public static void handleAfterInsert(List<Application__c> newRecords) {
    List<hed__Affiliation__c> affiliationsToInsert = new List<hed__Affiliation__c>();
    List<Contact> contactsToUpdate = new List<Contact>();

    // Collect Program Plan Ids for SOQL optimization
    Set<Id> programPlanIds = new Set<Id>();
    for (Application__c app : newRecords) {
        if (app.Status__c == 'CRM Enrolled' && app.Program_Plan__c != null) {
            programPlanIds.add(app.Program_Plan__c);
        }
    }

    // Query Program Plan details once
    Map<Id, hed__Program_Plan__c> programPlanMap = new Map<Id, hed__Program_Plan__c>(
        [SELECT hed__Start_Date__c, hed__End_Date__c FROM hed__Program_Plan__c WHERE Id IN :programPlanIds]
    );

    for (Application__c app : newRecords) {
        if (app.Status__c == 'CRM Enrolled' && app.Program_Plan__c != null && app.AccountId__c != null && app.ContactId__c != null) {
            hed__Program_Plan__c programPlan = programPlanMap.get(app.Program_Plan__c);

            // Create new Affiliation record
            hed__Affiliation__c newAffiliation = new hed__Affiliation__c(
                Program_Plan__c = app.Program_Plan__c,
                hed__Account__c = app.AccountId__c,
                hed__Contact__c = app.ContactId__c,
                hed__Status__c = 'Current',
                Individual_Application__c = app.Id,
                hed__StartDate__c = programPlan.hed__Start_Date__c,
                hed__EndDate__c = programPlan.hed__End_Date__c
            );
            affiliationsToInsert.add(newAffiliation);

            // Prepare Contact update
            contactsToUpdate.add(new Contact(
                Id = app.ContactId__c,
                RecordTypeId = STUDENT_RECORD_TYPE_ID
            ));
        }
    }

    // Insert Affiliation records
    if (!affiliationsToInsert.isEmpty()) {
        try {
            insert affiliationsToInsert;
        } catch (Exception e) {
            System.debug('Error creating Affiliation records: ' + e.getMessage());
        }
    }

    // Update Contact record types
    if (!contactsToUpdate.isEmpty()) {
        try {
            update contactsToUpdate;
        } catch (Exception e) {
            System.debug('Error updating Contact record types: ' + e.getMessage());
        }
    }
}
    public static void generateOfferFromApplication(List<Application__c> newList, Map<Id, Application__c> oldMap) {
        Set<Id> applicationIdsToGenerate = new Set<Id>();

        for (Application__c newApp : newList) {
            Application__c oldApp = oldMap.get(newApp.Id);

            if (oldApp == null) continue;

            // Check if Status__c changed to 'Generate offer'
            if (oldApp.Status__c != 'Generate Letter of Admission' && newApp.Status__c == 'Generate Letter of Admission') {
                System.debug('✅ Generating letter Of Admission because Status changed to Generate offer');
                applicationIdsToGenerate.add(newApp.Id);
            }
        }

        if (!applicationIdsToGenerate.isEmpty()) {
            // Fetch related Affiliation records
            List<hed__Affiliation__c> relatedAffs = [
                SELECT Id, Individual_Application__c
                FROM hed__Affiliation__c
                WHERE Individual_Application__c IN :applicationIdsToGenerate
            ];

            for (hed__Affiliation__c aff : relatedAffs) {
                generateOfferLetter(aff.Id); // Future method
            }
        }
    }
     @Future(callout=true)
    public static void generateOfferLetter(Id affId){
        System.debug('Affil>>>>>>>>>>>>>>>>>>>'+affId);
        
        OfferLetterController.generateAndAttachPDF( affId); 
        
        
    }
    
    
 public static void sendOffer(List<Application__c> newList, Map<Id, Application__c> oldMap) {
    Set<Id> admittedAppIds = new Set<Id>();

    // ✅ Use getInstance() to safely access hierarchy custom setting
    SendLetterOfAdmission__c settings = SendLetterOfAdmission__c.getInstance();

    // ✅ Proceed only if email sending is enabled
    if (settings != null && settings.send_Email__c == true) {
        for (Application__c app : newList) {
            Application__c oldApp = oldMap.get(app.Id);

            // Check if status changed to 'Admitted'
            if (app.Status__c == 'Admitted' && 
                (oldApp == null || oldApp.Status__c != 'Admitted')) {
                admittedAppIds.add(app.Id);
            }
        }
    }

    // ✅ If there are newly admitted applications, get affiliations and send emails
    if (!admittedAppIds.isEmpty()) {
        List<hed__Affiliation__c> affList = [
            SELECT Id
            FROM hed__Affiliation__c
            WHERE Individual_Application__c IN :admittedAppIds
        ];

        for (hed__Affiliation__c aff : affList) {
            sendOfferLetterAsEmailAttachment(aff.Id);
        }
    }
}

  public static void sendOfferLetterAsEmailAttachment(Id affId) {
    hed__Affiliation__c aff = [
        SELECT Name, Roll_Number__c, DSU_Email__c, Personal_Email__c, Approval_Status__c,
            hed__Account__r.Name, hed__Account__r.Course_duration__c,
            hed__Contact__c, hed__Contact__r.Name, hed__Contact__r.FirstName, hed__Contact__r.LastName,
            Program_Plan__r.Name, Program_Plan__r.Intake__c, Program_Plan__r.Batch__c 
        FROM hed__Affiliation__c
        WHERE Id = :affId LIMIT 1
    ];


    if (aff.Approval_Status__c == 'Approved'  ) {
        String fileName = aff.Roll_Number__c + '_LetterOfAdmission.pdf';
        ContentVersion v = [
    SELECT Title, VersionData 
    FROM ContentVersion 
    WHERE Title = :fileName 
      AND FileType = 'PDF'
    ORDER BY CreatedDate DESC 
    LIMIT 1
];

        EmailTemplate coverLetterEmailTemplate = [
            SELECT Id, Name
            FROM EmailTemplate
            WHERE Name = 'OfferLetterEmailTemplate'
            LIMIT 1
        ];

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(aff.hed__Contact__c);
        email.setToAddresses(new List<String>{aff.DSU_Email__c, aff.Personal_Email__c});
        email.setSubject('Letter of Admission');
        email.setSaveAsActivity(true);

        // Build formattedSession directly inside this method
        String intakeAbbrev = aff.Program_Plan__r.Intake__c;
        String year = aff.Program_Plan__r.Batch__c;
        Map<String, String> nextMonthMap = new Map<String, String>{
            'JAN' => 'FEB', 'FEB' => 'MAR', 'MAR' => 'APR',
            'APR' => 'MAY', 'MAY' => 'JUN', 'JUN' => 'JUL',
            'JUL' => 'AUG', 'AUG' => 'SEP', 'SEP' => 'OCT',
            'OCT' => 'NOV', 'NOV' => 'DEC', 'DEC' => 'JAN'
        };
        String formattedSession;
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

        String htmlBody = 'Dear ' + aff.hed__Contact__r.FirstName + ' ' + aff.hed__Contact__r.LastName + ',<br/><br/>' +
            'Congratulations! Your admission is approved for the Online ' +
aff.hed__Account__r.Name + '-' + aff.hed__Account__r.Course_duration__c +
' Program offered by the Centre for Distance and Online Education (CDOE), Dayananda Sagar University for the academic session ' +
formattedSession +
'<br/><br/>' +
            '<p><u><strong>Your Admissions details:</strong></u></p>' +
            '<ul>' +
            '<li><strong>USN:</strong> ' + aff.Roll_Number__c + '</li>' +
            '<li><strong>Program:</strong> ' + aff.hed__Account__r.Name + '-' + aff.hed__Account__r.Course_duration__c + '</li>' +
            '<li><strong>Academic Session:</strong> ' + formattedSession + '</li>' +
            '<li><strong>Semester:</strong> ' + 1 + '</li>' +
            '<li><strong>University Email Login URL:</strong> <a href=" https://outlook.office365.com/"> https://outlook.office365.com/</a></li>'  +
            '<li><strong>University Email ID:</strong> <a href="mailto:' + aff.DSU_Email__c + '">' + aff.DSU_Email__c + '</a></li>' +
            '<li><strong>University Email ID Password:</strong> DSU@54321</li>' +
            '</ul>' +
            '<p>To commence the learning activity, login to the University Student Portal with the credentials given by :<br/>' +
          '</p>' +
            '<ul>' +
            '<li><strong>Student Portal URL:</strong> <a href="https://student.dsuonline.com">https://student.dsuonline.com</a></li>'  +
            '<li><strong>Student Portal Login ID:</strong> ' + aff.DSU_Email__c + '</li>' +
            '<li><strong>Student Portal Password:</strong> Use the OTP sent to your University Email ID</li>' +
            '</ul>' +
            '<p>Login to your student portal to access the following documents:<br/>' +
            '<ul>' +
            '<li>Program Guideline</li>' +
            '<li>Online Program Code of Conduct</li>' +
            '</ul>' +
            '<p>You can do your Learning 24X7 on Desktops/ Laptops/ Tablets/ Mobile.<br/>' +
            '<p>The Semester End Examinations will be a Online Remote Proctored Examination.<br/>' +
            '<p>For Examinations, it is mandatory to use Desktops/ Laptops only.<br/>' +
            '<p>For any kind of support write to helpdesk@dsuonline.com, or call 9880148004.<br/>' +
            '<p>Wish you all the best for your academic journey.<br/><br/>' +
            'With Regards,<br/>O/o Dy.Registrar(Admissions)<br/>CDOE, Dayananda Sagar University<br/>Bangalore, Karnataka, India';

        email.setHtmlBody(htmlBody);

        Messaging.EmailFileAttachment offerLetterPDFAttachement = attachementBuilder(fileName, v.VersionData);
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ offerLetterPDFAttachement });

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }
}
    private static Messaging.EmailFileAttachment attachementBuilder(String fileName, Blob offetLetterPDF) {
        Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
        attach.setContentType('application/pdf');
        system.debug(fileName);
        attach.setFileName(fileName);
        attach.Body = offetLetterPDF;
        return attach;
    }
                                 
                                 




}