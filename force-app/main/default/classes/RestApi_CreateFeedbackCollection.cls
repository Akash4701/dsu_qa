// Explicitly without sharing: the integration user submits a student's answers on the student's behalf and must
// be able to write them regardless of record sharing. Access is gated by the Feedback_Integration_Access permission set.
@RestResource(urlMapping='/createFeedbackCollection')
global without sharing class RestApi_CreateFeedbackCollection {
    @HttpPost
    global static void doCreateFeedbackCollection(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
        try{
            responseCreateFeedbackCollectionWrapper responseAll=new responseCreateFeedbackCollectionWrapper();
            List<responseCreateFeedbackCollectionDataWrapper> responseList=new List<responseCreateFeedbackCollectionDataWrapper>();
            List<requestCreateFeedbackCollectionDataWrapper> requestList = (List<requestCreateFeedbackCollectionDataWrapper>) JSON.deserialize(RestContext.request.requestBody.toString(),List<requestCreateFeedbackCollectionDataWrapper>.class); 
            string feedbackItemId;
            if(!requestList.isEmpty()){
                List<Collected_Feedback_Data__c> collectionList = new List<Collected_Feedback_Data__c>();
                // One submission time for every answer row, taken on the server. request.feedbackDate is
                // intentionally ignored: the portal sent the form's due date, and Date.valueOf() would
                // drop the time of day anyway.
                Datetime submittedAt = System.now();
                for(requestCreateFeedbackCollectionDataWrapper request:requestList){
                    Collected_Feedback_Data__c collection = new Collected_Feedback_Data__c();
                    collection.Contact__c=request.contactId;
                    collection.Term__c=request.termId;
                    String resolvedRecordType = resolveCollectedFeedbackRecordTypeName(request.recordType);
                    Id matchedRecordTypeId = recordTypeIdsByName().get(resolvedRecordType);
                    if (matchedRecordTypeId == null) {
                        throw new RestApi_CreateFeedbackCollectionException(
                            'No Record Type named \'' + resolvedRecordType + '\' exists on Collected_Feedback_Data__c.'
                        );
                    }
                    collection.recordTypeId=matchedRecordTypeId;
                    collection.Feedback_Master__c=request.feedbackMasterId;
                    collection.Feedback_Master_Child__c=request.feedbackMasterChildId;
                    collection.Question__c=request.parameter;
                    collection.Answer__c=request.answer;
                    collection.Course_Name__c=request.courseId;
                    collection.Feedback_Item__c = request.feedbackItemId;
                    feedbackItemId = request.feedbackItemId;
                    if(request.courseOfferingId!=null){
                        collection.Course_Offering__c=request.courseOfferingId;
                    }
                    collection.Faculty__c=request.facultyId;
                    collection.Rating__c=request.rating;
                    // Submission time from the server, not the request (the portal sent the form's due date).
                    collection.Feedback_DateTime__c = submittedAt;
                    collectionList.add(collection);
                }
                
                if(!collectionList.isEmpty())
                {
                    try{
                        Database.UpsertResult[] myResult = Database.upsert(collectionList, false);
                        Boolean anySuccess = false;
                        // Results are positional: result i belongs to collectionList[i].
                        for (Integer i = 0; i < myResult.size(); i++) {
                            Database.UpsertResult s = myResult[i];
                            responseCreateFeedbackCollectionDataWrapper response = new responseCreateFeedbackCollectionDataWrapper();
                            if (s.isSuccess()) {
                                anySuccess = true;
                                response.collectionFeedbackId = s.getId();
                                response.success = 'true';
                                response.message = 'Data is Inserted';
                            } else {
                                List<String> errorTexts = new List<String>();
                                for (Database.Error err : s.getErrors()) {
                                    errorTexts.add(err.getStatusCode() + ': ' + err.getMessage());
                                }
                                response.collectionFeedbackId = collectionList[i].Id;
                                response.success = 'false';
                                response.message = 'Data is Failed';
                                response.errors = String.join(errorTexts, '; ');
                            }
                            res.statusCode = 200;
                            responseList.add(response);
                        }
                        // One status update for the whole submission, not one DML statement per answer row
                        // (a long form would otherwise exceed the 150 DML statement limit).
                        if (anySuccess && String.isNotBlank(feedbackItemId)) {
                            update new Feedback_Item__c(Id = feedbackItemId, Feedback_Status__c = 'Submitted');
                        }
                    }
                    Catch(Exception e){
                        responseCreateFeedbackCollectionDataWrapper response=new responseCreateFeedbackCollectionDataWrapper();
                        res.statusCode = 400;
                        response.success='false';
                        response.message='bad request';
                        response.errors=e.getMessage()+'at Line Number'+e.getLineNumber();
                        responseList.add(response);
                    }
                }
                
                responseAll.CollectionFeedback=responseList;
            	jsonResponse=json.serialize(responseAll);
            	res.responseBody=Blob.valueOf(jsonResponse);
            }
            res.statusCode=200;   
        }catch(exception e){
            res.statusCode=400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }

    // Read from RecordType itself, not Schema describe: getRecordTypeInfosByName() only lists record types
    // the RUNNING user can see, so an integration user missing the permission-set assignment gets a false
    // "does not exist". Active record types only; looked up once per transaction.
    private static Map<String, Id> recordTypeIdsCache;
    private static Map<String, Id> recordTypeIdsByName() {
        if (recordTypeIdsCache == null) {
            recordTypeIdsCache = new Map<String, Id>();
            for (RecordType rt : [SELECT Id, Name FROM RecordType
                                  WHERE SobjectType = 'Collected_Feedback_Data__c' AND IsActive = true]) {
                recordTypeIdsCache.put(rt.Name, rt.Id);
            }
        }
        return recordTypeIdsCache;
    }

    // Director/Assistant Dean/Deputy Director Feedback don't have their own Record Type on
    // Collected_Feedback_Data__c - they're treated as the same "leadership feedback" family as
    // Dean Feedback (see FeedbackSchedulerTriggerHandler, which already buckets all four types
    // together), so they submit under the existing Dean Feedback Record Type.
    private static String resolveCollectedFeedbackRecordTypeName(String recordTypeName) {
        if (recordTypeName == ConstantsControllerClass.DIRECTORFEEDBACK ||
            recordTypeName == ConstantsControllerClass.ASSISTANTDEANFEEDBACK ||
            recordTypeName == ConstantsControllerClass.DEPUTYDIRECTORFEEDBACK) {
            return ConstantsControllerClass.DEANFEEDBACK;
        }
        return recordTypeName;
    }

    global class requestCreateFeedbackCollectionDataWrapper {
        public String contactId {get;set;}
        public String programId {get;set;}
        public String recordType {get;set;}
        public String termId {get;set;}
        public string feedbackMasterId {get;set;}
        public string feedbackMasterChildId {get;set;}
        public String courseId {get;set;}
        public String courseOfferingId {get;set;}
        public String facultyId {get;set;}
        // Kept so existing callers still deserialize; no longer used (Feedback_DateTime__c is set server-side).
        public string feedbackDate {get;set;}
        public String parameter {get;set;}
        public String answer {get;set;}
        public String rating {get;set;}
        public String feedbackItemId {get;set;}
    }
    
    public class responseCreateFeedbackCollectionWrapper {
        public List<responseCreateFeedbackCollectionDataWrapper> CollectionFeedback {get;set;}
    }
    
    public class responseCreateFeedbackCollectionDataWrapper {
        public string success='true';
        public string message='Data is Added';
        public string errors {get;set;}
        public string collectionFeedbackId {get;set;}
    }

    public class RestApi_CreateFeedbackCollectionException extends Exception {}
}