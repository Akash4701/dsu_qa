public with sharing class EmailBrandingHelper {

    public static String applyBranding(String html) {
        if (String.isBlank(html)) {
            return html;
        }

        Email_Branding__c branding = Email_Branding__c.getInstance();

        return html
            .replace('%%PRIMARY_COLOR%%', safe(branding.Primary_Color__c, '#0055CC'))
            .replace('%%GRADIENT_START%%', safe(branding.Gradient_Start__c, '#0044BB'))
            .replace('%%GRADIENT_END%%', safe(branding.Gradient_End__c, '#0077EE'))
            .replace('%%DEEP_NAVY%%', safe(branding.Deep_Navy__c, '#002266'))
            .replace('%%MUTED_BLUE%%', safe(branding.Muted_Blue__c, '#A8C4E0'))
            .replace('%%ACCENT_LINE%%', safe(branding.Accent_Line__c, '#0077EE'))
            .replace('%%PORTAL_LOGIN_URL%%', safe(branding.Portal_Login_URL__c, 'https://student.dsuonline.com'))
            .replace('%%LOGO_URL%%', safe(branding.Logo_URL__c, ''))
            .replace('%%LOGO_ALT%%', safe(branding.Logo_Alt_Text__c, 'Dayananda Sagar University'))
            .replace('%%ORG_FOOTER_NAME%%', safe(branding.Org_Footer_Name__c, 'Dayananda Sagar University'));
    }

    private static String safe(String value, String fallback) {
        return String.isBlank(value) ? fallback : value;
    }
}