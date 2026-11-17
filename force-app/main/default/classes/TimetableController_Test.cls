@isTest
private with sharing class TimetableController_Test {

    @testSetup
    static void setupTestData() {
        
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
        // Create Account (Academic Program)
        RecordType academicProgramRT = [SELECT Id,DeveloperName  FROM RecordType WHERE DeveloperName = 'Academic_Program' AND SObjectType = 'Account'];
       

        Account account = new Account(Name = 'Test University', RecordTypeId = academicProgramRT.Id,LMS_Id__c = '12345');
        insert account;

        // Create hed__Program_Plan__c
        hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
            Name = 'Computer Science Plan',
            hed__Account__c = account.Id
        );
        insert programPlan;

        // Create hed__Term__c
        hed__Term__c term = new hed__Term__c(
            Name = 'Fall 2024',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(3),
            hed__Account__c=account.id,
            Term_Reference__c='Term 1'
        );
        insert term;

        // Create hed__Course_Offering__c
        hed__Course__c course = new hed__Course__c(
            Name = 'Intro to CS',
           
            hed__Account__c=account.id,
             hed__Course_ID__c = 'TC001',
                        LMS_ID__c = '54321'

        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'CS101-F24-A',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        // Create Section Data Map (mocked via JSON serialization)
        Map<String, List<Id>> sectionToOfferingIds = new Map<String, List<Id>>();
        sectionToOfferingIds.put('A', new List<Id>{offering.Id});

        // Store section ID list as JSON string
        String sectionIdsList = JSON.serialize(sectionToOfferingIds.get('A'));
        
        Contact fac = new Contact(LastName = 'testFac');
        insert fac;
        
        hed__Facility__c facility = new hed__Facility__c(
            Name = 'Room 101',
            hed__Facility_Type__c = ''
        );
        insert facility;

        // Create Session__c (custom object used internally)
        Session__c session = new Session__c(
         //   Name = 'Session A',
            Start_Date_Time__c = DateTime.now(),
            End_Date_Time__c = DateTime.now().addHours(2),
            Course_Offering__c = offering.Id,
            Type_of_Activity__c = 'Teaching',
            Faculty__c = fac.Id,
            Facility__c = facility.Id,
            Account_Name__c = 'accountName'
        );
        insert session;

        // Create Faculty Contact
        RecordType facultyRT = [SELECT Id FROM RecordType WHERE DeveloperName = 'Faculty' AND SObjectType = 'Contact'];
      

        Contact contact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            RecordTypeId = facultyRT.Id
        );
        insert contact;

        // Insert Faculty Booking
        Faculty_Booking__c booking = new Faculty_Booking__c(
           
        );
        insert booking;

        // Insert Facility Booking
        Facility_Booking__c fbooking = new Facility_Booking__c(
            FacilityID__c=facility.id
          
        );
        insert fbooking;
    }

    @isTest
    static void test_getAcademicPrograms() {
        List<TimetableController.ComboboxOption> result = TimetableController.getAcademicPrograms();
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void test_getProgramPlans() {
        List<Account> accounts = [SELECT Id FROM Account];
        List<TimetableController.ComboboxOption> result = TimetableController.getProgramPlans(accounts[0].Id);
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void test_getTerms() {
        List<hed__Program_Plan__c> plans = [SELECT Id FROM hed__Program_Plan__c];
        List<TimetableController.ComboboxOption> result = TimetableController.getTerms(plans[0].Id);
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void test_getSections() {
        List<hed__Term__c> terms = [SELECT Id FROM hed__Term__c];
        List<TimetableController.ComboboxOption> result = TimetableController.getSections(terms[0].Id);
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void test_getSubjects() {
        List<hed__Term__c> terms = [SELECT Id FROM hed__Term__c];
        List<hed__Course_Offering__c> offerings = [SELECT Id FROM hed__Course_Offering__c];

        String sectionIdsList = JSON.serialize(new List<Id>{offerings[0].Id});
        List<TimetableController.SubjectOption> result = TimetableController.getSubjects(terms[0].Id, sectionIdsList);
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void test_getActivityTypes() {
        List<TimetableController.ComboboxOption> result = TimetableController.getActivityTypes();
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void test_getFacilities() {
        List<TimetableController.ComboboxOption> result = TimetableController.getFacilities();
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void test_getFacultyMembers() {
        List<TimetableController.ComboboxOption> result = TimetableController.getFacultyMembers();
        System.assertNotEquals(0, result.size());
    }

    @isTest
    static void test_saveRecurringSessions() {
        Session__c session = [SELECT Id FROM Session__c LIMIT 1];
        Map<String, Object> sessionMap = new Map<String, Object>();
        sessionMap.put('startDate', Date.today());
        sessionMap.put('endDate', Date.today().addDays(7));
        sessionMap.put('startTime', '09:00 AM');
        sessionMap.put('endTime', '11:00 AM');
        sessionMap.put('accountId', [SELECT Id FROM Account LIMIT 1].Id);

        List<Map<String, Object>> selectedDaysObj = new List<Map<String, Object>>();
        Map<String, Object> dayData = new Map<String, Object>();
        dayData.put('day', 'Monday');
        dayData.put('startTime', '09:00 AM');
        dayData.put('endTime', '11:00 AM');
        selectedDaysObj.add(dayData);

        sessionMap.put('selectedDays', selectedDaysObj);
  //      String sessionId = TimetableController.saveRecurringSessions(sessionMap);
      //  System.assertNotEquals(null, sessionId);
    }

    @isTest
    static void test_deleteSession() {
        Session__c session = [SELECT Id FROM Session__c LIMIT 1];
        Test.startTest();
        TimetableController.deleteSession(session.Id);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Session__c WHERE Id = :session.Id]);
    }

    @isTest
    static void test_getSessionDetails() {
        Session__c session = [SELECT Id FROM Session__c LIMIT 1];
        String result = TimetableController.getSessionDetails(session.Id);
        System.assertNotEquals(null, result);
    }
    
    
    @isTest
    static void testGetHolidays() {
        // Create test holiday data
        List<K42_Holiday__c> testHolidays = new List<K42_Holiday__c>();
        
        // Holiday that falls completely within search range
        K42_Holiday__c holiday1 = new K42_Holiday__c(
            Name = 'New Year Holiday',
            K42_Hol_Start_Date__c = Date.newInstance(2024, 1, 1),
            K42_Hol_End_Date__c = Date.newInstance(2024, 1, 3)
        );
        testHolidays.add(holiday1);
        
        // Multi-day holiday that partially overlaps with search range (starts before)
        K42_Holiday__c holiday2 = new K42_Holiday__c(
            Name = 'Winter Break',
            K42_Hol_Start_Date__c = Date.newInstance(2023, 12, 25),
            K42_Hol_End_Date__c = Date.newInstance(2024, 1, 5)
        );
        testHolidays.add(holiday2);
        
        // Holiday that partially overlaps with search range (ends after)
        K42_Holiday__c holiday3 = new K42_Holiday__c(
            Name = 'Spring Break',
            K42_Hol_Start_Date__c = Date.newInstance(2024, 1, 25),
            K42_Hol_End_Date__c = Date.newInstance(2024, 2, 5)
        );
        testHolidays.add(holiday3);
        
        // Single day holiday
        K42_Holiday__c holiday4 = new K42_Holiday__c(
            Name = 'Independence Day',
            K42_Hol_Start_Date__c = Date.newInstance(2024, 1, 15),
            K42_Hol_End_Date__c = Date.newInstance(2024, 1, 15)
        );
        testHolidays.add(holiday4);
        
        // Holiday completely outside the search range (should not be returned)
        K42_Holiday__c holiday5 = new K42_Holiday__c(
            Name = 'Summer Holiday',
            K42_Hol_Start_Date__c = Date.newInstance(2024, 6, 1),
            K42_Hol_End_Date__c = Date.newInstance(2024, 6, 15)
        );
        testHolidays.add(holiday5);
        
        // Holiday with null dates (edge case)
        K42_Holiday__c holiday6 = new K42_Holiday__c(
            Name = 'Incomplete Holiday',
            K42_Hol_Start_Date__c = null,
            K42_Hol_End_Date__c = null
        );
        testHolidays.add(holiday6);
        
        insert testHolidays;
        
        Test.startTest();
        
        // Test 1: Normal date range
        Map<String, String> result1 = TimetableController.getHolidays('2024-01-01', '2024-01-31');
        
        // Test 2: Single day range
        Map<String, String> result2 = TimetableController.getHolidays('2024-01-01', '2024-01-01');
        
        // Test 3: Range with no holidays
        Map<String, String> result3 = TimetableController.getHolidays('2024-03-01', '2024-03-31');
        
        // Test 4: Wide date range
        Map<String, String> result4 = TimetableController.getHolidays('2023-12-01', '2024-02-29');
        
        
        
        // Test exception handling with invalid date format
        try {
            Map<String, String> resultError = TimetableController.getHolidays('invalid-date', '2024-01-31');
        } catch (Exception e) {
            // Expected exception for invalid date format
        }
        
        // Test exception handling with null parameters
        try {
            Map<String, String> resultError2 = TimetableController.getHolidays(null, '2024-01-31');
        } catch (Exception e) {
            // Expected exception for null parameter
        }
        Test.stopTest();
    }
    
    
    @isTest
    static void testUpdateSession() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        // Create test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create Faculty (Contact)
        Contact testFaculty = new Contact(
            FirstName = 'Test',
            LastName = 'Faculty',
            AccountId = testAccount.Id
        );
        insert testFaculty;
        
        // Create Facility
        hed__Facility__c testFacility = new hed__Facility__c(
            Name = 'Test Facility',
            hed__Account__c = testAccount.Id
        );
        insert testFacility;
        
        // Create Course
        hed__Course__c testCourse = new hed__Course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'TC001',
            hed__Account__c = testAccount.Id
        );
        insert testCourse;
        
        // Create Term
        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = testAccount.Id,
            Term_Reference__c = 'Term 1'
        );
        insert testTerm;
        
        // Create Course Offering
        hed__Course_Offering__c testOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = testCourse.Id,
            hed__Term__c = testTerm.Id
        );
        insert testOffering;
        
        // Create Session
        Session__c testSession = new Session__c(
            Type_of_Activity__c = 'Teaching',
            Faculty__c = testFaculty.Id,
            Facility__c = testFacility.Id,
            Account_Name__c = testAccount.Id,
            Course_Offering__c = testOffering.Id,
            Start_Date_Time__c = DateTime.newInstance(2024, 1, 15, 10, 0, 0),
            End_Date_Time__c = DateTime.newInstance(2024, 1, 15, 12, 0, 0),
            Mode_of_Delivery__c = 'Online'
        );
        insert testSession;
        
        Test.startTest();
        
        // Test 1: Complete session data update with all fields
        String sessionData1 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Workshop',
            'faculty' => testFaculty.Id,
            'facility' => testFacility.Id,
            'subject' => testCourse.Id,
            'sectionId' => testOffering.Id,
            'startDate' => '2024-01-20',
            'startTime' => '14:30',
            'endDate' => '2024-01-20',
            'endTime' => '16:30'
        });
        
        Id result1 = TimetableController.updateSession(sessionData1, testSession.Id);
        
        // Test 2: Session data with JSON array for sectionId
        String sessionData2 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Lab',
            'faculty' => testFaculty.Id,
            'facility' => testFacility.Id,
            'subject' => testCourse.Id,
            'sectionId' => JSON.serialize(new List<Id>{testOffering.Id}),
            'startDate' => '2024-01-25',
            'startTime' => '09:00',
            'endDate' => '2024-01-25',
            'endTime' => '11:00'
        });
        
        Id result2 = TimetableController.updateSession(sessionData2, testSession.Id);
        
        // Test 3: Session data with only date (no time)
        String sessionData3 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Teaching',
            'startDate' => '2024-01-30',
            'endDate' => '2024-01-30'
        });
        
        Id result3 = TimetableController.updateSession(sessionData3, testSession.Id);
        
        // Test 4: Session data with blank/null values
        String sessionData4 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Tutorial',
            'faculty' => '',
            'facility' => null,
            'subject' => '',
            'sectionId' => '',
            'startDate' => '2024-02-01',
            'startTime' => '08:15',
            'endDate' => '2024-02-01',
            'endTime' => '10:15'
        });
        
        Id result4 = TimetableController.updateSession(sessionData4, testSession.Id);
        
        // Test 5: Session data with invalid course offering relationship
        String sessionData5 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Exam',
            'subject' => testCourse.Id,
            'sectionId' => 'invalid-id',
            'startDate' => '2024-02-05',
            'startTime' => '13:00',
            'endDate' => '2024-02-05',
            'endTime' => '15:00'
        });
        
        Id result5 = TimetableController.updateSession(sessionData5, testSession.Id);
        
        // Test 6: Session data with malformed time format
        String sessionData6 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Exam',
            'startDate' => '2024-02-10',
            'startTime' => '14', // Missing minutes
            'endDate' => '2024-02-10',
            'endTime' => '16:30:45' // Extra seconds
        });
        
        Id result6 = TimetableController.updateSession(sessionData6, testSession.Id);
        
        
        
        // Test exception handling - Invalid JSON
        try {
            String invalidJson = 'invalid json string';
            Id resultError1 = TimetableController.updateSession(invalidJson, testSession.Id);
        } catch (Exception e) {
            // Expected exception for invalid JSON
        }
        
        // Test exception handling - Non-existent session ID
        try {
            String validSessionData = JSON.serialize(new Map<String, Object>{
                'activityType' => 'Lecture'
            });
            Id nonExistentId = '0031234567890123'; // Valid format but non-existent ID
            Id resultError2 = TimetableController.updateSession(validSessionData, nonExistentId);
        } catch (Exception e) {
            // Expected exception for non-existent session
        }
        
        // Test exception handling - Invalid date format
        try {
            String sessionDataInvalidDate = JSON.serialize(new Map<String, Object>{
                'activityType' => 'Workshop',
                'startDate' => 'invalid-date-format',
                'endDate' => '2024-02-15'
            });
            Id resultError3 = TimetableController.updateSession(sessionDataInvalidDate, testSession.Id);
        } catch (Exception e) {
            // Expected exception for invalid date format
        }
        Test.stopTest();
    }
    
    
    @isTest
    static void testCreateSession() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Test.setMock(HttpCalloutMock.class, new FailureHttpMock());
        Test.setMock(HttpCalloutMock.class, new NoDataHttpMock());
        // Create test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create Faculty (Contact)
        Contact testFaculty = new Contact(
            FirstName = 'Test',
            LastName = 'Faculty',
            AccountId = testAccount.Id
        );
        insert testFaculty;
        
        // Create Facility
        hed__Facility__c testFacility = new hed__Facility__c(
            Name = 'Test Facility',
            hed__Account__c = testAccount.Id
        );
        insert testFacility;
        
        // Create Course
        hed__Course__c testCourse = new hed__Course__c(
            Name = 'Test Course',
            hed__Course_ID__c = 'TC001',
            hed__Account__c = testAccount.Id
        );
        insert testCourse;
        
        // Create Term
        hed__Term__c testTerm = new hed__Term__c(
            Name = 'Test Term',
            hed__Account__c = testAccount.Id,
            Term_Reference__c = 'Term 1'
        );
        insert testTerm;
        
        // Create Course Offering
        hed__Course_Offering__c testOffering = new hed__Course_Offering__c(
            Name = 'Test Course Offering',
            hed__Course__c = testCourse.Id,
            hed__Term__c = testTerm.Id
        );
        insert testOffering;
        
        // Create a holiday for testing skipHolidays functionality
        K42_Holiday__c testHoliday = new K42_Holiday__c(
            Name = 'Test Holiday',
            K42_Hol_Start_Date__c = Date.newInstance(2024, 1, 15),
            K42_Hol_End_Date__c = Date.newInstance(2024, 1, 15)
        );
        insert testHoliday;
        
        Test.startTest();
        
        // Test 1: Single session creation with all fields
        String sessionData1 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Teaching',
            'subject' => testCourse.Id,
            'faculty' => testFaculty.Id,
            'facility' => testFacility.Id,
            'accountId' => testAccount.Id,
            'sectionId' => testOffering.Id,
            'startDate' => '2024-01-10',
            'startTime' => '10:00',
            'endDate' => '2024-01-10',
            'endTime' => '12:00',
            'isRecurrent' => false,
            'skipHolidays' => false
        });
        
        Id result1 = TimetableController.createSession(sessionData1);
        
        // Test 2: Single session with JSON array for sectionId
        String sessionData2 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Lab',
            'subject' => testCourse.Id,
            'faculty' => testFaculty.Id,
            'facility' => testFacility.Id,
            'accountId' => testAccount.Id,
            'sectionId' => JSON.serialize(new List<Id>{testOffering.Id}),
            'startDate' => '2024-01-12',
            'startTime' => '14:30',
            'endDate' => '2024-01-12',
            'endTime' => '16:30',
            'isRecurrent' => false,
            'skipHolidays' => false
        });
        
        Id result2 = TimetableController.createSession(sessionData2);
        
        // Test 3: Single session without time (default times)
        String sessionData3 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Workshop',
            'subject' => testCourse.Id,
            'faculty' => testFaculty.Id,
            'facility' => testFacility.Id,
            'accountId' => testAccount.Id,
            'sectionId' => testOffering.Id,
            'startDate' => '2024-01-20',
            'endDate' => '2024-01-20',
            'isRecurrent' => false,
            'skipHolidays' => false
        });
        
        Id result3 = TimetableController.createSession(sessionData3);
        
        // Test 4: Single session with minimal data
        String sessionData4 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Practical',
            'isRecurrent' => false,
            'skipHolidays' => false
        });
        
        Id result4 = TimetableController.createSession(sessionData4);
        
        // Test 5: Single session with blank/null values
        String sessionData5 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Tutorial',
            'subject' => '',
            'faculty' => null,
            'facility' => '',
            'accountId' => null,
            'sectionId' => '',
            'startDate' => '2024-01-25',
            'startTime' => '09:00',
            'endDate' => '2024-01-25',
            'endTime' => '11:00',
            'isRecurrent' => false,
            'skipHolidays' => false
        });
        
        Id result5 = TimetableController.createSession(sessionData5);
        
        // Test 6: Recurring session with multiple days
        List<Map<String, Object>> selectedDays = new List<Map<String, Object>>();
        selectedDays.add(new Map<String, Object>{
            'day' => 'Monday',
            'startTime' => '10:00',
            'endTime' => '12:00'
        });
        selectedDays.add(new Map<String, Object>{
            'day' => 'Wednesday',
            'startTime' => '14:00',
            'endTime' => '16:00'
        });
        selectedDays.add(new Map<String, Object>{
            'day' => 'Friday',
            'startTime' => '09:00',
            'endTime' => '11:00'
        });
        
        String sessionData6 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Teaching',
            'subject' => testCourse.Id,
            'faculty' => testFaculty.Id,
            'facility' => testFacility.Id,
            'accountId' => testAccount.Id,
            'sectionId' => testOffering.Id,
            'startDate' => '2024-02-01',
            'endDate' => '2024-02-28',
            'isRecurrent' => true,
            'skipHolidays' => true,
            'selectedDays' => selectedDays
        });
        
        Id result6 = TimetableController.createSession(sessionData6);
        
        // Test 7: Recurring session with incomplete day data
        List<Map<String, Object>> incompleteDays = new List<Map<String, Object>>();
        incompleteDays.add(new Map<String, Object>{
            'day' => 'Tuesday',
            'startTime' => '', // Missing start time
            'endTime' => '12:00'
        });
        incompleteDays.add(new Map<String, Object>{
            'day' => '', // Missing day
            'startTime' => '10:00',
            'endTime' => '12:00'
        });
        incompleteDays.add(new Map<String, Object>{
            'day' => 'Thursday',
            'startTime' => '14:00',
            'endTime' => null // Missing end time
        });
        
        String sessionData7 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Reinforcement',
            'subject' => testCourse.Id,
            'faculty' => testFaculty.Id,
            'facility' => testFacility.Id,
            'startDate' => '2024-03-01',
            'endDate' => '2024-03-31',
            'isRecurrent' => true,
            'skipHolidays' => false,
            'selectedDays' => incompleteDays
        });
        
        Id result7 = TimetableController.createSession(sessionData7);
        
        // Test 8: Recurring session with empty selectedDays
        String sessionData8 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Reinforcement',
            'startDate' => '2024-04-01',
            'endDate' => '2024-04-30',
            'isRecurrent' => true,
            'skipHolidays' => false,
            'selectedDays' => new List<Object>()
        });
        
        Id result8 = TimetableController.createSession(sessionData8);
        
        // Test 9: Invalid course offering relationship
        String sessionData9 = JSON.serialize(new Map<String, Object>{
            'activityType' => 'Teaching',
            'subject' => testCourse.Id,
            'sectionId' => 'invalid-offering-id',
            'startDate' => '2024-01-30',
            'startTime' => '10:00',
            'endDate' => '2024-01-30',
            'endTime' => '12:00',
            'isRecurrent' => false,
            'skipHolidays' => false
        });
        
        Id result9 = TimetableController.createSession(sessionData9);
                
        try {
            String holidaySessionData = JSON.serialize(new Map<String, Object>{
                'activityType' => 'Reinforcement',
                'startDate' => '2024-01-15', // This is a holiday
                'endDate' => '2024-01-15',
                'isRecurrent' => false,
                'skipHolidays' => true
            });
            
            Id holidayResult = TimetableController.createSession(holidaySessionData);
        } catch (Exception e) {
            // Expected exception for holiday
        }
        
        // Test exception handling - Invalid JSON
        try {
            String invalidJson = 'invalid json string';
            Id errorResult1 = TimetableController.createSession(invalidJson);
        } catch (Exception e) {
            // Expected exception for invalid JSON
        }
        
        // Test exception handling - Invalid date format
        try {
            String invalidDateData = JSON.serialize(new Map<String, Object>{
                'activityType' => 'Reinforcement',
                'startDate' => 'invalid-date-format',
                'endDate' => '2024-01-30',
                'isRecurrent' => false,
                'skipHolidays' => false
            });
            Id errorResult2 = TimetableController.createSession(invalidDateData);
        } catch (Exception e) {
            // Expected exception for invalid date
        }
        
        // Test exception handling - Invalid time format
        try {
            String invalidTimeData = JSON.serialize(new Map<String, Object>{
                'activityType' => 'Reinforcement',
                'startDate' => '2024-01-30',
                'startTime' => 'invalid-time',
                'endDate' => '2024-01-30',
                'endTime' => '12:00',
                'isRecurrent' => false,
                'skipHolidays' => false
            });
            Id errorResult3 = TimetableController.createSession(invalidTimeData);
        } catch (Exception e) {
            // Expected exception for invalid time
        }
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