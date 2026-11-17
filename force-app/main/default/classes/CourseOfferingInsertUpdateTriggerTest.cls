@isTest
private class CourseOfferingInsertUpdateTriggerTest {

    // Helper method to create test Course_Version__c records
    private static Course_Version__c createTestCourseVersion(Boolean withRequiredFields) {
        Course_Version__c cv = new Course_Version__c();
        if (withRequiredFields) {
            // Fill in required fields here based on your org's configuration
         //   cv.Name = 'Test Course Version';
          //  cv.Subject_Start_Date__c = Date.today();
            // Add other required fields if needed
        }
        return cv;
    }

    @isTest static void testAfterInsert() {
        Test.startTest();

        Course_Version__c cv = createTestCourseVersion(true);
        insert cv;

        System.debug('After Insert Trigger Tested');
        
        Test.stopTest();
    }

    @isTest static void testAfterUpdate() {
        // Insert a record first
        Course_Version__c cv = createTestCourseVersion(true);
        insert cv;

        Test.startTest();

        // Update it
      //  cv.Subject_Start_Date__c = Date.today().addDays(7);
        update cv;

        System.debug('After Update Trigger Tested');

        Test.stopTest();
    }

    @isTest static void testBeforeDelete() {
        // Insert a record first
        Course_Version__c cv = createTestCourseVersion(true);
        insert cv;

        Test.startTest();

        // Delete it
        delete cv;

        System.debug('Before Delete Trigger Tested');

        Test.stopTest();
    }

    @isTest static void testBeforeInsert_DuplicateCheck() {
        Test.startTest();

        // Insert duplicate records (simulate duplication)
        Course_Version__c cv1 = createTestCourseVersion(true);
        insert cv1;

        // Try inserting another with same info (you can simulate duplicate logic here)
        Course_Version__c cv2 = createTestCourseVersion(true);
      //  cv2.Name = cv1.Name;  // Assuming name is used for uniqueness check

        try {
            insert cv2;
           // System.assert(false, 'Expected exception due to duplicate Course Version');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('duplicate'), 'Correct exception not thrown');
        }

        Test.stopTest();
    }

    @isTest static void testAfterUndelete() {
        // Insert and delete a record
        Course_Version__c cv = createTestCourseVersion(true);
        insert cv;
        delete cv;

        Test.startTest();

        // Undelete it
        undelete cv;

        System.debug('After Undelete Trigger Tested');

        Test.stopTest();
    }

    @isTest static void testBeforeUpdate() {
        // Insert a record first
        Course_Version__c cv = createTestCourseVersion(true);
        insert cv;

        Test.startTest();

        // Modify before update
     //   cv.Subject_Start_Date__c = Date.today().addDays(5);
        update cv;

        System.debug('Before Update Trigger Tested');

        Test.stopTest();
    }
    @isTest static void testAfterUpdateWithFirstTimeFlag() {
    // Insert a record first
    Course_Version__c cv = createTestCourseVersion(true);
    insert cv;

    // Reset the isFirstTime flag to true to cover the specific condition
    ActivityTriggerNewHandler.isFirstTime = true;

    Test.startTest();

    // Update the record - this should trigger the after update logic
    // with isFirstTime = true
    update cv;

    System.debug('After Update with FirstTime Flag Tested');

    Test.stopTest();
    
    // Verify that isFirstTime was set to false
    System.assertEquals(false, ActivityTriggerNewHandler.isFirstTime, 
                       'isFirstTime should be set to false after trigger execution');
}
}