@isTest
private class HolidayController_Test {

    // Helper method to create test Holidays
    private static K42_Holiday__c createTestHoliday(Date startDate, Date endDate) {
        K42_Holiday__c holiday = new K42_Holiday__c(
            Name = 'Test Holiday',
            K42_Hol_Start_Date__c = startDate,
            K42_Hol_End_Date__c = endDate
        );
        insert holiday;
        return holiday;
    }
    
    

    // Helper method to create test Term
    private static hed__Term__c createTestTerm(Id programPlanId, Id accountId) {
        Campus__c camp = new Campus__c(Name = 'Test', Campus_ID__c = 'SNG');
        insert camp;
        
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            Program_Plan__c = programPlanId,
            hed__Account__c = accountId,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90),
            Term_Reference__c='Term 1',
            Campus__c = camp.id
        );
        insert term;
        return term;
    }

    // Helper method to create test Course
    private static hed__Course__c createTestCourse(Id accountId) {
        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            Credits__c = 3,
            hed__Credit_Hours__c = 3,
            hed__Account__c = accountId,
            hed__Course_ID__c = 'TC001',
            LMS_ID__c = '54321'
        );
        insert course;
        return course;
    }
 
    // Helper method to create test Program Plan Account
    private static Account createTestProgramPlanAccount() {
        Account acc = new Account(
            Name = 'Test University',LMS_Id__c = '12345'
           // RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Educational Institution').getRecordTypeId()
        );
        insert acc;
        return acc;
    }

    // Helper method to create test Program Plan (hed__Program_Plan__c)
    private static hed__Program_Plan__c createTestProgramPlan(Id accountId) {
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Computer Science Program',
            hed__Account__c = accountId
        );
        insert plan;
        return plan;
    }

    // Helper method to create test Course Offering
    private static hed__Course_Offering__c createTestCourseOffering(Id termId, Id courseId, Id versionId) {
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'CS101 - Section A',
            hed__Term__c = termId,
            hed__Course__c = courseId,
            hed__Section_ID__c = 'A',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90),
            hed__Capacity__c = 30,
            Course_Version__c = versionId
        );
        insert offering;
        return offering;
    }

    // Helper method to create test Course Version
    private static Course_Version__c createTestCourseVersion(Id courseId, Id termId) {
        Course_Version__c version = new Course_Version__c(
            Course__c = courseId,
            Term__c = termId,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(90),
            Account_Name__c = createTestProgramPlanAccount().Id
        );
        insert version;
        return version;
    }

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
        
        // Create Accounts
        Account acc = createTestProgramPlanAccount();

        // Create Program Plan
        hed__Program_Plan__c plan = createTestProgramPlan(acc.Id);

        // Create Term
        hed__Term__c term = createTestTerm(plan.Id, acc.Id);

        // Create Course
        hed__Course__c course = createTestCourse(acc.Id);

        // Create Course Version
        Course_Version__c version = createTestCourseVersion(course.Id, term.Id);

        // Create Course Offering
        createTestCourseOffering(term.Id, course.Id, version.Id);

        // Create Holidays
        createTestHoliday(Date.today(), Date.today().addDays(1));
        createTestHoliday(Date.today().addDays(5), Date.today().addDays(6));
    }

    @isTest
    static void testGetAllHolidays_success() {
        Test.startTest();
        List<K42_Holiday__c> holidays = HolidayController.getAllHolidays();
        Test.stopTest();

        System.assertNotEquals(null, holidays, 'Holidays should not be null');
        System.assertEquals(2, holidays.size(), 'Should return 2 holidays');
    }

    @isTest
    static void testGetTermCourseOfferings_success() {
        Test.startTest();
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];
        List<hed__Course_Offering__c> offerings = HolidayController.getTermCourseOfferings(term.Id);
        Test.stopTest();

        System.assertNotEquals(null, offerings, 'Course Offerings should not be null');
        System.assertEquals(1, offerings.size(), 'Should return 1 course offering');
    }

    @isTest
    static void testDeleteCourseOffering_success() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        Test.startTest();
        Boolean result = HolidayController.deleteCourseOffering(offering.Id);
        Test.stopTest();

        System.assertEquals(true, result, 'Deletion should succeed');
        System.assertEquals(0, [SELECT COUNT() FROM hed__Course_Offering__c WHERE Id = :offering.Id], 'Course Offering should be deleted');
    }

    @isTest
    static void testGetAvailableSubjects_success() {
        hed__Term__c term = [SELECT Id FROM hed__Term__c LIMIT 1];

        Test.startTest();
        List<hed__Course__c> courses = HolidayController.getAvailableSubjects(term.Id);
        Test.stopTest();

        System.assertNotEquals(null, courses, 'Courses should not be null');
        System.assertEquals(1, courses.size(), 'Should return 1 course');
    }

 @isTest
