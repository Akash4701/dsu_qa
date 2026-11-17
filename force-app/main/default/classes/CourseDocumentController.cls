public class CourseDocumentController {
	public AreaHeadResponse response {get;set;}
    public Id facultyId {get;set;}
    
    public CourseDocumentController(){
        String courseDocumentRecordId = ApexPages.currentPage().getParameters().get('courseDocumentId');//'a361y0000001RHfAAM';
        facultyId = ApexPages.currentPage().getParameters().get('contactId');//'0031y00000RTOfeAAH';//
        Course_Document__c[] courseDocRecords = [SELECT Id, Name, Status__c, Comment__c, Area_Head_Status__c, Is_Link_Active__c, Faculty__c, Faculty__r.Email, Course__r.Name, Faculty__r.FirstName, Faculty__r.LastName,
                                              Area_Head__c,No_of_Divisions__c,No_of_Sessions__c,Campus__c,Mode_of_delivery__c,Term__r.Name,Start_Date__c,End_Date__c from Course_Document__c where Id=:courseDocumentRecordId];
        response = new AreaHeadResponse(courseDocRecords[0]);
    }
    

   public PageReference save() {
    try {
        Course_Document__c courseDocRecord = [SELECT Id, Name, Status__c, Comment__c, Area_Head_Status__c, Is_Link_Active__c, Faculty__c, Faculty__r.Email, Course__r.Name, Faculty__r.FirstName, Faculty__r.LastName,
                                              Area_Head__c,No_of_Divisions__c,No_of_Sessions__c,Campus__c,Mode_of_delivery__c,Term__r.Name,Start_Date__c,End_Date__c
                                              FROM Course_Document__c WHERE Id = :response.courseDocumentRecordId];

        if (courseDocRecord.Is_Link_Active__c == false) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Your response was already submitted'));
        } else {
            Course_Document__c courseDocObj = new Course_Document__c();
            courseDocObj.Area_Head_Status__c = response.availability;
            system.debug('Area head Status===>'+response.availability);
            if (response.availability == 'Modify') {
                courseDocObj.Status__c = 'Pending';
            }else {
    		courseDocObj.Status__c = 'Submitted';
			}
            courseDocObj.Comment__c = response.note;
            courseDocObj.Is_Link_Active__c = false;
            courseDocObj.Id = response.courseDocumentRecordId;
            update courseDocObj;

            // Check conditions for sending email
            if ((courseDocObj.Area_Head_Status__c == 'Modify' && courseDocObj.Status__c == 'Pending') ||
                (courseDocObj.Area_Head_Status__c == 'Approved' && courseDocObj.Status__c == 'Submitted')) {
                sendEmailToAreaHeadAndFaculty(courseDocObj);
            }

            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Response recorded, Please close the tab'));
        }
    } catch (Exception ex) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'An error occurred while saving the record: ' + ex.getMessage()));
    }
    return null;
}

    public void sendEmailToAreaHeadAndFaculty(Course_Document__c courseDocObj) {
    try {
          system.debug('courseDocObj===>'+courseDocObj);
            OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress 
                                        //WHERE DisplayName='Do Not Reply'
                                         LIMIT 1];
        
        Course_Document__c courseDocRecord = [SELECT Id, Name, Status__c, Comment__c, Area_Head_Status__c, Is_Link_Active__c, Faculty__c, Faculty__r.Email, Course__r.Name, Faculty__r.FirstName, Faculty__r.LastName,
                                              Area_Head__c,No_of_Divisions__c,No_of_Sessions__c,Campus__c,Mode_of_delivery__c,Term__r.Name,Start_Date__c,End_Date__c FROM Course_Document__c WHERE Id = :courseDocObj.id];

        // Compose email message
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[]{courseDocRecord.Faculty__r.Email,System.Label.Admin_Email_Id};
        system.debug('toAddresses===>'+toAddresses);
        mail.setToAddresses(toAddresses);
       
                
        // Set subject
        mail.setSubject('Notification to Faculty and Admin on Course outline Approval ' + courseDocRecord.Course__r.Name +'-'+ courseDocRecord.Term__r.Name);
        
        String emailBody = 'Dear ' + courseDocRecord.Faculty__r.FirstName + ',\n\n';
        emailBody += 'This is to inform you that the ' + courseDocRecord.Area_Head__c +' '+ 'has given the response on the submitted outline for the course - ' + courseDocRecord.Course__r.Name + '.\n\n';
        emailBody += 'Please find the response below:\n';
        emailBody += 'Response: ' + courseDocRecord.Area_Head_Status__c + '\n';
        emailBody += 'Comments: ' + courseDocRecord.Comment__c + '\n';
        emailBody += '1.Course: ' + courseDocRecord.Course__r.Name + '\n';
        emailBody += '2.Cohort: ' + courseDocRecord.Term__r.Name + '\n';
        emailBody += '3.Duration: ' + courseDocRecord.Start_Date__c + ' - ' + courseDocRecord.End_Date__c + '\n';
        emailBody += '4.No. of divisions: ' + String.valueOf(courseDocRecord.No_of_Divisions__c) + '\n';
        emailBody += '5.No. of sessions: ' + String.valueOf(courseDocRecord.No_of_Sessions__c) + '\n';
        emailBody += '6.Campus: ' + courseDocRecord.Campus__c + '\n';
        emailBody += '7.Mode of delivery: ' + courseDocRecord.Mode_of_delivery__c + '\n\n';
        
        emailBody += 'Thanks and Regards,\nSP Jain School of Global Management';
        
        mail.setPlainTextBody(emailBody);
        mail.setOrgWideEmailAddressId(owea.Id);

        // Add related record Id for merge fields in the template
        mail.setWhatId(courseDocObj.Id);

        system.debug('Mail=====>'+mail);
        

        // Send the email
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
    } catch (Exception e) {
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'An error occurred while sending email: ' + e.getMessage()));
    }
}

    
    public class AreaHeadResponse{
        public String availability {get; set;}
        public String note {get; set;}
        public Id courseDocumentRecordId;
        
        public AreaHeadResponse(Course_Document__c courseDocObj){
            this.availability=courseDocObj.Status__c;
            if(courseDocObj.Comment__c==null)
            	this.note=courseDocObj.Comment__c;
            this.courseDocumentRecordId=courseDocObj.Id;
        }
    }
       
}