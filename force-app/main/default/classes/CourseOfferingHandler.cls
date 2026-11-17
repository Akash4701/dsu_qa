public class CourseOfferingHandler extends TriggerHandler {
	public static Integer count = 0;
	public override void processAfterInsert() {
        //createBBCourses(Trigger.new);
        //createEvaluationPlan();
		// gradeSchemeUpdate(Trigger.new);
	}
    
     
    
         @future(callout=true)
    public static void sendCourseOfferings(List<Id> offeringIds) {
        List<hed__Course_Offering__c> offerings = [
            SELECT Id, Name, hed__Course__r.LMS_ID__c
            FROM hed__Course_Offering__c
            WHERE Id IN :offeringIds
        ];
        LMS_URL__c bulkEnroll = [SELECT Bulk_Enroll__c FROM LMS_URL__c WHERE Name = 'course offering url' LIMIT 1];
        Http http = new Http();
        for (hed__Course_Offering__c offering : offerings) {
            CourseOfferingCalloutWrapper wrapper = new CourseOfferingCalloutWrapper(offering.Name, offering.Id, offering.hed__Course__r.LMS_ID__c);
            HttpRequest request = new HttpRequest();
            request.setEndpoint(bulkEnroll.Bulk_Enroll__c);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(wrapper));
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                if (respMap.containsKey('data')) {
                    Map<String, Object> data = (Map<String, Object>) respMap.get('data');
                    String identifier = (String) data.get('Identifier');
                    hed__Course_Offering__c updateOffering = [
                        SELECT Id, LMS_Id__c
                        FROM hed__Course_Offering__c
                        WHERE Id = :offering.Id
                        LIMIT 1
                    ];
                    if (updateOffering.LMS_Id__c != identifier) {
                        updateOffering.LMS_Id__c = identifier;
                        update updateOffering;
                    }
                }
            }
        }
    }




	public override void processAfterUpdate() {
		/*if (count == 0) {
			gradeSchemeUpdate(Trigger.new);
		}*/
        
        //updateBBCourse(Trigger.new);
		//syncCourseSubomponent(Trigger.new);
	}

	/*public override void processBeforeUpdate() {
		if (count < 2) {
			gradeSchemeRemoved(Trigger.new);
			populateLetterGradeSetting((hed__Course_Offering__c) Trigger.new[0]);
		}
	}
    
    public override void processBeforeDelete(){
       // deleteBBCourses(Trigger.old);
    }*/

	/*public static void syncCourseSubomponent(List<hed__Course_Offering__c> courseOfferingList) {
		List<hed__Course_Offering__c> updateCourseOffering = new List<hed__Course_Offering__c>();
		for (hed__Course_Offering__c eachCourseOffering : courseOfferingList) {
			if (
				eachCourseOffering.Grade_Book_Status__c !=
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Book_Status__c && eachCourseOffering.Grade_Book_Status__c == 'Received'
			) {
				createBBActivityBatchClass bcn = new createBBActivityBatchClass( eachCourseOffering.Id ) ;
				ID batchprocessid = Database.executeBatch(bcn,1);
			}
		}
	}*/
    
    /*private static void deleteBBCourses(List<hed__Course_Offering__c> courseOffering){
        List<String> courseIds = new List<String>();
        
        for(hed__Course_Offering__c eachCourseOffering : courseOffering){
            if(String.isNotBlank(eachCourseOffering.BB_Id__c))
                courseIds.add(eachCourseOffering.BB_Id__c);
        }
        if(!courseIds.isEmpty()){
          DeleteBBCourseBatch bcn = new DeleteBBCourseBatch( courseIds ) ;
          ID batchprocessid = Database.executeBatch(bcn,1);
        }
    }
    
    private static void updateBBCourse(List<hed__Course_Offering__c> courseOffering ){
        Set<Id> courseOfferingIds = new Set<Id>();
        
        for(hed__Course_Offering__c eachCourseOffering : courseOffering){
            if((eachCourseOffering.Name != null && eachCourseOffering.hed__Start_Date__c != null  && eachCourseOffering.hed__End_Date__c != null) 
				&& ( ( eachCourseOffering.hed__Start_Date__c !=
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).hed__Start_Date__c)
                    || ( eachCourseOffering.hed__End_Date__c !=
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).hed__End_Date__c)
                    || ( eachCourseOffering.Name !=
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Name) ) ){
                                        courseOfferingIds.add(eachCourseOffering.Id);

                    }
            
        }
        if(!courseOfferingIds.isEmpty()){
          UpdateBBCourseBatch bcn = new UpdateBBCourseBatch( courseOfferingIds ) ;
          ID batchprocessid = Database.executeBatch(bcn,1);
        }
        
    }
    
    public static void createBBCourses(List<hed__Course_Offering__c> courseOfferings){
        Set<Id> courseOfferingIds = new Set<Id>();
        
        for(hed__Course_Offering__c eachCourseOffering : courseOfferings){
            courseOfferingIds.add(eachCourseOffering.Id);
        }
        
        if(!courseOfferingIds.isEmpty()){
          CreateBBCourseBatchClass bcn = new CreateBBCourseBatchClass( courseOfferingIds ) ;
          ID batchprocessid = Database.executeBatch(bcn,1);
        }
    }*/


	/*private static void gradeSchemeRemoved(List<hed__Course_Offering__c> courseOfferingList) {
		List<hed__Course_Offering__c> updateCourseOffering = new List<hed__Course_Offering__c>();
		for (hed__Course_Offering__c eachCourseOffering : courseOfferingList) {
			if (
				eachCourseOffering.Grade_Scheme__c != null ||
				eachCourseOffering.Grade_Scheme__c ==
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme__c
			)
				continue;
			eachCourseOffering.Letter_Grade_Setting__c = null;
		}
	}
    

	public static void gradeSchemeUpdate(List<hed__Course_Offering__c> courseOffering) {
		List<hed__Course_Offering__c> courseLevelCourseOffering = new List<hed__Course_Offering__c>();
		Set<Id> termIds = new Set<Id>();
		Set<Id> courseIds = new Set<Id>();
		List<hed__Course_Offering__c> relatedCourseOfferingToUpdate = new List<hed__Course_Offering__c>();
		Map<Id, Id> gradeSchemeIdByCourseOffering = new Map<Id, Id>();

		for (hed__Course_Offering__c eachCourseOffering : courseOffering) {
			if (
				(eachCourseOffering.Grade_Scheme__c ==
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme__c) ||
				((((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme__c == null ||
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme_RecordType_Name__c ==
				'Course_Section') && eachCourseOffering.Grade_Scheme_RecordType_Name__c == 'Course_Section') ||
				(((hed__Course_Offering__c)Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme_RecordType_Name__c ==
				'Course_Section' && eachCourseOffering.Grade_Scheme__c == null)
			)
				continue;

			if (eachCourseOffering.Grade_Scheme_RecordType_Name__c == 'Course') {
				gradeSchemeIdByCourseOffering.put(eachCourseOffering.Id, eachCourseOffering.Grade_Scheme__c);
			} else if (
				eachCourseOffering.Grade_Scheme__c == null ||
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme_RecordType_Name__c ==
				'Course'
			) {
				gradeSchemeIdByCourseOffering.put(eachCourseOffering.Id, null);
			}
			courseLevelCourseOffering.add(eachCourseOffering);
			termIds.add(eachCourseOffering.hed__Term__c);
			courseIds.add(eachCourseOffering.hed__Course__c);
		}

		List<hed__Course_Offering__c> relatedCourseOffering = [
			SELECT Id, hed__Term__c, hed__Course__c, Grade_Scheme__c
			FROM hed__Course_Offering__c
			WHERE hed__Course__c IN :courseIds AND hed__Term__c IN :termIds AND Id NOT IN :courseLevelCourseOffering
		];

		for (hed__Course_Offering__c eachCourseOffering : courseLevelCourseOffering) {
			for (hed__Course_Offering__c eachRelatedCourseOffering : relatedCourseOffering) {
				if (
					eachCourseOffering.Grade_Scheme__c != eachRelatedCourseOffering.Grade_Scheme__c &&
					eachCourseOffering.hed__Term__c == eachRelatedCourseOffering.hed__Term__c &&
					eachCourseOffering.hed__Course__c == eachRelatedCourseOffering.hed__Course__c
				) {

					eachRelatedCourseOffering.Grade_Scheme__c = gradeSchemeIdByCourseOffering.get(
						eachCourseOffering.Id
					);
					relatedCourseOfferingToUpdate.add(eachRelatedCourseOffering);
				}
			}
		}

		if (!relatedCourseOfferingToUpdate.isEmpty()) {
			count++;
			update relatedCourseOfferingToUpdate;
		}
	}

	public void populateLetterGradeSetting(hed__Course_Offering__c courseOffering) {
		String mechanismType;
		Set<Id> courseOfferingIds = new Set<Id>{ courseOffering.Id };

		if(courseOffering.Grade_Scheme__c == ((hed__Course_Offering__c)Trigger.oldMap.get(courseOffering.Id)).Grade_Scheme__c)
			return;

		if (courseOffering.Grade_Scheme_RecordType_Name__c == 'Course') {
			courseOfferingIds.addAll(
				new Map<Id, hed__Course_Offering__c>(
						[
							SELECT Id
							FROM hed__Course_Offering__c
							WHERE
								hed__Term__c = :courseOffering.hed__Term__c
								AND hed__Course__c = :courseOffering.hed__Course__c
						]
					)
					.keySet()
			);
		}

		List<Grade_Scheme_Critera__c> criterias = [
			SELECT Id, Range_From__c, Range_To__c, Mechanism_Type__c
			FROM Grade_Scheme_Critera__c
			WHERE Grade_Scheme__c = :courseOffering.Grade_Scheme__c
		];
		List<hed__Course_Enrollment__c> courseConnectionRecords = [
			SELECT Id
			FROM hed__Course_Enrollment__c
			WHERE hed__Course_Offering__c = :courseOfferingIds AND RecordType.DeveloperName = 'Student'
		];

		Integer studentStrength = courseConnectionRecords.size();
		for (Grade_Scheme_Critera__c eachGradeSchemeCriteria : criterias) {
			if (
				studentStrength < eachGradeSchemeCriteria.Range_From__c ||
				studentStrength > eachGradeSchemeCriteria.Range_To__c
			)
				continue;
			mechanismType = eachGradeSchemeCriteria.Mechanism_Type__c;
		}

		if (String.isBlank(mechanismType))
			return;

		List<Letter_Grade_Setting__c> settings = [
			SELECT Id
			FROM Letter_Grade_Setting__c
			WHERE RecordType.DeveloperName = 'Master' AND Mechanism__c = :mechanismType AND Is_Active__c = TRUE
		];

		if (settings.isEmpty())
			return;

		courseOffering.Letter_Grade_Setting__c = settings[0].Id;
	}*/
    @TestVisible
    private static void createEvaluationPlan(){
        List<Course_Evaluation_Component__c > newEvaluationPlans = new List<Course_Evaluation_Component__c >();

        // Map to store Course Ids and their associated Evaluation Plans
        Map<Id, List<sobject>> courseToEvaluationPlanMap = new Map<Id, List<sobject>>();

        // Collect all Course Ids from new Course Offering records
        Set<Id> courseIds = new Set<Id>();
        for (hed__Course_Offering__c co : (List<hed__Course_Offering__c>)trigger.new) {
            courseIds.add(co.hed__Course__c);
        }

        // Query related Courses with their Evaluation Plans
        for (hed__Course__c course : [SELECT Id, (SELECT Id, Name, Component_Name__c,Weightage__c,Maximum_Marks__c,Exam_Required__c FROM Master_Evaluation_Components__r) FROM hed__Course__c WHERE Id IN :courseIds]) {
            if (course.Master_Evaluation_Components__r != null && !course.Master_Evaluation_Components__r.isEmpty()) {
                for( Evaluation_Component_Master__c masterEvaluationPlan : course.Master_Evaluation_Components__r){
                    
                    if (courseToEvaluationPlanMap.containsKey(course.Id)) {
                        courseToEvaluationPlanMap.get(course.Id).add(masterEvaluationPlan);
                        } else {
                            courseToEvaluationPlanMap.put(course.Id,new List<Evaluation_Component_Master__c>{ masterEvaluationPlan });
                        }
                }
                
            }
        }

        // Create Evaluation Plan records for each Course Offering
        for (hed__Course_Offering__c co : (List<hed__Course_Offering__c>)trigger.new) {
            if (courseToEvaluationPlanMap.containsKey(co.hed__Course__c)) {
                List<Evaluation_Component_Master__c> masterEvaluation = courseToEvaluationPlanMap.get(co.hed__Course__c);

                // Create a new Evaluation Plan record for the Course Offering
                for(Evaluation_Component_Master__c masterEval : masterEvaluation){
                Course_Evaluation_Component__c newEvaluationPlan = new Course_Evaluation_Component__c(
                    Course_Offering__c = co.Id,
                    Name = masterEval.Component_Name__c ,
                    Weightage__c = masterEval.Weightage__c ,
                    Maximum_Marks_for_the_Component__c = masterEval.Maximum_Marks__c ,
                    Exam_Required__c = masterEval.Exam_Required__c
                    
                );

                newEvaluationPlans.add(newEvaluationPlan);
                }
            }
        }

        // Insert all new Evaluation Plan records
        if (!newEvaluationPlans.isEmpty()) {
            insert newEvaluationPlans;
        }
    }
       
}