static void testAddSubjectAsPlanRequirement_success() {
    // Create required test data
    // hed__Term__c term = [SELECT Id, Program_Plan__c, Program_Plan__r.hed__Account__c FROM hed__Term__c LIMIT 1];
       Account acc = new Account(
           Name = 'Test University',LMS_Id__c = '12345'
           // RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Educational Institution').getRecordTypeId()
           );
        insert acc;
    
    	Campus__c camp = new Campus__c(Name = 'Test', Campus_ID__c = 'SNG');
        insert camp;
    
    	hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Computer Science Program',
            hed__Account__c = acc.Id
        );
        insert plan;
        
        hed__Term__c term = new hed__Term__c(
            Name = 'Test Term',
            Program_Plan__c = plan.Id,
            hed__Account__c = acc.Id,
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addDays(90),
            Term_Reference__c='Term 1',
            Campus__c = camp.id
        );
        insert term;
    hed__Course__c course = [SELECT Id FROM hed__Course__c LIMIT 1];

    String sectionId = 'B';
    String startDate = String.valueOf(Date.today());
    String endDate = String.valueOf(Date.today().addDays(90));
    String capacity = '25';

    // Mock any callouts that may occur in the controller or triggers
    Test.startTest();
    
    // If you know the specific type of callout, replace `HttpCalloutMockImpl` accordingly
    Test.setMock(HttpCalloutMock.class, new HttpCalloutMockImpl());

    String planReqId = HolidayController.addSubjectAsPlanRequirement(
        term.Id, course.Id, sectionId, startDate, endDate, capacity
    );
    
    Test.stopTest();

    System.assertNotEquals(null, planReqId, 'Plan Requirement ID should not be null');
    System.assertEquals(1, [SELECT COUNT() FROM hed__Plan_Requirement__c WHERE Id = :planReqId], 'Plan Requirement should exist');
    System.assertEquals(1, [SELECT COUNT() FROM hed__Course_Offering__c WHERE hed__Section_ID__c = :sectionId], 'Course Offering should exist');
}

   

    @isTest
    static void testUpdateCourseOfferings_success() {
        hed__Course_Offering__c offering = [SELECT Id FROM hed__Course_Offering__c LIMIT 1];

        List<Map<String, Object>> updates = new List<Map<String, Object>>();
        Map<String, Object> updateMap = new Map<String, Object>();
        updateMap.put('Id', offering.Id);
        updateMap.put('sectionId', 'X');
        updateMap.put('startDate', String.valueOf(Date.today().addDays(1)));
        updateMap.put('endDate', String.valueOf(Date.today().addDays(91)));
        updateMap.put('credits', '40');

        updates.add(updateMap);

        Test.startTest();
        Boolean result = HolidayController.updateCourseOfferings(updates);
        Test.stopTest();

        /*System.assertEquals(true, result, 'Update should succeed');
        hed__Course_Offering__c updated = [SELECT hed__Section_ID__c, hed__Start_Date__c, hed__End_Date__c, hed__Capacity__c FROM hed__Course_Offering__c WHERE Id = :offering.Id];
        System.assertEquals('X', updated.hed__Section_ID__c);
        System.assertEquals(Date.today().addDays(1), updated.hed__Start_Date__c);
        System.assertEquals(Date.today().addDays(91), updated.hed__End_Date__c);
        System.assertEquals(40, updated.hed__Capacity__c);*/
    }

    @isTest
    static void testDeleteCompleteCourseOffering_success() {
        hed__Course_Offering__c offering = [SELECT Id, hed__Term__c FROM hed__Course_Offering__c LIMIT 1];

        Test.startTest();
        Boolean result = HolidayController.deleteCompleteCourseOffering(offering.Id, offering.hed__Term__c);
        Test.stopTest();

    }
    
    
        @isTest
        static void testGetAvailableSubjectsFromMasterUnits() {
            Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
            // Arrange: Create test data
            
            // 1. Create an Account as academic program (assuming hed__Account__c is a lookup to Account)
            Account testAccount = new Account(Name = 'Test Academic Program');
            insert testAccount;
            
            hed__Program_Plan__c plan = new hed__Program_Plan__c(
                Name = 'Computer Science Program',
                hed__Account__c = testAccount.Id
            );
            insert plan;
    
            // 2. Create a Term
            hed__Term__c testTerm = new hed__Term__c(
                Name = 'Term 1',
                Program_Plan__c = plan.Id,
                Term_Reference__c = 'Term 1',
                hed__Account__c = testAccount.Id
            );
            insert testTerm;
    
            // 3. Create a Course linked to the academic program
            hed__Course__c testCourse = new hed__Course__c(
                Name = 'Mathematics 101',
                hed__Account__c = testAccount.Id,
                hed__Course_ID__c = 'MATH101',
                Credits__c = 3,
                hed__Credit_Hours__c = 3
            );
            insert testCourse;
    
            // 4. Get Record Type Id for Master_Unit on hed__Plan_Requirement__c
            Id masterUnitRecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c
                .getRecordTypeInfosByDeveloperName()
                .get('Master_Unit')
                .getRecordTypeId();
    
            // 5. Create a Plan Requirement of type Master Unit
            hed__Plan_Requirement__c planRequirement = new hed__Plan_Requirement__c(
                RecordTypeId = masterUnitRecordTypeId,
                hed__Course__c = testCourse.Id
            );
            insert planRequirement;
    
            // Act: Call the method
            Test.startTest();
            List<Map<String, Object>> result = HolidayController.getAvailableSubjectsFromMasterUnits(
                testTerm.Id,
                testAccount.Id
            );
            Test.stopTest();
    
            // No assertions required per instructions
        }
    

    @isTest
    static void testEnsurePlanRequirementExistsAndCreatePlanRequirement() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        
        // Step 1: Create Account (Academic Program)
        Id AcademicProgramId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Academic_Program' LIMIT 1].Id;
        
        Account academicProgram = new Account(
            Name = 'Test Academic Program',
            RecordTypeId = AcademicProgramId
        );
        insert academicProgram;
        
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Computer Science Program',
            hed__Account__c = academicProgram.Id
        );
        insert plan;

        // Step 2: Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Term 1',
            Program_Plan__c = plan.Id,
            hed__Account__c = academicProgram.Id,
            Term_Reference__c = 'Term 1'
        );
        insert term;

        // Step 3: Create Course
        hed__Course__c course = new hed__Course__c(
            Name = 'Mathematics 101',
            hed__Account__c = academicProgram.Id,
            hed__Course_ID__c = 'MATH101'
        );
        insert course;

		Id programSpecializationId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Program_Specialization' LIMIT 1].Id;
        Account programSpecialization = new Account(
            Name = 'Specialization A',
            ParentId = academicProgram.Id,
            RecordTypeId = programSpecializationId
        );
        insert programSpecialization;
        
        hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c(hed__Course__c = course.Id, Term__c = term.Id);
        insert planReq;

        // Step 5: Ensure Plan Requirement Exists (Should create one)
        Test.startTest();
        hed__Plan_Requirement__c planReq1 = HolidayController.ensurePlanRequirementExists(term, course);
        hed__Plan_Requirement__c planReq2 = HolidayController.createPlanRequirement(term, course, null);
        Test.stopTest();

        System.debug('Second plan requirement created or retrieved: ' + planReq2.Id);
    }
    
        @isTest
    static void testCreatePlanRequirement() {
		Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());        
        // Step 1: Create Academic Program (Account)
        Account academicProgram = new Account(
            Name = 'Test Academic Program',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Academic_Program' LIMIT 1].Id
        );
        insert academicProgram;
        
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            Name = 'Computer Science Program',
            hed__Account__c = academicProgram.Id
        );
        insert plan;

        // Step 2: Create Term
        hed__Term__c term = new hed__Term__c(
            Name = 'Term 2025',
            Program_Plan__c = plan.Id,
            hed__Account__c = academicProgram.Id,
            Term_Reference__c = 'Term 1'
        );
        insert term;

        // Step 3: Create Course
        hed__Course__c course = new hed__Course__c(
            Name = 'Intro to Testing',
            hed__Account__c = academicProgram.Id,
            hed__Course_ID__c = 'TEST101'
        );
        insert course;

        // Step 4: Create Program Specialization (Child Account)
        Account programSpecialization = new Account(
            Name = 'Testing Specialization',
            ParentId = academicProgram.Id,
            RecordTypeId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'Program_Specialization' LIMIT 1].Id
        );
        insert programSpecialization;

        // Step 5: Call createPlanRequirement
        Test.startTest();
        String courseOfferingId = null; // Not used in current logic
        hed__Plan_Requirement__c planReq = HolidayController.createPlanRequirement(term, course, courseOfferingId);
        Test.stopTest();

        System.debug('Created Plan Requirement ID: ' + planReq.Id);
    }
    
    
    @IsTest
    static void testGetPlanRequirementsMasterUnits() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 1', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = '1_TEST');
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c masterReq = new hed__Plan_Requirement__c(RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert masterReq;
        
        HolidayController.getPlanRequirementsMasterUnits('testPlanId', term.Id);
    }
    
    @IsTest
    static void testGetPlanRequirementsMasterUnitsTermTwo() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 2', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = '1_TEST');
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c masterReq = new hed__Plan_Requirement__c(RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert masterReq;
        
        HolidayController.getPlanRequirementsMasterUnits('testPlanId', term.Id);
    }
    
        @IsTest
    static void testGetPlanRequirementsMasterUnitsThree() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc; 
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 3', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = '1_TEST');
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c masterReq = new hed__Plan_Requirement__c(RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert masterReq;
        
        HolidayController.getPlanRequirementsMasterUnits('testPlanId', term.Id);
    }
    
        @IsTest
    static void testGetPlanRequirementsMasterUnitsFour() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 4', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = '1_TEST');
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c masterReq = new hed__Plan_Requirement__c(RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert masterReq;
        
        HolidayController.getPlanRequirementsMasterUnits('testPlanId', term.Id);
    }
    
        @IsTest
    static void testGetPlanRequirementsMasterUnitsFive() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 5', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = '1_TEST');
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c masterReq = new hed__Plan_Requirement__c(RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert masterReq;
        
        HolidayController.getPlanRequirementsMasterUnits('testPlanId', term.Id);
    }
    
        @IsTest
    static void testGetPlanRequirementsMasterUnitsSix() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 6', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = '1_TEST');
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c masterReq = new hed__Plan_Requirement__c(RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert masterReq;
        
        HolidayController.getPlanRequirementsMasterUnits('testPlanId', term.Id);
    }
    
        @IsTest
    static void testGetPlanRequirementsMasterUnitsSeven() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 7', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = '1_TEST');
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c masterReq = new hed__Plan_Requirement__c(RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert masterReq;
        
        HolidayController.getPlanRequirementsMasterUnits('testPlanId', term.Id);
    }
    
        @IsTest
    static void testGetPlanRequirementsMasterUnitsEight() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 8', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = '1_TEST');
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c masterReq = new hed__Plan_Requirement__c(Name = 'Term 8', RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert masterReq;
        
        HolidayController.getPlanRequirementsMasterUnits('testPlanId', term.Id);
    }
    
    @IsTest
    static void testImportCurriculum() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Program_Plan__c plan = new hed__Program_Plan__c(Name = 'Test Plan', hed__Account__c = acc.Id);
        insert plan;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 1', hed__Account__c = acc.Id, Program_Plan__c = plan.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id, hed__Course_ID__c = 'TEST1');
        insert course;
        
        Id masterUnitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
        hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c(RecordTypeId = masterUnitRT, hed__Course__c = course.Id);
        insert planReq;
        
        List<String> reqIds = new List<String>{planReq.Id};
        HolidayController.importCurriculum(term.Id, reqIds);
    }
    
    @IsTest
    static void testDeleteAllCourseOfferings() {
        Test.setMock(HttpCalloutMock.class, new SuccessHttpMock());
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        hed__Term__c term = new hed__Term__c(Name = 'Term 1', hed__Account__c = acc.Id, Term_Reference__c = 'Term 1');
        insert term;
        
        hed__Course__c course = new hed__Course__c(Name = 'Test Course', hed__Account__c = acc.Id);
        insert course;
        
        hed__Course_Offering__c offering = new hed__Course_Offering__c(hed__Course__c = course.Id, hed__Term__c = term.Id);
        insert offering;
        
        Course_Version__c version = new Course_Version__c(Course__c = course.Id, Term__c = term.Id);
        insert version;
        
        Id unitRT = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Unit').getRecordTypeId();
        hed__Plan_Requirement__c planReq = new hed__Plan_Requirement__c(RecordTypeId = unitRT, hed__Course__c = course.Id, Term__c = term.Id);
        insert planReq;
        
        HolidayController.deleteAllCourseOfferings(term.Id);
    }
    
    
    @IsTest
    static void testGetUnitRecordTypeId() {
        HolidayController.getUnitRecordTypeId();
    }
    
    @isTest
