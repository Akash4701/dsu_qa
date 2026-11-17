@isTest
private class EmailBrandingHelperTest {

    @TestSetup
    static void setup() {
        Email_Branding__c b = Email_Branding__c.getOrgDefaults();
        b.SetupOwnerId = UserInfo.getOrganizationId();
        b.Primary_Color__c = '#111111';
        b.Gradient_Start__c = '#222222';
        b.Gradient_End__c = '#333333';
        b.Deep_Navy__c = '#444444';
        b.Muted_Blue__c = '#555555';
        b.Accent_Line__c = '#666666';
        b.Logo_URL__c = 'https://example.com/logo.png';
        b.Logo_Alt_Text__c = 'Test Alt';
        b.Org_Footer_Name__c = 'Test Org';
        upsert b;
    }

    @isTest
    static void replacesAllTokensWithConfiguredValues() {
        String template = '%%PRIMARY_COLOR%% %%GRADIENT_START%% %%GRADIENT_END%% %%DEEP_NAVY%% %%MUTED_BLUE%% %%ACCENT_LINE%% %%LOGO_URL%% %%LOGO_ALT%% %%ORG_FOOTER_NAME%%';

        Test.startTest();
        String result = EmailBrandingHelper.applyBranding(template);
        Test.stopTest();

        System.assertEquals(
            '#111111 #222222 #333333 #444444 #555555 #666666 https://example.com/logo.png Test Alt Test Org',
            result,
            'All branding tokens should be substituted with the configured values.'
        );
    }

    @isTest
    static void returnsBlankInputUnchanged() {
        System.assertEquals(null, EmailBrandingHelper.applyBranding(null));
        System.assertEquals('', EmailBrandingHelper.applyBranding(''));
    }

    @isTest
    static void fallsBackToDefaultsWhenNoRecordConfigured() {
        delete [SELECT Id FROM Email_Branding__c];

        Test.startTest();
        String result = EmailBrandingHelper.applyBranding('%%PRIMARY_COLOR%% %%LOGO_ALT%%');
        Test.stopTest();

        System.assertEquals('#0055CC Dayananda Sagar University', result, 'Blank fields should fall back to hardcoded defaults.');
    }
}