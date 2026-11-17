@RestResource(urlMapping='/createCaseWithAttachment')
global with sharing class CreateCaseWithAttachmentService {
    global class CaseRequest {
        public String contactId;
        public String subject;
        public String description;
        public String origin;
        public String status;
        public String recordTypeId;
        public String priority;
        public String type;
        public String serviceOfferingId;
        public String attachmentBase64;
        public String attachmentName;
        public String attachmentContentType;
    }
    
    global class CaseResponse {
        public Boolean success;
        public String caseId;
        public String error;
        public String attachmentId;
        public String previewUrl;
        public String publicUrl;
        public String downloadUrl;
    }
    
    @HttpPost
    global static String createCaseWithAttachment() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        CaseRequest input;
        CaseResponse output = new CaseResponse();
        List<CaseResponse> responseList = new List<CaseResponse>();
        
        try {
            input = (CaseRequest) JSON.deserialize(RestContext.request.requestBody.toString(), CaseRequest.class);
            
            // Create the case record
            Case caseRecord = new Case();
            caseRecord.ContactId = input.contactId;
            caseRecord.Subject = input.subject;
            caseRecord.Description = input.description;
            caseRecord.Origin = input.origin;
            caseRecord.Status = input.status;
            caseRecord.RecordTypeId = input.recordTypeId;
            caseRecord.Priority = input.priority;
            caseRecord.Type = input.type;
            caseRecord.Service_Offering__c = input.serviceOfferingId;
            insert caseRecord;
            
            // Handle attachment if present
            if (String.isNotBlank(input.attachmentBase64)) {
                String previewUrl = '';
                String publicUrl = '';
                String downloadUrl = '';
                String attachmentId = '';
                
                try {
                    // Use ContentVersion for better file handling
                    ContentVersion cv = new ContentVersion();
                    cv.Title = String.isNotBlank(input.attachmentName) ? input.attachmentName : 'uploaded_file';
                    
                    // Ensure proper file extension for preview
                    String fileName = String.isNotBlank(input.attachmentName) ? input.attachmentName : 'uploaded_file';
                    
                    // If no extension provided, determine from content type
                    if (!fileName.contains('.') && String.isNotBlank(input.attachmentContentType)) {
                        String contentType = input.attachmentContentType.toLowerCase();
                        
                        // Image types
                        if (contentType.contains('image/jpeg') || contentType.contains('image/jpg')) {
                            fileName += '.jpg';
                        } else if (contentType.contains('image/png')) {
                            fileName += '.png';
                        } else if (contentType.contains('image/gif')) {
                            fileName += '.gif';
                        } else if (contentType.contains('image/bmp')) {
                            fileName += '.bmp';
                        } else if (contentType.contains('image/webp')) {
                            fileName += '.webp';
                        } else if (contentType.contains('image/svg')) {
                            fileName += '.svg';
                        } 
                        // Document types
                        else if (contentType.contains('pdf')) {
                            fileName += '.pdf';
                        } else if (contentType.contains('msword') || contentType.contains('wordprocessingml')) {
                            fileName += '.docx';
                        } else if (contentType.contains('excel') || contentType.contains('spreadsheetml')) {
                            fileName += '.xlsx';
                        } else if (contentType.contains('powerpoint') || contentType.contains('presentationml')) {
                            fileName += '.pptx';
                        }
                        // Text types
                        else if (contentType.contains('text/plain')) {
                            fileName += '.txt';
                        } else if (contentType.contains('text/csv')) {
                            fileName += '.csv';
                        } else if (contentType.contains('application/json')) {
                            fileName += '.json';
                        } else if (contentType.contains('text/xml') || contentType.contains('application/xml')) {
                            fileName += '.xml';
                        }
                        // Default fallback - try to detect from base64 content
                        else {
                            fileName += getExtensionFromBase64Content(input.attachmentBase64);
                        }
                    }
                    
                    // If still no extension after content type check, default based on content analysis
                    if (!fileName.contains('.')) {
                        fileName += getExtensionFromBase64Content(input.attachmentBase64);
                    }
                    
                    cv.PathOnClient = fileName;
                    cv.VersionData = EncodingUtil.base64Decode(input.attachmentBase64);
                    cv.FirstPublishLocationId = caseRecord.Id;
                    cv.IsMajorVersion = true;
                    cv.Origin = 'H'; // Chatter origin for better preview support
                    
                    // Set content type if provided
                    if (String.isNotBlank(input.attachmentContentType)) {
                        cv.Description = 'Content-Type: ' + input.attachmentContentType;
                    }
                    
                    insert cv;
                    
                    // Query to get ContentDocumentId and other details
                    cv = [SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, 
                          FileType, FileExtension, ContentSize, ContentDocument.Title
                          FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
                    
                    attachmentId = cv.ContentDocumentId;
                    
                    // Create ContentDistribution for public access
                    ContentDistribution cd = new ContentDistribution();
                    cd.Name = cv.ContentDocument.Title + ' - Public Link';
                    cd.ContentVersionId = cv.Id;
                    cd.PreferencesAllowOriginalDownload = true;
                    cd.PreferencesAllowPDFDownload = true;
                    cd.PreferencesAllowViewInBrowser = true;
                    cd.PreferencesExpires = false; // Set to true if you want expiration
                    cd.PreferencesNotifyOnVisit = false;
                    cd.PreferencesPasswordRequired = false;
                    cd.PreferencesNotifyRndtnComplete = false;
                    
                    insert cd;
                    
                    // Query the ContentDistribution to get the public URLs
                    cd = [SELECT Id, ContentDownloadUrl, DistributionPublicUrl, PdfDownloadUrl 
                          FROM ContentDistribution WHERE Id = :cd.Id LIMIT 1];
                    
                    // Set the public URLs
                    publicUrl = cd.DistributionPublicUrl;
                    downloadUrl = cd.ContentDownloadUrl;
                    
                    // For preview, use the public distribution URL
                    previewUrl = publicUrl;
                    
                    // If PDF is available, provide that option too
                    if (String.isNotBlank(cd.PdfDownloadUrl)) {
                        // PDF preview URL is also available
                        System.debug('PDF Download URL available: ' + cd.PdfDownloadUrl);
                    }
                    
                } catch (Exception attachmentException) {
                    System.debug('ContentVersion/Distribution failed: ' + attachmentException.getMessage());
                    
                    // Fallback: Use traditional Attachment object (Note: This won't be publicly accessible)
                    Attachment att = new Attachment();
                    att.Name = String.isNotBlank(input.attachmentName) ? input.attachmentName : 'uploaded_file';
                    att.Body = EncodingUtil.base64Decode(input.attachmentBase64);
                    att.ParentId = caseRecord.Id;
                    att.ContentType = input.attachmentContentType;
                    insert att;
                    
                    attachmentId = att.Id;
                    String baseUrl = getBaseUrl();
                    // Note: Attachment URLs are not publicly accessible
                    previewUrl = baseUrl + '/' + att.Id;
                    publicUrl = 'Not available - requires authentication';
                    downloadUrl = previewUrl;
                }
                
                // Update the Case with the public preview URL
                caseRecord.Attachment__c = publicUrl;
                update caseRecord;
                
                output.attachmentId = attachmentId;
                output.previewUrl = previewUrl;
                output.publicUrl = publicUrl;
                output.downloadUrl = downloadUrl;
            }
            
            output.success = true;
            output.caseId = caseRecord.Id;
            
        } catch (Exception e) {
            res.statusCode = 500;
            output.success = false;
            output.error = e.getMessage();
            System.debug('Error: ' + e.getMessage() + ' Stack: ' + e.getStackTraceString());
        }
        
        responseList.add(output);
        String jsonResponse = JSON.serialize(responseList);
        System.debug('Response JSON: ' + jsonResponse);
        return jsonResponse;
    }
    
    // Helper method to get base URL more reliably
    private static String getBaseUrl() {
        String baseUrl = '';
        
        try {
            // Try to get from REST context first
            String protocol = RestContext.request.headers.get('X-Forwarded-Proto');
            String host = RestContext.request.headers.get('Host');
            
            if (String.isNotBlank(host)) {
                if (String.isBlank(protocol)) {
                    protocol = 'https'; // Default to HTTPS
                }
                baseUrl = protocol + '://' + host;
            } else {
                // Fallback: Use System.URL methods for current API versions
                baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
            }
        } catch (Exception e) {
            // Final fallback: construct from request URL
            try {
                String requestUrl = RestContext.request.requestURI;
                if (String.isNotBlank(requestUrl)) {
                    // Extract base URL from request URI
                    String[] urlParts = requestUrl.split('/services/');
                    if (urlParts.size() > 0) {
                        baseUrl = 'https://' + RestContext.request.headers.get('Host');
                    }
                }
                
                // Last resort: use a hardcoded pattern (you should replace with your actual domain)
                if (String.isBlank(baseUrl)) {
                    String host = RestContext.request.headers.get('Host');
                    baseUrl = String.isNotBlank(host) ? 'https://' + host : '';
                }
            } catch (Exception ex) {
                System.debug('Error getting base URL: ' + ex.getMessage());
                // Use empty string as final fallback - this will create relative URLs
                baseUrl = '';
            }
        }
        
        return baseUrl;
    }
    
    // Helper method to detect file extension from base64 content
    private static String getExtensionFromBase64Content(String base64Content) {
        if (String.isBlank(base64Content)) {
            return '.txt';
        }
        
        try {
            // Get the first few bytes to check file signature
            Blob fileBlob = EncodingUtil.base64Decode(base64Content);
            String hexString = EncodingUtil.convertToHex(fileBlob).substring(0, Math.min(20, EncodingUtil.convertToHex(fileBlob).length()));
            
            // Check file signatures (magic numbers)
            if (hexString.startsWith('ffd8ff')) {
                return '.jpg';
            } else if (hexString.startsWith('89504e47')) {
                return '.png';
            } else if (hexString.startsWith('47494638')) {
                return '.gif';
            } else if (hexString.startsWith('424d')) {
                return '.bmp';
            } else if (hexString.startsWith('25504446')) {
                return '.pdf';
            } else if (hexString.startsWith('504b0304')) {
                return '.zip'; // Could be docx, xlsx, etc.
            } else if (hexString.contains('3c68746d6c') || hexString.contains('3c48544d4c')) {
                return '.html';
            } else {
                return '.txt'; // Default fallback
            }
        } catch (Exception e) {
            System.debug('Error detecting file type: ' + e.getMessage());
            return '.txt';
        }
    }
    
    // Optional: Method to create public link for existing ContentDocument
    @HttpGet
    global static String createPublicLink() {
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        
        String contentDocumentId = RestContext.request.params.get('contentDocumentId');
        
        if (String.isBlank(contentDocumentId)) {
            res.statusCode = 400;
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => 'contentDocumentId parameter is required'
            });
        }
        
        try {
            // Get the latest ContentVersion for this document
            ContentVersion cv = [SELECT Id, ContentDocumentId, ContentDocument.Title 
                               FROM ContentVersion 
                               WHERE ContentDocumentId = :contentDocumentId 
                               AND IsLatest = true 
                               LIMIT 1];
            
            // Create ContentDistribution for public access
            ContentDistribution cd = new ContentDistribution();
            cd.Name = cv.ContentDocument.Title + ' - Public Link';
            cd.ContentVersionId = cv.Id;
            cd.PreferencesAllowOriginalDownload = true;
            cd.PreferencesAllowPDFDownload = true;
            cd.PreferencesAllowViewInBrowser = true;
            cd.PreferencesExpires = false;
            cd.PreferencesNotifyOnVisit = false;
            cd.PreferencesPasswordRequired = false;
            cd.PreferencesNotifyRndtnComplete = false;
            
            insert cd;
            
            // Query the ContentDistribution to get the public URLs
            cd = [SELECT Id, ContentDownloadUrl, DistributionPublicUrl, PdfDownloadUrl 
                  FROM ContentDistribution WHERE Id = :cd.Id LIMIT 1];
            
            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'publicUrl' => cd.DistributionPublicUrl,
                'downloadUrl' => cd.ContentDownloadUrl,
                'pdfUrl' => cd.PdfDownloadUrl
            });
            
        } catch (Exception e) {
            res.statusCode = 500;
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage()
            });
        }
    }
}