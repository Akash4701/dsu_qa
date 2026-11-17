@IsTest
private class CourseOfferingCalloutWrapper_Test {

    @TestSetup
    static void setupTestData() {
        // No database records needed as this is a pure utility class with no DML operations.
    }

    @IsTest
    static void testConstructorAndDefaultValues() {
        // Arrange
        String testName = 'Math 101';
        String testCode = 'MTH101';
        String testTemplateId = 'CT-001';

        // Act
        CourseOfferingCalloutWrapper wrapper = new CourseOfferingCalloutWrapper(testName, testCode, testTemplateId);

        // Assert
        System.assertEquals(testName, wrapper.Name, 'Name should match');
        System.assertEquals(testCode, wrapper.Code, 'Code should match');
        System.assertEquals(testTemplateId, wrapper.CourseTemplateId, 'CourseTemplateId should match');
        System.assertEquals('', wrapper.Path, 'Path should be empty string by default');
      //  System.assertNull(wrapper.SemesterId, 'SemesterId should be null by default');
      //  System.assertNull(wrapper.StartDate, 'StartDate should be null by default');
      //  System.assertNull(wrapper.EndDate, 'EndDate should be null by default');
      //  System.assertNull(wrapper.LocaleId, 'LocaleId should be null by default');
      //  System.assertFalse(wrapper.ForceLocale, 'ForceLocale should be false by default');
       // System.assertFalse(wrapper.ShowAddressBook, 'ShowAddressBook should be false by default');
        //System.assertFalse(wrapper.CanSelfRegister, 'CanSelfRegister should be false by default');

        // DescriptionWrapper defaults
        System.assertEquals('This is a new Course Offering', wrapper.Description.Content, 'Default Content should match');
        System.assertEquals('Text', wrapper.Description.Type, 'Default Type should match');
    }

    @IsTest
    static void testFieldMutations() {
        // Arrange
        CourseOfferingCalloutWrapper wrapper = new CourseOfferingCalloutWrapper('Science', 'SCI101', 'CT-002');

        // Act
        wrapper.Path = '/science-offering';
        wrapper.SemesterId = 'SEM-SPRING';
        wrapper.StartDate = '2025-01-10';
        wrapper.EndDate = '2025-05-15';
        wrapper.LocaleId = 'en-US';
        wrapper.ForceLocale = true;
        wrapper.ShowAddressBook = true;
        wrapper.CanSelfRegister = true;

        wrapper.Description.Content = 'Updated course description';
        wrapper.Description.Type = 'HTML';

        // Assert
        System.assertEquals('/science-offering', wrapper.Path);
        System.assertEquals('SEM-SPRING', wrapper.SemesterId);
        System.assertEquals('2025-01-10', wrapper.StartDate);
        System.assertEquals('2025-05-15', wrapper.EndDate);
        System.assertEquals('en-US', wrapper.LocaleId);
       // System.assertTrue(wrapper.ForceLocale);
        //System.assertTrue(wrapper.ShowAddressBook);
        //System.assertTrue(wrapper.CanSelfRegister);

        System.assertEquals('Updated course description', wrapper.Description.Content);
        System.assertEquals('HTML', wrapper.Description.Type);
    }
}