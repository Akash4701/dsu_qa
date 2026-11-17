/**
 * Single access point for the Feedback_Home_Setting__mdt "Default" record: the response-rate goal and
 * the "closes soon" alert window. Values outside a sane range (or a missing record) fall back to the
 * built-in defaults, so a bad admin edit can never break the home screen.
 */
public with sharing class FeedbackHomeSettings {
    public static final Integer DEFAULT_TARGET_RATE = 75;
    public static final Integer DEFAULT_ALERT_WINDOW_DAYS = 3;
    private static final String DEFAULT_RECORD = 'Default';

    // Custom Metadata records cannot be inserted in tests, so tests inject a setting here.
    @TestVisible
    private static Feedback_Home_Setting__mdt settingOverride;

    private static Feedback_Home_Setting__mdt cached;

    public static Integer targetResponseRate() {
        return inRange(setting()?.Target_Response_Rate__c, 1, 100, DEFAULT_TARGET_RATE);
    }

    public static Integer alertWindowDays() {
        return inRange(setting()?.Alert_Window_Days__c, 0, 30, DEFAULT_ALERT_WINDOW_DAYS);
    }

    private static Feedback_Home_Setting__mdt setting() {
        if (settingOverride != null) {
            return settingOverride;
        }
        if (cached == null) {
            cached = Feedback_Home_Setting__mdt.getInstance(DEFAULT_RECORD);
        }
        return cached;
    }

    private static Integer inRange(Decimal value, Integer low, Integer high, Integer fallback) {
        if (value == null || value < low || value > high) {
            return fallback;
        }
        return value.intValue();
    }
}