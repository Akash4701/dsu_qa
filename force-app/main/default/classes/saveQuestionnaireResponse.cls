@RestResource(urlMapping='/saveQuestionnaire/*')
global with sharing class saveQuestionnaireResponse {
    private static final String URL_BASE ='/saveQuestionnaire/';
    @httpGet
    global static void doGet(){
        RestRequest req = RestContext.request;
        String requestURI = req.requestURI.replace(URL_BASE,'');
        String[] urlParts = requestURI.split('/');
        
        if(urlParts.size() < 1){
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST,RestApiUtility.ERROR_URL_INVALID);
            return;
        }
        
        if(urlParts[0] == 'getCaseDetails'){
            retrieveCaseDetails();
        }
    }
    
    @HttpPost
    global static QuestionnairePostResponse saveQuestionnaire() {
        RestRequest req = RestContext.request;
        QuestionnairePostResponse response = new QuestionnairePostResponse();
        
        try {
            String jsonBody = req.requestBody.toString();
            QuestionnairePostRequest requestPayload = (QuestionnairePostRequest) JSON.deserialize(jsonBody, QuestionnairePostRequest.class);
            String serviceRecordTypeID = Schema.getGlobalDescribe().get('Case').getDescribe().getRecordTypeInfosByName().get('Service').getRecordTypeId();
            
            requestPayload.caseRecord.recordTypeId = serviceRecordTypeID;
            
            fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new Schema.SObjectType[] {
                Case.SObjectType,
                    Alm_Questionnaire_Parameter_Response__c.SObjectType,
                    ContentVersion.sObjectType,
                    ContentDistribution.sObjectType
                    });
            
            uow.registerNew(requestPayload.caseRecord);
            List<Alm_Questionnaire_Parameter_Response__c> fileUploadResponses = new List<Alm_Questionnaire_Parameter_Response__c>();
            for (QuestionnairePostRequestWrapper wrapper : requestPayload.response) {
                for (Alm_Questionnaire_Parameter_Response__c paramResponse : wrapper.response) {
                    paramResponse.Response_Category__c = 'Case';
                    if (wrapper.fileType != null && wrapper.fileType.toLowerCase() == 'pdf') {
                        if(paramResponse.Response__c != null) {
                            Blob fileBlob = EncodingUtil.base64Decode(paramResponse.Response__c);
                            paramResponse.Response__c = null;
                            uow.registerNew(paramResponse, Alm_Questionnaire_Parameter_Response__c.Case__c,requestPayload.caseRecord);
                            
                            ContentVersion cv = new ContentVersion();
                            cv.Title = 'Questionnaire Response File';
                            cv.PathOnClient = 'ResponseFile.pdf' ;
                            cv.VersionData = fileBlob;
                            uow.registerNew(cv, ContentVersion.FirstPublishLocationId,paramResponse);
                            
                            ContentDistribution cd = new ContentDistribution();
                            cd.Name = 'Questionnaire File Response';
                            cd.PreferencesNotifyOnVisit = false;
                            cd.PreferencesAllowOriginalDownload = true;

                            uow.registerNew(cd,ContentDistribution.ContentVersionId,cv);
                            
                            fileUploadResponses.add(paramResponse);
                        }
                    }
                    else {
                        paramResponse.Case__c = requestPayload.caseRecord?.Id;
                        uow.registerNew(paramResponse,Alm_Questionnaire_Parameter_Response__c.Case__c,requestPayload.caseRecord);
                    }
                }
            }
            
            uow.commitWork();
            
            updateParamResponsesWithFileUrl(fileUploadResponses);
            
            response.success = true;
            response.message = 'Response created successfully';
            
        } catch (Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
        }
        
        return response;
    }
    
    @TestVisible
    private static void updateParamResponsesWithFileUrl(List<Alm_Questionnaire_Parameter_Response__c> responses){
        if(responses == null || responses.isEmpty()) {
            return;
        }
        
        // Get the IDs of the parameter responses
        Set<Id> responseIds = new Set<Id>();
        for(Alm_Questionnaire_Parameter_Response__c response : responses) {
            if(response.Id != null) {
                responseIds.add(response.Id);
            }
        }
        
        if(responseIds.isEmpty()) {
            return;
        }
        
        // Query ContentVersions linked to these parameter responses
        List<ContentVersion> contentVersions = [
            SELECT Id, FirstPublishLocationId, ContentDocumentId
            FROM ContentVersion 
            WHERE FirstPublishLocationId IN :responseIds
            AND IsLatest = true
        ];
        
        if(contentVersions.isEmpty()) {
            return;
        }
        
        // Get ContentVersion IDs to find their ContentDistributions
        Set<Id> contentVersionIds = new Set<Id>();
        Map<Id, Id> cvToResponseMap = new Map<Id, Id>(); // ContentVersionId -> ResponseId
        
        for(ContentVersion cv : contentVersions) {
            contentVersionIds.add(cv.Id);
            cvToResponseMap.put(cv.Id, cv.FirstPublishLocationId);
        }
        
        // Query ContentDistributions for these ContentVersions
        List<ContentDistribution> distributions = [
            SELECT Id, ContentVersionId, DistributionPublicUrl,contentDownloadUrl
            FROM ContentDistribution 
            WHERE ContentVersionId IN :contentVersionIds
        ];
        
        if(distributions.isEmpty()) {
            return;
        }
        
        // Create map of ResponseId -> Distribution URL
        Map<Id, String> responseToUrlMap = new Map<Id, String>();
        for(ContentDistribution cd : distributions) {
            Id responseId = cvToResponseMap.get(cd.ContentVersionId);
            if(responseId != null) {
                responseToUrlMap.put(responseId, cd.DistributionPublicUrl);
            }
        }
        
        List<Alm_Questionnaire_Parameter_Response__c> responsesToUpdate = new List<Alm_Questionnaire_Parameter_Response__c>();
        for(Alm_Questionnaire_Parameter_Response__c response : responses) {
            if(response.Id != null && responseToUrlMap.containsKey(response.Id)) {
                response.Response__c = responseToUrlMap.get(response.Id);
                responsesToUpdate.add(response);
            }
        }
        
        // Update the records
        if(!responsesToUpdate.isEmpty()) {
            try {
                update responsesToUpdate;
            } catch(DmlException e) {
                System.debug('Error updating parameter responses with file URLs: ' + e.getMessage());
            }
        }
    }
    
    @TestVisible
    private static void retrieveCaseDetails(){
        Restrequest req = RestContext.request;
        Map<String,String> paramsMap = req.params;
        String caseId = paramsMap.get('caseId');
        
        if(String.isBlank(caseId)){
            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST, 'Missing caseId.');
            return;
        }
        
        caseDetailsWrapper response = new caseDetailsWrapper();
        
        response.paramresponses = [Select Id, Case__c, Questionnaire_Parameter__c,Questionnaire_Parameter__r.Question_Label__c,Response__c from Alm_Questionnaire_Parameter_Response__c where Case__c != null AND Case__c = :caseId];
        RestApiUtility.createSuccessGetResponse(response);
    }
    
    global class QuestionnairePostRequest {
        public Case caseRecord;
        public List<QuestionnairePostRequestWrapper> response;
    }
    
    global class QuestionnairePostRequestWrapper {
        public String fileType;
        public List<Alm_Questionnaire_Parameter_Response__c> response;
    }
    
    global class QuestionnairePostResponse {
        public Boolean success;
        public String message;
    }
    
    global class caseDetailsWrapper{
        public List<Alm_Questionnaire_Parameter_Response__c> paramresponses;
    }
    
}