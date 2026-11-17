/**
 * Single access point for the Feedback_Email_Setting__mdt "Default" record: the
 * Organization-Wide Email Address (resolved by Display Name) and the email template
 * Developer Names used by Feedback Management. Keeps org-specific values out of Apex.
 */
public with sharing class FeedbackEmailSettings {
    private static final String DEFAULT_RECORD = 'Default';
    private static final String FALLBACK_FIRST_TEMPLATE = 'Feedback_Schedule_Email_Notification';
    private static final String FALLBACK_REMINDER_TEMPLATE = 'Feedback_Reminder_Email_Notification';

    // Custom Metadata records cannot be inserted in tests, so tests inject a setting here.
    @TestVisible
    private static Feedback_Email_Setting__mdt settingOverride;

    private static Feedback_Email_Setting__mdt cached;

    public static String firstTemplateDeveloperName() {
        return valueOrDefault(setting()?.First_Template_Developer_Name__c, FALLBACK_FIRST_TEMPLATE);
    }

    public static String reminderTemplateDeveloperName() {
        return valueOrDefault(setting()?.Reminder_Template_Developer_Name__c, FALLBACK_REMINDER_TEMPLATE);
    }

    /**
     * Id of the Organization-Wide Email Address matching the configured display name. When no display name is
     * configured (or none matches), falls back to any Organization-Wide Email Address; null only if the org has none.
     */
    public static Id orgWideEmailAddressId() {
        String displayName = setting()?.Org_Wide_Email_Display_Name__c;
        if (String.isNotBlank(displayName)) {
            List<OrgWideEmailAddress> matches = [
                SELECT Id
                FROM OrgWideEmailAddress
                WHERE DisplayName = :displayName
                ORDER BY Address
                LIMIT 1
            ];
            if (!matches.isEmpty()) {
                return matches[0].Id;
            }
        }
        List<OrgWideEmailAddress> anyAddress = [SELECT Id FROM OrgWideEmailAddress ORDER BY Address LIMIT 1];
        return anyAddress.isEmpty() ? null : anyAddress[0].Id;
    }

    private static Feedback_Email_Setting__mdt setting() {
        if (settingOverride != null) {
            return settingOverride;
        }
        if (cached == null) {
            cached = Feedback_Email_Setting__mdt.getInstance(DEFAULT_RECORD);
        }
        return cached;
    }

    private static String valueOrDefault(String value, String fallback) {
        return String.isBlank(value) ? fallback : value.trim();
    }
}