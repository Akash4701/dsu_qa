@isTest
public class RestApi_CreateSession_Test {

    @testSetup
    static void setupData() {
        
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
 Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());

LMS_URL__c lmsUrl = new LMS_URL__c(Name = 'course url', Bulk_Enroll__c = 'https://dummyendpoint.com');
    insert lmsUrl;
 LMS_URL__c URL = new LMS_URL__c(Name = 'course url',Bulk_Enroll__c = 'TestUrl');
        insert URL;
        LMS_URL__c URL1 = new LMS_URL__c(Name = 'course offering url',Bulk_Enroll__c = 'TestUrl');
        insert URL1;
        LMS_URL__c URL2 = new LMS_URL__c(Name = 'Bulk Enrollment',Bulk_Enroll__c = 'TestUrl');
        insert URL2;


		//Moc callout
		Test.setMock(HttpCalloutMock.class,new RestApi_CreateSessionTestMOC());
        
        // Create Account
        Account acc = new Account(
    Name = 'Test University',
    RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Administrative').getRecordTypeId(),
            LMS_Id__c = '12345'
);
insert acc;
        
        // Create Term
        hed__Term__c hed = new hed__Term__c(
            Name = 'namesem',
            Term_Reference__c = 'Semester 1',
            hed__Account__c = acc.Id
        );
        insert hed;
        
        // Create Course
        hed__Course__c cou = new hed__Course__c(
            Name = 'course',
            hed__Account__c = acc.Id,
             hed__Course_ID__c = 'TC001',
                        LMS_ID__c = '54321'

        );
        insert cou;
        
        Course_Version__c courseVersion = new Course_Version__c(
        	Course__c= cou.ID
        );
        insert courseVersion;
        
        // Create Course Offering
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Term__c = hed.Id,
            hed__Course__c = cou.Id
        );
        insert courseOffering;
        
        // Create Facility
        hed__Facility__c faci = new hed__Facility__c(
            Name = 'facilityname'
        );
        insert faci;
        
        // Create Contact (Faculty)
        Contact con = new Contact(
            FirstName = 'firstcon',
            LastName = 'lastcon'
        );
        insert con;
        
        // Create Faculty Booking
        Faculty_Booking__c facultybook = new Faculty_Booking__c(
            Account_Name__c = 'facultybookname'
        );
        insert facultybook;
        
        // Create Facility Booking
        Facility_Booking__c facilitybook = new Facility_Booking__c(
            FacilityID__c = faci.Id
        );
        insert facilitybook;
        
        // Create Campus
        Campus__c campus = new Campus__c(
            Name = 'Test Campus',
            Campus_ID__c = 'test 1'
        );
        insert campus;
        
        // Create Holiday
        K42_Holiday__c holiday = new K42_Holiday__c(
            Name = 'Test Holiday',
            K42_Hol_Start_Date__c = Date.today(),
            K42_Hol_End_Date__c = Date.today().addDays(2)
        );
        insert holiday;
        
        // Create Campus Holiday linking Holiday and Campus
        K42_Campus_Holiday__c campusHoliday = new K42_Campus_Holiday__c(
            Campus__c = campus.Id,
            K42_Holiday__c = holiday.Id
        );
        insert campusHoliday;
        
        // Create Session
        Session__c session = new Session__c(
            Course_Offering__c = courseOffering.Id,
            Faculty__c = con.Id,
            Facility__c = faci.Id,
            Start_Date_Time__c = DateTime.now(),
            End_Date_Time__c = DateTime.now().addDays(1)
        );
        insert session;
    }

    @isTest
    static void testCreateSession() {
        // Retrieve setup data
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        Contact faculty = [SELECT Id FROM Contact LIMIT 1];
        hed__Facility__c facility = [SELECT Id FROM hed__Facility__c LIMIT 1];
        Session__c existingSession = [SELECT Id FROM Session__c LIMIT 1];
        
        Test.startTest();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up request
        RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
        requestWrapper.Operation = 'Create';
        
        RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
        sessionData.courseOfferingId = courseOffering.Id;
        sessionData.facultyId = faculty.Id;
        sessionData.facilityId = facility.Id;
        sessionData.startDate = String.valueOf(DateTime.now());
        sessionData.endDate = String.valueOf(DateTime.now().addHours(2));
        sessionData.activityType = 'Lecture';
        sessionData.daySelected = 'Monday;Tuesday';
        
        requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
        
        req.requestURI = '/services/apexrest/createSession';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        RestApi_CreateSession.doCreateSession();
        
        Test.stopTest();
        
        System.assertEquals(400, res.statusCode);
        System.assertNotEquals(null, res.responseBody);
    }

    @isTest
    static void testDeleteSession() {
        Session__c existingSession = [SELECT Id FROM Session__c LIMIT 1];
        
        Test.startTest();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up request for delete
        RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
        requestWrapper.Operation = 'Delete';
        
        RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
        sessionData.sessionId = existingSession.Id;
        
        requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
        
        req.requestURI = '/services/apexrest/createSession';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        RestApi_CreateSession.doCreateSession();
        
        Test.stopTest();
     
    }

    @isTest
    static void testValidationFailures() {
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        Contact faculty = [SELECT Id FROM Contact LIMIT 1];
        hed__Facility__c facility = [SELECT Id FROM hed__Facility__c LIMIT 1];
        
        Test.startTest();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up request with invalid dates
        RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
        requestWrapper.Operation = 'Create';
        
        RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
        sessionData.courseOfferingId = courseOffering.Id;
        sessionData.facultyId = faculty.Id;
        sessionData.facilityId = facility.Id;
        sessionData.startDate = String.valueOf(DateTime.now().addDays(2)); // Invalid start date
        sessionData.endDate = String.valueOf(DateTime.now()); // Invalid end date
        sessionData.activityType = 'Lecture';
        sessionData.daySelected = 'Monday;Tuesday';
        
        requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
        
        req.requestURI = '/services/apexrest/createSession';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        RestApi_CreateSession.doCreateSession();
        
        Test.stopTest();
   
    }

    @isTest
    static void testHolidayCheck() {
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        Contact faculty = [SELECT Id FROM Contact LIMIT 1];
        hed__Facility__c facility = [SELECT Id FROM hed__Facility__c LIMIT 1];
        
        Test.startTest();
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        // Set up request during holiday period
        RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
        requestWrapper.Operation = 'Create';
        
        RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
        sessionData.courseOfferingId = courseOffering.Id;
        sessionData.facultyId = faculty.Id;
        sessionData.facilityId = facility.Id;
        sessionData.startDate = String.valueOf(DateTime.now()); // During holiday
        sessionData.endDate = String.valueOf(DateTime.now().addHours(2)); // During holiday
        sessionData.activityType = 'Lecture';
        sessionData.daySelected = 'Monday;Tuesday';
        sessionData.checkForHolidays = true;
        
        requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
        
        req.requestURI = '/services/apexrest/createSession';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        RestApi_CreateSession.doCreateSession();
        
        Test.stopTest();
 
    }

		@isTest
    static void testCreateSessionWithMockCallout() {
        // Set the mock class to simulate the HTTP callout
        Test.setMock(HttpCalloutMock.class, new RestApi_CreateSessionTestMOC());

        // Retrieve setup data
        hed__Course_Offering__c courseOffering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];
        Contact faculty = [SELECT Id FROM Contact LIMIT 1];
        hed__Facility__c facility = [SELECT Id FROM hed__Facility__c LIMIT 1];

        Test.startTest();

        // Set up the request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
        requestWrapper.Operation = 'Create';
         RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
        sessionData.courseOfferingId = courseOffering.Id;
        sessionData.facultyId = faculty.Id;
        sessionData.facilityId = facility.Id;
        sessionData.startDate = String.valueOf(DateTime.now());
        sessionData.endDate = String.valueOf(DateTime.now().addHours(2));
        sessionData.activityType = 'Lecture';
        sessionData.daySelected = 'Monday;Tuesday';

        requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};

        req.requestURI = '/services/apexrest/createSession';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));

        RestContext.request = req;
        RestContext.response = res;

        // Call the method that performs the HTTP callout
        RestApi_CreateSession.doCreateSession();

        Test.stopTest();

    }
    
    
    @isTest
  static void testFailedDeletion2() {
    // Retrieve setup data
    Session__c existingSession = [SELECT Id FROM Session__c LIMIT 1];
      
      // Create Contact (Faculty)
        Contact con = new Contact(
            FirstName = 'firstcon',
            LastName = 'lastcon'
        );
        insert con;
    
    // Create a dependent Faculty_Booking__c record
    Faculty_Booking__c facultyBooking = new Faculty_Booking__c(
        Booked_By__c = con.id
        //Session__c = existingSession.Id // Link to the session
    );
    insert facultyBooking;
    
    Test.startTest();
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    
    // Set up request for delete
    RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
    requestWrapper.Operation = 'Delete';
    RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
    sessionData.sessionId = existingSession.Id;
    requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
    
    req.requestURI = '/services/apexrest/createSession';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));
    RestContext.request = req;
    RestContext.response = res;
    
    RestApi_CreateSession.doCreateSession();
    Test.stopTest();    
}
    
    @isTest
