@isTest
public class UserEnrollmentWrapperTest {

    @isTest
    static void testUserEnrollmentWrapperInitialization() {
        // Instantiate the wrapper
        UserEnrollmentWrapper wrapper = new UserEnrollmentWrapper();

        // Validate UserData defaults
        System.assertNotEquals(null, wrapper.user, 'UserData should be initialized');
        System.assertEquals('110', wrapper.user.RoleId, 'Default RoleId should be 110');
        System.assertEquals(true, wrapper.user.IsActive, 'Default IsActive should be true');
        System.assertEquals(false, wrapper.user.SendCreationEmail, 'Default SendCreationEmail should be false');

        // Validate EnrollmentData list
        System.assertNotEquals(null, wrapper.enroll, 'Enroll list should be initialized');
        System.assertEquals(0, wrapper.enroll.size(), 'Enroll list should be empty initially');
    }

    @isTest
    static void testEnrollmentDataEquality() {
        // Create two enrollment entries with same OrgUnitId
        UserEnrollmentWrapper.EnrollmentData enroll1 = new UserEnrollmentWrapper.EnrollmentData();
        enroll1.OrgUnitId = 'OU001';
        enroll1.OrgSFID = 'SF001';

        UserEnrollmentWrapper.EnrollmentData enroll2 = new UserEnrollmentWrapper.EnrollmentData();
        enroll2.OrgUnitId = 'OU001';
        enroll2.OrgSFID = 'SF002';

        UserEnrollmentWrapper.EnrollmentData enroll3 = new UserEnrollmentWrapper.EnrollmentData();
        enroll3.OrgUnitId = 'OU999';

        // Check equality and hash code
        System.assertEquals(true, enroll1.equals(enroll2), 'Equal OrgUnitId should make them equal');
        System.assertEquals(false, enroll1.equals(enroll3), 'Different OrgUnitId should make them not equal');
    }

    @isTest
    static void testApiResponseInitialization() {
        UserEnrollmentWrapper.ApiResponse apiResp = new UserEnrollmentWrapper.ApiResponse();
        apiResp.user = new UserEnrollmentWrapper.UserResponse();
        apiResp.enroll = new List<UserEnrollmentWrapper.EnrollmentResponse>();

        UserEnrollmentWrapper.UserResponse userResp = new UserEnrollmentWrapper.UserResponse();
        userResp.status = true;
        userResp.recordId = '001D000000XYZ123';
        userResp.lmsId = 'LMS1001';

        UserEnrollmentWrapper.EnrollmentResponse enrollResp = new UserEnrollmentWrapper.EnrollmentResponse();
        enrollResp.status = true;
        enrollResp.recordId = 'ER001';

        apiResp.user = userResp;
        apiResp.enroll.add(enrollResp);

        System.assertEquals(true, apiResp.user.status, 'User status should be true');
        System.assertEquals('LMS1001', apiResp.user.lmsId, 'LMS ID should be LMS1001');
        System.assertEquals(1, apiResp.enroll.size(), 'Should contain 1 enrollment response');
    }
}