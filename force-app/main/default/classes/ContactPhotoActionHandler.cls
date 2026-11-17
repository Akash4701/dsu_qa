public with sharing class ContactPhotoActionHandler {
    @AuraEnabled
    public static void processPassportPhoto(Id contactId) {
        if (contactId == null) {
            throw new AuraHandledException('Contact Id is required.');
        }

        
        List<ContentDocumentLink> allLinks = [
            SELECT Id, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :contactId
        ];

        Set<Id> allDocIds = new Set<Id>();
        for (ContentDocumentLink link : allLinks) {
            allDocIds.add(link.ContentDocumentId);
        }

        
        List<ContentVersion> allVersions = new List<ContentVersion>();
        if (!allDocIds.isEmpty()) {
            allVersions = [
                SELECT Id, ContentDocumentId, FileExtension, VersionData, Title, LastModifiedDate
                FROM ContentVersion
                WHERE ContentDocumentId IN :allDocIds
                AND FileExtension IN ('jpg', 'png','jpeg')
                ORDER BY LastModifiedDate DESC
            ];
        }

        if (allVersions.isEmpty()) {
            throw new AuraHandledException('No JPG/PNG/JPEG file found for Contact.');
        }

        
        ContentVersion latest = allVersions[0];

        Set<Id> docIdsToUnlink = new Set<Id>();
        for (Integer i = 1; i < allVersions.size(); i++) {
            docIdsToUnlink.add(allVersions[i].ContentDocumentId);
        }

        List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
        for (ContentDocumentLink l : allLinks) {
            if (docIdsToUnlink.contains(l.ContentDocumentId)) {
                linksToDelete.add(l);
            }
        }

        if (!linksToDelete.isEmpty()) {
            delete linksToDelete;
        }

        
        Blob fileBlob = latest.VersionData;
        String base64Data = EncodingUtil.base64Encode(fileBlob);
        String fileName = latest.Title + '.' + latest.FileExtension;

        String publicUrl = ken42_CreateContentVersion.createContentVersion(fileName, base64Data);

        if (String.isBlank(publicUrl)) {
            throw new AuraHandledException('Public URL generation failed.');
        }

        
        Contact c = [SELECT Id, Passport_Size_Photo__c FROM Contact WHERE Id = :contactId];
        c.Passport_Size_Photo__c = publicUrl;
        update c;
    }
}