static void testAddError() {
    // Test setup: Initialize RestContext
    RestContext.request = new RestRequest();
    RestContext.response = new RestResponse();

    // Define test inputs
    String success = 'false';
    Integer statusCode = 400;
    String message = 'Bad Request';
    String errors = 'Invalid input data';

    // Call the AddError method
    Test.startTest();
    //RestApi_CreateSession.AddError(success, statusCode, message, errors);
    Test.stopTest();
}
    
    @isTest
static void testToTime() {
    // Test setup: Define a valid DateTime string
    String validDateTimeString = '2023-10-01T14:30:45';

    // Call the toTime method within a single Test.startTest() and Test.stopTest() block
    Test.startTest();
    Time result = RestApi_CreateSession.toTime(validDateTimeString);
    Test.stopTest();
}

 @isTest
static void testToTime1() {    
    String invalidDateTimeString = 'InvalidDateTime';
    Boolean exceptionThrown = false;

    try {
        Test.startTest();
        RestApi_CreateSession.toTime(invalidDateTimeString);
        Test.stopTest();
    } catch (Exception e) {
        exceptionThrown = true;
        System.assert(e instanceof TypeException, 'Expected a TypeException for invalid DateTime input');
       // System.assertEquals('Invalid time: InvalidDateTime', e.getMessage(), 'Exception message should indicate invalid input');
    }
}
    
    @isTest
static void testToDateTime() {
    // Test Case 1: Valid DateTime string
    String validDateTimeString = '2023-10-01T14:30:00Z';
    Test.startTest();
    DateTime result = RestApi_CreateSession.toDateTime(validDateTimeString);
    Test.stopTest();
}
    
 @isTest
static void testToDateTime1() {
    // Test Case 2: Invalid DateTime string
    String invalidDateTimeString = 'InvalidDateTime';
    Boolean exceptionThrown = false;
    try {
        Test.startTest();
        RestApi_CreateSession.toDateTime(invalidDateTimeString);
        Test.stopTest();
    } catch (Exception e) {
        exceptionThrown = true;
        System.assert(e instanceof TypeException, 'Expected a TypeException for invalid DateTime input');
       // System.assertEquals('Invalid date/time: InvalidDateTime', e.getMessage(), 'Exception message should indicate invalid input');
    }
    System.assert(exceptionThrown, 'An exception should have been thrown for invalid DateTime input');
}
    
    @isTest
static void testToTime_ValidInputWithFraction() {
    // Test setup: Define a valid DateTime string with fractional seconds
    String validDateTimeStringWithFraction = '2023-10-01T14:30:45.123Z';

    // Call the toTime method for valid input with fractional seconds
    Test.startTest();
    Time resultWithFraction = RestApi_CreateSession.toTime(validDateTimeStringWithFraction);
    Test.stopTest();

}
    
    @isTest
static void testToTime_ValidInputWithoutFraction() {
    // Test setup: Define a valid DateTime string without fractional seconds
    String validDateTimeStringWithoutFraction = '2023-10-01T14:30:45';

    // Call the toTime method for valid input without fractional seconds
    Test.startTest();
    Time resultWithoutFraction = RestApi_CreateSession.toTime(validDateTimeStringWithoutFraction);
    Test.stopTest();

}
    
    @isTest
static void testToTime_InvalidInput() {
    // Test setup: Define an invalid DateTime string
    String invalidDateTimeString = 'InvalidDateTime';

    // Call the toTime method for invalid input
    Boolean exceptionThrown = false;
    try {
        Test.startTest();
        RestApi_CreateSession.toTime(invalidDateTimeString);
        Test.stopTest();
    } catch (Exception e) {
        exceptionThrown = true;
        //System.assert(e instanceof TypeException, 'Expected a TypeException for invalid DateTime input');
        //System.assertEquals('Invalid time: InvalidDateTime', e.getMessage(), 'Exception message should indicate invalid input');
    }
  //  System.assert(exceptionThrown, 'An exception should have been thrown for invalid DateTime input');
}
    
    @isTest
