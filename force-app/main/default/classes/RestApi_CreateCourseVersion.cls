@RestResource(urlMapping='/createCourseVersion')
global class RestApi_CreateCourseVersion {
    
    
    
    @HttpPost
    global static void doCourseVersion(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
        Map<Id,Id> accToContactMap = new Map<Id,Id>();
        try{
            requestCourseVersionWrapper request = (requestCourseVersionWrapper) JSON.deserialize(RestContext.request.requestBody.toString(),requestCourseVersionWrapper.class);
            system.debug('request==>'+request);
            responseCourseVersionWrapper response=new responseCourseVersionWrapper();
            if(request.Operation=='Delete')
            {
                if(String.isNotBlank(request.termId)){
                    List<hed__Course_Offering__c> requestedCourseOfferings = new List<hed__Course_Offering__c>();
                    List<Course_Version__c> requestedCourseVersions = new List<Course_Version__c>();
                    List<Activity__c> requestedActivities = new List<Activity__c>();
                    List<Faculty_Booking__c> requestedFacultyBookings = new List<Faculty_Booking__c>();
                    List<Exam__c> requestedExams = new List<Exam__c>();
                    List<Subject_Activity__c> requestedSubjActivity = new List<Subject_Activity__c>();
                    List<Subject_Planner__c> requestedSubjPlanner = new List<Subject_Planner__c>();
                    List<hed__Plan_Requirement__c> requestedPlanRequirement = new List<hed__Plan_Requirement__c>();
                    
                    List<Course_Version__c> allCourseRealtedDataWithTerm=[Select Id,Name, (Select Id from Course_Offerings__r),(SELECT Id FROM Faculty_Bookings__r),(Select Id from Exams__r),(Select Id from Activities__r),(Select Id from Subject_Activities__r),(Select Id from Subject_Planners__r) from Course_Version__c where Term__c=:request.termId];
                    List<hed__Plan_Requirement__c> allplanRequirement = [Select Id from hed__Plan_Requirement__c Where Term__c=:request.termId AND RecordType.Name = 'Unit'];
  
                    for(Course_Version__c cvObj:allCourseRealtedDataWithTerm){
                        requestedCourseOfferings.addAll(cvObj.Course_Offerings__r);
                        requestedActivities.addAll(cvObj.Activities__r);
                        requestedFacultyBookings.addAll(cvObj.Faculty_Bookings__r);
                        requestedExams.addAll(cvObj.Exams__r);
                        requestedSubjActivity.addAll(cvObj.Subject_Activities__r);
                        requestedSubjPlanner.addAll(cvObj.Subject_Planners__r);
                        requestedCourseVersions.add(cvObj);
                    }
                    for(hed__Plan_Requirement__c eachPlanRequirement :allplanRequirement ){
                        requestedPlanRequirement.add(eachPlanRequirement);
                    }
                    system.debug(requestedCourseOfferings);
                    if(!requestedCourseOfferings.isEmpty())
                        delete [Select Id from hed__Course_Offering__c where Id IN: requestedCourseOfferings];
                    if(!requestedExams.isEmpty())
                        delete [Select Id from Exam__c where Id IN: requestedExams];
                    if(!requestedActivities.isEmpty())
                        delete [Select Id from Activity__c where Id IN: requestedActivities];
                    if(!requestedSubjActivity.isEmpty())
                        delete [Select Id from Subject_Activity__c where Id IN: requestedSubjActivity];
                    if(!requestedSubjPlanner.isEmpty())
                        delete [Select Id from Subject_Planner__c where Id IN: requestedSubjPlanner];
                    if(!requestedFacultyBookings.isEmpty())
                        delete [Select Id from Faculty_Booking__c where Id IN: requestedFacultyBookings];
                    if(!requestedCourseVersions.isEmpty())
                        delete [Select Id from Course_Version__c where Id IN: requestedCourseVersions];
                    if(!requestedPlanRequirement.isEmpty())
                        delete [Select Id from hed__Plan_Requirement__c where Id IN: requestedPlanRequirement];
                    
                    res.statusCode = 200;
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "Data is Deleted"}' );   
                }else{
                    if(!String.isBlank(request.CourseVersion.courseVersionId))
                    { 
                        List<Course_Version__c> allCourseRealtedData=new List<Course_Version__c> ();
                        allCourseRealtedData = [Select Id, (Select Id from Course_Offerings__r),(SELECT Id FROM Faculty_Bookings__r),(Select Id from Exams__r),(Select Id from Activities__r),(Select Id from Subject_Activities__r),(Select Id from Subject_Planners__r) from Course_Version__c where Id=:request.CourseVersion.courseVersionId];
                        if(!allCourseRealtedData.isEmpty())
                        {
                            if(!allCourseRealtedData[0].Course_Offerings__r.isEmpty())
                            {
                                delete allCourseRealtedData[0].Course_Offerings__r;
                            }
                            if(!allCourseRealtedData[0].Exams__r.isEmpty())
                            {
                                delete allCourseRealtedData[0].Exams__r;
                            }
                            if(!allCourseRealtedData[0].Activities__r.isEmpty())
                            {
                                delete allCourseRealtedData[0].Activities__r;
                            }
                            if(!allCourseRealtedData[0].Subject_Activities__r.isEmpty())
                            {
                                delete allCourseRealtedData[0].Subject_Activities__r;
                            }
                            if(!allCourseRealtedData[0].Subject_Planners__r.isEmpty())
                            {
                                delete allCourseRealtedData[0].Subject_Planners__r;
                            }
                            if(!allCourseRealtedData[0].Faculty_Bookings__r.isEmpty())
                            {
                                delete allCourseRealtedData[0].Faculty_Bookings__r;
                            }
                            delete allCourseRealtedData;
                            res.statusCode = 200;
                            res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "Data is Deleted"}' );
                        }
                        else
                        {
                            res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                        }
                    }
                    else 
                    {
                        res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                    }
                }
                
            }
            else
            {
                if(String.isBlank(request.CourseVersion.termName) && String.isBlank(request.CourseVersion.courseId)){
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                    return;
                }
                if(request.Operation == null){
                List<Course_Version__c> CheckExistingcourseV = [SELECT Id, Name, Term__c,Term__r.Name, Course__c FROM Course_Version__c WHERE Term__r.Name = :request.CourseVersion.termName AND Course__c =:request.CourseVersion.courseId];
                if(!CheckExistingcourseV.isEmpty()){
                    res.statusCode = 400;
                     res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Duplicate Record Found."}' );
                    return;
                }
                    //added to check prerequisite
                if (!validatePlanRequirement(request.CourseVersion)) {
					res.statusCode = 400;
					res.responseBody = Blob.valueOf(
						'{ "success": "false", "message": "Unable to continue as prerequisites are not met" }'
					);
					return;
				}
                    if(!validateDuplicateRecordsFromPrevTerms(request.CourseVersion)){
                        res.statusCode = 400;
					res.responseBody = Blob.valueOf(
						'{ "success": "false" , "message": "Duplicate Record Found."}'
					);
					return;
                    }
                }
                
                List<hed__Term__c> termVal=new List<hed__Term__c>([SELECT Id,Name,hed__Account__c,Program_Plan__c,hed__End_Date__c FROM hed__Term__c WHERE Name=:request.CourseVersion.termName AND RecordType.Name = 'Default Record' ]);

                if(termVal.isEmpty() )
                {
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                    return;
                }
                List<Course_Version__c> courseV=new List<Course_Version__c>();
                if(!String.isBlank(request.CourseVersion.courseVersionId))
                {
                    courseV=new List<Course_Version__c>([SELECT Id,Name,(SELECT Id,Booked_By__c FROM Faculty_Bookings__r) FROM Course_Version__c 
                                                         WHERE Id =:request.CourseVersion.courseVersionId]);
                }
                Course_Version__c course=new Course_Version__c();
                if(!courseV.isEmpty())
                {
                    course.Id=courseV[0].Id; 
                    if(!courseV[0].Faculty_Bookings__r.isEmpty())
                    {
                        delete courseV[0].Faculty_Bookings__r;
                    }
                }
                system.debug('termVal[0].Id--->'+termVal[0].Id);
                course.Course__c=request.CourseVersion.courseId;
                course.Term__c=termVal[0].Id; 
                system.debug('request.CourseVersion.startDate===>'+request.CourseVersion.startDate);
                if(!String.isBlank(request.CourseVersion.startDate))
                {
                    String stDate = request.CourseVersion.startDate;
                    course.Start_Date__c=date.parse(stDate);
                }
                if(!String.isBlank(request.CourseVersion.endDate))
                {
                    String edDate = request.CourseVersion.endDate;
                    course.Subject_End_Date__c=date.parse(edDate);   
                }
                if(request.CourseVersion.examRequired !=NULL)
                {
                    course.Exam_Required__c	=request.CourseVersion.examRequired;
                }
                course.Faculties__c  = request.CourseVersion.facultyWithId;
                if(!String.isBlank(request.CourseVersion.facility))
                {
                    course.Facilities__c  = request.CourseVersion.facility;
                }
                if(request.CourseVersion.numOfSessions!=null)
                {
                    course.Number_of_Sessions__c  = request.CourseVersion.numOfSessions;
                }
                String errorMessage;
                if(course<> null)
                {
                    upsert course;
                    database.upsertResult myResult=database.upsert(course,false);
                    response.courseVersionId=course.Id;
                    for(Database.Error error:myResult.getErrors()){
                        errorMessage = error.getMessage();
                    }
                }
                if(String.isNotBlank(errorMessage)){
                    res.statusCode = 400;
                    res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "'+errorMessage+'"}' );
                    return;
                }
                
                res.statusCode = 200;
                if(String.isBlank(response.courseVersionId)){
                    res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
                    return;
                }
                List<String> allFaculty=new List<String>();
                if(String.isNotBlank(request.CourseVersion.facultyWithId)){
                    allFaculty=request.CourseVersion.facultyWithId.split(',');
                }
                
                List<Account> accList = getConatctFromAccount(allFaculty);
                for(Account acc : accList) {
                    accToContactMap.put(acc.Id,acc.PersonContactId);
                }
                
                System.debug('accToContactMap::' + accToContactMap);
                
                if(!allFaculty.isEmpty()){
                    for(String fac:allFaculty){
                        String facultyId=fac.substringAfter('-');
                        try{
                            Datetime startDate = date.parse(request.CourseVersion.startDate); 
                            Datetime endDate = date.parse(request.CourseVersion.endDate); 
                            //createFacultyBooking(facultyId,startDate,date.parse(request.CourseVersion.startDate),response,date.parse(request.CourseVersion.endDate),termVal[0].hed__End_Date__c);
                        	createFacultyBooking(accToContactMap.get(facultyId),startDate,date.parse(request.CourseVersion.startDate),response,date.parse(request.CourseVersion.endDate),termVal[0].hed__End_Date__c);
                        }
                        Catch(Exception e){
                            res.statusCode = 400;
                            response.success='false';
                            response.message='"bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber();
                            break;
                        }
                    }  
                }
                jsonResponse=json.serialize(response);
                res.responseBody=Blob.valueOf(jsonResponse); 
            }
        }
        catch(Exception e){
            if(e.getMessage() == 'Upsert failed. First exception on row 0; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, You are Unable to create this record because, with the Same Details already Record Existed..: []'){
                res.statusCode = 409;
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Duplicate records found..." }' );
            }else{
                res.statusCode = 400;
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
            }
        } 
    }
    
    public static List<Account> getConatctFromAccount(List<String> facultyIds) {
        List<String> facIds = new List<String>();
        List<Account> accList = new List<Account>();
        for(String fac:facultyIds){
            facIds.add(fac.substringAfter('-'));
        }
        
        if(!facIds.isEmpty()) {
            accList =  [SELECT Id, Name, PersonContactId FROM Account WHERE Id IN :facIds ];
            /*for(Account acc : accList) {
                 accToContactMap.put(acc.Id, acc.PersonContactId);
            }*/
           
        }
        return accList;
        
    }
    //Wrapper class for the request from API 
    public class requestCourseVersionWrapper {
        public requestCourseVersionDataWrapper CourseVersion {get;set;}
        public string Operation {get;set;}
        public Id termId {get;set;}
        
    }
    public class requestCourseVersionDataWrapper {
        public String termName {get;set;}
        public String courseVersionId {get;set;}
        public String courseId {get;set;}
        public String startDate {get;set;}
        public String endDate {get;set;}
        public Boolean examRequired {get;set;}
        public Decimal numOfSessions {get;set;}
        public string facultyWithId{get;set;}
        public Id facility{get;set;}
    }
    public class responseCourseVersionWrapper {
        public string success='true';
        public string message='Data is Added';
        public String courseVersionId {get;set;}
    }
    
    public static Id createFacultyBooking(String facultyId,DateTime startDateVal,Date start,responseCourseVersionWrapper response,Date endDate,Date termEndDate)
    {
        Map<Id,Date> mapOfActivity= new Map<Id,Date>();
        List<Activity__c> activityList = [Select Id,Name,Subject__c,Subject__r.Term__r.hed__End_Date__c,Duration__c,Subject__r.Term__r.Program_Plan__r.Working_Days__c,Activity_Duration__c,Start_date__c,End_date__c from Activity__c where Subject__c =:response.courseVersionId];
        mapOfActivity = ActivityTriggerNewHandler.creatingMapOfCvAndActivityHighestEndDate(activityList);
        Faculty_Booking__c faculty=new Faculty_Booking__c();
        faculty.Booked_By__c=facultyId;
        if(startDateVal!=null)
        {
            faculty.Start_Date_Time__c=startDateVal;
        }
        Date activityEndDate = mapOfActivity.containsKey(response.courseVersionId)?mapOfActivity.get(response.courseVersionId):termEndDate;
        faculty.End_Date_Time__c = activityEndDate;        
        faculty.Course_Version__c=response.courseVersionId;
        faculty.Type__c='Planned';
        upsert faculty;
        return faculty.Id;
    }
    // added method to check the prerequisite
    
    @Testvisible
    private static Boolean validatePlanRequirement(requestCourseVersionDataWrapper request) {
		Set<Id> masterPlanReqIds = new Set<Id>();
		set<Id> allCourseIds = new Set<Id>();
        
        //List<hed__Course__c> courseList = [SELECT Id, Name,(SELECT Id, Name,)]

		//for (courseWrapper courseWrap : courseList) {
		//	masterPlanReqIds.add(courseWrap.masterPlanReqId);
		//	allCourseIds.add(courseWrap.courseId);
		//}

		List<hed__Plan_Requirement__c> planRequirements = [
			SELECT Id, Pre_Requisites_1__c,hed__Course__c, Pre_Requisites_2__c, Pre_Requisites_3__c, Term__r.Term_Reference__c
			FROM hed__Plan_Requirement__c
			WHERE
				hed__Course__c = :request.courseId AND RecordType.Name ='Master Unit'
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
			if (!allCourseIds.contains(preRequisiteId)) {
				filteredPreRequisiteId.add(preRequisiteId);
			}
		}
		List<Course_Version__c> courseVersions = [SELECT Id, Name, Term__r.Name,Course__c FROM Course_Version__c WHERE Course__c IN:filteredPreRequisiteId AND Term__r.Name =:request.termName ];
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
			return ValidateCoursesFromPreviousTerm(request.termName, filteredPreRequisiteId);
		}

	}
        @TestVisible

    private static Boolean ValidateCoursesFromPreviousTerm(string termName, set<Id> filteredPreRequisiteId) {
		Set<Id> pccIds = new Set<Id>();

		List<Term_Campus_Relationship__c> termRelations = [
			SELECT Id, Program_Campus_Combination__c, Term__r.Term_Reference__c,Term__r.Name
			FROM Term_Campus_Relationship__c
			WHERE Term__r.Name = :termName
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
        @TestVisible

    private static boolean validateDuplicateRecordsFromPrevTerms(requestCourseVersionDataWrapper request){
        Set<Id> pccIds = new Set<Id>();

		List<Term_Campus_Relationship__c> termRelations = [
			SELECT Id, Program_Campus_Combination__c, Term__r.Term_Reference__c,Term__r.Name
			FROM Term_Campus_Relationship__c
			WHERE Term__r.Name = :request.termName
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
        if(!courseIds.isEmpty() && courseIds.contains(request.courseId)){
            return false;
        }
        return true;
    }
    
    
    /*   @HttpPost
global static void doPost(){


RestResponse res = RestContext.response;
try{
List<wrapperForPost> inputList = (List<wrapperForPost>) JSON.deserialize( RestContext.request.requestBody.toString(), List<wrapperForPost>.class);
map<string,list<string>>courseVersionfacultyList = new map<string,list<string>>();

for(wrapperForPost wrapper:inputList){
if(!string.isEmpty(wrapper.courseVersionId) && !(wrapper.facultyIds.isEmpty())){
courseVersionfacultyList.put(wrapper.courseVersionId,wrapper.facultyIds);  
}else{
res.responseBody = Blob.valueOf('{"success" : "false","message" : "Invalid Paramters "}'); 
}

}
List<Course_Version__c> InputCourseVersions = [select id,Name,(Select Faculty__c,Course_Version__c from Course_Version_Faculty_Mapping__r) from Course_Version__c where id =: courseVersionfacultyList.keySet()];
List<Course_Version_Faculty_Mapping__c> newListofCourseVersionFaculty = new List<Course_Version_Faculty_Mapping__c>();
List<Course_Version_Faculty_Mapping__c>Deletinglist = new List<Course_Version_Faculty_Mapping__c>();
//  Set<string> verifyinglist = new Set<string>();
if(!InputCourseVersions.isEmpty()){
for(Course_Version__c version : InputCourseVersions){
Set<string> verifyinglist = new Set<string>();
if(!version.Course_Version_Faculty_Mapping__r.isEmpty()){
for(Course_Version_Faculty_Mapping__c childs : version.Course_Version_Faculty_Mapping__r){
verifyinglist.add(childs.Faculty__c);
}
for(string courseversioncheck:courseVersionfacultyList.get(version.id)){
if(!verifyinglist.contains(courseversioncheck)){
Course_Version_Faculty_Mapping__c newRecord = new Course_Version_Faculty_Mapping__c();
newRecord.Course_Version__c = version.id;
newRecord.Faculty__c = courseversioncheck;
newListofCourseVersionFaculty.add(newRecord);

}

}
}else{

for(string faculty:courseVersionfacultyList.get(version.id)){
Course_Version_Faculty_Mapping__c cvf = new Course_Version_Faculty_Mapping__c();
cvf.Course_Version__c = version.id;
cvf.Faculty__c = faculty;
newListofCourseVersionFaculty.add(cvf);
}
} 
}
if(!newListofCourseVersionFaculty.isEmpty()){
insert newListofCourseVersionFaculty; 
res.responseBody = Blob.valueOf('{"success" : "True","message" : "Records Inserted Succesfully..."}'); 
}
List<Course_Version__c> courseVersionsWithCVFaculty = [select id,Name,(Select Faculty__c,Course_Version__c from Course_Version_Faculty_Mapping__r) from Course_Version__c where id =: courseVersionfacultyList.keySet()];
for(Course_Version__c courseVersions : courseVersionsWithCVFaculty){
for(Course_Version_Faculty_Mapping__c listOfAllCVFacultyrecords :courseVersions.Course_Version_Faculty_Mapping__r){
list<string>initialList= courseVersionfacultyList.get(courseVersions.id);
if(!initialList.contains(listOfAllCVFacultyrecords.Faculty__c)){
Deletinglist.add(listOfAllCVFacultyrecords); 
}
}
} 

if(!Deletinglist.isEmpty()){
Delete Deletinglist; 
res.responseBody = Blob.valueOf('{"success" : "True","message" : "Records Deleted Succesfully..."}'); 
}
}else{
res.responseBody = Blob.valueOf('{"success" : "false","message" : "No Data Found "}');    
}
}catch(exception e){
res.responseBody = Blob.valueOf('{"success" : "false","error" : "'+e.getMessage()+ 'at line number '+e.getLineNumber()+'"}'); 
}

}
global class wrapperForPost{
global string courseVersionId;
global list<string> facultyIds;
}*/
    
    /*   [{
"courseVersionId":"a241y000000LHHyAAO",
"facultyIds":["0031y00000LXVyNAAX","0031y00000MZcjUAAT"]
}] */
}