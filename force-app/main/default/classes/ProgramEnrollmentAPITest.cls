@isTest
private class ProgramEnrollmentAPITest {
    
    @testSetup
    static void setup() {
        Account program = new Account(Name='Test Account');
        insert program;
        
        hed__Term__c term = new hed__Term__c(Name = 'Test Term', Minimum_Credit__c = 12, Maximum_Credit__c = 18, hed__Account__c = program.id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Course_ID__c = 'CS101', Credits__c = 3, hed__Account__c = program.id);
        insert course;
        
        Course_Enrollment__c enrollment = new Course_Enrollment__c(Name = 'Test Enrollment', Order_of_Priority__c = 1);
        insert enrollment;
        
        Academic_Term__c academicTerm = new Academic_Term__c(Name = 'Test Academic Term');
        insert academicTerm;
        
        Course_Enrollment_Management__c management = new Course_Enrollment_Management__c(Academic_Term__c = academicTerm.id);
        insert management;
        
        Program_Pathway__c pathway = new Program_Pathway__c(Name = 'Test Pathway', Maximum_Credits__c = 15, Specialization_Type__c = 'Major');
        insert pathway;
        
        Interpathway_Capacity_Planner__c planner = new Interpathway_Capacity_Planner__c(Capacity__c = 30);
        insert planner;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Course_Enrollment_Management__c = management.Id,
            hed__Course__c = course.Id,
            Program_Pathway__c = pathway.Id,
            Interpathway_Capacity_Planner__c = planner.Id,
            hed__Term__c = term.Id,
            Academic_Term__c = academicTerm.Id,
            Course_Pre_requisites__c = 'None',
            Course_Enrollment__c = enrollment.Id
        );
        insert offering;
        
        hed__Program_Enrollment__c programEnrollment = new hed__Program_Enrollment__c();
        insert programEnrollment;
        
        hed__Course_Enrollment__c courseEnrollment = new hed__Course_Enrollment__c(
            
            hed__Program_Enrollment__c = programEnrollment.Id,
            hed__Course_Offering__c = offering.Id,
            hed__Status__c = 'Current'
        );
        insert courseEnrollment;
    }
    
    @isTest
    static void testDoGetSuccess() {
        hed__Program_Enrollment__c programEnrollment = [SELECT Id FROM hed__Program_Enrollment__c LIMIT 1];
        
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/programEnrollments/' + programEnrollment.Id;
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        ProgramEnrollmentAPI.doGet();
        Test.stopTest();
    }
    
    @isTest
    static void testDoGetException() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/programEnrollments/invalidId';
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        ProgramEnrollmentAPI.doGet();
        Test.stopTest();
    }
}