@isTest
private class FeedbackEmailSettingsTest {

    @isTest
    static void usesConfiguredTemplateNames() {
        FeedbackEmailSettings.settingOverride = new Feedback_Email_Setting__mdt(
            First_Template_Developer_Name__c = ' My_First ',
            Reminder_Template_Developer_Name__c = 'My_Reminder'
        );

        System.assertEquals('My_First', FeedbackEmailSettings.firstTemplateDeveloperName());
        System.assertEquals('My_Reminder', FeedbackEmailSettings.reminderTemplateDeveloperName());
    }

    @isTest
    static void fallsBackToDefaultTemplateNamesWhenBlank() {
        FeedbackEmailSettings.settingOverride = new Feedback_Email_Setting__mdt();

        System.assertEquals('Feedback_Schedule_Email_Notification', FeedbackEmailSettings.firstTemplateDeveloperName());
        System.assertEquals('Feedback_Reminder_Email_Notification', FeedbackEmailSettings.reminderTemplateDeveloperName());
    }

    @isTest
    static void fallsBackToAnyOrgWideAddressWhenDisplayNameBlankOrUnknown() {
        List<OrgWideEmailAddress> anyAddress = [SELECT Id FROM OrgWideEmailAddress ORDER BY Address LIMIT 1];
        Id expected = anyAddress.isEmpty() ? null : anyAddress[0].Id;

        FeedbackEmailSettings.settingOverride = new Feedback_Email_Setting__mdt();
        System.assertEquals(expected, FeedbackEmailSettings.orgWideEmailAddressId(), 'Blank display name');

        FeedbackEmailSettings.settingOverride = new Feedback_Email_Setting__mdt(
            Org_Wide_Email_Display_Name__c = 'No Such Display Name 9f3c1'
        );
        System.assertEquals(expected, FeedbackEmailSettings.orgWideEmailAddressId(), 'Unknown display name');
    }

    @isTest
    static void orgWideAddressResolvedByDisplayName() {
        List<OrgWideEmailAddress> existing = [SELECT Id, DisplayName FROM OrgWideEmailAddress LIMIT 1];
        if (existing.isEmpty()) {
            return; // OrgWideEmailAddress cannot be inserted from a test; nothing to resolve in this org.
        }
        FeedbackEmailSettings.settingOverride = new Feedback_Email_Setting__mdt(
            Org_Wide_Email_Display_Name__c = existing[0].DisplayName
        );

        System.assertNotEquals(null, FeedbackEmailSettings.orgWideEmailAddressId());
    }
}