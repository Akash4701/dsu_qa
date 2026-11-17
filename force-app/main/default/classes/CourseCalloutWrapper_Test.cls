@IsTest
private class CourseCalloutWrapper_Test {

    @TestSetup
    static void setupTestData() {
        // No database operations needed for this class since it's not interacting with Salesforce data.
        // We'll prepare test data in each method as needed.
    }

    @IsTest
    static void testCourseDataInitialization() {
        // Arrange
        String testName = 'Math 101';
        String testCode = 'MTH101';
        String testParentOrgUnitId = 'ORG001';

        // Act
        CourseCalloutWrapper.CourseData course = new CourseCalloutWrapper.CourseData(testName, testCode, testParentOrgUnitId);

        // Assert
        System.assertEquals(testName, course.Name, 'Name should match');
        System.assertEquals(testCode, course.Code, 'Code should match');
        System.assertEquals('', course.Path, 'Path should be empty string by default');
        System.assertEquals(1, course.ParentOrgUnitIds.size(), 'ParentOrgUnitIds should have one element');
        System.assertEquals(testParentOrgUnitId, course.ParentOrgUnitIds[0], 'ParentOrgUnitId should match');
    }

    @IsTest
    static void testMultipleParentOrgUnitIds() {
        // Arrange
        String testName = 'Science 101';
        String testCode = 'SCI101';
        String[] parentIds = new String[]{'ORG001', 'ORG002'};

        // Act
        CourseCalloutWrapper.CourseData course = new CourseCalloutWrapper.CourseData(testName, testCode, parentIds[0]);
        course.ParentOrgUnitIds.add(parentIds[1]);

        // Assert
        System.assertEquals(2, course.ParentOrgUnitIds.size(), 'ParentOrgUnitIds should have two elements');
    //    System.assertTrue(course.ParentOrgUnitIds.containsAll(parentIds), 'ParentOrgUnitIds should contain both test IDs');
    }

    @IsTest
    static void testCourseListInitialization() {
        // Arrange
        CourseCalloutWrapper wrapper = new CourseCalloutWrapper();

        // Act
        wrapper.courses = new List<CourseCalloutWrapper.CourseData>();

        CourseCalloutWrapper.CourseData course1 = new CourseCalloutWrapper.CourseData('History', 'HIS101', 'ORG003');
        CourseCalloutWrapper.CourseData course2 = new CourseCalloutWrapper.CourseData('Art', 'ART101', 'ORG004');

        wrapper.courses.add(course1);
        wrapper.courses.add(course2);

        // Assert
        System.assertEquals(2, wrapper.courses.size(), 'Wrapper should hold 2 courses');
        System.assertEquals('History', wrapper.courses[0].Name);
        System.assertEquals('ART101', wrapper.courses[1].Code);
    }
}