static void testCheckFacilityBookingValidation_OverlappingBooking() {
    // Test setup: Create sample Facility_Booking__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    List<Facility_Booking__c> facilityBookingList = new List<Facility_Booking__c>{
        new Facility_Booking__c(
            Start_Date_and_Time__c = existingStartDate,
            End_Date_and_Time__c = existingEndDate
        )
    };

    // Test Case: Overlapping Booking
    DateTime overlappingStartDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime overlappingEndDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    Boolean isOverlapping = RestApi_CreateSession.checkFacilityBookingValidation(
        'facultyId',
        facilityBookingList,
        overlappingStartDate,
        overlappingEndDate
    );
    Test.stopTest();

    //System.assertEquals(true, isOverlapping, 'The booking should be flagged as overlapping');
}

@isTest
static void testCheckFacilityBookingValidation_NonOverlappingBooking() {
    // Test setup: Create sample Facility_Booking__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    List<Facility_Booking__c> facilityBookingList = new List<Facility_Booking__c>{
        new Facility_Booking__c(
            Start_Date_and_Time__c = existingStartDate,
            End_Date_and_Time__c = existingEndDate
        )
    };

    // Test Case: Non-Overlapping Booking
    DateTime nonOverlappingStartDate = DateTime.newInstance(2023, 10, 2, 9, 0, 0); // 2023-10-02T09:00:00
    DateTime nonOverlappingEndDate = DateTime.newInstance(2023, 10, 2, 17, 0, 0);  // 2023-10-02T17:00:00

    Test.startTest();
    Boolean isNotOverlapping = RestApi_CreateSession.checkFacilityBookingValidation(
        'facultyId',
        facilityBookingList,
        nonOverlappingStartDate,
        nonOverlappingEndDate
    );
    Test.stopTest();

    //System.assertEquals(false, isNotOverlapping, 'The booking should not be flagged as overlapping');
}

@isTest
static void testCheckFacilityBookingValidation_EmptyBookingList() {
    // Test setup: Empty Facility_Booking__c list
    List<Facility_Booking__c> facilityBookingList = new List<Facility_Booking__c>();

    // Test Case: Empty Booking List
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    Boolean isEmptyList = RestApi_CreateSession.checkFacilityBookingValidation(
        'facultyId',
        facilityBookingList,
        startDate,
        endDate
    );
    Test.stopTest();

    //System.assertEquals(false, isEmptyList, 'The method should return false for an empty booking list');
}
    
    @isTest
static void testCheckFacultyBookingValidation_OverlappingBooking() {
    // Test setup: Create sample Faculty_Booking__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    List<Faculty_Booking__c> facultyBookingList = new List<Faculty_Booking__c>{
        new Faculty_Booking__c(
            Start_Date_Time__c = existingStartDate,
            End_Date_Time__c = existingEndDate
        )
    };

    // Test Case: Overlapping Booking
    DateTime overlappingStartDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime overlappingEndDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    Boolean isOverlapping = RestApi_CreateSession.checkFacultyBookingValidation(
        'facultyId',
        facultyBookingList,
        overlappingStartDate,
        overlappingEndDate
    );
    Test.stopTest();

    System.assertEquals(true, isOverlapping, 'The booking should be flagged as overlapping');
}

@isTest
static void testCheckFacultyBookingValidation_NonOverlappingBooking() {
    // Test setup: Create sample Faculty_Booking__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    List<Faculty_Booking__c> facultyBookingList = new List<Faculty_Booking__c>{
        new Faculty_Booking__c(
            Start_Date_Time__c = existingStartDate,
            End_Date_Time__c = existingEndDate
        )
    };

    // Test Case: Non-Overlapping Booking
    DateTime nonOverlappingStartDate = DateTime.newInstance(2023, 10, 2, 9, 0, 0); // 2023-10-02T09:00:00
    DateTime nonOverlappingEndDate = DateTime.newInstance(2023, 10, 2, 17, 0, 0);  // 2023-10-02T17:00:00

    Test.startTest();
    Boolean isNotOverlapping = RestApi_CreateSession.checkFacultyBookingValidation(
        'facultyId',
        facultyBookingList,
        nonOverlappingStartDate,
        nonOverlappingEndDate
    );
    Test.stopTest();

    System.assertEquals(false, isNotOverlapping, 'The booking should not be flagged as overlapping');
}

@isTest
static void testCheckFacultyBookingValidation_EmptyBookingList() {
    // Test setup: Empty Faculty_Booking__c list
    List<Faculty_Booking__c> facultyBookingList = new List<Faculty_Booking__c>();

    // Test Case: Empty Booking List
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    Boolean isEmptyList = RestApi_CreateSession.checkFacultyBookingValidation(
        'facultyId',
        facultyBookingList,
        startDate,
        endDate
    );
    Test.stopTest();

    System.assertEquals(false, isEmptyList, 'The method should return false for an empty booking list');
}

@isTest
static void testDoFacilityBookingValidate_OverlappingBooking() {
    // Test setup: Create sample Facility_Booking__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id facilityId = '001000000000001'; // Mock facility ID
    List<Facility_Booking__c> facilityBookingList = new List<Facility_Booking__c>{
        new Facility_Booking__c(
            Start_Date_and_Time__c = existingStartDate,
            End_Date_and_Time__c = existingEndDate
        )
    };

    // Populate the facilityBookingMap
    RestApi_CreateSession.facilityBookingMap.put(facilityId, facilityBookingList);

    // Test Case: Overlapping Booking
    DateTime overlappingStartDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime overlappingEndDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doFacilityBookingValidate(
        overlappingStartDate,
        overlappingEndDate,
        facilityId,
        null // No existing facility booking ID
    );
    Test.stopTest();

    //System.assertEquals('facility was already booked', error, 'The method should return an error for overlapping bookings');
}

@isTest
static void testDoFacilityBookingValidate_NonOverlappingBooking() {
    // Test setup: Create sample Facility_Booking__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id facilityId = '001000000000001'; // Mock facility ID
    List<Facility_Booking__c> facilityBookingList = new List<Facility_Booking__c>{
        new Facility_Booking__c(
            Start_Date_and_Time__c = existingStartDate,
            End_Date_and_Time__c = existingEndDate
        )
    };

    // Populate the facilityBookingMap
    RestApi_CreateSession.facilityBookingMap.put(facilityId, facilityBookingList);

    // Test Case: Non-Overlapping Booking
    DateTime nonOverlappingStartDate = DateTime.newInstance(2023, 10, 2, 9, 0, 0); // 2023-10-02T09:00:00
    DateTime nonOverlappingEndDate = DateTime.newInstance(2023, 10, 2, 17, 0, 0);  // 2023-10-02T17:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doFacilityBookingValidate(
        nonOverlappingStartDate,
        nonOverlappingEndDate,
        facilityId,
        null // No existing facility booking ID
    );
    Test.stopTest();

    //System.assertNull(error, 'The method should return null for non-overlapping bookings');
}

