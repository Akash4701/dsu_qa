/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 10-23-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@RestResource(urlMapping='/feedback/*')
global with sharing class FeedbackServiceRestApi {
    private static final String URL_BASE = '/feedback/';
    
    @HttpGet
    global static void doGet() {
        String requestURI = RestContext.request.requestURI;
        requestURI = requestURI.replace(URL_BASE, '');
        String[] urlParts = requestURI.split('/');
        
        if (urlParts.size() < 1) {
            RestApiUtility.addError(RestApiUtility.HTTP_NOT_FOUND, RestApiUtility.ERROR_URL_INVALID);
            
            return;
        }
        
        RestRequest req = RestContext.request;
        Map<String, String> paramsMap = RestContext.request.params;
        String contactId = paramsMap.get('contactid');
        
        List<Feedback_Item__c> feedbackItems = [
			SELECT
				Id,
				Course_Offering__c,
				Course_Offering__r.Name,
				Course_Offering__r.hed__Section_ID__c,
				Course_Offering__r.hed__Course__r.Name,
				Course_Offering__r.hed__Course__r.hed__Course_ID__c,
				Course_Offering__r.hed__Faculty__r.Name,
				Course_Offering__r.hed__Term__r.Program_Plan__r.Name,
				Course_Offering__r.hed__Term__r.Name,
				End_Date__c,
				Feedback_Status__c,
				Start_Date__c,
				Feedback_Scheduler__r.Term__r.Name,
				Feedback_Scheduler__r.Term__r.Program_Plan__r.Name,
				Feedback_Scheduler__r.Feedback_Master__r.Feedback_Type__c
			FROM Feedback_Item__c
			WHERE Assignee__c = :contactId AND End_Date__c >= TODAY
		];
        
        Map<String, List<Object>> feedbackByType = new Map<String, List<Object>>();
        
        for (Feedback_Item__c fi : feedbackItems) {
            String feedbackType = fi.Feedback_Scheduler__r.Feedback_Master__r.Feedback_Type__c;
            
            if (feedbackType == null)
                continue;
            
            if (!feedbackByType.containsKey(feedbackType)) {
                feedbackByType.put(feedbackType, new List<Object>());
            }
            
            if (
                feedbackType == ConstantsControllerClass.OrientationFeedback ||
                feedbackType == ConstantsControllerClass.GraduationFeedback ||
                feedbackType == ConstantsControllerClass.EndTermFeedback ||
                feedbackType == ConstantsControllerClass.EventAndWorkshopFeedback
            ) {
                FeedBackScheduleWrapper wrapper = new FeedBackScheduleWrapper();
                wrapper.recordId = fi.Id;
                wrapper.termId = fi.Feedback_Scheduler__r.Term__c;
                wrapper.intake = fi.Feedback_Scheduler__r.Term__r.Program_Plan__r.Name;
                wrapper.termName = fi.Feedback_Scheduler__r.Term__r.Name;
                wrapper.dueDate = fi.End_Date__c;
                wrapper.startDate = fi.Start_Date__c;
                wrapper.Status = fi.Feedback_Status__c == 'Completed'
                    ? 'Submitted'
                    : fi.Feedback_Status__c;
                
                feedbackByType.get(feedbackType).add(wrapper);
            } else if (feedbackType == ConstantsControllerClass.FacultyFeedback) {
                CourseFeedBackScheduleWrapper wrapper = new CourseFeedBackScheduleWrapper();
                wrapper.recordId = fi.Id;
                wrapper.intake = fi.Course_Offering__r.hed__Term__r.Program_Plan__r.Name;
                wrapper.section = fi.Course_Offering__r.hed__Section_ID__c;
                wrapper.termName = fi.Course_Offering__r.hed__Term__r.Name;
                wrapper.courseId = fi.Course_Offering__r.hed__Course__c;
                wrapper.courseName = fi.Course_Offering__r.hed__Course__r.Name;
                wrapper.courseCode = fi.Course_Offering__r.hed__Course__r.hed__Course_ID__c;
                wrapper.startDate = fi.Start_Date__c;
                wrapper.dueDate = fi.End_Date__c;
                wrapper.Status = fi.Feedback_Status__c == 'Completed'
                    ? 'Submitted'
                    : fi.Feedback_Status__c;
                
                feedbackByType.get(feedbackType).add(wrapper);
            } else {
                CourseFeedBackScheduleWrapper wrapper = new CourseFeedBackScheduleWrapper();
                wrapper.recordId = fi.Id;
                wrapper.intake = fi.Course_Offering__c != null
                    ? fi.Course_Offering__r.hed__Term__r.Program_Plan__r.Name
                    : fi.Feedback_Scheduler__r.Term__r.Program_Plan__r.Name;
                wrapper.termName = fi.Course_Offering__c != null
                    ? fi.Course_Offering__r.hed__Term__r.Name
                    : fi.Feedback_Scheduler__r.Term__r.Name;
                wrapper.facultyName = fi.Course_Offering__r.hed__Faculty__r.Name;
                wrapper.courseId = fi.Course_Offering__r.hed__Course__c;
                wrapper.courseName = fi.Course_Offering__r.hed__Course__r.Name;
                wrapper.courseCode = fi.Course_Offering__r.hed__Course__r.hed__Course_ID__c;
                wrapper.startDate = fi.Start_Date__c;
                wrapper.dueDate = fi.End_Date__c;
                wrapper.Status = fi.Feedback_Status__c == 'Completed'
                    ? 'Submitted'
                    : fi.Feedback_Status__c;
                
                feedbackByType.get(feedbackType).add(wrapper);
            }
        }
        
        RestApiUtility.createSuccessGetResponse(feedbackByType);
    }
    
    public class FeedBackScheduleWrapper {
        public String recordId { get; set; }
        public String intake { get; set; }
        public String termId { get; set; }
        public String termName { get; set; }
        public Date dueDate { get; set; }
        public Date startDate { get; set; }
        public String Status { get; set; }
    }
    
    public class CourseFeedBackScheduleWrapper {
        public String recordId { get; set; }
        public String intake { get; set; }
        public String termName { get; set; }
        public String courseId { get; set; }
        public String courseName { get; set; }
        public String courseCode { get; set; }
        public String section { get; set; }
        public String facultyName { get; set; }
        public Date startDate { get; set; }
        public Date dueDate { get; set; }
        public string Status { get; set; }
    }
}