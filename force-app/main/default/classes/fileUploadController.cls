/**
 * @description       : 
 * @author            : Ken42
 * @group             : 
 * @last modified on  : 27-10-2025
 * @last modified by  : Ken42
**/
public with sharing class fileUploadController {
        
    @AuraEnabled
    public static String uploadAndGetPublicUrl(String fileName, String base64Content) {
        return ken42_CreateContentVersion.createContentVersion(fileName, base64Content);
    }
    
    @AuraEnabled
    public static void saveFileRecord(String announcementId, String fileUrl, String fileName) {
        if (String.isBlank(announcementId)) {
            throw new AuraHandledException('Announcement ID is required.');
        }
        Annexure__c file = new Annexure__c();
        file.File_Url__c = fileUrl;
        file.Name = fileName;
        file.Announcement__c = announcementId;
        insert file;
    }
}