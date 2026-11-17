@RestResource(urlMapping='/createDocument')
global with sharing class DocumentRestService {

    @HttpPost
    global static void createDocument() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        try {
            // Convert Blob requestBody to String
            String requestBody = req.requestBody.toString();

            // Parse the incoming JSON request body
            Map<String, Object> requestBodyMap = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            String recordId = (String) requestBodyMap.get('recordId');
            String versionData = (String) requestBodyMap.get('versionData');
            String title = (String) requestBodyMap.get('title'); // Optional: to give a title to the document

            // Create the ContentVersion (Salesforce file)
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.FirstPublishLocationId = recordId; // Record to link the document to
            contentVersion.VersionData = EncodingUtil.base64Decode(versionData); // Base64 decoded file data
            contentVersion.PathOnClient = title != null ? title : 'Uploaded Document'; // Document title
            insert contentVersion;

            // Query to get the related ContentDocumentId
            ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];

            // Return the ContentDocumentId
          //  res.responseBody = Blob.valueOf('{"message": "File uploaded successfully", "ContentDocumentId": "' + insertedContentVersion.ContentDocumentId + '"}');
            res.responseBody = Blob.valueOf('{"message": "File uploaded successfully", "ContentVersionId": "' + insertedContentVersion.Id + '", "ContentDocumentId": "' + insertedContentVersion.ContentDocumentId + '"}');
            res.statusCode = 200;
          
        } catch (Exception e) {
            res.responseBody = Blob.valueOf('{"error": "Error: ' + e.getMessage() + '"}');
            res.statusCode = 400;
        }
    }
}