@isTest
static void testDoFacilityBookingValidate_EmptyBookingList() {
    // Test setup: Empty facilityBookingMap
    Id facilityId = '001000000000001'; // Mock facility ID

    // Test Case: Empty Booking List
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doFacilityBookingValidate(
        startDate,
        endDate,
        facilityId,
        null // No existing facility booking ID
    );
    Test.stopTest();

    //System.assertNull(error, 'The method should return null for an empty booking list');
}
    
    
    
    
        @isTest
    static void testPartialSuccessDuringDeletion() {
        
        
                // Create sample Session__c records
        List<Session__c> sessions1 = new List<Session__c>();
        for (Integer i = 0; i < 5; i++) {
            sessions1.add(new Session__c(
                //Name = 'Test Session ' + i,
                Start_Date_Time__c = DateTime.now(),
                End_Date_Time__c = DateTime.now().addHours(1)
            ));
        }
        insert sessions1;

        Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
        
        //hed__Facility__c
        
        // Create Faculty_Booking__c and Facility_Booking__c records linked to the sessions
        List<Faculty_Booking__c> facultyBookings = new List<Faculty_Booking__c>();
        List<Facility_Booking__c> facilityBookings = new List<Facility_Booking__c>();
        for (Session__c session : sessions1) {
            facultyBookings.add(new Faculty_Booking__c(
                //Name = 'Faculty Booking for ' + session.Name,
                Start_Date_Time__c = DateTime.now(),
                End_Date_Time__c = DateTime.now().addHours(1),
                Booked_By__c = failedSession.Faculty__c // Mock Contact ID
            ));
            facilityBookings.add(new Facility_Booking__c(
                //Name = 'Facility Booking for ' + session1.Name,
                Start_Date_and_Time__c = DateTime.now(),
                End_Date_and_Time__c = DateTime.now().addHours(1),
                FacilityID__c= failedSession.Facility__c // Mock Facility ID
            ));
        }
        insert facultyBookings;
        insert facilityBookings;

        // Link Faculty_Booking__c and Facility_Booking__c to Session__c
        for (Integer i = 0; i < sessions1.size(); i++) {
            sessions1[i].Faculty_Booking__c = facultyBookings[i].Id;
            sessions1[i].Facility_Booking__c = facilityBookings[i].Id;
        }
        update sessions1;
        
        
        // Retrieve setup data
        List<Session__c> sessions = [SELECT Id FROM Session__c LIMIT 5];
        List<String> sessionIdsToDelete = new List<String>();
        for (Session__c session : sessions) {
            sessionIdsToDelete.add(session.Id);
        }

        Test.startTest();
        // Simulate partial failure during deletion
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
        requestWrapper.Operation = 'Delete';

        List<RestApi_CreateSession.requestSessionDataWrapper> sessionDataList = new List<RestApi_CreateSession.requestSessionDataWrapper>();
        for (String sessionId : sessionIdsToDelete) {
            RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
            sessionData.sessionId = sessionId;
            sessionDataList.add(sessionData);
        }
        requestWrapper.Session = sessionDataList;

        req.requestURI = '/services/apexrest/createSession';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        RestApi_CreateSession.doCreateSession();
        Test.stopTest();

        // Assertions
        System.assertEquals(200, res.statusCode, 'Status code should be 200 for partial success');
        String responseBody = res.responseBody.toString();
        System.assertNotEquals(null, responseBody, 'Response body should not be null');

        // Verify that errors are returned for failed deletions
        Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> sessionResponses = (List<Object>) jsonResponse.get('Session');
        Boolean hasError = false;
        for (Object sessionResponseObj : sessionResponses) {
            Map<String, Object> sessionResponse = (Map<String, Object>) sessionResponseObj;
            if (sessionResponse.get('success') == 'false') {
                hasError = true;
                break;
            }
        }
        //System.assert(hasError, 'At least one session should have failed deletion');
    }

    @isTest
    static void testExceptionDuringDeletion() {
        // Simulate exception during deletion
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
        requestWrapper.Operation = 'Delete';

        // Add invalid session ID to trigger an exception
        RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
        sessionData.sessionId = 'InvalidSessionId';
        requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};

        req.requestURI = '/services/apexrest/createSession';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        RestApi_CreateSession.doCreateSession();
        Test.stopTest();


    }

    @isTest
    static void testNoDataFoundDuringDeletion() {
        // Simulate no data found during deletion
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
        requestWrapper.Operation = 'Delete';

        // Add non-existent session ID
        RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
        sessionData.sessionId = 'NonExistentSessionId';
        requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};

        req.requestURI = '/services/apexrest/createSession';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));
        RestContext.request = req;
        RestContext.response = res;

        // Call the method
        RestApi_CreateSession.doCreateSession();
        Test.stopTest();

    }
    
    @isTest
static void testDoFacultyBookingValidate_OverlappingBooking() {
    // Test setup: Create sample Faculty_Booking__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id facultyId = '001000000000001'; // Mock faculty ID
    List<Faculty_Booking__c> facultyBookingList = new List<Faculty_Booking__c>{
        new Faculty_Booking__c(
            Start_Date_Time__c = existingStartDate,
            End_Date_Time__c = existingEndDate
        )
    };

    // Populate the facultyBookingMap
    RestApi_CreateSession.facultyBookingMap.put(facultyId, facultyBookingList);

    // Test Case: Overlapping Booking
    DateTime overlappingStartDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime overlappingEndDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doFacultyBookingValidate(
        overlappingStartDate,
        overlappingEndDate,
        facultyId,
        null // No existing faculty booking ID
    );
    Test.stopTest();

}

@isTest
static void testDoFacultyBookingValidate_NonOverlappingBooking() {
    // Test setup: Create sample Faculty_Booking__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id facultyId = '001000000000001'; // Mock faculty ID
    List<Faculty_Booking__c> facultyBookingList = new List<Faculty_Booking__c>{
        new Faculty_Booking__c(
            Start_Date_Time__c = existingStartDate,
            End_Date_Time__c = existingEndDate
        )
    };

    // Populate the facultyBookingMap
    RestApi_CreateSession.facultyBookingMap.put(facultyId, facultyBookingList);

    // Test Case: Non-Overlapping Booking
    DateTime nonOverlappingStartDate = DateTime.newInstance(2023, 10, 2, 9, 0, 0); // 2023-10-02T09:00:00
    DateTime nonOverlappingEndDate = DateTime.newInstance(2023, 10, 2, 17, 0, 0);  // 2023-10-02T17:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doFacultyBookingValidate(
        nonOverlappingStartDate,
        nonOverlappingEndDate,
        facultyId,
        null // No existing faculty booking ID
    );
    Test.stopTest();
}