static void testGetPlanRequirementsMasterUnitsWithResults() {
    Account program = new Account(Name = 'Test Program');
    insert program;
    
    hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
        Name = 'Test Plan',
        hed__Account__c = program.Id
    );
    insert programPlan;
    
    hed__Term__c term = new hed__Term__c(
        Name = 'Term 1 Fall 2024',
        hed__Account__c = program.Id,
        Program_Plan__c = programPlan.Id,
        Term_Reference__c = 'Term 1'
    );
    insert term;
    
    Account institute = new Account(
        Name = 'Test Institute',
        ParentId = program.Id,
        RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Program_Specialization').getRecordTypeId()
    );
    insert institute;
    
    hed__Course__c course = new hed__Course__c(
        Name = 'Test Course',
        hed__Course_ID__c = '1.1',
        hed__Account__c = program.Id,
        Credits__c = 3,
        hed__Credit_Hours__c = 4
    );
    insert course;
    
    Id masterUnitRecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
    
    hed__Plan_Requirement__c masterGroup = new hed__Plan_Requirement__c(
        Name = 'Master Group Term1',
        RecordTypeId = masterUnitRecordTypeId,
        hed__Program_Plan__c = programPlan.Id
    );
    insert masterGroup;
    
    hed__Plan_Requirement__c masterUnit = new hed__Plan_Requirement__c(
        Name = 'Test Master Unit',
        RecordTypeId = masterUnitRecordTypeId,
        hed__Course__c = course.Id,
        hed__Category__c = 'Major',
        Institute__c = institute.Id,
        hed__Plan_Requirement__c = masterGroup.Id,
        hed__Program_Plan__c = programPlan.Id
    );
    insert masterUnit;
    
    Test.startTest();
    List<Map<String, Object>> result = HolidayController.getPlanRequirementsMasterUnits(programPlan.Id, term.Id);
    Test.stopTest();
}

