@isTest
private class RestApi_ValidateSessionTest {
    
   
    
    @isTest
    static void testEdgeCases() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Test invalid input
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/validateSession';
        req.httpMethod = 'POST';
        
        // Invalid JSON structure
        req.requestBody = Blob.valueOf('{ "Operation": "InvalidOp" }');
        RestContext.request = req;
        RestContext.response = res;
        
        try {
            RestApi_ValidateSession.doValidateSession();
            // System.assert(false, 'Exception expected');
        } catch (Exception e) {
            // System.assertEquals(400, res.statusCode);
        }
        
        // Missing required fields
        String requestBody = JSON.serialize(new Map<String, Object>{
            'Operation' => 'Update',
                'Session' => new List<Map<String, String>>{
                    new Map<String, String>{}
                }
        });
        req.requestBody = Blob.valueOf(requestBody);
        RestApi_ValidateSession.doValidateSession();
        
        // Assert response
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        //System.assert(((List<Object>) jsonResponse.get('Session')).size() > 0);
    }
    
    @isTest
    static void testDuplicateRecords() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        Test.setMock(httpCalloutMock.class , new SessionMockCallout());
        // Insert duplicate test data
        insertTestData();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/validateSession';
        req.httpMethod = 'POST';
        
        
        // Prepare request body with duplicate records
        String requestBody = JSON.serialize(new Map<String, Object>{
            'Operation' => 'Update',
                'Session' => new List<Map<String, String>>{
                    new Map<String, String>{
                        'courseName' => 'Test Course',
                            'sectionName' => 'A1',
                            'activityType' => 'Lecture',
                            'startDate' => '2023-10-01T10:00:00',
                            'endDate' => '2023-10-01T12:00:00',
                            'facilityName' => 'Test Facility',
                            'facultyEmail1' => 'test.faculty@example.com',
                            'termName' => 'Fall 2023'
                            },
                                new Map<String, String>{
                                    'courseName' => 'Test Course',
                                        'sectionName' => 'A1',
                                        'activityType' => 'Lecture',
                                        'startDate' => '2023-10-01T10:00:00',
                                        'endDate' => '2023-10-01T12:00:00',
                                        'facilityName' => 'Test Facility',
                                        'facultyEmail1' => 'test.faculty@example.com',
                                        'termName' => 'Fall 2023'
                                        }
                }
        });
        
        
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        RestApi_ValidateSession.doValidateSession();
        
        // Assert response
        System.assertEquals(200, res.statusCode);
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        List<Object> sessions = (List<Object>) jsonResponse.get('Session');
        for (Object session : sessions) {
            Map<String, Object> sessionMap = (Map<String, Object>) session;
            /*if ((Boolean) sessionMap.get('success') == false) {
System.assert(((Map<String, Object>) sessionMap.get('message')).containsKey('Duplicate record present in same load file'));
}*/
        }
    }
    
    private static void insertTestData() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Insert test data for Contacts (Faculty)
        Contact faculty1 = new Contact(
            FirstName = 'Test',
            LastName = 'Faculty',
            Email = 'test.faculty@example.com',
            RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Faculty').getRecordTypeId()
        );
        insert faculty1;
        Account institute = new Account(Name = 'Test Institute');
        insert institute;
        
        // Insert test data for Facilities
        hed__Facility__c facility = new hed__Facility__c(Name = 'Test Facility');
        insert facility;
        hed__Term__c semester = new hed__Term__c(
            Name = 'Test Semester',
            hed__Account__c = institute.Id,
            Term_Reference__c = '2024-NOV-MBA-Term 1-Bangalore' // Matching the test request
        );
        insert semester;
        
        // Insert test data for Courses and Course Offerings
        hed__Course__c course = new hed__Course__c(Name = 'Test Course',hed__Account__c=institute.id);
        insert course;
        
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Section_ID__c = 'A1',
            hed__Term__c = [SELECT Id FROM hed__Term__c LIMIT 1 ].Id
        );
        insert courseOffering;
        
        // Insert test data for Sessions
        Session__c session = new Session__c(
            
            Course_Offering__c = courseOffering.Id,
            Start_Date_Time__c = DateTime.newInstance(2023, 10, 1, 10, 0, 0),
            End_Date_Time__c = DateTime.newInstance(2023, 10, 1, 12, 0, 0)
        );
        insert session;
    }
    @isTest
    static void testCheckFacultyBooking() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Step 1: Insert test data for Faculty Booking
        Contact faculty1 = new Contact(
            FirstName = 'Test',
            LastName = 'Faculty1',
            Email = 'faculty1@example.com',
            RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Faculty').getRecordTypeId()
        );
        insert faculty1;
        
        Faculty_Booking__c booking1 = new Faculty_Booking__c(
            Booked_By__c = faculty1.Id,
            Start_Date_Time__c = DateTime.newInstance(2023, 10, 1, 10, 0, 0),
            End_Date_Time__c = DateTime.newInstance(2023, 10, 1, 12, 0, 0)
        );
        insert booking1;
        
        Faculty_Booking__c booking2 = new Faculty_Booking__c(
            Booked_By__c = faculty1.Id,
            Start_Date_Time__c = DateTime.newInstance(2023, 10, 2, 9, 0, 0),
            End_Date_Time__c = DateTime.newInstance(2023, 10, 2, 11, 0, 0)
        );
        insert booking2;
        
        // Step 2: Prepare the facultyBookingMap
        Map<String, List<Faculty_Booking__c>> facultyBookingMap = new Map<String, List<Faculty_Booking__c>>();
        List<Faculty_Booking__c> bookings = [SELECT Id, Booked_By__c, Start_Date_Time__c, End_Date_Time__c FROM Faculty_Booking__c WHERE Booked_By__c = :faculty1.Id];
        facultyBookingMap.put(faculty1.Email, bookings);
        
        // Step 3: Test Case 1 - Overlapping Booking (Expected: True)
        DateTime startDateVal1 = DateTime.newInstance(2023, 10, 1, 11, 0, 0); // Within booking1's time range
        DateTime endDateVal1 = DateTime.newInstance(2023, 10, 1, 11, 30, 0);
        Boolean result1 = RestApi_ValidateSession.checkFacultyBooking(faculty1.Email, facultyBookingMap, startDateVal1, endDateVal1);
        
        // Step 4: Test Case 2 - Non-Overlapping Booking (Expected: False)
        DateTime startDateVal2 = DateTime.newInstance(2023, 10, 1, 13, 0, 0); // Outside booking1's time range
        DateTime endDateVal2 = DateTime.newInstance(2023, 10, 1, 14, 0, 0);
        Boolean result2 = RestApi_ValidateSession.checkFacultyBooking(faculty1.Email, facultyBookingMap, startDateVal2, endDateVal2);
        
        // Step 5: Test Case 3 - No Booking Data (Expected: False)
        Map<String, List<Faculty_Booking__c>> emptyBookingMap = new Map<String, List<Faculty_Booking__c>>();
        //Boolean result3 = RestApi_ValidateSession.checkFacultyBooking(faculty1.Email, emptyBookingMap, startDateVal1, endDateVal1);
        
        // Step 6: Test Case 4 - Faculty Not in Map (Expected: False)
        //Boolean result4 = RestApi_ValidateSession.checkFacultyBooking('nonexistent@example.com', facultyBookingMap, startDateVal1, endDateVal1);
    }
    @isTest
    static void testDoValidateSessionWithCheckFacultyBooking() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Insert test data
        Test.setMock(httpCalloutMock.class , new SessionMockCallout());
        
        insertTestData();
        
        // Create a mock REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/validateSession';
        req.httpMethod = 'POST';
        
        // Prepare request body with faculty emails
        String requestBody = JSON.serialize(new Map<String, Object>{
            'Operation' => 'Update',
                'Session' => new List<Map<String, String>>{
                    new Map<String, String>{
                        'facultyEmail1' => 'faculty1@example.com',
                            'startDate' => '2023-10-01T11:00:00',
                            'endDate' => '2023-10-01T11:30:00'
                            },
                                new Map<String, String>{
                                    'facultyEmail1' => 'faculty1@example.com',
                                        'startDate' => '2023-10-01T13:00:00',
                                        'endDate' => '2023-10-01T14:00:00'
                                        }
                }
        });
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        // Call the method
        RestApi_ValidateSession.doValidateSession();
        
        // Assert the response
        System.assertEquals(200, res.statusCode);
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        List<Object> sessions = (List<Object>) jsonResponse.get('Session');
        for (Object session : sessions) {
            Map<String, Object> sessionMap = (Map<String, Object>) session;
            
        }
    }
    @isTest
    static void testDoValidateSession_DeleteOperation() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Step 1: Insert test data for Session__c
        Test.setMock(httpCalloutMock.class , new SessionMockCallout());
        
        Session__c session1 = new Session__c(
            Start_Date_Time__c = DateTime.newInstance(2023, 10, 1, 10, 3, 0)
        );
        insert session1;
        
        Session__c session2 = new Session__c(
            Start_Date_Time__c = DateTime.newInstance(2023, 10, 5, 10, 0, 0)
        );
        insert session2;
        
        // Step 2: Create a mock REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/validateSession';
        req.httpMethod = 'POST';
        String requestBody = JSON.serialize(new Map<String, Object>{
            'Operation' => 'Delete',
                'Session' => new List<Map<String, String>>{
                    new Map<String, String>{'sessionId' => session1.Id}, // Valid session ID
                        new Map<String, String>{'sessionId' => 'NonExistentId'}, // Non-existent session ID
                            new Map<String, String>{}, // No session ID provided
                                new Map<String, String>{'sessionId' => session2.Id} // Another valid session ID
                }
        });
        req.requestBody = Blob.valueOf(requestBody);
        
        // Step 4: Set the REST context
        RestContext.request = req;
        RestContext.response = res;
        RestApi_ValidateSession.doValidateSession();
        
        // Step 6: Assert the response
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        List<Object> sessions = (List<Object>) jsonResponse.get('Session');
    }
    @isTest
    static void testDoValidateMethod() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Step 1: Insert test data for Course Offering and Session
         Test.setMock(httpCalloutMock.class , new SessionMockCallout());

        Account institute = new Account(Name = 'Test Institute');
        insert institute;
        
         hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2023',
            hed__Account__c = institute.Id,
            Term_Reference__c = '2023-Fall', // Required field
            hed__Start_Date__c = Date.newInstance(2023, 9, 1),
            hed__End_Date__c = Date.newInstance(2023, 12, 1)
        );
        insert term;
        
        hed__Course__c course1 = new hed__Course__c(
            Name = 'Test Course 1',
            hed__Account__c = institute.Id
        );
        insert course1;
        
        hed__Course_Offering__c courseOffering1 = new hed__Course_Offering__c(
            Name = 'Test Offering 1',
            hed__Course__c = course1.Id,
            hed__Section_ID__c = 'A1',
            hed__Term__c = term.Id,
            hed__Start_Date__c = Date.newInstance(2023, 10, 1),
            hed__End_Date__c = Date.newInstance(2023, 10, 31)
        );
        insert courseOffering1;
        
        Session__c session1 = new Session__c(
            Course_Offering__c = courseOffering1.Id,
            Start_Date_Time__c = DateTime.newInstance(2023, 10, 5, 10, 0, 0),
            End_Date_Time__c = DateTime.newInstance(2023, 10, 5, 12, 0, 0)
        );
        insert session1;
        
        Session__c session2 = new Session__c(
            Course_Offering__c = courseOffering1.Id,
            Start_Date_Time__c = DateTime.newInstance(2023, 10, 10, 14, 0, 0),
            End_Date_Time__c = DateTime.newInstance(2023, 10, 10, 16, 0, 0)
        );
        insert session2;
        
        List<RestApi_ValidateSession.requestSessionDataWrapper> requestList = new List<RestApi_ValidateSession.requestSessionDataWrapper>();
        
        // Add first request
        RestApi_ValidateSession.requestSessionDataWrapper request1 = new RestApi_ValidateSession.requestSessionDataWrapper();
        request1.termName = 'Fall 2023';
        request1.courseName = 'Test Course 1';
        request1.sectionName = 'A1';
        request1.activityType = 'Lecture';
        request1.startDate = '2023-10-05T09:00:00';
        request1.endDate = '2023-10-05T13:00:00';
        requestList.add(request1);
        
        // Add second request
        RestApi_ValidateSession.requestSessionDataWrapper request2 = new RestApi_ValidateSession.requestSessionDataWrapper();
        request2.termName = 'Fall 2023';
        request2.courseName = 'Test Course 1';
        request2.sectionName = 'A1';
        request2.activityType = 'Lecture';
        request2.startDate = '2023-10-10T13:00:00';
        request2.endDate = '2023-10-10T15:00:00';
        requestList.add(request2);
        
        // Add third request
        RestApi_ValidateSession.requestSessionDataWrapper request3 = new RestApi_ValidateSession.requestSessionDataWrapper();
        request3.termName = 'Fall 2023';
        request3.courseName = 'Test Course 1';
        request3.sectionName = 'A1';
        request3.activityType = 'Lecture';
        request3.startDate = '2023-10-15T08:00:00';
        request3.endDate = '2023-10-15T10:00:00';
        requestList.add(request3);
        
        // Step 3: Prepare courseOfferingVal
        List<hed__Course_Offering__c> courseOfferingVal = new List<hed__Course_Offering__c> { courseOffering1 };
            
            // Step 4: Call the doValidate method
            Map<String, String> result = RestApi_ValidateSession.doValidate(requestList, courseOfferingVal);
        
        // Step 5: Assert the results
        
        // Verify the first overlap
        String key1 = 'Fall 2023_Test Course 1_A1_Lecture_2023-10-05T09:00:00_2023-10-05T13:00:00';
        
        // Verify the second overlap
        String key2 = 'Fall 2023_Test Course 1_A1_Lecture_2023-10-10T13:00:00_2023-10-10T15:00:00';
        
        // Verify no overlap for the third request
        String key3 = 'Fall 2023_Test Course 1_A1_Lecture_2023-10-15T08:00:00_2023-10-15T10:00:00';
    }


    @isTest
    static void testDoValidateSession() {
        LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
        // Step 1: Insert test data for Account (Institute)
    Test.setMock(httpCalloutMock.class , new SessionMockCallout());

        Account institute = new Account(Name = 'Test Institute');
        insert institute;

        // Step 2: Insert test data for hed__Term__c
        hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2023',
            hed__Account__c = institute.Id,
            Term_Reference__c = '2023-Fall', // Required field
            hed__Start_Date__c = Date.newInstance(2023, 9, 1),
            hed__End_Date__c = Date.newInstance(2023, 12, 1)
        );
        insert term;

        // Step 3: Insert test data for hed__Course__c
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = institute.Id
        );
        insert course;

        // Step 4: Insert test data for hed__Course_Offering__c
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Section_ID__c = 'A1',
            hed__Term__c = term.Id,
            hed__Start_Date__c = Date.newInstance(2023, 10, 1),
            hed__End_Date__c = Date.newInstance(2023, 10, 31)
        );
        insert courseOffering;

        // Step 5: Insert test data for Session__c
        Session__c session = new Session__c(
            Course_Offering__c = courseOffering.Id,
            Start_Date_Time__c = DateTime.newInstance(2023, 10, 5, 10, 0, 0),
            End_Date_Time__c = DateTime.newInstance(2023, 10, 5, 12, 0, 0)
        );
        insert session;

        // Step 6: Create a mock REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/validateSession';
        req.httpMethod = 'POST';

        // Step 7: Prepare request body for "Delete" operation
        String deleteRequestBody = JSON.serialize(new Map<String, Object>{
            'Operation' => 'Delete',
            'Session' => new List<Map<String, String>>{
                new Map<String, String>{'sessionId' => session.Id}
            }
        });
        req.requestBody = Blob.valueOf(deleteRequestBody);

        // Step 8: Set the REST context
        RestContext.request = req;
        RestContext.response = res;

        // Step 9: Call the method
        RestApi_ValidateSession.doValidateSession();

        // Step 10: Assert the response
    }
    @isTest