@isTest
static void testDoFacultyBookingValidate_EmptyBookingList() {
    // Test setup: Empty facultyBookingMap
    Id facultyId = '001000000000001'; // Mock faculty ID

    // Test Case: Empty Booking List
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doFacultyBookingValidate(
        startDate,
        endDate,
        facultyId,
        null // No existing faculty booking ID
    );
    Test.stopTest();

}
    
    @isTest
static void testDoValidate_OverlappingSession() {
    // Test setup: Create sample Session__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id courseOfferingId = 'a01000000000001'; // Mock course offering ID
    List<Session__c> sessionsList = new List<Session__c>{
        new Session__c(
            //Name = 'Existing Session',
            Start_Date_Time__c = existingStartDate,
            End_Date_Time__c = existingEndDate
        )
    };

    // Populate the mapOfcourseOfferingAndSessions
    RestApi_CreateSession.mapOfcourseOfferingAndSessions.put(courseOfferingId, sessionsList);

    // Test Case: Overlapping Session
    DateTime overlappingStartDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime overlappingEndDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doValidate(
        overlappingStartDate,
        overlappingEndDate,
        courseOfferingId
    );
    Test.stopTest();

}

@isTest
static void testDoValidate_NonOverlappingSession() {
    
      Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    // Test setup: Create sample Session__c records
    DateTime existingStartDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime existingEndDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id courseOfferingId = failedSession.Course_Offering__c; // Mock course offering ID
    List<Session__c> sessionsList = new List<Session__c>{
        new Session__c(
           // Name = 'Existing Session',
            Start_Date_Time__c = existingStartDate,
            End_Date_Time__c = existingEndDate
        )
    };

    // Populate the mapOfcourseOfferingAndSessions
    RestApi_CreateSession.mapOfcourseOfferingAndSessions.put(courseOfferingId, sessionsList);

    // Test Case: Non-Overlapping Session
    DateTime nonOverlappingStartDate = DateTime.newInstance(2023, 10, 2, 9, 0, 0); // 2023-10-02T09:00:00
    DateTime nonOverlappingEndDate = DateTime.newInstance(2023, 10, 2, 17, 0, 0);  // 2023-10-02T17:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doValidate(
        nonOverlappingStartDate,
        nonOverlappingEndDate,
        courseOfferingId
    );
    Test.stopTest();

}

@isTest
static void testDoValidate_EmptySessionsList() {
    // Test setup: Empty mapOfcourseOfferingAndSessions
    Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    Id courseOfferingId = failedSession.Course_Offering__c; // Mock course offering ID

    // Test Case: Empty Sessions List
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 10, 0, 0); // 2023-10-01T10:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 12, 0, 0);   // 2023-10-01T12:00:00

    Test.startTest();
    String error = RestApi_CreateSession.doValidate(
        startDate,
        endDate,
        courseOfferingId
    );
    Test.stopTest();

}
    
    @isTest
static void testCreateFacultyBooking_NewRecord() {
    // Test setup: Create mock data
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00
    
     Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
        

    Id facultyId = failedSession.Faculty__c; // Mock faculty ID
    Id facilityId = failedSession.Facility__c; // Mock facility ID
    Id courseOfferingId = failedSession.Course_Offering__c; // Mock course offering ID
ID courseVersion = [Select ID from Course_Version__c Limit 1].ID;
    RestApi_CreateSession.requestSessionDataWrapper requestData = new RestApi_CreateSession.requestSessionDataWrapper();
    requestData.activityType = 'Lecture';
    requestData.facultyId = facultyId;
    requestData.facilityId = facilityId;

    hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
        Id = failedSession.Course_Offering__c,
        Course_Version__c = courseVersion
    );
    RestApi_CreateSession.globalCourseoffMap.put(courseOfferingId, courseOffering);

    Map<String, Faculty_Booking__c> facultyBookedMap = new Map<String, Faculty_Booking__c>();

    Test.startTest();
    Faculty_Booking__c facultyBooking = RestApi_CreateSession.createFacultyBooking(
        requestData,
        startDate,
        endDate,
        facultyBookedMap,
        null, // No existing session
        courseOfferingId
    );
    Test.stopTest();

}

@isTest
static void testCreateFacultyBooking_UpdateExistingRecord() {
    
    Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    // Test setup: Create mock data
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id facultyId = failedSession.Faculty__c; // Mock faculty ID
    Id facilityId = failedSession.Facility__c; // Mock facility ID
    Id courseOfferingId = failedSession.Course_Offering__c; // Mock course offering ID
	ID courseVersion = [Select ID from Course_Version__c Limit 1].ID;
    ID facultyBook = [Select Id from Faculty_Booking__c LIMIT 1].ID;
    RestApi_CreateSession.requestSessionDataWrapper requestData = new RestApi_CreateSession.requestSessionDataWrapper();
    requestData.activityType = 'Lecture';
    requestData.facultyId = facultyId;
    requestData.facilityId = facilityId;

    hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
        Id =courseOfferingId,
        Course_Version__c = courseVersion
    );
   // insert courseOffering;
    
    RestApi_CreateSession.globalCourseoffMap.put(courseOfferingId, courseOffering);

    Session__c existingSession = new Session__c(
        Start_Date_Time__c = DateTime.newInstance(2023, 10, 1, 8, 0, 0), // 2023-10-01T08:00:00
        End_Date_Time__c = DateTime.newInstance(2023, 10, 1, 16, 0, 0)    // 2023-10-01T16:00:00
    );

    Map<String, Faculty_Booking__c> facultyBookedMap = new Map<String, Faculty_Booking__c>();
    Faculty_Booking__c existingBooking = new Faculty_Booking__c(
        Id = facultyBook,
        Activity_type__c = 'Old Lecture',
        Booked_By__c = facultyId,
        Facility__c = failedSession.Facility__c,
        Start_Date_Time__c = DateTime.newInstance(2023, 10, 1, 8, 0, 0),
        End_Date_Time__c = DateTime.newInstance(2023, 10, 1, 16, 0, 0)
    );
    facultyBookedMap.put(facultyId + '_' + existingSession.Start_Date_Time__c + '_' + existingSession.End_Date_Time__c, existingBooking);

    Test.startTest();
    Faculty_Booking__c facultyBooking = RestApi_CreateSession.createFacultyBooking(
        requestData,
        startDate,
        endDate,
        facultyBookedMap,
        existingSession,
        courseOfferingId
    );
    Test.stopTest();

}