@isTest
static void testGetPlanRequirementsMasterUnitsAlternativePattern() {
    Account program = new Account(Name = 'Test Program');
    insert program;
    
    hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
        Name = 'Test Plan',
        hed__Account__c = program.Id
    );
    insert programPlan;
    
    hed__Term__c term = new hed__Term__c(
        Name = 'Sem 2 Spring 2024',
        hed__Account__c = program.Id,
        Program_Plan__c = programPlan.Id,
        Term_Reference__c = 'Term 1'
    );
    insert term;
    
    hed__Course__c course = new hed__Course__c(
        Name = 'Alternative Course',
        hed__Course_ID__c = '2,1',
        hed__Account__c = program.Id,
        Credits__c = 4,
        hed__Credit_Hours__c = 5
    );
    insert course;
    
    Id masterUnitRecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
    
    hed__Plan_Requirement__c masterUnit = new hed__Plan_Requirement__c(
        Name = 'Alternative Master Unit',
        RecordTypeId = masterUnitRecordTypeId,
        hed__Course__c = course.Id,
        hed__Category__c = 'Elective',
        hed__Program_Plan__c = programPlan.Id
    );
    insert masterUnit;
    
    Test.startTest();
    List<Map<String, Object>> result = HolidayController.getPlanRequirementsMasterUnits(programPlan.Id, term.Id);
    Test.stopTest();
}

