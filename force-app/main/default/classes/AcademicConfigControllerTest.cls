@IsTest(SeeAllData=true)
private class AcademicConfigControllerTest {

    @IsTest
    static void testGetAcademicConfigurationMatch() {

        Test.startTest();
        Academic_Program_Config__mdt cfg =
            AcademicConfigController.getAcademicConfiguration('College');
        Test.stopTest();
    }

    @IsTest
    static void testGetAcademicConfigurationFallback() {

        Test.startTest();
        Academic_Program_Config__mdt cfg =
            AcademicConfigController.getAcademicConfiguration('NonExistingType');
        Test.stopTest();
    }

    @IsTest
    static void testGetAllConfigurations() {

        Test.startTest();
        List<Academic_Program_Config__mdt> configs =
            AcademicConfigController.getAllConfigurations();
        Test.stopTest();
    }

    @IsTest
    static void testParseWorkingDays() {
        List<String> days = AcademicConfigController.parseWorkingDays('Mon,Tue');
    }

    @IsTest
    static void testParseWorkingDaysDefault() {
        List<String> days = AcademicConfigController.parseWorkingDays('');
    }
}