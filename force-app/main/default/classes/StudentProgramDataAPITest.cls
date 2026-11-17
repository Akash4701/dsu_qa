@isTest
private class StudentProgramDataAPITest {
    
    @testSetup
    static void setup() {
        Contact testContact = new Contact(FirstName = 'Test', LastName = 'Contact');
        insert testContact;
        
        Account program = new Account(Name = 'Test Program');
        insert program;
        
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert programPlan;
        
        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            hed__Account__c = program.Id,
            Program_Plan__c = programPlan.Id
        );
        insert affiliation;
        
        Program_Pathway__c pathway = new Program_Pathway__c(
            Name = 'Test Pathway',
            Specialization_Type__c = 'Major',
            Maximum_Credits__c = 15,
            Program_Plan__c = programPlan.Id
        );
        insert pathway;
        
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90),
            hed__Account__c = program.id,
            Term_Reference__c = 'Term 1',
            Program_Plan__c = programPlan.Id
        );
        insert term;
        
        Course_Enrollment__c enrollment = new Course_Enrollment__c(Name = 'Test Enrollment');
        insert enrollment;
        
        Cluster__c cluster = new Cluster__c(
            Name = 'Test Cluster',
            Term__c = term.Id,
            Minimum_Courses__c = 1,
            Maximum_Courses__c = 3,
            Course_Enrollment__c = enrollment.Id
        );
        insert cluster;
        
        hed__Program_Enrollment__c programEnrollment = new hed__Program_Enrollment__c(
            
            Term__c = term.Id,
            hed__Contact__c = testContact.Id
        );
        insert programEnrollment;
        
        Student_Registration_Window__c regWindow = new Student_Registration_Window__c(
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30),
            Credits__c = '12',
            Program_Plan__c = programPlan.Id,
            Active__c = true
        );
        insert regWindow;
    }
    
    @isTest
    static void testGetStudentProgramDataSuccess() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/studentProgramData/';
        req.addParameter('contactId', testContact.Id);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        List<StudentProgramDataAPI.StudentProgramResponse> result = StudentProgramDataAPI.getStudentProgramData();
        Test.stopTest();
    }
    
    @isTest
    static void testGetStudentProgramDataMissingContactId() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/studentProgramData/';
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        try {
            StudentProgramDataAPI.getStudentProgramData();
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetStudentProgramDataInvalidContactId() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/studentProgramData/';
        req.addParameter('contactId', 'invalidId');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        try {
            StudentProgramDataAPI.getStudentProgramData();
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetStudentProgramDataContactNotFound() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/studentProgramData/';
        req.addParameter('contactId', '0030000000000000');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        try {
            StudentProgramDataAPI.getStudentProgramData();
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    // A student who withdrew from a program and re-enrolled on the same program plan must
    // see only the active affiliation and its own program enrollments.
    @isTest
    static void testWithdrawnAffiliationIsExcluded() {
        Contact testContact = [SELECT Id FROM Contact LIMIT 1];
        hed__Affiliation__c activeAffiliation = [
            SELECT Id, hed__Account__c, Program_Plan__c FROM hed__Affiliation__c LIMIT 1
        ];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        hed__Affiliation__c withdrawnAffiliation = new hed__Affiliation__c(
            hed__Contact__c = testContact.Id,
            hed__Account__c = activeAffiliation.hed__Account__c,
            Program_Plan__c = activeAffiliation.Program_Plan__c,
            hed__Status__c = 'Withdrawn'
        );
        insert withdrawnAffiliation;

        hed__Program_Enrollment__c withdrawnEnrollment = new hed__Program_Enrollment__c(
            Term__c = term.Id,
            hed__Contact__c = testContact.Id,
            hed__Affiliation__c = withdrawnAffiliation.Id
        );
        insert withdrawnEnrollment;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/studentProgramData/';
        req.addParameter('contactId', testContact.Id);
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        List<StudentProgramDataAPI.StudentProgramResponse> result = StudentProgramDataAPI.getStudentProgramData();
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Only the active affiliation should be returned');
        System.assertEquals(String.valueOf(activeAffiliation.Id), result[0].AffiliationId,
            'The withdrawn affiliation must not be the one returned for the shared program plan');

        Set<String> returnedEnrollmentIds = new Set<String>();
        for (StudentProgramDataAPI.TermInfo termInfo : result[0].Terms) {
            for (StudentProgramDataAPI.ProgramEnrollmentInfo enrollment : termInfo.ProgramEnrollments) {
                returnedEnrollmentIds.add(enrollment.ProgramEnrollmentId);
            }
        }
        System.assert(!returnedEnrollmentIds.contains(String.valueOf(withdrawnEnrollment.Id)),
            'Program enrollments of a withdrawn affiliation must not be returned');
    }
}