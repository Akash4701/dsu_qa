@RestResource(urlMapping='/TermsAndCourseVersions/*')
global class RestApi_GetTerm_CourseVersion {
	@HttpGet
	global static void doGet() {
		RestResponse res = RestContext.response;
		res.addHeader('Content-Type', 'application/json');
		String programPlanId = RestContext.request.params.get('programPlanId');

		try {
			if (String.isNotBlank(programPlanId)) {
				List<hed__Term__c> termsList = new List<hed__Term__c>(
					[
						SELECT
							Id,
							Name,
							hed__Parent_Term__r.Id,
							hed__Parent_Term__r.Name,
							Program_Plan__c,
							hed__Start_Date__c,
							hed__End_Date__c,
							Term_Duration__c,
							Campus__c,
							Campus__r.Name,
							Program_Plan__r.Working_Days__c,
							Program_Plan__r.Intake__c,
							Program_Plan__r.Batch__c,
							Program_Plan__r.hed__Account__r.Course_duration__c,
							Program_Plan__r.hed__Account__r.Program_Duration_in_Weeks__c,
							(
								SELECT
									Id,
									Name,
									Course__c,
									Start_Date__c,
									End_Date__c,
									Course_Credits__c,
									Course__r.Name,
									Course__r.Id,
									Facilities__r.Name,
									Facilities__r.Id,
									Course__r.hed__Course_ID__c,
                                	Course__r.hed__Credit_Hours__c,
									Faculties__c,
									StartDate__c,
									Subject_Start_Date__c,
									Subject_End_Date__c,
									Term__r.Program_Plan__r.Working_Days__c,
									Term__r.Term_Duration__c,
									Term__r.Program_Plan__r.Intake__c,
									Term__r.Program_Plan__r.Batch__c,
									Term__r.Program_Plan__r.hed__Account__r.Course_duration__c,
									Term__r.Program_Plan__r.hed__Account__r.Program_Duration_in_Weeks__c,
									WeekNo__c,
									Term__r.hed__Start_Date__c,
									Term__r.hed__End_Date__c
								FROM Course_Versions__r
								ORDER BY Start_Date__c ASC
							),
							(
								SELECT Id, Pre_Requisites_1__c, Pre_Requisites_2__c, Pre_Requisites_3__c, hed__Course__c
								FROM Plan_Requirements__r
							)
						FROM hed__Term__c
						WHERE Program_Plan__c = :programPlanId
					]
				);

				List<termsWrapper> trmWrapList = new List<termsWrapper>();
				for (hed__Term__c termObj : termsList) {
					Map<String, List<String>> preRequisiteCourseIdsByCourseId = new Map<String, List<String>>();

					for (hed__Plan_Requirement__c p : termObj.Plan_Requirements__r) {
						if (!preRequisiteCourseIdsByCourseId.containsKey(p.hed__Course__c)) {
							preRequisiteCourseIdsByCourseId.put(p.hed__Course__c, new List<Id>());
						} /*else {*/
							if (p.Pre_Requisites_1__c != null) {
								preRequisiteCourseIdsByCourseId.get(p.hed__Course__c).add(p.Pre_Requisites_1__c);
							}
							if (p.Pre_Requisites_2__c != null) {
								preRequisiteCourseIdsByCourseId.get(p.hed__Course__c).add(p.Pre_Requisites_2__c);
							}
							if (p.Pre_Requisites_3__c != null) {
								preRequisiteCourseIdsByCourseId.get(p.hed__Course__c).add(p.Pre_Requisites_3__c);
							}
						//}
					}
					system.debug('preRequisiteCourseIdsByCourseId'+preRequisiteCourseIdsByCourseId);
					termsWrapper termWrapObj = new termsWrapper();
					termWrapObj.masterTermId = termObj.hed__Parent_Term__r.Id;
					termWrapObj.masterTermName = termObj.hed__Parent_Term__r.Name;
					termWrapObj.termId = termObj.Id;
					termWrapObj.termName = termObj.Name;
					termWrapObj.termStartDate = termObj.hed__Start_Date__c;
					termWrapObj.termEndDate = termObj.hed__End_Date__c;
					termWrapObj.termDuration = termObj.Term_Duration__c;
					termWrapObj.campusId = termObj.Campus__c;
					termWrapObj.campusName = termObj.Campus__r.Name;
					termWrapObj.batch = termObj.Program_Plan__r.Batch__c;
					termWrapObj.intake = termObj.Program_Plan__r.Intake__c;
					termWrapObj.programDuration = termObj.Program_Plan__r.hed__Account__r.Program_Duration_in_Weeks__c;
					termWrapObj.workingDays = termObj.Program_Plan__r.Working_Days__c;
					List<courseVersionWrapper> couVerWrapList = new List<courseVersionWrapper>();
					for (Course_Version__c cvObj : termObj.Course_Versions__r) {
						courseVersionWrapper cvWrapObj = new courseVersionWrapper();
						cvWrapObj.courseVersionId = cvObj.Id;
						cvWrapObj.courseVersionName = cvObj.Name;
						cvWrapObj.preRequisiteCourseIds = preRequisiteCourseIdsByCourseId.containsKey(cvObj.Course__c)
							? String.join(preRequisiteCourseIdsByCourseId.get(cvObj.Course__c), ',')
							: '';
						cvWrapObj.startDate = cvObj.Start_Date__c;
						cvWrapObj.endDate = cvObj.Subject_End_Date__c;
						cvWrapObj.courseRecordId = cvObj.Course__c;
						cvWrapObj.courseId = cvObj.Course__r.hed__Course_ID__c;
						cvWrapObj.courseName = cvObj.Course__r.Name;
						cvWrapObj.credits = cvObj.Course_Credits__c;
                        cvWrapObj.creditHours = cvObj.Course__r.hed__Credit_Hours__c;
						cvWrapObj.workingDays = cvObj.Term__r.Program_Plan__r.Working_Days__c;
						cvWrapObj.termDuration = cvObj.Term__r.Term_Duration__c;
						cvWrapObj.batch = cvObj.Term__r.Program_Plan__r.Batch__c;
						cvWrapObj.intake = cvObj.Term__r.Program_Plan__r.Intake__c;
						cvWrapObj.programDuration = cvObj.Term__r.Program_Plan__r.hed__Account__r.Program_Duration_in_Weeks__c;
						cvWrapObj.weekNo = cvObj.WeekNo__c;
						cvWrapObj.facility = cvObj.Facilities__r.Name;
						cvWrapObj.facilityId = cvObj.Facilities__r.Id;
						cvWrapObj.termStartDate = cvObj.Term__r.hed__Start_Date__c;
						cvWrapObj.termEndDate = cvObj.Term__r.hed__End_Date__c;

						List<facultyWrapper> facultyWrapList = new List<facultyWrapper>();
						if (!string.isEmpty(cvObj.Faculties__c)) {
							List<String> ListOfFaculties = cvObj.Faculties__c.split(',');
							for (string facultyRecord : ListOfFaculties) {
								facultyWrapper facWrapperObj = new facultyWrapper();
								facWrapperObj.facultyName = facultyRecord.substringBefore('-');
								facWrapperObj.facultyId = facultyRecord.substringAfter('-');
								facultyWrapList.add(facWrapperObj);
							}
						}

						List<hed__Course_Offering__c> courseOfferings = [
							SELECT Id, Name, hed__Section_ID__c, hed__Start_Date__c, hed__End_Date__c, hed__Faculty__r.Name, Course_Version__c
							FROM hed__Course_Offering__c
							WHERE Course_Version__c = :cvObj.Id
						];

						List<CourseOfferingWrapper> courseOfferingWrappersList = new List<CourseOfferingWrapper>();
						for (hed__Course_Offering__c courseOffering : courseOfferings) {
							CourseOfferingWrapper courseOfferingWrapper = new CourseOfferingWrapper();
							courseOfferingWrapper.courseOfferingId = courseOffering.Name;
							courseOfferingWrapper.sectionId = courseOffering.hed__Section_ID__c;
							courseOfferingWrapper.startDate = courseOffering.hed__Start_Date__c;
							courseOfferingWrapper.endDate = courseOffering.hed__End_Date__c;
                            courseOfferingWrapper.faculty = courseOffering.hed__Faculty__r.Name;
							courseOfferingWrappersList.add(courseOfferingWrapper);
						}
						cvWrapObj.courseOffering = courseOfferingWrappersList;
						cvWrapObj.facultyList = facultyWrapList;

						couVerWrapList.add(cvWrapObj);
					}

					termWrapObj.courseVersion = couVerWrapList;
					trmWrapList.add(termWrapObj);
				}
				system.debug('The res' + trmWrapList);
				if (!trmWrapList.isEmpty()) {
					res.statusCode = 200;
					res.responseBody = Blob.valueOf('{ "success": "true" ,"data":' + json.serialize(trmWrapList) + '}');
				} else {
					res.statusCode = 200;
					res.responseBody = Blob.valueOf('{ "success": "true" ,"data": [] }');
				}
			} else {
				res.statusCode = 400;
				res.responseBody = Blob.valueOf('{ "success": "false" ,"message": "No data found"}');
			}
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

	global class jsonWrapper {
		public List<termsWrapper> terms;
	}
	global class termsWrapper {
		public Id masterTermId;
		public string masterTermName;
		public Id termId;
		public string termName;
		public Date termStartDate { get; set; }
		public Date termEndDate { get; set; }
		public String termDuration;
		public string campusId { get; set; }
		public string campusName { get; set; }
		public string batch { get; set; }
		public string intake { get; set; }
		public Decimal programDuration { get; set; }
		public string workingDays { get; set; }
		public List<courseVersionWrapper> courseVersion;
	}
	global class courseVersionWrapper {
		public Id courseVersionId;
		public string courseVersionName;
		public string preRequisiteCourseIds;
		public Date startDate;
		public Date endDate;
		public Id courseRecordId;
		public string courseId;
		public string courseName;
		public Decimal credits;
        public Decimal creditHours;
		public String termDuration;
		public string workingDays { get; set; }
		public string batch { get; set; }
		public string intake { get; set; }
		public Decimal programDuration { get; set; }
		public String weekNo { get; set; }
		public List<facultyWrapper> facultyList;
		public string facility;
		public Id facilityId;
		public Date termStartDate { get; set; }
		public Date termEndDate { get; set; }
		public List<courseversionFacultyWrapper> courseVersionFaculty;
		public list<CourseOfferingWrapper> courseOffering;
	}
	global class facultyWrapper {
		public string facultyId;
		public string facultyName;
	}
	global class courseversionFacultyWrapper {
		public string recordId;
		public string facultyId;
		public string facultyName;
	}
	global class CourseOfferingWrapper {
		public string courseOfferingId;
		public string sectionId;
		public Date startDate;
		public Date endDate;
        public string faculty;
	}

        
}