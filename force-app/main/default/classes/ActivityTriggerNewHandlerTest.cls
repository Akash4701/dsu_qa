@isTest
private class ActivityTriggerNewHandlerTest {
    
    @testSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test Campus
        Campus__c testCampus = new Campus__c(Name = 'Test Campus', Campus_ID__c = 'SNG');
        insert testCampus;
        
        // Create test Program Plan
        hed__Program_Plan__c testProgramPlan = new hed__Program_Plan__c(Name = 'Test Program Plan', hed__Account__c = testAccount.Id);
        insert testProgramPlan;

        // Create test Term
        hed__Term__c testTerm = new hed__Term__c(
            Name = '2030-NCECVR-PS-Term',
            hed__Account__c = testAccount.Id,
            hed__Start_Date__c = System.today(),
            hed__End_Date__c = System.today().addDays(5),
            hed__Grading_Period_Sequence__c = 10,
            Campus__c = testCampus.Id,
            hed__Type__c = 'School Year',
            hed__Instructional_Days__c = 20,
            Program_Plan__c = testProgramPlan.Id,
            Term_Reference__c = 'Term 1'
        );
        insert testTerm;

        // Create test Course Version
        Course_Version__c testCourseVersion = new Course_Version__c(
            Term__c = testTerm.Id,
            Start_Date__c = System.today(),
            Subject_End_Date__c=System.today().addDays(5)
        );
        insert testCourseVersion;

         List<Activity__c> activities = new List<Activity__c>();
        activities.add(new Activity__c(Name = 'Activity 1', Subject__c = testCourseVersion.Id, Start_date__c = System.today(), End_date__c = System.today().addDays(3), Activity_Duration__c = 3, Offset__c = 1));
        activities.add(new Activity__c(Name = 'Activity 2', Subject__c = testCourseVersion.Id, Start_date__c = System.today().addDays(5), End_date__c = System.today().addDays(8), Activity_Duration__c = 3, Offset__c = 5));
        insert activities;
    }
    
    @isTest
    static void testCalculateCourseVersionEndDate() {
        // Query activities and modify them
        List<Activity__c> activities = [SELECT Id, Name, Subject__c, Activity_type__c, Start_date__c, End_date__c FROM Activity__c];
        Course_Version__c cv=[SELECT Id, Name, Subject_End_Date__c, Start_Date__c  FROM Course_Version__c];
        Test.startTest();
        ActivityTriggerNewHandler.calculateCourseVersionEndDate(activities);
        Test.stopTest();
        
      
    }
   
    @IsTest
    public static void testReturnEndDate() {
        // Scenario 1: Basic Test with a start date and duration within a single week
        Date startDate = Date.newInstance(2023, 6, 26); // A Monday
        Decimal duration = 3;
        List<String> wrkDays = new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
        
        Date expectedEndDate = Date.newInstance(2023, 6, 28); // Should be Wednesday
        Date actualEndDate = ActivityTriggerNewHandler.returnEndDate(startDate, duration, wrkDays);
        System.assertEquals(expectedEndDate, actualEndDate, 'The end date should be 2023-06-28');
        
        // Scenario 2: Test with a weekend in between
        startDate = Date.newInstance(2023, 6, 30); // A Friday
        duration = 3;
        wrkDays = new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
        
        expectedEndDate = Date.newInstance(2023, 7, 4); // Should be Tuesday, skipping the weekend
        actualEndDate = ActivityTriggerNewHandler.returnEndDate(startDate, duration, wrkDays);
         Assert.areEqual(expectedEndDate, actualEndDate, 'The end date should be 2023-07-04');
        
        // Scenario 3: Test with a custom set of working days (e.g., only Monday and Wednesday)
        startDate = Date.newInstance(2023, 6, 26); // A Monday
        duration = 3;
        wrkDays = new List<String>{'Monday', 'Wednesday'};
        
        expectedEndDate = Date.newInstance(2023, 7, 3); // Should be the next Monday after the following Wednesday
        actualEndDate = ActivityTriggerNewHandler.returnEndDate(startDate, duration, wrkDays);
       Assert.areEqual(expectedEndDate, actualEndDate, 'The end date should be 2023-07-03');
        
        // Scenario 4: Test with duration of 1 day (should return the start date)
        startDate = Date.newInstance(2023, 6, 26); // A Monday
        duration = 1;
        wrkDays = new List<String>{'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
        
        expectedEndDate = Date.newInstance(2023, 6, 26); // Should be the same day
        actualEndDate = ActivityTriggerNewHandler.returnEndDate(startDate, duration, wrkDays);
      
    }
    
    @isTest
    public static void testCalculateCourseVersionEndDateWithCV() {
        Account testAccount = [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
        
        // Retrieve the Contact
        //Contact con = [SELECT Id, LastName FROM Contact WHERE LastName = 'Test Raju' LIMIT 1];
        
        // Retrieve the Campus
        Campus__c camp = [SELECT Id, Name, Campus_ID__c FROM Campus__c WHERE Name = 'Test Campus' LIMIT 1];
        
        
        hed__Program_Plan__c testProgramPlan = new hed__Program_Plan__c(Name = 'Test Program Plan', hed__Account__c = testAccount.Id);
        insert testProgramPlan;

        // Create test Term
        hed__Term__c testTerm = new hed__Term__c(
            Name = '2030-NCECVR-PS-Term',
            hed__Account__c = testAccount.Id,
            hed__Start_Date__c = System.today(),
            hed__End_Date__c = System.today().addDays(5),
            hed__Grading_Period_Sequence__c = 10,
            Campus__c = camp.Id,
            hed__Type__c = 'School Year',
            hed__Instructional_Days__c = 20,
            Program_Plan__c = testProgramPlan.Id,
            Term_Reference__c = 'Term 1'
        );
        insert testTerm;

        // Create test Course Version
        Course_Version__c testCourseVersion = new Course_Version__c(
            Term__c = testTerm.Id,
            Start_Date__c = System.today(),
            Subject_End_Date__c=System.today().addDays(5)
        );
        insert testCourseVersion;

         List<Activity__c> activities = new List<Activity__c>();
        activities.add(new Activity__c(Name = 'Activity 1', Subject__c = testCourseVersion.Id, Start_date__c = System.today(), End_date__c = System.today().addDays(3), Activity_Duration__c = 3, Offset__c = 1));
        activities.add(new Activity__c(Name = 'Activity 2', Subject__c = testCourseVersion.Id, Start_date__c = System.today().addDays(5), End_date__c = System.today().addDays(8), Activity_Duration__c = 3, Offset__c = 5));
        insert activities;
        
        Test.startTest();
        List<Course_Version__c> courseVersionsToUpdate = new List<Course_Version__c>{testCourseVersion};
        ActivityTriggerNewHandler.calculateCourseVersionEndDateWithCV(courseVersionsToUpdate);
        Test.stopTest();

        // Verify the results
        List<Course_Version__c> updatedCourseVersions = [SELECT Id, Subject_End_Date__c FROM Course_Version__c WHERE Id = :testCourseVersion.Id];
        System.assertEquals(1, updatedCourseVersions.size(), 'One Course_Version__c record should be updated.');
        System.assertNotEquals(null, updatedCourseVersions[0].Subject_End_Date__c, 'Subject End Date should not be null after calculation.');
    }
}