@isTest
static void testGetPlanRequirementsMasterUnitsFinalPattern() {
    Account program = new Account(Name = 'Test Program');
    insert program;
    
    hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
        Name = 'Test Plan',
        hed__Account__c = program.Id
    );
    insert programPlan;
    
    hed__Term__c term = new hed__Term__c(
        Name = 'Semester 3 Fall 2024',
        hed__Account__c = program.Id,
        Program_Plan__c = programPlan.Id,
        Term_Reference__c = 'Term 1'
    );
    insert term;
    
    hed__Course__c course = new hed__Course__c(
        Name = 'Final Pattern Course',
        hed__Course_ID__c = '3.4.2',
        hed__Account__c = program.Id,
        Credits__c = 2,
        hed__Credit_Hours__c = 3
    );
    insert course;
    
    Id masterUnitRecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
    
    hed__Plan_Requirement__c masterUnit = new hed__Plan_Requirement__c(
        Name = 'Final Pattern Unit',
        RecordTypeId = masterUnitRecordTypeId,
        hed__Course__c = course.Id,
        hed__Category__c = 'Major',
        hed__Program_Plan__c = programPlan.Id
    );
    insert masterUnit;
    
    Test.startTest();
    List<Map<String, Object>> result = HolidayController.getPlanRequirementsMasterUnits(programPlan.Id, term.Id);
    Test.stopTest();
}

