@IsTest
private class CourseEnrollmentAPITest {
    
    @TestSetup
    static void setupData() {
        
        // ---------------------------------------------------------------------
        // 1. Academic Department (required for hed__Course__c)
        // ---------------------------------------------------------------------
        Account dept = new Account(Name = 'Dept of Test');
        insert dept;
        
        // ---------------------------------------------------------------------
        // 2. EDA Term (hed__Term__c) – required for Course Offering + API
        // ---------------------------------------------------------------------
        hed__Term__c hedTerm = new hed__Term__c(Name = 'SpringTerm', hed__Account__c = dept.Id, 
                                                Term_Reference__c = 'Term 1');
        insert hedTerm;
        
        // ---------------------------------------------------------------------
        // 3. Contact
        // ---------------------------------------------------------------------
        Contact con = new Contact(LastName = 'Test Student');
        insert con;
        
        // ---------------------------------------------------------------------
        // 4. Program Pathway + Pathway Master (for pathway eligibility logic)
        // ---------------------------------------------------------------------
        Pathway_Master__c pm = new Pathway_Master__c(Name='MasterPath');
        insert pm;
        
        Program_Pathway__c ppMain = new Program_Pathway__c(
            Name = 'MasterPath',
            Pathway_Master__c = pm.Id
        );
        insert ppMain;
        
        Program_Pathway__c ppSecondary = new Program_Pathway__c(
            Name = 'SecondaryPath',
            Pathway_Master__c = pm.Id
        );
        insert ppSecondary;
        
        // ---------------------------------------------------------------------
        // 5. Pathway Connection (contact enrolled in main pathway)
        // ---------------------------------------------------------------------
        // Pathway Enrollment (required)
        Academic_Term__c term = new Academic_Term__c(
            Name = 'Fall 2024'
        );
        insert term;
        
        Pathway_Enrollment__c pEnroll = new Pathway_Enrollment__c(
            Contact__c = con.Id,
            Program_Pathway__c = ppMain.Id,
            Academic_Term__c = term.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(30)
        );
        insert pEnroll;
        
        // Pathway Connection (must reference enrollment)
        Pathway_Connection__c pconn = new Pathway_Connection__c(
            Contact__c = con.Id,
            Program_Pathway__c = ppMain.Id,
            Pathway_Enrollment__c = pEnroll.Id
        );
        insert pconn;
        
        
        hed__Course__c course = new hed__Course__c(
            Name = 'Course 101',
            hed__Course_ID__c = 'C101',
            Credits__c = 3,
            hed__Account__c = dept.Id
        );
        insert course;
        
        Course_Enrollment_Management__c cem = new Course_Enrollment_Management__c(
            Academic_Term__c = term.Id
        );
        insert cem;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Course101 - Offer A',
            hed__Course__c = course.Id,
            hed__Term__c = hedTerm.Id,
            Academic_Term__c = term.Id
        );
        insert offering;
        
        Interpathway_Capacity_Planner__c icp = new Interpathway_Capacity_Planner__c(
            Academic_Term__c = term.Id,
            Capacity__c = 50
        );
        insert icp;
        
        // Offerings might use ICP data
        offering.Interpathway_Capacity_Planner__c = icp.Id;
        update offering;
        
        hed__Course_Enrollment__c ceEnroll = new hed__Course_Enrollment__c(
            hed__Contact__c = con.Id,
            hed__Course_Offering__c = offering.Id
        );
        insert ceEnroll;
        
        Course_Enrollment__c ceMain = new Course_Enrollment__c(
            Name = 'MainCE',
            Order_of_Priority__c = 1
        );
        insert ceMain;
        
        hed__Course_Offering__c coChild = new hed__Course_Offering__c(
            Course_Enrollment__c = ceMain.Id,
            Course_Pre_requisites__c = 'None',
            hed__Course__c = course.Id,
            hed__Term__c = hedTerm.Id,
            Academic_Term__c = term.Id,
            Program_Pathway__c = ppMain.Id,
            Course_Enrollment_Management__c = cem.Id,
            Interpathway_Capacity_Planner__c = icp.Id
        );
        insert coChild;
        
        Cluster__c cluster = new Cluster__c(
            Name = 'Cluster A',
            Term__c = hedTerm.Id,
            Minimum_Courses__c = 1,
            Maximum_Courses__c = 3,
            Course_Enrollment__c = ceMain.Id
        );
        insert cluster;
        
        Pathway_Unit__c punit = new Pathway_Unit__c(
            Cluster__c = cluster.Id,
            Course__c = course.Id,
            Program_Pathway__c = ppMain.Id,
            Course_Offering__c = offering.Id
        );
        insert punit;
    }
    
    @IsTest
    static void testMissingParams() {
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestURI = '/services/apexrest/courseenrollments/';
        RestContext.request = req;
        
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        Test.startTest();
        CourseEnrollmentAPI.doGet();
        Test.stopTest();
    }
    
    @IsTest
    static void testValidRequest() {
        
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestURI = '/services/apexrest/courseenrollments/';
        req.addParameter('termId', term.Id);
        req.addParameter('contactId', con.Id);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        CourseEnrollmentAPI.doGet();
        Test.stopTest();
    }
    
    @IsTest
    static void testInvalidTermId() {
        
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        RestRequest req = new RestRequest();
        req.httpMethod = 'GET';
        req.requestURI = '/services/apexrest/courseenrollments/';
        req.addParameter('termId', '123456');     // invalid id
        req.addParameter('contactId', con.Id);
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        CourseEnrollmentAPI.doGet();
        Test.stopTest();
    }
}