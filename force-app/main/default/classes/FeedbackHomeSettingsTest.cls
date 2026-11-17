@IsTest
private class FeedbackHomeSettingsTest {

    @IsTest
    static void configuredValuesAreUsed() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        FeedbackHomeSettings.settingOverride = new Feedback_Home_Setting__mdt(
            Target_Response_Rate__c = 90, Alert_Window_Days__c = 5);

        System.assertEquals(90, FeedbackHomeSettings.targetResponseRate());
        System.assertEquals(5, FeedbackHomeSettings.alertWindowDays());
            }
    }

    @IsTest
    static void blankOrOutOfRangeValuesFallBackToDefaults() {
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
        FeedbackHomeSettings.settingOverride = new Feedback_Home_Setting__mdt(
            Target_Response_Rate__c = 250, Alert_Window_Days__c = -4);

        System.assertEquals(FeedbackHomeSettings.DEFAULT_TARGET_RATE, FeedbackHomeSettings.targetResponseRate());
        System.assertEquals(FeedbackHomeSettings.DEFAULT_ALERT_WINDOW_DAYS, FeedbackHomeSettings.alertWindowDays());

        FeedbackHomeSettings.settingOverride = new Feedback_Home_Setting__mdt();
        System.assertEquals(FeedbackHomeSettings.DEFAULT_TARGET_RATE, FeedbackHomeSettings.targetResponseRate());
            }
    }

    @IsTest
    static void overviewUsesTheConfiguredTarget() {
        FeedbackHomeSettings.settingOverride = new Feedback_Home_Setting__mdt(
            Target_Response_Rate__c = 40, Alert_Window_Days__c = 3);
        System.runAs(FeedbackHomeTestData.asFeedbackUser()) {
            System.assertEquals(40, FeedbackHomeService.overview().targetResponseRate);
        }
    }
}