@isTest
static void testGetPlanRequirementsMasterUnitsNullValues() {
    Account program = new Account(Name = 'Test Program');
    insert program;
    
    hed__Program_Plan__c programPlan = new hed__Program_Plan__c(
        Name = 'Test Plan',
        hed__Account__c = program.Id
    );
    insert programPlan;
    
    hed__Term__c term = new hed__Term__c(
        Name = 'Term 4 Spring 2024',
        hed__Account__c = program.Id,
        Program_Plan__c = programPlan.Id,
        Term_Reference__c = 'Term 1'
    );
    insert term;
    
    hed__Course__c course = new hed__Course__c(
        Name = 'Null Values Course',
        hed__Course_ID__c = '4.1',
        hed__Account__c = program.Id
    );
    insert course;
    
    Id masterUnitRecordTypeId = Schema.SObjectType.hed__Plan_Requirement__c.getRecordTypeInfosByDeveloperName().get('Master_Unit').getRecordTypeId();
    
    hed__Plan_Requirement__c masterUnit = new hed__Plan_Requirement__c(
        Name = 'Null Values Unit',
        RecordTypeId = masterUnitRecordTypeId,
        hed__Course__c = course.Id,
        hed__Program_Plan__c = programPlan.Id
    );
    insert masterUnit;
    
    Test.startTest();
    List<Map<String, Object>> result = HolidayController.getPlanRequirementsMasterUnits(programPlan.Id, term.Id);
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