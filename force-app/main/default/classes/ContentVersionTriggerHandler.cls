public class ContentVersionTriggerHandler {
    public static void handleAfterInsert(List<ContentVersion> newVersions) {
        Set<Id> contactIds = new Set<Id>();
        Map<Id, ContentVersion> newContentMap = new Map<Id, ContentVersion>();

        for (ContentVersion cv : newVersions) {
            if (
                cv.FirstPublishLocationId != null &&
                cv.PathOnClient != null &&
                (cv.PathOnClient.toLowerCase().endsWith('.jpg') || cv.PathOnClient.toLowerCase().endsWith('.png')|| cv.PathOnClient.toLowerCase().endsWith('.jpeg'))
            ) {
                
                if (String.valueOf(cv.FirstPublishLocationId).startsWith('003')) {
                    contactIds.add(cv.FirstPublishLocationId);
                    newContentMap.put(cv.Id, cv);
                }
            }
        }

        if (contactIds.isEmpty()) return;

        
        List<ContentDocumentLink> allLinks = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :contactIds
        ];

        Set<Id> allDocIds = new Set<Id>();
        for (ContentDocumentLink link : allLinks) {
            allDocIds.add(link.ContentDocumentId);
        }

        if (allDocIds.isEmpty()) return;

        
        List<ContentVersion> allVersions = [
            SELECT Id, ContentDocumentId, FileExtension, LastModifiedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :allDocIds
            AND FileExtension IN ('jpg', 'png','jpeg')
            ORDER BY LastModifiedDate DESC
        ];

       
        Map<Id, List<ContentVersion>> versionsByContact = new Map<Id, List<ContentVersion>>();
        Map<Id, Id> docIdToContactId = new Map<Id, Id>();
        for (ContentDocumentLink link : allLinks) {
            docIdToContactId.put(link.ContentDocumentId, link.LinkedEntityId);
        }

        for (ContentVersion version : allVersions) {
            Id contactId = docIdToContactId.get(version.ContentDocumentId);
            if (contactId != null) {
                if (!versionsByContact.containsKey(contactId)) {
                    versionsByContact.put(contactId, new List<ContentVersion>());
                }
                versionsByContact.get(contactId).add(version);
            }
        }

        
        List<ContentDocumentLink> linksToDelete = new List<ContentDocumentLink>();
        for (Id contactId : versionsByContact.keySet()) {
            List<ContentVersion> versions = versionsByContact.get(contactId);
            if (versions.size() > 1) {
                for (Integer i = 1; i < versions.size(); i++) {
                    Id oldDocId = versions[i].ContentDocumentId;
                    for (ContentDocumentLink link : allLinks) {
                        if (link.LinkedEntityId == contactId && link.ContentDocumentId == oldDocId) {
                            linksToDelete.add(link);
                        }
                    }
                }
            }
        }

        if (!linksToDelete.isEmpty()) {
            delete linksToDelete;
        }
    }
}