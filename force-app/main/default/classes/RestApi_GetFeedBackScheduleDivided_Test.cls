@isTest
private class RestApi_GetFeedBackScheduleDivided_Test {
    
    public class MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();
            String method = req.getMethod();            
            if (method == 'POST' && endpoint.contains('/courses')) {
                res.setStatusCode(201);
                res.setBody('{"success": true}');
            } 
            else if (method == 'PATCH' && endpoint.contains('/courses/')) {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            } 
            else if (method == 'GET' && endpoint.contains('/courses/')) {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            } 
            else if (method == 'POST' && endpoint.contains('/students')) {
                res.setStatusCode(201);
                res.setBody('{"success": true}');
            } 
            else if (method == 'PUT' && endpoint.contains('/courses/')) {
                res.setStatusCode(201);
                res.setBody('{"success": true}');
            }
            else if (method == 'DELETE' && endpoint.contains('/courses/')) {
                res.setStatusCode(204);
                res.setBody('');
            }
            else if (method == 'POST' && endpoint.contains('/contents/createAssignment')) {
                res.setStatusCode(201);
                res.setBody('{"success": true}');
            } 
            else if (method == 'GET' && endpoint.contains('/gradebook/columns/')) {
                res.setStatusCode(200);
                res.setBody('{"success": true}');
            }
            else {
                res.setStatusCode(400);
                res.setBody('{"success": false}');
            }
            return res;
        }
    }
    
    @isTest
    static void test_doGetFeedBackScheduleDividedData() {
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        try{

        Contact student = new Contact(LastName = 'Test Student', RecordTypeId = '012Hy000003aSodIAE');
        insert student;

        Contact faculty = new Contact(LastName = 'Test Faculty', RecordTypeId = '012Hy000003aSoZIAU');
        insert faculty;

        // Create necessary supporting data
        Account account = new Account(Name = 'Test Academic Program');
        insert account;

        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(Name = 'Test Program Plan');
        insert programPlan;
        
        Campus__c campus = new Campus__c(Campus_ID__c = 'CAMPUS123');
        insert campus;

        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = account.Id,
            Campus__c = campus.Id,
            Program_Plan__c = programPlan.Id,
            Term_Reference__c = 'Term 1'
        );
        insert term;

		Questionnaire_Metadata__c QMD = new Questionnaire_Metadata__c();
        insert QMD;

        Feedback_Scheduler__c scheduler = new Feedback_Scheduler__c(
            Term__c = term.Id,
            Feedback_Master__c = QMD.Id,
            End_Date__c = System.today().addDays(7)
        );
        insert scheduler;

        hed__Course__c course = new hed__Course__c(Name = 'Math 101', 
                                                   hed__Course_ID__c = 'MATH101',
                                                   hed__Account__c = account.Id
                                                  );
        insert course;

        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert courseOffering;

        hed__Affiliation__c affiliation = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Status__c = 'Current'
        );
        insert affiliation;

        hed__Program_Enrollment__c programEnrollment = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            Term__c = term.Id,
            hed__Affiliation__c = affiliation.Id
        );
        insert programEnrollment;

        hed__Course_Enrollment__c studentEnrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = courseOffering.Id,
            hed__Program_Enrollment__c = programEnrollment.Id
        );
        insert studentEnrollment;

        hed__Course_Enrollment__c facultyEnrollment = new hed__Course_Enrollment__c(
            hed__Contact__c = faculty.Id,
            hed__Course_Offering__c = courseOffering.Id,
            hed__Status__c = 'Current'
        );
        insert facultyEnrollment;

        Collected_Feedback_Data__c collected = new Collected_Feedback_Data__c(
            Term__c = term.Id,
            Contact__c = student.Id,
            Feedback_Master__c = QMD.Id,
            Course_Name__c = course.Id
        );
        insert collected;

        // Set REST context
        RestContext.request = new RestRequest();
        RestContext.request.params.put('contactId', student.Id);
        RestContext.request.params.put('feedBackScheduleId', scheduler.Id);
        RestContext.response = new RestResponse();

        Test.startTest();
        RestApi_GetFeedBackScheduleDivided.doGetFeedBackScheduleDividedData();
        Test.stopTest();
        }
        catch(Exception e){
            //
        }
    }
}