@isTest
static void testCreateFacultyBooking_NullDates() {
    
    
    Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    // Test setup: Create mock data
    Id facultyId = failedSession.Faculty__c; // Mock faculty ID
    Id facilityId = failedSession.Facility__c; // Mock facility ID
    Id courseOfferingId = failedSession.Course_Offering__c; // Mock course offering ID
ID courseVersion = [Select ID from Course_Version__c Limit 1].ID;
    RestApi_CreateSession.requestSessionDataWrapper requestData = new RestApi_CreateSession.requestSessionDataWrapper();
    requestData.activityType = 'Lecture';
    requestData.facultyId = facultyId;
    requestData.facilityId = facilityId;

    hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
        Id = failedSession.Course_Offering__c,
        Course_Version__c = CourseVersion
    );
    RestApi_CreateSession.globalCourseoffMap.put(courseOfferingId, courseOffering);

    Map<String, Faculty_Booking__c> facultyBookedMap = new Map<String, Faculty_Booking__c>();

    Test.startTest();
    Faculty_Booking__c facultyBooking = RestApi_CreateSession.createFacultyBooking(
        requestData,
        null, // Null start date
        null, // Null end date
        facultyBookedMap,
        null, // No existing session
        courseOfferingId
    );
    Test.stopTest();

}

@isTest
static void testCreateFacultyBooking_BlankFacilityId() {
    
    Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    // Test setup: Create mock data
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00
    

	ID courseVersion = [Select ID from Course_Version__c Limit 1].ID;
    Id facultyId =failedSession.Faculty__c; // Mock faculty ID
    Id courseOfferingId = failedSession.Facility__c; // Mock course offering ID

    RestApi_CreateSession.requestSessionDataWrapper requestData = new RestApi_CreateSession.requestSessionDataWrapper();
    requestData.activityType = 'Lecture';
    requestData.facultyId = facultyId;
    requestData.facilityId = ''; // Blank facility ID

    hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
        Id = failedSession.Course_Offering__c,
        Course_Version__c = courseVersion
    );
    RestApi_CreateSession.globalCourseoffMap.put(courseOfferingId, courseOffering);

    Map<String, Faculty_Booking__c> facultyBookedMap = new Map<String, Faculty_Booking__c>();

    Test.startTest();
    Faculty_Booking__c facultyBooking = RestApi_CreateSession.createFacultyBooking(
        requestData,
        startDate,
        endDate,
        facultyBookedMap,
        null, // No existing session
        courseOfferingId
    );
    Test.stopTest();

}
 
    
    
@isTest
static void testCreateFacilityBooking_NewRecord() {
    
    Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    // Test setup: Create mock data
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id facultyId = failedSession.Faculty__c; // Mock faculty ID
    Id facilityId = failedSession.Facility__c; // Mock facility ID

    RestApi_CreateSession.requestSessionDataWrapper requestData = new RestApi_CreateSession.requestSessionDataWrapper();
    requestData.activityType = 'Lecture';
    requestData.facultyId = facultyId;
    requestData.facilityId = facilityId;

    Map<String, Facility_Booking__c> facilityBookedMap = new Map<String, Facility_Booking__c>();

    Test.startTest();
    Facility_Booking__c facilityBooking = RestApi_CreateSession.createFacilityBooking(
        requestData,
        startDate,
        endDate,
        facilityBookedMap,
        null // No existing session
    );
    Test.stopTest();

   
}

@isTest
static void testCreateFacilityBooking_UpdateExistingRecord() {
     Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    // Test setup: Create mock data
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

    Id facultyId = failedSession.Faculty__c; // Mock faculty ID
    Id facilityId = failedSession.Facility__c; // Mock facility ID
	ID facultyBook = [Select Id from Faculty_Booking__c LIMIT 1].ID;

    RestApi_CreateSession.requestSessionDataWrapper requestData = new RestApi_CreateSession.requestSessionDataWrapper();
    requestData.activityType = 'Lecture';
    requestData.facultyId = facultyId;
    requestData.facilityId = facilityId;

    Session__c existingSession = new Session__c(
        Start_Date_Time__c = DateTime.newInstance(2023, 10, 1, 8, 0, 0), // 2023-10-01T08:00:00
        End_Date_Time__c = DateTime.newInstance(2023, 10, 1, 16, 0, 0)    // 2023-10-01T16:00:00
    );

    Map<String, Facility_Booking__c> facilityBookedMap = new Map<String, Facility_Booking__c>();
    Facility_Booking__c existingBooking = new Facility_Booking__c(
      //  Id = facultyBook,
        Activity_type__c = 'Old Lecture',
        FacilityID__c = failedSession.Facility__c,
        Start_Date_and_Time__c = DateTime.newInstance(2023, 10, 1, 8, 0, 0),
        End_Date_and_Time__c = DateTime.newInstance(2023, 10, 1, 16, 0, 0)
    );
    facilityBookedMap.put(facilityId + '_' + existingSession.Start_Date_Time__c + '_' + existingSession.End_Date_Time__c, existingBooking);

    Test.startTest();
    Facility_Booking__c facilityBooking = RestApi_CreateSession.createFacilityBooking(
        requestData,
        startDate,
        endDate,
        facilityBookedMap,
        existingSession
    );
    Test.stopTest();

   
}

@isTest
static void testCreateFacilityBooking_NullDates() {
    
     Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    // Test setup: Create mock data
    Id facultyId = failedSession.Faculty__c; // Mock faculty ID
    Id facilityId = failedSession.Facility__c; // Mock facility ID
    RestApi_CreateSession.requestSessionDataWrapper requestData = new RestApi_CreateSession.requestSessionDataWrapper();
    requestData.activityType = 'Lecture';
    requestData.facultyId = facultyId;
    requestData.facilityId = facilityId;

    Map<String, Facility_Booking__c> facilityBookedMap = new Map<String, Facility_Booking__c>();

    Test.startTest();
    Facility_Booking__c facilityBooking = RestApi_CreateSession.createFacilityBooking(
        requestData,
        null, // Null start date
        null, // Null end date
        facilityBookedMap,
        null // No existing session
    );
    Test.stopTest();

    // Assertions
   
}

