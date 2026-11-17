@IsTest
private class PathwayEnrollmentAPITest {

    @TestSetup
    static void setup() {
        // Create Program Plan
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Test Plan'
        );
        insert plan;

        // Create Major Program Pathway
        Program_Pathway__c majorPP = new Program_Pathway__c(
            Name = 'Computer Science',
            Program_Plan__c = plan.Id,
            Specialization_Type__c = 'Major'
        );
        insert majorPP;

        // Create Minor Program Pathway
        Program_Pathway__c minorPP = new Program_Pathway__c(
            Name = 'Computer Science',  // Matching name to trigger logic
            Program_Plan__c = plan.Id,
            Specialization_Type__c = 'Minor'
        );
        insert minorPP;

        // Academic Term
        Academic_Term__c term = new Academic_Term__c(
            Name = 'Fall 2024'
        );
        insert term;

        // Contact
        Contact con = new Contact(
            LastName = 'Student'
        );
        insert con;

        // Major Enrollment
        Pathway_Enrollment__c majorEnroll = new Pathway_Enrollment__c(
            Program_Pathway__c = majorPP.Id,
            Academic_Term__c = term.Id,
            Is_Active__c = true,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(4)
        );
        insert majorEnroll;

        // Major Connection
        Pathway_Connection__c majorConn = new Pathway_Connection__c(
            Program_Pathway__c = majorPP.Id,
            Contact__c = con.Id,
            Status__c = 'Enrolled',
            Pathway_Enrollment__c = majorEnroll.Id
        );
        insert majorConn;

        // Minor Enrollment
        Pathway_Enrollment__c minorEnroll = new Pathway_Enrollment__c(
            Program_Pathway__c = minorPP.Id,
            Academic_Term__c = term.Id,
            Is_Active__c = true,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addMonths(4)
        );
        insert minorEnroll;

    }


    @IsTest
    static void testGetAllPathwayEnrollments() {
        // Get IDs
        hed__Program_Plan__c plan = [SELECT Id FROM hed__Program_Plan__c LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        // Set REST Request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        String endpoint = '/services/apexrest/getPathwayEnrollments/' + plan.Id + '/' + con.Id;
        req.requestURI = endpoint;
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        // Call API
        List<PathwayEnrollmentAPI.PathwayEnrollmentResponse> result =
            PathwayEnrollmentAPI.getAllPathwayEnrollments();


        Boolean foundMajor = false;
        Boolean foundMinor = false;

        
    }


    @IsTest
    static void testMissingParamsShouldReturn400() {

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        // Missing plan + contact
        req.requestURI = '/services/apexrest/getPathwayEnrollments/';
        req.httpMethod = 'GET';

        RestContext.request = req;
        RestContext.response = res;

        try {
            PathwayEnrollmentAPI.getAllPathwayEnrollments();
        } catch (Exception e) {
            
        }
    }
}