public with sharing class ken42_CreateContentVersion {

    /**
     * Stores a base64 document as a Salesforce file and returns a public download URL for it,
     * or NULL when the file could not be stored or published.
     *
     * PKDSU-243 - why this returns null instead of an error message:
     * callers assign the result straight onto URL fields, for example
     * Contact.Passport_Size_Photo__c in ApplicantServiceV3/V4. This method used to catch any
     * failure and `return ex.getMessage()`, so when the org hit its content publication limit
     * the text "ContentPublication Limit exceeded" was written into a URL field. The following
     * `update applicant` then failed on an invalid URL and took the whole applicant import down
     * with it - which is what marked those records as Failed. A failure to publish must cost the
     * photo, never the import, so it now returns null and leaves the field empty.
     */
    public static String createContentVersion(String title, String base64String) {
        return createContentVersion(title, base64String, null);
    }

    /**
     * As above, and additionally attaches the stored file to linkedEntityId.
     *
     * Passing a linked entity also enables reuse: if that record already holds a published file
     * with the same title, its existing URL is returned rather than publishing another copy.
     * Every ContentDistribution consumes a content publication against the org's limit, so
     * re-running an import no longer burns a fresh one per document per attempt.
     */
    public static String createContentVersion(String title, String base64String, Id linkedEntityId) {
        if (String.isBlank(base64String) || String.isBlank(title)) {
            return null;
        }

        // Reuse anything already published for this record under the same title
        if (linkedEntityId != null) {
            String existingUrl = findExistingPublishedUrl(title, linkedEntityId);
            if (existingUrl != null) {
                return existingUrl;
            }
        }

        ContentVersion newVersion = new ContentVersion();
        try {
            newVersion.Title = title;
            newVersion.PathOnClient = title;
            newVersion.VersionData = EncodingUtil.base64Decode(base64String);
            insert newVersion;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ken42_CreateContentVersion: could not store "' + title + '": ' + ex.getMessage());
            return null;
        }

        ContentVersion stored;
        try {
            stored = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :newVersion.Id LIMIT 1];
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ken42_CreateContentVersion: could not read back "' + title + '": ' + ex.getMessage());
            return null;
        }

        // Attach the file to the record. Kept separate from publishing so that a publication
        // failure still leaves the document stored against the record rather than orphaned.
        if (linkedEntityId != null && stored.ContentDocumentId != null) {
            try {
                insert new ContentDocumentLink(
                    ContentDocumentId = stored.ContentDocumentId,
                    LinkedEntityId = linkedEntityId,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'ken42_CreateContentVersion: could not link "' + title + '": ' + ex.getMessage());
            }
        }

        // Publishing is the step that consumes the content publication limit, so it is the step
        // most likely to fail. A failure here returns null and the caller simply has no URL.
        try {
            ContentDistribution distribution = new ContentDistribution();
            distribution.Name = title;
            distribution.ContentVersionId = stored.Id;
            distribution.PreferencesLinkLatestVersion = true;
            distribution.PreferencesAllowViewInBrowser = true;
            distribution.PreferencesNotifyOnVisit = false;
            insert distribution;

            ContentDistribution published = [
                SELECT Id, ContentDownloadUrl, DistributionPublicUrl
                FROM ContentDistribution
                WHERE Id = :distribution.Id
                LIMIT 1
            ];
            return published.ContentDownloadUrl;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ken42_CreateContentVersion: could not publish "' + title + '": ' + ex.getMessage());
            return null;
        }
    }

    // Returns the download URL of a file already published against this record under this
    // title, or null when there is none.
    private static String findExistingPublishedUrl(String title, Id linkedEntityId) {
        try {
            Set<Id> documentIds = new Set<Id>();
            for (ContentDocumentLink link : [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :linkedEntityId
            ]) {
                documentIds.add(link.ContentDocumentId);
            }
            if (documentIds.isEmpty()) {
                return null;
            }

            List<ContentDistribution> published = [
                SELECT Id, ContentDownloadUrl
                FROM ContentDistribution
                WHERE ContentDocumentId IN :documentIds
                  AND Name = :title
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return published.isEmpty() ? null : published[0].ContentDownloadUrl;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'ken42_CreateContentVersion: reuse lookup failed for "' + title + '": ' + ex.getMessage());
            return null;
        }
    }
}