/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 05-08-2024
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@RestResource(urlMapping='/createCourseVersionsAndActivites/*')
global class RestApi_CreateTerms_CV_Activites {
	@HttpPost
	global static void doPost() {
		RestResponse res = RestContext.response;
		string jsonResponse = '';
		try {
            //request
			List<requestCourseVersionDataWrapper> request = (List<requestCourseVersionDataWrapper>) JSON.deserialize(
				RestContext.request.requestBody.toString(),
				List<requestCourseVersionDataWrapper>.class
			);
			List<Course_Version__c> courseVerList = new List<Course_Version__c>();
			List<Activity__c> activityList = new List<Activity__c>();
			Set<Id> courseIds = new Set<Id>();
			Id termId;
			//collecting courseIds
			for (requestCourseVersionDataWrapper reqCourseWrapObj : request) {
				for (courseWrapper courseWrapObj : reqCourseWrapObj.courseList) {
					courseIds.add(courseWrapObj.courseId);
				}
			}
            //checking whether all courses have credit hours  
			List<hed__Course__c> courses = [
				SELECT Id
				FROM hed__Course__c
				WHERE Id = :courseIds AND hed__Credit_Hours__c = NULL
			];
            //if any course doesn't have credit hours throwing an error 
			if (!courses.isEmpty()) {
				res.statusCode = 400;
				res.responseBody = Blob.valueOf('{ "success": "false", "message": "credit hours are missing" }');
				return;
			}
			Map<String, List<activitesWrapper>> mapOfReqCVandActivites = new Map<String, List<activitesWrapper>>();
			for (requestCourseVersionDataWrapper reqCursVerWrapObj : request) {
				if (!validatePlanRequirement(reqCursVerWrapObj.courseList, reqCursVerWrapObj.termId)) {
					res.statusCode = 400;
					res.responseBody = Blob.valueOf(
						'{ "success": "false", "message": "Unable to continue as prerequisites are not met" }'
					);
					return;
				}
				termId = reqCursVerWrapObj.termId;
				hed__Term__c[] previousTermsWithCourses = [
					SELECT Id, Name, hed__Account__c, Program_Plan__c, hed__Start_Date__c, hed__End_Date__c
					FROM hed__Term__c
					WHERE Id = :reqCursVerWrapObj.termId AND RecordType.Name = 'Default Record'
					LIMIT 1
				];
                List<String> termIds = new List<String>();
                List<String> getCourseIds = new List<String>();
                for(courseWrapper reqCourseWrapObj : reqCursVerWrapObj.courseList) {
                    termIds.add(reqCursVerWrapObj.termId);
                    getCourseIds.add(reqCourseWrapObj.courseId);
                }
                List<Course_Version__c> courseVersion = [SELECT Id, Name,Term__c,Course__c, Course__r.hed__Course_ID__c  FROM Course_Version__c WHERE Term__c IN :termIds AND Course__c IN : getCourseIds ];
                if(!courseVersion.isEmpty()){
                    /*List<String> courseCodes = new List<String>();
                    for(Course_Version__c cv : courseVersion){
                        courseCodes.add(cv.Course__r.hed__Course_ID__c);
                    }*/
                    res.statusCode = 400;
					res.responseBody = Blob.valueOf(
						'{ "success": "false", "message": "Duplicate records found." }'
					);
					return;
                }
				if(!validateDuplicateRecordsFromPrevTerms(termIds, getCourseIds)){
					res.statusCode = 400;
				res.responseBody = Blob.valueOf(
					'{ "success": "false" , "message": "Duplicate Record Found."}'
				);
				return;
				}
				for (courseWrapper reqCourseWrapObj : reqCursVerWrapObj.courseList) {
					Course_Version__c courseVerObj = new Course_Version__c();

					courseVerObj.Term__c = reqCursVerWrapObj.termId;
					courseVerObj.Course__c = reqCourseWrapObj.courseId;
					courseVerObj.End_Date__c = reqCourseWrapObj.endDate;
					courseVerObj.Exam_Required__c = false; //reqCourseWrapObj.examRequired;
					courseVerObj.Number_of_Sessions__c = reqCourseWrapObj.numberOfSessions;
                    //courseVerObj.Subject_Offset__c = Decimal.valueOf(reqCourseWrapObj.subjectOffset);
                    courseVerObj.Credit_hours__c = reqCourseWrapObj.creditHours;
					if (String.isBlank(reqCourseWrapObj.subjectOffset)) {
                        
						courseVerObj.Start_Date__c = previousTermsWithCourses[0].hed__Start_Date__c;
					} else {
                        courseVerObj.Subject_Offset__c = Decimal.valueOf(reqCourseWrapObj.subjectOffset);
						courseVerObj.Start_Date__c = reqCourseWrapObj.startDate; //+ Integer.valueOf(reqCourseWrapObj.subjectOffset);
					}
					courseVerObj.Subject_End_Date__c = previousTermsWithCourses[0].hed__End_Date__c;
					courseVerList.add(courseVerObj);
					mapOfReqCVandActivites.put(
						reqCursVerWrapObj.termId +
						'_' +
						reqCourseWrapObj.courseId,
						reqCourseWrapObj.activitesList
					);
				}
			}
			if (!courseVerList.isEmpty()) {
				insert courseVerList;
				List<Course_Version__c> cvList = [
					SELECT
						Id,
						Name,
						Term__c,
						Term__r.Name,
						Term__r.hed__End_Date__c,
						Course__c,
						Start_Date__c,
						Term__r.Program_Plan__r.Working_Days__c
					FROM Course_Version__c
					WHERE Id IN :courseVerList
				];
				Map<String, Course_Version__c> mapOfCVandIds = new Map<String, Course_Version__c>();
				for (Course_Version__c cvObj : cvList) {
					mapOfCVandIds.put(cvObj.Term__c + '_' + cvObj.Course__c, cvObj);
				}
				system.debug(termId);
				system.debug('keysetofIds===>' + mapOfCVandIds.keySet());
				K42_Academic_Planner__c[] academicPlanner = [
					SELECT Id
					FROM K42_Academic_Planner__c
					WHERE Term__c = :termId
				];
				system.debug('keysetofIds===>' + mapOfCVandIds.keySet());
				for (String str : mapOfCVandIds.keySet()) {
					Id courseVersionid = mapOfCVandIds.get(str).Id;
					Date stDate = mapOfCVandIds.get(str).Start_Date__c;
					if (!mapOfReqCVandActivites.get(str).isEmpty()) {
						for (activitesWrapper activityWrapObj : mapOfReqCVandActivites.get(str)) {
							Activity__c activityObj = new Activity__c();

							activityObj.Academic_Planner__c = academicPlanner.isEmpty() ? null : academicPlanner[0].Id;
							activityObj.Subject__c = courseVersionid;
							activityObj.Name = mapOfCVandIds.get(str).Term__r.Name + '-' + 'Activity';
							activityObj.Activity_type__c = activityWrapObj.activityType;
							activityObj.Number_of_Sessions__c = activityWrapObj.numberOfSessions;
							activityObj.Start_date__c = activityWrapObj.startDate;
							List<String> wrkDaysList = mapOfCVandIds.get(str).Term__r.Program_Plan__r.Working_Days__c !=
								null
								? mapOfCVandIds.get(str).Term__r.Program_Plan__r.Working_Days__c.split(';')
								: null;
							if (activityWrapObj.endDate != null) {
								activityObj.End_date__c = activityWrapObj.endDate;
							} else if (mapOfCVandIds.get(str).Term__r.hed__End_Date__c != null) {
								activityObj.End_date__c = mapOfCVandIds.get(str).Term__r.hed__End_Date__c;
							} else {
								activityObj.End_date__c = stDate + 14;
							}
							//activityObj.End_date__c = ActivityHandler.returnSubjectEndDate(activityWrapObj.startDate, Decimal.valueOf(activityWrapObj.activityDuration), holidaysSet, wrkDaysList);

							activityObj.Activity_Duration__c = String.isBlank(activityWrapObj.activityDuration)
								? 1
								: Decimal.valueOf(activityWrapObj.activityDuration);
							activityObj.Offset__c = String.isBlank(activityWrapObj.activityOffset)
								? 0
								: Integer.valueOf(activityWrapObj.activityOffset);
							activityObj.RecordTypeId = Schema.SObjectType.Activity__c.getRecordTypeInfosByName()
								.get('Default')
								.getRecordTypeId();
							if (!academicPlanner.isEmpty()) {
								activityObj.Academic_Planner__c = academicPlanner[0].Id;
							}

							activityList.add(activityObj);
						}
					} else {
						Activity__c activityObj = new Activity__c();

						activityObj.Academic_Planner__c = academicPlanner.isEmpty() ? null : academicPlanner[0].Id;
						activityObj.Subject__c = courseVersionid;
						activityObj.Name = mapOfCVandIds.get(str).Term__r.Name + '-' + 'Activity';
						activityObj.Activity_type__c = 'Teaching';
						activityObj.Start_date__c = stDate;
						activityObj.End_date__c = mapOfCVandIds.get(str).Term__r.hed__End_Date__c;
						activityObj.Activity_Duration__c = 1;
						activityObj.Offset__c = 0;
						activityObj.Number_of_Sessions__c = 0;
						activityObj.RecordTypeId = Schema.SObjectType.Activity__c.getRecordTypeInfosByName()
							.get('Default')
							.getRecordTypeId();
						if (!academicPlanner.isEmpty()) {
							activityObj.Academic_Planner__c = academicPlanner[0].Id;
						}

						activityList.add(activityObj);
					}
				}
				if (!activityList.isEmpty()) {
					insert activityList;
				}
			}

			res.statusCode = 200;
			res.responseBody = Blob.valueOf('{ "success": "true" , "message":"Data created"}');
		} catch (Exception e) {
			system.debug(e.getMessage() + 'at Line Number' + e.getLineNumber());
			if (
				e.getMessage() ==
				'Insert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, You are Unable to create this record because, with the Same Details already Record Existed..: []'
			) {
				res.statusCode = 409;
				res.responseBody = Blob.valueOf(
					'{ "success": "false" , "message": "You are Unable to create the record because, with the Same Details already Record Existed" }'
				);
			} else {
				res.statusCode = 400;
				system.debug(e.getMessage() + 'at Line Number' + e.getLineNumber());
				res.responseBody = Blob.valueOf(
					'{ "success": "false" , "message": "bad request", "errors": "' +
					e.getMessage() +
					'at Line Number' +
					e.getLineNumber() +
					'" }'
				);
			}
		}
	}

	private static Boolean validatePlanRequirement(List<courseWrapper> courseList, Id termId) {
		Set<Id> masterPlanReqIds = new Set<Id>();
		set<Id> allCourseIds = new Set<Id>();
		map<Id, courseWrapper> courseWrapByCourseId = new map<Id, courseWrapper>();
		for (courseWrapper courseWrap : courseList) {
			masterPlanReqIds.add(courseWrap.masterPlanReqId);
			allCourseIds.add(courseWrap.courseId);
            courseWrapByCourseId.put(courseWrap.courseId,courseWrap);
		}

		List<hed__Plan_Requirement__c> planRequirements = [
			SELECT Id, Pre_Requisites_1__c, Pre_Requisites_2__c, Pre_Requisites_3__c, Term__r.Term_Reference__c
			FROM hed__Plan_Requirement__c
			WHERE
				Id IN :masterPlanReqIds
				AND (Pre_Requisites_1__c != NULL
				OR Pre_Requisites_2__c != NULL
				OR Pre_Requisites_3__c != NULL)
		];

		if (planRequirements.isEmpty())
			return true;

		set<Id> allPreRequisiteIds = new Set<Id>();

		for (hed__Plan_Requirement__c planReq : planRequirements) {
			Set<Id> prerequisiteIds = new Set<Id>();
			if (planReq.Pre_Requisites_1__c != null) {
				prerequisiteIds.add(planReq.Pre_Requisites_1__c);
			}
			if (planReq.Pre_Requisites_2__c != null) {
				prerequisiteIds.add(planReq.Pre_Requisites_2__c);
			}
			if (planReq.Pre_Requisites_3__c != null) {
				prerequisiteIds.add(planReq.Pre_Requisites_3__c);
			}

			allPreRequisiteIds.addall(prerequisiteIds);
		}
		System.debug('All Preq'+allPreRequisiteIds);

		set<Id> filteredPreRequisiteId = new Set<Id>();
        
        for (Id preRequisiteId : allPreRequisiteIds) {
        boolean isPrerequisiteMet = false;
        
            for (Id courseId : allCourseIds) {
                if (preRequisiteId.equals(courseId)) {
                    // Found a matching course ID in the current course IDs
                    CourseWrapper prereqCourse = courseWrapByCourseId.get(preRequisiteId);
                    CourseWrapper currentCourse = courseWrapByCourseId.get(courseId);
                    
                    if (prereqCourse != null && currentCourse != null) {
                        // Check if the end date of the prerequisite course is after the start date of the current course
                        if (prereqCourse.endDate > currentCourse.startDate) {
                            // Prerequisite is not met if the end date of the prerequisite course is after the start date of the current course
                            isPrerequisiteMet = false;
                            break; // No need to check further if one course fails the prerequisite condition
                        } else {
                            // Prerequisite is met
                            isPrerequisiteMet = true;
                        }
                    }
                }
            }
        
            if (!isPrerequisiteMet) {
                // Add the prerequisite ID to the filtered set if the prerequisite condition is not met
                filteredPreRequisiteId.add(preRequisiteId);
            }
    	}
		/*for (Id preRequisiteId : allPreRequisiteIds) {
            for(Id courseId : allCourseIds){
                if(preRequisiteId == courseId){
                    CourseWrapper prereqCourse = courseWrapByCourseId.get(preRequisiteId);
            		CourseWrapper currentCourse = courseWrapByCourseId.get(courseId);
                    if(courseWrapByCourseId.get(preRequisiteId).endDate > courseWrapByCourseId.get(courseId).startDate){
                        return false;
                    }
                }else{
                    filteredPreRequisiteId.add(preRequisiteId);
                }
			}
            
			//if (!allCourseIds.contains(preRequisiteId)) {
			//	filteredPreRequisiteId.add(preRequisiteId);
           // }else{
                //courseWrapByCourseId.get(preRequisiteId).endDate > 
            //}
		}*/
		List<Course_Version__c> courseVersions = [SELECT Id, Name, Term__c,Course__c FROM Course_Version__c WHERE Course__c IN:filteredPreRequisiteId AND Term__c =:termId ];
		if(!courseVersions.isEmpty()){
			return true;
		}
		System.debug('All filtered Preq'+filteredPreRequisiteId);

		if(!filteredPreRequisiteId.isEmpty() && planRequirements[0].Term__r.Term_Reference__c == 'Term 1') {
			return false;
		}

		if(filteredPreRequisiteId.isEmpty()){
			return true;
		} 
		else{
			return ValidateCoursesFromPreviousTerm(termId, filteredPreRequisiteId);
		}

	}
   /* private static Boolean ValidateCoursesFromPreviousTerm(Id termId, Set<Id> filteredPreRequisiteId) {
    // Step 1: Get the list of Term_Campus_Relationship__c records for the specified term.
    List<Term_Campus_Relationship__c> termRelations = [
        SELECT Id, Program_Campus_Combination__c, Term__r.Term_Reference__c, Program_Campus_Combination__r.Campus__c
        FROM Term_Campus_Relationship__c
        WHERE Term__c = :termId
    ];
    
    // Determine the program campus combination IDs and their associated campuses.
    Map<String, Set<Id>> pccsByCampus = new Map<String, Set<Id>>();
    for (Term_Campus_Relationship__c tcr : termRelations) {
        String campus = tcr.Program_Campus_Combination__r.Campus__c;
        if (!pccsByCampus.containsKey(campus)) {
            pccsByCampus.put(campus, new Set<Id>());
        }
        pccsByCampus.get(campus).add(tcr.Program_Campus_Combination__c);
    }
    
    // Step 2: Retrieve previous term relations for each campus.
    Map<String, Set<Id>> previousTermsByCampus = new Map<String, Set<Id>>();
    for (String campus : pccsByCampus.keySet()) {
        Set<Id> pccIds = pccsByCampus.get(campus);
        
        // Retrieve previous term relations for the campus.
        List<Term_Campus_Relationship__c> previousTermRelations = [
            SELECT Id, Program_Campus_Combination__c, Term__c, Term__r.Term_Reference__c
            FROM Term_Campus_Relationship__c
            WHERE Program_Campus_Combination__c IN :pccIds
            AND Term__r.Term_Reference__c < :termRelations[0].Term__r.Term_Reference__c
        ];
        
        if (previousTermRelations.isEmpty()) {
            continue;  // Skip to next iteration if no previous terms found.
        }
        
        // Collect previous term IDs for the campus.
        Set<Id> termIds = new Set<Id>();
        for (Term_Campus_Relationship__c tcr : previousTermRelations) {
            termIds.add(tcr.Term__c);
        }
        
        // Store the previous term IDs for the campus.
        previousTermsByCampus.put(campus, termIds);
    }
    system.debug('previousTermsByCampus-->'+previousTermsByCampus.keySet());
    // Step 3: Retrieve courses from the previous terms for each campus.
    Map<String, Set<Id>> coursesByCampus = new Map<String, Set<Id>>();
    for (String campus : previousTermsByCampus.keySet()) {
        Set<Id> termIds = previousTermsByCampus.get(campus);
        
        // Fetch courses for the terms under this campus.
        List<hed__Term__c> terms = [
            SELECT Id, Name, (SELECT Id, Name, Course__c FROM Course_Versions__r)
            FROM hed__Term__c
            WHERE Id IN :termIds
        ];
        
        // Collect courses from terms.
        Set<Id> courseIds = new Set<Id>();
        for (hed__Term__c term : terms) {
            system.debug(term.Name);
            system.debug('termIds'+term.Id);
            for (Course_Version__c cv : term.Course_Versions__r) {
                system.debug('cv.Course__c==>'+cv.Course__c);
                courseIds.add(cv.Course__c);
            }
        }
        
        // Store courses for the campus.
        coursesByCampus.put(campus, courseIds);
    }
        system.debug('coursesByCampus==>'+coursesByCampus);
    	system.debug('filteredPreRequisiteId-->'+filteredPreRequisiteId);
    // Step 4: Check if prerequisites are met across all required campuses.
    // Ensure prerequisites are met in all campus combinations required for the new term.
    for (Set<Id> courseIds : coursesByCampus.values()) {
        if (!courseIds.containsAll(filteredPreRequisiteId)) {
            // If any campus does not satisfy all prerequisites, return false.
            return false;
        }
    }
    
    // If all required campuses satisfy all prerequisites, return true.
    return true;
}*/


    
	//commented code for testing
	private static Boolean ValidateCoursesFromPreviousTerm(Id termId, set<Id> filteredPreRequisiteId) {
		Set<Id> pccIds = new Set<Id>();

		List<Term_Campus_Relationship__c> termRelations = [
			SELECT Id, Program_Campus_Combination__c, Term__r.Term_Reference__c
			FROM Term_Campus_Relationship__c
			WHERE Term__c = :termId
		];

        for(Term_Campus_Relationship__c t : termRelations) {
            pccIds.add(t.Program_Campus_Combination__c);
        }

		List<Term_Campus_Relationship__c> previousTermRelations = [
			SELECT Id, Program_Campus_Combination__c, Term__c, Term__r.Term_Reference__c,Campus__r.Name
			FROM Term_Campus_Relationship__c
			WHERE
				Program_Campus_Combination__c IN :pccIds
				AND Term__r.Term_Reference__c < :termRelations[0].Term__r.Term_Reference__c
		];
        
        Map<Id, Set<Id>> termsByPcc = new Map<Id, Set<Id>>();

        for (Term_Campus_Relationship__c tcr : previousTermRelations) {
			if (!termsByPcc.containsKey(tcr.Program_Campus_Combination__c)) {
				termsByPcc.put(tcr.Program_Campus_Combination__c, new Set<Id>());
			}

			termsByPcc.get(tcr.Program_Campus_Combination__c).add(tcr.Term__c);
		}

		if (previousTermRelations.isEmpty())
			return true;

		Set<Id> previousTermIds = new Set<Id>();
		for (Term_Campus_Relationship__c tcr2 : previousTermRelations) {
			previousTermIds.add(tcr2.Term__c);
		}

		List<hed__Term__c> previousTermsWithCourses = [
			SELECT Id, Name, (SELECT Id, Name,Campus__c, Course__c FROM Course_Versions__r)
			FROM hed__Term__c
			WHERE Id IN :previousTermIds
		];

		Map<Id, Set<Id>> courseIdsByTerm = new Map<Id, Set<Id>>();
		for(hed__Term__c term : previousTermsWithCourses) {
			Set<Id> courseIds = new Set<Id>();
			for(Course_Version__c course : term.Course_Versions__r) {
				courseIds.add(course.Course__c);
                System.debug('logss courseIds '+courseIds);
			}

			courseIdsByTerm.put(term.Id, courseIds);
		}
        
        System.debug('logss courseIdsByTerm '+courseIdsByTerm);

        boolean isFound = true;
        for (Id pccId : termsByPcc.keySet()) {
            isFound = true;
            Set<Id> courseIds = new Set<Id>();
			for(Id tId : termsByPcc.get(pccId)){
                System.debug('logss termId '+tId);
            	System.debug('logss courseIdsByTerm.get(termId) '+courseIdsByTerm.get(tId));
                if(courseIdsByTerm.get(tId)!= null)
				courseIds.addAll(courseIdsByTerm.get(tId));
			}
            
            System.debug('logss courseIds '+courseIds);
            System.debug('logss filteredPreRequisiteId '+filteredPreRequisiteId);
            if (!courseIds.containsAll(filteredPreRequisiteId)) {
				isFound = false;
                 break;
            }
        }

		return isFound;
	}

	private static boolean validateDuplicateRecordsFromPrevTerms(List<String> termIds,List<String> getCourseIds){
        Set<Id> pccIds = new Set<Id>();

		List<Term_Campus_Relationship__c> termRelations = [
			SELECT Id, Program_Campus_Combination__c, Term__r.Term_Reference__c,Term__r.Name
			FROM Term_Campus_Relationship__c
			WHERE Term__c IN :termIds
		];

        for(Term_Campus_Relationship__c t : termRelations) {
            pccIds.add(t.Program_Campus_Combination__c);
        }

		List<Term_Campus_Relationship__c> previousTermRelations = [
			SELECT Id, Program_Campus_Combination__c, Term__c, Term__r.Term_Reference__c,Campus__r.Name
			FROM Term_Campus_Relationship__c
			WHERE
				Program_Campus_Combination__c IN :pccIds
				AND Term__r.Term_Reference__c < :termRelations[0].Term__r.Term_Reference__c
		];
        
        if (previousTermRelations.isEmpty())
			return true;

		Set<Id> previousTermIds = new Set<Id>();
		for (Term_Campus_Relationship__c tcr2 : previousTermRelations) {
			previousTermIds.add(tcr2.Term__c);
		}

		List<hed__Term__c> previousTermsWithCourses = [
			SELECT Id, Name, (SELECT Id, Name,Campus__c, Course__c FROM Course_Versions__r)
			FROM hed__Term__c
			WHERE Id IN :previousTermIds
		];
        Set<Id> courseIds = new Set<Id>();
        for(hed__Term__c term : previousTermsWithCourses) {
			for(Course_Version__c course : term.Course_Versions__r) {
				courseIds.add(course.Course__c);
			}
		}

		for(Id courseId : getCourseIds){
			if(!courseIds.isEmpty() && courseIds.contains(courseId)){
				return false;
			}
		}
	
        return true;
    }
   

	//Wrapper class for the request from API
	public class requestCourseVersionDataWrapper {
		public Id termId;
		public List<courseWrapper> courseList;
	}
	public class courseWrapper {
		public Id courseId;
		public Date startDate;
		public Date endDate;
		public Boolean examRequired;
		public string subjectOffset;
		public Decimal numberOfSessions;
        public string creditHours;
		public String masterPlanReqId;
		public List<activitesWrapper> activitesList;
	}
	public class activitesWrapper {
		public string activityName;
		public string activityType;
		public string activityDuration;
		public string activityOffset;
		public Date startDate;
		public Date endDate;
		public Decimal numberOfSessions;
	}
    
}