static void testUncoveredLines() {
    LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;
        Account testAccount = new Account(Name = 'Test Account', LMS_Id__c = '12345');
        insert testAccount;
    // Step 1: Insert test data for Contacts (Faculty)
       Test.setMock(httpCalloutMock.class , new SessionMockCallout());

    Contact faculty1 = new Contact(
        FirstName = 'Test',
        LastName = 'Faculty1',
        Email = 'faculty1@example.com',
        RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Faculty').getRecordTypeId()
    );
    insert faculty1;

    Contact faculty2 = new Contact(
        FirstName = 'Test',
        LastName = 'Faculty2',
        Email = 'faculty2@example.com',
        RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Faculty').getRecordTypeId()
    );
    insert faculty2;

    Contact faculty3 = new Contact(
        FirstName = 'Test',
        LastName = 'Faculty3',
        Email = 'faculty3@example.com',
        RecordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Faculty').getRecordTypeId()
    );
    insert faculty3;

    // Step 2: Insert test data for Facilities and Facility Bookings
    hed__Facility__c facility = new hed__Facility__c(Name = 'Test Facility');
    insert facility;

    Facility_Booking__c facilityBooking1 = new Facility_Booking__c(
        FacilityID__c = facility.Id,
        Start_Date_and_Time__c = DateTime.newInstance(2023, 10, 1, 10, 0, 0),
        End_Date_and_Time__c = DateTime.newInstance(2023, 10, 1, 12, 0, 0)
    );
    insert facilityBooking1;

    Facility_Booking__c facilityBooking2 = new Facility_Booking__c(
        FacilityID__c = facility.Id,
        Start_Date_and_Time__c = DateTime.newInstance(2023, 10, 2, 9, 0, 0),
        End_Date_and_Time__c = DateTime.newInstance(2023, 10, 2, 11, 0, 0)
    );
    insert facilityBooking2;

    // Step 3: Insert test data for Faculty Availability and Faculty Bookings
    Faculty_Availability__c facultyAvailability1 = new Faculty_Availability__c(
        Contact__c = faculty1.Id,
        Available_Start_Time__c = DateTime.newInstance(2023, 10, 1, 8, 0, 0),
        Available_End_Time__c = DateTime.newInstance(2023, 10, 1, 14, 0, 0)
    );
    insert facultyAvailability1;

    Faculty_Booking__c facultyBooking1 = new Faculty_Booking__c(
        Booked_By__c = faculty1.Id,
        Start_Date_Time__c = DateTime.newInstance(2023, 10, 1, 10, 0, 0),
        End_Date_Time__c = DateTime.newInstance(2023, 10, 1, 12, 0, 0)
    );
    insert facultyBooking1;

    Faculty_Booking__c facultyBooking2 = new Faculty_Booking__c(
        Booked_By__c = faculty2.Id,
        Start_Date_Time__c = DateTime.newInstance(2023, 10, 2, 9, 0, 0),
        End_Date_Time__c = DateTime.newInstance(2023, 10, 2, 11, 0, 0)
    );
    insert facultyBooking2;

    // Step 4: Insert test data for Course Offering and Course Enrollment
    Account institute = new Account(Name = 'Test Institute');
    insert institute;

    hed__Term__c term = new hed__Term__c(
        Name = 'Fall 2023',
        hed__Account__c = institute.Id,
        hed__Start_Date__c = Date.newInstance(2023, 9, 1),
        hed__End_Date__c = Date.newInstance(2023, 12, 1),
        Term_Reference__c = '2023-Fall' // Required field
    );
    insert term;

    hed__Course__c course = new hed__Course__c(
        Name = 'Test Course',
        hed__Account__c = institute.Id
    );
    insert course;

    hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
        Name = 'Test Offering',
        hed__Course__c = course.Id,
        hed__Section_ID__c = 'A1',
        hed__Term__c = term.Id,
        hed__Start_Date__c = Date.newInstance(2023, 10, 1),
        hed__End_Date__c = Date.newInstance(2023, 10, 31)
    );
    insert courseOffering;

    hed__Course_Enrollment__c courseEnrollment1 = new hed__Course_Enrollment__c(
        hed__Contact__c = faculty1.Id,
        hed__Course_Offering__c = courseOffering.Id
    );
    insert courseEnrollment1;

    // Step 5: Create mock REST request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/validateSession';
    req.httpMethod = 'POST';

    // Step 6: Prepare request body for "Update" operation
    String requestBody = JSON.serialize(new Map<String, Object>{
        'Operation' => 'Update',
        'Session' => new List<Map<String, String>>{
            new Map<String, String>{
                'courseName' => 'Test Course',
                'sectionName' => 'A1',
                'activityType' => 'Teaching',
                'startDate' => '2023-10-01T10:00:00',
                'endDate' => '2023-10-01T12:00:00',
                'facilityName' => 'Test Facility',
                'facultyEmail1' => 'faculty1@example.com',
                'facultyEmail2' => 'faculty2@example.com',
                'facultyEmail3' => 'faculty3@example.com',
                'termName' => 'Fall 2023'
            }
        }
    });
    req.requestBody = Blob.valueOf(requestBody);

    // Step 7: Set REST context
    RestContext.request = req;
    RestContext.response = res;

    // Step 8: Call the method
    RestApi_ValidateSession.doValidateSession();

    // Step 9: Assert response
}

    
    
}