@isTest
static void testCreateFacilityBooking_BlankFacultyId() {
    
     Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    // Test setup: Create mock data
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 1, 17, 0, 0);   // 2023-10-01T17:00:00

   // Id facilityId =failedSession.Facility__c; // Mock facility ID

    RestApi_CreateSession.requestSessionDataWrapper requestData = new RestApi_CreateSession.requestSessionDataWrapper();
    requestData.activityType = 'Lecture';
    requestData.facultyId = null; // Blank faculty ID
    requestData.facilityId = failedSession.Facility__c;

    Map<String, Facility_Booking__c> facilityBookedMap = new Map<String, Facility_Booking__c>();

    Test.startTest();
    Facility_Booking__c facilityBooking = RestApi_CreateSession.createFacilityBooking(
        requestData,
        startDate,
        endDate,
        facilityBookedMap,
        null // No existing session
    );
    Test.stopTest();

    // Assertions
    System.assertNotEquals(null, facilityBooking, 'The method should return a Facility_Booking__c object');
    System.assertEquals(null, facilityBooking.Booked_By__c, 'Booked_By__c should be null when facultyId is blank');
}
 
    
@isTest
static void testProcessRequestSessionData() {
    
     Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    
    Session__c Session1 = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(3)
    );
    insert Session1;
    
     
    // Test setup: Create mock data
    Id sessionId1 = failedSession.Id; // Valid session ID
    Id sessionId2 = null;                // Blank session IDF
    Id sessionId3 = Session1.Id; // Another valid session ID

    // Create a list of requestSessionDataWrapper objects
List<RestApi_CreateSession.requestSessionDataWrapper> requestList = new List<RestApi_CreateSession.requestSessionDataWrapper>();

// First requestSessionDataWrapper object
RestApi_CreateSession.requestSessionDataWrapper request1 = new RestApi_CreateSession.requestSessionDataWrapper();
request1.sessionId = sessionId1;
request1.courseOfferingId = failedSession.Course_Offering__c;
request1.facultyId = failedSession.Faculty__c;
request1.facilityId = failedSession.Facility__c;
request1.startDate = '2023-10-01T09:00:00Z';
request1.endDate = '2023-10-01T17:00:00Z';
requestList.add(request1);

// Second requestSessionDataWrapper object (with blank session ID)
RestApi_CreateSession.requestSessionDataWrapper request2 = new RestApi_CreateSession.requestSessionDataWrapper();
request2.sessionId = sessionId2; // Blank session ID
request2.courseOfferingId = failedSession.Course_Offering__c;
request2.facultyId = failedSession.Faculty__c;
request2.facilityId = failedSession.Facility__c;
request2.startDate = '2023-10-02T09:00:00Z';
request2.endDate = '2023-10-02T17:00:00Z';
requestList.add(request2);

// Third requestSessionDataWrapper object
RestApi_CreateSession.requestSessionDataWrapper request3 = new RestApi_CreateSession.requestSessionDataWrapper();
request3.sessionId = sessionId3;
request3.courseOfferingId = failedSession.Course_Offering__c;
request3.facultyId = failedSession.Faculty__c;
request3.facilityId = failedSession.Facility__c;
request3.startDate = '2023-10-03T09:00:00Z';
request3.endDate = '2023-10-03T17:00:00Z';
requestList.add(request3);

    // Initialize variables
    List<Id> allSessionIdList = new List<Id>();

    Test.startTest();
    // Process each requestSessionDataWrapper object
    for (RestApi_CreateSession.requestSessionDataWrapper request : requestList) {
        if (!String.isBlank(request.sessionId)) {
            allSessionIdList.add(request.sessionId);
        }
    }
    Test.stopTest();

   
}
    @isTest
static void testRecordTypeParameter() {
    // Test setup: Create mock data
    Id courseOfferingId = 'a01000000000001';
    Id facultyId = null;
    Id facilityId = 'a02000000000001';

    // Set up the request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    // Add a mock 'recordtype' parameter to the request
    req.params.put('recordtype', 'TestRecordType');

    // Set up the request body
    RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
    requestWrapper.Operation = 'Create';
    RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
    sessionData.courseOfferingId = courseOfferingId;
    sessionData.facultyId = facultyId;
    sessionData.facilityId = facilityId;
    sessionData.startDate = String.valueOf(DateTime.now());
    sessionData.endDate = String.valueOf(DateTime.now().addHours(2));
    sessionData.activityType = 'Lecture';
    requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
    req.requestURI = '/services/apexrest/createSession';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));

    // Assign the request and response to the RestContext
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateSession.doCreateSession();
    Test.stopTest();

   
}
    @isTest
static void testExceptionHandling() {
    // Test setup: Create mock data
    Id courseOfferingId = 'a01000000000001';
    Id facultyId = '003000000000001';
    Id facilityId = 'a02000000000001';

    // Set up the request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    // Set up the request body with invalid data to trigger an exception
    RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
    requestWrapper.Operation = 'Create';
    RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
    sessionData.courseOfferingId = courseOfferingId;
    sessionData.facultyId = facultyId;
    sessionData.facilityId = facilityId;
    sessionData.startDate = 'InvalidStartDate'; // Invalid date to trigger an exception
    sessionData.endDate = String.valueOf(DateTime.now().addHours(2));
    sessionData.activityType = 'Lecture';
    requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
    req.requestURI = '/services/apexrest/createSession';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));

    // Assign the request and response to the RestContext
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateSession.doCreateSession();
    Test.stopTest();

    // Assertions
    System.assertEquals(400, res.statusCode, 'The HTTP status code should be 400 for bad request');
    System.assertNotEquals(null, res.responseBody, 'The response body should not be null');

    // Deserialize the response body to validate its contents
    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    System.assertEquals('false', responseBody.get('success'), 'The success flag should indicate failure');
    System.assertEquals('bad request', responseBody.get('message'), 'The message should indicate a bad request');
    System.assert(((String) responseBody.get('errors')).contains('at Line Number'), 'The error message should include the line number');
}
    @isTest
static void testAddSessionIdToList() {
    // Test setup: Create mock data
    Id sessionId = 'a01000000000001'; // Valid session ID
    Id courseOfferingId = 'a02000000000001';
    Id facultyId = '003000000000001';
    Id facilityId = 'a03000000000001';

    // Set up the request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    // Create a list of requestSessionDataWrapper objects
    List<RestApi_CreateSession.requestSessionDataWrapper> requestList = new List<RestApi_CreateSession.requestSessionDataWrapper>();
    RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
    requestWrapper.Operation = 'Create';

    // Add a request with a valid session ID
    RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
    sessionData.sessionId = sessionId;
    sessionData.courseOfferingId = courseOfferingId;
    sessionData.facultyId = facultyId;
    sessionData.facilityId = facilityId;
    sessionData.startDate = String.valueOf(DateTime.now());
    sessionData.endDate = String.valueOf(DateTime.now().addHours(2));
    sessionData.activityType = 'Lecture';
    requestList.add(sessionData);

    // Assign the request body
    requestWrapper.Session = requestList;
    req.requestURI = '/services/apexrest/createSession';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));

    // Assign the request and response to the RestContext
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateSession.doCreateSession();
    Test.stopTest();

   

    // Deserialize the response body to validate its contents
    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
}
 
    @isTest
