/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 10-17-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
@RestResource(urlMapping='/FeedBackData/*')
global with sharing class RestApi_GetMasterFeedBacks {
	@HttpGet
	global static void doGetMasterFeedBackData() {
		String feedbackItemId = RestContext.request.params.get('feedbackItemId');
		String contactId = RestContext.request.params.get('contactId');

		RestResponse res = RestContext.response;
		res.addHeader('Content-Type', 'application/json');
		string jsonResponse;

		try {
			List<Collected_Feedback_Data__c> collFeedBackSetupList = new List<Collected_Feedback_Data__c>();
			List<Questionnaire_Metadata__c> parSectionList = new List<Questionnaire_Metadata__c>();
			Map<Id, Collected_Feedback_Data__c> collFeedBackSetupMap = new Map<Id, Collected_Feedback_Data__c>();

			Feedback_Item__c item = [
				SELECT
					Feedback_Scheduler__r.Feedback_Master__c,
					Feedback_Scheduler__r.Term__c,
					Course_Offering__r.hed__Section_ID__c,
					Feedback_Scheduler__r.Term__r.Name
				FROM Feedback_Item__c
				WHERE Id = :feedbackItemId WITH SECURITY_ENFORCED
			];

			parSectionList = [
				SELECT
					Id,
					Feedback_Type__c,
					Face_to_Face_and_Online__c,
					Academic__c,
					Program__c,
					(
						SELECT
							Id,
							Section_Label__c,
							Label__c,
							Max_Grade__c,
							Question_Label__c,
							Question_Type__c,
							Answers__c,
							Mandatory__c,
							Order__c,
							Type__c,
                        	Active__c
						FROM Question_Metadata__r
						WHERE RecordType.Name = 'Feedback' and Active__c = true
						ORDER BY Order__c ASC
					)
				FROM Questionnaire_Metadata__c
				WHERE Id = :item.Feedback_Scheduler__r.Feedback_Master__c
				WITH SECURITY_ENFORCED
				ORDER BY Order__c ASC
			];

			collFeedBackSetupList = [
				SELECT
					Id,
					Term__c,
					Contact__c,
					Feedback_Master__c,
					Feedback_Master__r.Feedback_Type__c,
					Faculty__c,
					Course_Name__c,
					Feedback_Master_Child__c,
					Feedback_DateTime__c,
					Rating__c,
					Parameter__c,
					Answer__c
				FROM Collected_Feedback_Data__c
				WHERE Contact__c = :contactId AND Feedback_Item__c = :feedbackItemId
				WITH SECURITY_ENFORCED
			];

			if (!collFeedBackSetupList.isEmpty()) {
				for (Collected_Feedback_Data__c coll : collFeedBackSetupList) {
					collFeedBackSetupMap.put(coll.Feedback_Master_Child__c, coll);
				}
			}

			if (!parSectionList.isEmpty()) {
				List<responseMasterFeedBackWrapper> responseFeedBack = new List<responseMasterFeedBackWrapper>();

				for (Questionnaire_Metadata__c parSec : parSectionList) {
					responseMasterFeedBackWrapper responseFeedBackParameterSec = new responseMasterFeedBackWrapper();
					responseFeedBackParameterSec.contactId = contactId;
					responseFeedBackParameterSec.termId = item.Feedback_Scheduler__r.Term__c;
					responseFeedBackParameterSec.termName = item.Feedback_Scheduler__r.Term__r.Name;
					responseFeedBackParameterSec.courseOfferingId = item.Course_Offering__c;
					responseFeedBackParameterSec.masterFeedBackId = item.Feedback_Scheduler__r.Feedback_Master__c;
					responseFeedBackParameterSec.parameterSectionId = parSec.Id;
					responseFeedBackParameterSec.programId = parSec.Program__c;
					responseFeedBackParameterSec.feedbackType = parSec.Feedback_Type__c;
					responseFeedBackParameterSec.onlineFandF = parSec.Face_to_Face_and_Online__c;
					responseFeedBackParameterSec.academic = parSec.Academic__c;

					if (!parSec.Question_Metadata__r.isEmpty()) {
						List<responseMasterFeedBackDataWrapper> responseFeedBackParameterList = new List<responseMasterFeedBackDataWrapper>();
						for (Question_Metadata__c parameter : parSec.Question_Metadata__r) {
							responseMasterFeedBackDataWrapper responseFeedBackParameter = new responseMasterFeedBackDataWrapper();
							responseFeedBackParameter.parameterId = parameter.Id;
							responseFeedBackParameter.sectionLabel = parameter.Section_Label__c;
							responseFeedBackParameter.maxGrade = parameter.Max_Grade__c;
							responseFeedBackParameter.questionLabel = parameter.Question_Label__c;
                            responseFeedBackParameter.isActive = parameter.Active__c;
							responseFeedBackParameter.questionType = parameter.Question_Type__c;
							responseFeedBackParameter.sublabel = parameter.Label__c;
							if (
								parameter.Question_Type__c == 'Multiple Option Rating' ||
								parameter.Question_Type__c == 'Multiple Choice' ||
								parameter.Question_Type__c == 'Likert Scale'
							) {
								// Choices are stored semicolon-separated in Answers__c; blank/stray entries are dropped.
								List<String> allAnswer = new List<String>();
								for (String choice : (parameter.Answers__c == null ? '' : parameter.Answers__c).split(';')) {
									if (String.isNotBlank(choice)) {
										allAnswer.add(choice.trim());
									}
								}
								if (!allAnswer.isEmpty()) {
									List<responseAnswerWrapper> responseAnswerList = new List<responseAnswerWrapper>();
									for (String ans : allAnswer) {
										responseAnswerWrapper responseAnswer = new responseAnswerWrapper();
										responseAnswer.label = ans;
										if (
											parameter.Question_Type__c == 'Multiple Option Rating'
										) {
											responseAnswer.value = '0';
										} else if (parameter.Question_Type__c == 'Likert Scale') {
											// Scale point (1 = first choice) so the consumer can score the selection.
											responseAnswer.value = String.valueOf(responseAnswerList.size() + 1);
										} else {
											responseAnswer.value = 'true';
										}
										responseAnswerList.add(responseAnswer);
									}
									responseFeedBackParameter.answer = JSON.serialize(
										responseAnswerList
									);
								}
							} else {
								responseFeedBackParameter.answer = parameter.Answers__c;
							}
							responseFeedBackParameter.mandatory = parameter.Mandatory__c;
							responseFeedBackParameter.order = parameter.Order__c;
							responseFeedBackParameter.typeName = parameter.Type__c;
							system.debug(collFeedBackSetupMap);
							if (
								!collFeedBackSetupMap.isEmpty() &&
								collFeedBackSetupMap.keyset().contains(parameter.Id)
							) {
								responseMasterFeedBackCollectionDataWrapper collection = new responseMasterFeedBackCollectionDataWrapper();
								Collected_Feedback_Data__c collData = collFeedBackSetupMap.get(
									parameter.Id
								);
								collection.termId = collData.Term__c;
								collection.courseId = collData.Course_Name__c;
								collection.facultyId = collData.Faculty__c;
								collection.feedbackDate = collData.Feedback_DateTime__c;
								collection.parameter = collData.Parameter__c;
								collection.rating = collData.Rating__c;
								collection.answer = collData.Answer__c;
								responseFeedBackParameter.feedbackCollection = collection;
							}
							responseFeedBackParameterList.add(responseFeedBackParameter);
						}
						responseFeedBackParameterSec.feeedbackOption = responseFeedBackParameterList;
					}

					responseFeedBack.add(responseFeedBackParameterSec);
				}

				jsonResponse = JSON.serialize(responseFeedBack);
				if (jsonResponse != null) {
					res.responseBody = Blob.valueOf(jsonResponse);
				} else {
					res.responseBody = Blob.valueOf('[]');
				}
			} else {
				res.responseBody = Blob.valueOf(
					'{ "success": "true" , "message": "No Data Found"}'
				);
			}

			res.statusCode = 200;
		} catch (Exception e) {
			res.statusCode = 400;
			res.responseBody = Blob.valueOf(
				'{ "success": "false" , "message": "bad request", "errors": "' +
				e.getMessage() +
				'at Line Number' +
				e.getLineNumber() +
				'" }'
			);
		}
	}

	public class responseAnswerWrapper {
		public String label { get; set; }
		public String value { get; set; }
	}

	public class responseMasterFeedBackWrapper {
		public String contactId { get; set; }
		public String termId { get; set; }
		public String termName { get; set; }
		public String courseOfferingId { get; set; }
		public String masterFeedBackId { get; set; }
		public String parameterSectionId { get; set; }
		public String programId { get; set; }
		public String programName = 'GMBA'; //{get;set;}
		public String feedbackType { get; set; }
		public string onlineFandF { get; set; }
		public string academic = 'GMBA'; //{get;set;}
		public List<responseMasterFeedBackDataWrapper> feeedbackOption { get; set; }
	}

	public class responseMasterFeedBackDataWrapper {
		public String parameterId { get; set; }
		public String sublabel { get; set; }
		public String sectionLabel { get; set; }
		public decimal maxGrade { get; set; }
		public String questionLabel { get; set; }
		public String questionType { get; set; }
        public Boolean isActive {get;set;}
		public String answer { get; set; }
		public boolean mandatory { get; set; }
		public decimal order { get; set; }
		public String typeName { get; set; }
		public responseMasterFeedBackCollectionDataWrapper feedbackCollection { get; set; }
	}

	public class responseMasterFeedBackCollectionDataWrapper {
		public String termId { get; set; }
		public String courseId { get; set; }
		public String facultyId { get; set; }
		public DateTime feedbackDate { get; set; }
		public String parameter { get; set; }
		public String rating { get; set; }
		public String answer { get; set; }
	}
}