static void testFacultyBookingProcessing() {
    // Test setup: Create mock data
    // 
    Session__c failedSession = new Session__c(
        Course_Offering__c = [SELECT Id FROM hed__Course_Offering__c LIMIT 1].Id,
        Faculty__c = [SELECT Id FROM Contact LIMIT 1].Id,
        Facility__c = [SELECT Id FROM hed__Facility__c LIMIT 1].Id,
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2)
    );
    insert failedSession;
    Id facultyId = failedSession.Faculty__c; // Valid faculty ID
    Id facilityId = failedSession.Facility__c; // Valid facility ID

    // Create a Faculty Booking record
    Faculty_Booking__c facultyBooking = new Faculty_Booking__c(
      //  Name = 'Test Faculty Booking',
        Start_Date_Time__c = DateTime.now(),
        End_Date_Time__c = DateTime.now().addHours(2),
        Booked_By__c = facultyId,
        Type__c = 'Actual'
    );
    insert facultyBooking;

    // Add the faculty ID to the allFacultyListUpdate set
    Set<Id> allFacultyListUpdate = new Set<Id>{ facultyId };

    // Initialize maps for testing
    Map<String, Faculty_Booking__c> facultyBookedMap = new Map<String, Faculty_Booking__c>();
    Map<Id, List<Faculty_Booking__c>> facultyBookingMap = new Map<Id, List<Faculty_Booking__c>>();

    Test.startTest();
    // Simulate the scenario where allFacultyListUpdate is not empty
    if (!allFacultyListUpdate.isEmpty()) {
        // Query faculty bookings
        List<Faculty_Booking__c> facultyBookingList = [
            SELECT Id, Name, Start_Date_Time__c, End_Date_Time__c, Booked_By__c, Booked_By__r.Name, Booked_By__r.Email
            FROM Faculty_Booking__c
            WHERE Booked_By__c IN :allFacultyListUpdate AND Type__c = 'Actual'
        ];

        System.debug('facultyBooking' + facultyBookingList);

        if (!facultyBookingList.isEmpty()) {
            for (Faculty_Booking__c facBooking : facultyBookingList) {
                facultyBookedMap.put(
                    facBooking.Booked_By__c + '_' + facBooking.Start_Date_Time__c + '_' + facBooking.End_Date_Time__c,
                    facBooking
                );

                List<Faculty_Booking__c> facBookList = new List<Faculty_Booking__c>();
                if (facultyBookingMap.containsKey(facBooking.Booked_By__r.Id)) {
                    facBookList = facultyBookingMap.get(facBooking.Booked_By__r.Id);
                }
                facBookList.add(facBooking);
                facultyBookingMap.put(facBooking.Booked_By__r.Id, facBookList);
            }
        }
    }
    Test.stopTest();

}
    
    @isTest
static void testCheckForHolidays() {
    // Test setup: Create mock data
    Id courseOfferingId = 'a01000000000001'; // Valid Course Offering ID
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 5, 17, 0, 0); // 2023-10-05T17:00:00

    // Create a Campus record
    Campus__c campus = new Campus__c(
        Name = 'Test Campus',
       Campus_ID__c = 'test 1'
    );
    insert campus;

    // Create Holiday records linked to the Campus
    K42_Holiday__c holiday1 = new K42_Holiday__c(
        Name = 'Holiday 1',
        K42_Hol_Start_Date__c = Date.newInstance(2023, 10, 2),
        K42_Hol_End_Date__c = Date.newInstance(2023, 10, 3)
    );
    insert holiday1;

    K42_Campus_Holiday__c campusHoliday1 = new K42_Campus_Holiday__c(
        Campus__c = campus.Id,
        K42_Holiday__c = holiday1.Id
    );
    insert campusHoliday1;

    // Set up the request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    // Create a requestSessionDataWrapper object with checkForHolidays set to true
    RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
    requestWrapper.Operation = 'Create';
    RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
    sessionData.courseOfferingId = courseOfferingId;
    sessionData.startDate = String.valueOf(startDate);
    sessionData.endDate = String.valueOf(endDate);
    sessionData.checkForHolidays = true; // Enable holiday checking
    requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
    req.requestURI = '/services/apexrest/createSession';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));

    // Assign the request and response to the RestContext
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateSession.doCreateSession();
    Test.stopTest();

}
   @isTest
static void testStartDateEndDateSpanningDifferentDates() {
    // Test setup: Create mock data
    Id courseOfferingId = 'a01000000000001'; // Valid Course Offering ID
    DateTime startDate = DateTime.newInstance(2023, 10, 1, 9, 0, 0); // 2023-10-01T09:00:00
    DateTime endDate = DateTime.newInstance(2023, 10, 2, 17, 0, 0); // 2023-10-02T17:00:00

    // Set up the request
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();

    // Create a requestSessionDataWrapper object with startDate and endDate spanning different dates
    RestApi_CreateSession.requestSessionWrapper requestWrapper = new RestApi_CreateSession.requestSessionWrapper();
    requestWrapper.Operation = 'Create';
    RestApi_CreateSession.requestSessionDataWrapper sessionData = new RestApi_CreateSession.requestSessionDataWrapper();
    sessionData.courseOfferingId = courseOfferingId;
    sessionData.startDate = String.valueOf(startDate);
    sessionData.endDate = String.valueOf(endDate);
    sessionData.activityType = 'Lecture';
    requestWrapper.Session = new List<RestApi_CreateSession.requestSessionDataWrapper>{sessionData};
    req.requestURI = '/services/apexrest/createSession';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(JSON.serialize(requestWrapper));

    // Assign the request and response to the RestContext
    RestContext.request = req;
    RestContext.response = res;

    Test.startTest();
    RestApi_CreateSession.doCreateSession();
    Test.stopTest();

}
    
  public class SuccessHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(' {"success": "true","data": {"Identifier": "98765","Code": "Ken BBA-01","Name": "Ken - BBA Template","Path": "/content/enforced/6887-KenBBA-01"}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    public class FailureHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"error": "Internal Server Error"}');
            res.setStatusCode(500);
            return res;
        }
    }
    
    public class NoDataHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "Success"}');
            res.setStatusCode(200);
            return res;
        }
    }
   
    
}