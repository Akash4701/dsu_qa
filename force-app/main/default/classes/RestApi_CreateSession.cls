@RestResource(urlMapping='/createSession')
global class RestApi_CreateSession {
    public static Map<Id,List<Session__c>> mapOfcourseOfferingAndSessions = new Map<Id,List<Session__c>>();
    //Faculty Booking Validation variable
    public static Map<Id,List<Faculty_Booking__c>> facultyBookingMap=new Map<Id,List<Faculty_Booking__c>>();
	//Facility Booking Validation variable
    public static Map<Id,List<Facility_Booking__c >> facilityBookingMap=new Map<Id,List<Facility_Booking__c >>();
    public  static Boolean courseOfferingFlag = false;
    public static Map<Id,hed__Course_Offering__c> globalCourseoffMap = new Map<Id,hed__Course_Offering__c>();
    
    @HttpPost
    global static void doCreateSession(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
        String recordtype;
        if(recordtype!=null){
        recordtype= RestContext.request.params.get('recordtype');
        }
        Set<Id> accountIds=new Set<Id>();
        Map<Id,Id> accPersonAccMap=new Map<Id,Id>();
        Set<Id> courseOffringIds = new Set<Id>();
        try{
            Boolean facultyBookingValidation=false;
            Boolean facilityBookingValidation=false;
            Boolean dateValidation=false;
            String errorMsg;
            requestSessionWrapper requestAll = (requestSessionWrapper) JSON.deserialize(RestContext.request.requestBody.toString(),requestSessionWrapper.class);
            responseSessionWrapper responseAll=new responseSessionWrapper();
            List<responseSessionDataWrapper> responseList=new List<responseSessionDataWrapper>();
            List<requestSessionDataWrapper> requestList=new List<requestSessionDataWrapper>();
            requestList=requestAll.Session;
             for(requestSessionDataWrapper req:requestList){
                accountIds.add(req.facultyId);
            }
            List<Account> accList=new List<Account>();
            /*System.debug(accountIds);
            accList=[SELECT Id, Name, PersonContactId FROM Account WHERE Id IN :accountIds];
            for(Account acc:accList){
                accPersonAccMap.put(acc.id,acc.PersonContactId);
            }*/ 
            if(requestAll.Operation=='Delete')
            {

                if(!requestList.isEmpty())
                {
                    List<String> allSesssionListDelete=new  List<String>();
                    List<String> allFacultyBookingListDelete=new  List<String>();
                    List<String> allFacilityBookingListDelete=new  List<String>();
                    Map<Id,Session__c> checkAllSessionRecord=new Map<Id,Session__c>();
                    for(requestSessionDataWrapper request:requestList)
                    {
                        if(!String.isBlank(request.sessionId))
                        {
                            allSesssionListDelete.add(request.sessionId);
                        }
                    }
                    if(!allSesssionListDelete.isEmpty())
                    {
                        List<Session__c> sessionList=new List<Session__c>([SELECT Id,Name,Facility_Booking__c,Faculty_Booking__c FROM Session__c WHERE Id IN:allSesssionListDelete]);
                        if(!sessionList.isEmpty())
                        {
                            for(Session__c session:sessionList)
                            {
                                checkAllSessionRecord.put(session.Id,session);
                                allFacultyBookingListDelete.add(session.Faculty_Booking__c);
                                allFacilityBookingListDelete.add(session.Facility_Booking__c);
                            }
                        }
                    }
                    if(!allFacultyBookingListDelete.isEmpty()){
                        List<Faculty_Booking__c> facultyBookList=new List<Faculty_Booking__c>([SELECT Id FROM Faculty_Booking__c WHERE Id IN:allFacultyBookingListDelete]);
                        delete facultyBookList;
                    }
                    if(!allFacilityBookingListDelete.isEmpty()){
                        List<Facility_Booking__c> facilityBookList=new List<Facility_Booking__c>([SELECT Id FROM Facility_Booking__c WHERE Id IN:allFacilityBookingListDelete]);
                        delete facilityBookList;
                    }
                    if(!checkAllSessionRecord.keyset().isEmpty())
                    {
                        try{
                            database.DeleteResult[] myResult=database.delete(checkAllSessionRecord.values(),false);
                            Set<Id> allSuccessId=new Set<Id>();
                            for(database.DeleteResult s:myResult){
                                responseSessionDataWrapper response=new responseSessionDataWrapper();
                                if(s.isSuccess()){
                                    allSuccessId.add(s.getId());
                                    response.sessionId=s.getId();
                                    response.success='true';
                                    response.message='Data is Deleted';
                                    res.statusCode = 200;
                                    responseList.add(response);
                                }
                                else{
                                    database.Error[] er=s.getErrors();
                                    for(database.Error e:er){
                                        for(id ids:checkAllSessionRecord.keyset()){
                                            if(!allSuccessId.contains(ids)){
                                                response.sessionId=ids;
                                                response.success='true';
                                                response.message='Data is Not Deleted';
                                                res.statusCode = 200;
                                                response.errors=e.getStatusCode() + ': ' + e.getMessage();
                                                responseList.add(response);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Catch(Exception e){
                            responseSessionDataWrapper response=new responseSessionDataWrapper();
                            res.statusCode = 400;
                            response.success='false';
                            response.message='bad request';
                            response.errors=e.getMessage()+'at Line Number'+e.getLineNumber();
                            responseList.add(response);
                        }
                    }
                    else
                    {
                        responseSessionDataWrapper response=new responseSessionDataWrapper();
                        response.success='true';
                        response.message='No Data Found';
                        res.statusCode = 200;
                        responseList.add(response);
                    }
                }
            }
            else
            {
                if(!requestList.isEmpty())
                {
                    List<Id> allSessionIdList=new  List<Id>();
                    List<Id> allFacilityListUpdate=new  List<Id>();
                    List<Id> allFacultyListUpdate=new  List<Id>();
                    List<Id> allCourseOfferingUpdate=new  List<Id>();
                    List<Facility_Booking__c> allFacilityListUpsert=new  List<Facility_Booking__c>();
                    List<Faculty_Booking__c> allFacultyListUpsert=new  List<Faculty_Booking__c>();
                    Map<String,Id> allFacilityListUpsertMap=new  Map<String,Id>();
                    Map<String,Id> allFacultyListUpsertMap=new  Map<String,Id>();
                    Set<Id> facilityBookedIds = new Set<Id>();
                    Set<Id> facultyBookedIds = new Set<Id>();
                    Set<Id> deleteFacilityBookedIds = new Set<Id>();
                    Set<Id> deleteFacultyBookedIds = new Set<Id>();
                    Map<String,Facility_Booking__c> facilityBookedMap=new Map<String,Facility_Booking__c>();
                    Map<String,Faculty_Booking__c> facultyBookedMap=new Map<String,Faculty_Booking__c>();
                    List<Session__c> allSessionUpdated=new List<Session__c>();
                    List<Session__c> sessionsAllList=new List<Session__c>();
                    List<Session__c> sessionsAllListNew=new List<Session__c>();
                    Map<Id,Session__c> allSessionMap=new Map<Id,Session__c>();

                    Map<String,requestSessionDataWrapper> uniqueData=new Map<String,requestSessionDataWrapper>();
                    Map<requestSessionDataWrapper,Session__c> sessionUpdateMap=new Map<requestSessionDataWrapper,Session__c>();



                    Boolean check=false;
                    String queryStr='SELECT Id,Contact__r.Name,Faculty__r.Name,Faculty__r.email,Course_Offering__r.Name,Facility__r.Name,Start_Date_Time__c,End_Date_Time__c,RecordTypeId,Facility_Booking__c,Faculty_Booking__c FROM Session__c WHERE Name<>null';

                    for(requestSessionDataWrapper request:requestList)
                    {
                        String uniqueStr;
                        if(!String.isBlank(request.sessionId))
                        {
                            allSessionIdList.add(request.sessionId);
                        }
                        if(!String.isBlank(request.facultyId))
                        {
                            allFacultyListUpdate.add(request.facultyId);
                            uniqueStr+=request.facultyId;
                        }
                        if(!String.isBlank(request.facilityId))
                        {
                            allFacilityListUpdate.add(request.facilityId);
                            uniqueStr+=request.facilityId;
                        }
                        if(!String.isBlank(request.courseOfferingId))
                        {
                            allCourseOfferingUpdate.add(request.courseOfferingId);
                            uniqueStr+=request.courseOfferingId;
                        }
                        if(uniqueStr<>null)
                        {
                            uniqueData.put(uniqueStr,request);
                        }
                    }
					for(Session__c sessObj:[SELECT Id,Contact__r.Name,Faculty__r.Name,Faculty__r.email,Course_Offering__r.Name,Facility__r.Name,Start_Date_Time__c,End_Date_Time__c,RecordTypeId,Facility_Booking__c,Faculty_Booking__c FROM Session__c WHERE Id=:allSessionIdList]){
                        system.debug('sessObj'+sessObj.Facility_Booking__c);
                        facilityBookedIds.add(sessObj.Facility_Booking__c);
                        facultyBookedIds.add(sessObj.Faculty_Booking__c);
                    }
                    if(!allFacultyListUpdate.isEmpty() || !allFacilityListUpdate.isEmpty() || !allCourseOfferingUpdate.isEmpty())
                    {

                        if(!allFacultyListUpdate.isEmpty())
                        {
                            queryStr+=' OR Faculty__c IN: allFacultyListUpdate';
                            check=true;
                        }
                        if(!allFacilityListUpdate.isEmpty())
                        {
                            queryStr+=' OR Facility__c IN: allFacilityListUpdate';
                            check=true;
                        }
                        if(!allCourseOfferingUpdate.isEmpty())
                        {
                            queryStr+=' OR Course_Offering__c IN: allCourseOfferingUpdate';
                            check=true;
                        }
                        if(check==true)
                        {
                            allSessionUpdated=Database.query(queryStr);
                        }
                    }

                    if(!allSessionUpdated.isEmpty())
                    {
                        for(Session__c sess:allSessionUpdated)
                        {
                            String uniqueString;
                            if(!String.isBlank(sess.Contact__c))
                            {
                                uniqueString+=sess.Contact__c;
                            }
                            if(!String.isBlank(sess.Faculty__c))
                            {
                                uniqueString+=sess.Faculty__c;
                            }
                            if(!String.isBlank(sess.Facility__c))
                            {
                                uniqueString+=sess.Facility__c;
                            }
                            if(!String.isBlank(sess.Course_Offering__c))
                            {
                                uniqueString+=sess.Course_Offering__c;
                            }
                            if(String.isNotBlank(uniqueString))
                            {
                                if(uniqueData.keyset().contains(uniqueString))
                                {
                                    sessionUpdateMap.put(uniqueData.get(uniqueString),sess);
                                }
                            }

                        }
                    }
                    if(!allSessionIdList.isEmpty()){
                        for(Session__c sess:[SELECT Id,Faculty__c,Faculty_Booking__c,Facility_Booking__c,Facility__c,Start_Date_Time__c, End_Date_Time__c FROM Session__c]){
                            allSessionMap.put(sess.Id,sess);
                        }
                    }
                    //fetching all the sessions related to that courseOffering
                    for(Session__c sessionObj:[Select Id,Name,Start_Date_Time__c,End_Date_Time__c,Course_Offering__c from Session__c where Course_Offering__c=: allCourseOfferingUpdate and Id!=:allSessionIdList]){
                        if(mapOfcourseOfferingAndSessions.containsKey(sessionObj.Course_Offering__c)){
                            List<Session__c> sessionsList = mapOfcourseOfferingAndSessions.get(sessionObj.Course_Offering__c);
                            sessionsList.add(sessionObj);
                            mapOfcourseOfferingAndSessions.put(sessionObj.Course_Offering__c,sessionsList);
                        }else{
                            mapOfcourseOfferingAndSessions.put(sessionObj.Course_Offering__c,new List<Session__c>{ sessionObj });
                        }
                    }
                    //Getting all Faculty Booking values
                    if(!allFacultyListUpdate.isEmpty()){
                        List<Faculty_Booking__c> facultyBookingList=new List<Faculty_Booking__c>([SELECT Id,Name,Start_Date_Time__c,End_Date_Time__c,Booked_By__c,Booked_By__r.Name,Booked_By__r.Email FROM Faculty_Booking__c WHERE Booked_By__c IN: allFacultyListUpdate AND Type__c='Actual' /*and Id!=:facultyBookedIds*/]);
                        system.debug('facultyBooking'+facultyBookingList);
                        if(!facultyBookingList.isEmpty())
                        {
                            for(Faculty_Booking__c facBooking:facultyBookingList)
                            {
                                facultyBookedMap.put(facBooking.Booked_By__c+'_'+facBooking.Start_Date_Time__c+'_'+facBooking.End_Date_Time__c,facBooking);
                                List<Faculty_Booking__c> facBookList=new List<Faculty_Booking__c>();
                                if(facultyBookingMap.keyset().contains(facBooking.Booked_By__r.Id))
                                {
                                    facBookList=facultyBookingMap.get(facBooking.Booked_By__r.Id);
                                }
                                facBookList.add(facBooking);
                                facultyBookingMap.put(facBooking.Booked_By__r.Id,facBookList);
                            }
                        }
                    }
                    //Getting all Facility Booking values
                    system.debug('facBookedIds'+facilityBookedIds);
                    if(!allFacilityListUpdate.isEmpty()){
                        List<Facility_Booking__c> facilityBookingList=new List<Facility_Booking__c>([SELECT Id,Name,Start_Date_and_Time__c,End_Date_and_Time__c,FacilityID__c ,FacilityID__r.Name FROM Facility_Booking__c WHERE FacilityID__c IN: allFacilityListUpdate /*and Id!=:facilityBookedIds*/]);
                        if(!facilityBookingList.isEmpty())
                        {
                            for(Facility_Booking__c facBooking:facilityBookingList)
                            {
                                facilityBookedMap.put(facBooking.FacilityID__c+'_'+facBooking.Start_Date_and_Time__c+'_'+facBooking.End_Date_and_Time__c,facBooking);
                                List<Facility_Booking__c> facBookList=new List<Facility_Booking__c>();
                                if(facilityBookingMap.keyset().contains(facBooking.FacilityID__c))
                                {
                                    facBookList=facilityBookingMap.get(facBooking.FacilityID__c);
                                }
                                facBookList.add(facBooking);
                                facilityBookingMap.put(facBooking.FacilityID__c ,facBookList);
                            }
                        }
                    }
                    
                    for(requestSessionDataWrapper request:requestList) {
                        courseOffringIds.add(request?.courseOfferingId);
                    }
                    
                    if(!courseOffringIds.isEmpty()){
                        globalCourseoffMap = getCourseOffering(courseOffringIds);
                    }

                    for(requestSessionDataWrapper request:requestList)
                    {	
                        System.debug('inside for loop::::');
                        //system.debug('requestList:::' + requestList);
                        system.debug('requestList size():::' + requestList.size());
                        String days = String.isBlank(request.daySelected)?'Monday;Tuesday;Wednesday;Thursday;Friday;Saturday;Sunday':request.daySelected;
                        List<String> selectedDays = days.split(';');
                        System.debug('request.startDate '+request.startDate);
                        System.debug('request.endDate '+request.endDate);
                        Time stTime = DateTime.valueOf(request.startDate.removeEnd('z').replace('T', ' ')).time();
                        Time endTime = DateTime.valueOf(request.endDate.removeEnd('z').replace('T', ' ')).time();
                        
                        System.debug('stTime '+stTime);
                        System.debug('endTime '+endTime);
                        Long lstTime=stTime.hour();
                        Long lendTime=endTime.hour();
                        if(request.startDate>=request.endDate){
                             dateValidation= true;
                        }
                        if(request.checkForHolidays){
                            List<K42_Campus_Holiday__c> dts=checkForHolidayDates(request.courseOfferingId,DateTime.valueOf(request.startDate.removeEnd('z').replace('T', ' ')).date(),DateTime.valueOf(request.endDate.removeEnd('z').replace('T', ' ')).date());
                            if(!dts.isEmpty()){
                                String holidayss = '';
                                List<HolidaysWrapper> holidays = new List<HolidaysWrapper>();
                                for(K42_Campus_Holiday__c holiday : dts) {
                                    HolidaysWrapper holidayWrapObj = new HolidaysWrapper();
                                    holidayWrapObj.Name=holiday.K42_Holiday__r.Name;
                                    holidayWrapObj.Frm=holiday.K42_Holiday__r.K42_Hol_Start_Date__c;
                                    holidayWrapObj.To=holiday.K42_Holiday__r.K42_Hol_End_Date__c;
                                    holidays.add(holidayWrapObj);
                                    //holidayss += '{ '+holiday.K42_Holiday__r.Name + ' From : '+ holiday.K42_Holiday__r.K42_Hol_Start_Date__c +'  To : ' + holiday.K42_Holiday__r.K42_Hol_End_Date__c + '},';
                                }
                                
                                AddError('false',200,'Holidays present between selected dates',json.serialize(holidays));
                                return;
                            }
                        }
                        
                        for(Date dt:returnDatesBtwTwoDates(Date.valueOf(request.startDate),Date.valueOf(request.endDate))){
                            if((dt == Date.valueOf(request.endDate)) && ((lendTime - lstTime) <0)) break;   
                            system.debug(dt);
                            Session__c session=new Session__c();
                            DateTime currDate = DateTime.newInstance(dt.year(), dt.month(), dt.day());
                            String todayDay = currDate.format('EEEE');
                            if(!selectedDays.isEmpty() && selectedDays.contains(todayDay)){
                                system.debug('inside 1st if');
                                system.debug('facultyBookingMap'+facultyBookingMap);
                                system.debug('facultyBookingValidation'+facultyBookingValidation);
                                system.debug('request.sessionId'+request.sessionId);
                                if(!facultyBookingMap.keyset().isEmpty() && (!facultyBookingValidation && (String.isBlank(request.sessionId) && facultyBookingMap.keyset().contains(request.facultyId))
                                   || (!String.isBlank(request.sessionId) && allSessionMap.get(request.sessionId).Faculty__c!=accPersonAccMap.get(request.facultyId)))){
                                   system.debug('inside 2st if');
                                       facultyBookingValidation=checkFacultyBookingValidation(request.facultyId,facultyBookingMap.get(request.facultyId),DateTime.newInstance(dt, stTime),DateTime.newInstance(dt, endTime));
                                }
                                System.debug('facilityBookingValidation1.1'+facilityBookingValidation);
                                if(!facilityBookingMap.keyset().isEmpty() && (!facilityBookingValidation && (String.isBlank(request.sessionId) && facilityBookingMap.keyset().contains(request.facilityId))
                                   || (!String.isBlank(request.sessionId) && allSessionMap.get(request.sessionId).Facility__c!=request.facilityId))){
                                       system.debug(facilityBookingMap.get(request.facilityId));
                                       system.debug('stTime==>'+stTime);
                                       system.debug('endTime-->'+endTime);
                                   facilityBookingValidation=checkFacilityBookingValidation(request.facilityId,facilityBookingMap.get(request.facilityId),DateTime.newInstance(dt, stTime),DateTime.newInstance(dt, endTime));
                                }
                                
								System.debug('facilityBookingValidation1'+facilityBookingValidation);
                                DateTime startDate;
                                DateTime endDate;
                                //**********************************************************************************
                                if(!String.isBlank(request.startDate) && !String.isBlank(request.endDate))
                                {
                                    startDate=DateTime.newInstance(dt, stTime);
                                    endDate=DateTime.newInstance(dt, endTime);

                                    //startDate=DateTime.newInstanceGmt(dt, stTime);
                                    //endDate=DateTime.newInstanceGmt(dt, endTime);
                                    system.debug('1'+startDate);
                                    system.debug('2'+endDate);
                                    if(startDate.date()!=endDate.date()){
                                        system.debug('INSIDE1'+startDate);
                                    	system.debug('INSIDE2'+endDate);
                                        Date tmp=startDate.date();
                                        startDate=DateTime.newInstance(endDate.date(), stTime);
                                        endDate=DateTime.newInstance(tmp, endTime);
                                        //startDate=DateTime.newInstanceGmt(endDate.date(), stTime);
                                    	//endDate=DateTime.newInstanceGmt(tmp, endTime);
                                        system.debug('LAST1'+startDate);
                                    	system.debug('LAST2'+endDate);
                                    }
                                    system.debug('endDate'+endDate);
                                    /*if(startDate>=endDate){
                                        dateValidation= true;
                                    }*/
                                }
                                //********************************************************************************************
								system.debug('endDate'+endDate);
                                DateTime startDateTime = DateTime.newInstanceGmt(dt, stTime);
                                DateTime endDateTime = DateTime.newInstanceGmt(dt, endTime);
                                system.debug('startDateTime'+startDateTime);
                                system.debug('endDateTime'+endDateTime);
                                system.debug(DateTime.newInstanceGmt(dt, stTime));
                                system.debug(DateTime.newInstanceGmt(dt, endTime));
                                system.debug(request.facilityId);
                                String facilityErrorMsg;
                                if(!String.isBlank(request.sessionId)){
                                    facilityErrorMsg=doFacilityBookingValidate(startDate,endDate,request.facilityId,allSessionMap.get(request.sessionId).Facility_Booking__c);
                                }
                                else{
                                	facilityErrorMsg=doFacilityBookingValidate(startDate,endDate,request.facilityId,null);
                                }
                                system.debug(facilityErrorMsg);
                                if(facilityErrorMsg!=null){
                                    AddError('false',200,'Data cannot be added',facilityErrorMsg);
                                    return;
                                }
                                String facultyErrorMsg;
                                if(!String.isBlank(request.sessionId)){
                                    facultyErrorMsg=doFacultyBookingValidate(startDate,endDate,request.facultyId,allSessionMap.get(request.sessionId).Faculty_Booking__c);
                                }
                                else{
                                	facultyErrorMsg=doFacultyBookingValidate(startDate,endDate,request.facultyId,null);
                                }
                                system.debug(facultyErrorMsg);
                                if(facultyErrorMsg!=null){
                                    AddError('false',200,'Data cannot be added',facultyErrorMsg);
                                    return;
                                }
                                //if(String.isBlank(request.sessionId)){
                                    errorMsg = doValidate(startDate,endDate,request.courseOfferingId);
                                //}
                                system.debug(errorMsg);
                                System.debug('facilityBookingValidation2'+facilityBookingValidation);
                                if(!facilityBookingValidation && !facultyBookingValidation && !dateValidation && String.isBlank(errorMsg)){
                                    if(!String.isBlank(request.sessionId))
                                    {
                                        session.Id=request.sessionId;
                                    }
                                    else if(sessionUpdateMap.keyset().contains(request))
                                    {
                                        if(sessionUpdateMap.get(request).Start_Date_Time__c==toDateTime(request.startDate) && sessionUpdateMap.get(request).End_Date_Time__c==toDateTime(request.endDate))
                                        {
                                            session.Id=sessionUpdateMap.get(request).Id;
                                        }
                                    }
                                    if(request.activityType!=null)
                                    {
                                        session.Type_of_Activity__c=request.activityType;
                                    }
                                    //if(!String.isBlank(request.courseOfferingId))
                                    //{
                                        session.Course_Offering__c=request.courseOfferingId;
                                    //}
                                    if(String.isNotBlank(request.termId)){
                                        session.Term__c = request.termId;
                                    }
                                    if(String.isNotBlank(request.modeOfDelivery) && request.modeOfDelivery!=null){
                                    	session.Mode_of_Delivery__c=request.modeOfDelivery;
                                	}
                                    if(String.isNotBlank(request.timeZone) && request.timeZone!=null){
                                    	session.TimeZone__c=request.timeZone;
                                	}
                                    if(!String.isBlank(request.facilityId))
                                    {
                                        system.debug(request.facilityId);
                                        session.Facility__c=request.facilityId;
                                        Facility_Booking__c facBook;
                                        if(!String.isBlank(request.sessionId)){
                                            if(allSessionMap.get(request.sessionId).Facility__c!=request.facilityId){
                                                deleteFacilityBookedIds.add(allSessionMap.get(request.sessionId).Facility_Booking__c);
                                            }
                                            //if(String.isNotBlank(errorMsg) || errorMsg!=null){
                                                facBook=createFacilityBooking(request,startDate,endDate/*DateTime.newInstanceGmt(dt, stTime),DateTime.newInstance(dt, endTime)*/,facilityBookedMap,allSessionMap.get(request.sessionId));
                                            //}
                                            
                                        }
                                        else{
                                            //if(String.isNotBlank(errorMsg) || errorMsg!=null){
                                                facBook=createFacilityBooking(request,startDate,endDate/*DateTime.newInstanceGmt(dt, stTime),DateTime.newInstance(dt, endTime)*/,facilityBookedMap,NULL);
                                            //}
                                        }
                                        allFacilityListUpsert.add(facBook);
                                    }
                                    if(!String.isBlank(request.facultyId))
                                    {
                                        system.debug(request.facultyId);
                                        //need to check
                                        session.Faculty__c=request.facultyId;//accPersonAccMap.get(request.facultyId);
                                        Faculty_Booking__c facultBook;
                                        if(!String.isBlank(request.sessionId)){
                                            if(allSessionMap.get(request.sessionId).Faculty__c!=request.facultyId){
                                                deleteFacultyBookedIds.add(allSessionMap.get(request.sessionId).Faculty_Booking__c);
                                            }
                                            //if(String.isNotBlank(errorMsg) || errorMsg!=null){
                                                facultBook=createFacultyBooking(request,startDate,endDate/*DateTime.newInstanceGmt(dt, stTime),DateTime.newInstance(dt, endTime)*/,facultyBookedMap,allSessionMap.get(request.sessionId),request.courseOfferingId);
                                            //}
                                        }
                                        else{
                                            //if(String.isNotBlank(errorMsg) || errorMsg!=null){
                                                facultBook=createFacultyBooking(request,startDate,endDate/*DateTime.newInstanceGmt(dt, stTime),DateTime.newInstance(dt, endTime)*/,facultyBookedMap,NULL,request.courseOfferingId);
                                            //}                                            
                                        }


                                        allFacultyListUpsert.add(facultBook);
                                    }
                                    if(!String.isBlank(request.startDate))
                                    {
                                        System.debug('Startdate ==> ' + startDate);

                                        session.Start_Date_Time__c=startDate;
                                        //session.Start_Date_Time__c = startDateTime;
                                        										System.debug('session.Start_Date_Time__c ==> ' + session.Start_Date_Time__c);

                                    }
                                    if(!String.isBlank(request.recordTypeId))
                                    {
                                        
                                        session.RecordTypeId=(request.recordTypeId);
                                    }
                                    if(!String.isBlank(request.endDate))
                                    {
                                                                                System.debug('endDate ==> ' + endDate);
										//session.End_Date_Time__c = endDateTime;
                                        session.End_Date_Time__c=endDate;
                                                                               System.debug('session.End_Date_Time__c ==> ' + session.End_Date_Time__c);

                                    }
                                    session.RecordTypeId = Schema.SObjectType.Session__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
                                    sessionsAllList.add(session);
                                }
                            }
                        }
                    }
					system.debug('@@@allFacilityListUpsert'+allFacilityListUpsert);
                    system.debug('@@@allFacultyListUpsert'+allFacultyListUpsert);
                    System.debug('facilityBookingValidation'+facilityBookingValidation);
                    //Check all Validation is passed
                    if(!facilityBookingValidation && facultyBookingValidation==false && String.isBlank(errorMsg)  && !dateValidation){
                        //Upsert Facility Booking
                        if(!allFacilityListUpsert.isEmpty() && allFacilityListUpsert!=null){
                            database.upsertResult[] myResult=database.upsert(allFacilityListUpsert,false);
                            for(Facility_Booking__c fac:allFacilityListUpsert){
                                allFacilityListUpsertMap.put(fac.FacilityID__c+'_'+fac.Start_Date_and_Time__c+'_'+fac.End_Date_and_Time__c,fac.Id);
                            }
                        }
                        //Upsert Faculty Booking
                        if(!allFacultyListUpsert.isEmpty()){
                            database.upsertResult[] myResult=database.upsert(allFacultyListUpsert,false);
                            for(Faculty_Booking__c facul:allFacultyListUpsert){
                                allFacultyListUpsertMap.put(facul.Booked_By__c+'_'+facul.Start_Date_Time__c+'_'+facul.End_Date_Time__c,facul.Id);
                            }
                        }

                        //Delete old Facility Booking
                        if(!deleteFacilityBookedIds.isEmpty()){
                            List<Facility_Booking__c> facBookList=[SELECT Id FROM Facility_Booking__c WHERE Id IN:deleteFacilityBookedIds];
                            if(!facBookList.isEmpty()){
                            	delete facBookList;
                            }

                        }
                        //Delete old Faculty Booking
                        if(!deleteFacultyBookedIds.isEmpty()){
                            List<Faculty_Booking__c> faculBookList=[SELECT Id FROM Faculty_Booking__c WHERE Id IN:deleteFacultyBookedIds];
                            if(!faculBookList.isEmpty()){
                            	delete faculBookList;
                            }
                        }

                        //Map Session with Faculty and Facility Id
                        if(!sessionsAllList.isEmpty()){
                            for(Session__c sess:sessionsAllList){
                                
                               
                                System.debug('sess.End_Date_Time__c on before upsert ==> ' + sess.End_Date_Time__c);
                                System.debug('sess.Start_Date_Time__c on before upsert ==> ' + sess.Start_Date_Time__c);
                                Session__c newSess=sess;
                                if(!allFacultyListUpsertMap.keyset().isEmpty() && allFacultyListUpsertMap.keyset().contains(sess.Faculty__c+'_'+sess.Start_Date_Time__c+'_'+sess.End_Date_Time__c)){
                                    newSess.Faculty_Booking__c=allFacultyListUpsertMap.get(sess.Faculty__c+'_'+sess.Start_Date_Time__c+'_'+sess.End_Date_Time__c);
                                }
                                if(!allFacilityListUpsertMap.keyset().isEmpty() && allFacilityListUpsertMap.keyset().contains(sess.Facility__c+'_'+sess.Start_Date_Time__c+'_'+sess.End_Date_Time__c)){
                                    newSess.Facility_Booking__c=allFacilityListUpsertMap.get(sess.Facility__c+'_'+sess.Start_Date_Time__c+'_'+sess.End_Date_Time__c);
                                }
                                 System.debug('newSess.Session_EndTime__c on before upsert ==> ' + newSess.Session_EndTime__c);
                                System.debug('newSess.Session_StartTime__c on before upsert ==> ' + newSess.Session_StartTime__c);
                                
                                sessionsAllListNew.add(newSess);
                            }
                        }
                    }

                    //Upsert Session Data
                    if(!sessionsAllListNew.isEmpty()){
                        try{
                            database.upsertResult[] myResult=database.upsert(sessionsAllListNew,false);
                            Set<Id> allSuccessId=new Set<Id>();
                            for(database.upsertResult s:myResult){
                                responseSessionDataWrapper response=new responseSessionDataWrapper();
                                if(s.isSuccess()){
                                    allSuccessId.add(s.getId());
                                    response.sessionId=s.getId();
                                    response.success='true';
                                    response.message='Data is Upserted';
                                    res.statusCode = 200;
                                    responseList.add(response);
                                }
                                else{
                                    database.Error[] er=s.getErrors();
                                    for(database.Error e:er){
                                        response.success='false';
                                        response.message='Data is Not Upserted';
                                        response.errors=e.getStatusCode() + ': ' + e.getMessage();
                                        res.statusCode = 400;
                                        responseList.add(response);
                                    }
                                }
                            }
                        }
                        Catch(Exception e){
                            responseSessionDataWrapper response=new responseSessionDataWrapper();
                            res.statusCode = 400;
                            response.success='false';
                            response.message='bad request';
                            response.errors=e.getMessage()+'at Line Number'+e.getLineNumber();
                            responseList.add(response);
                        }
                    }
                }
            }

            if(dateValidation)
            {
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Data cannot be added", "errors": "Start date/time cannot be greater than End date/time" }' );
            }
            else if(facultyBookingValidation){
                system.debug(facultyBookingValidation);
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Data cannot be added", "errors": "Faculty was Booked in this timeslot" }' );
            }
            else if(facilityBookingValidation){
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Data cannot be added", "errors": "Facility was Booked in this timeslot" }' );
            }
            else if (!String.isBlank(errorMsg)){
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Data cannot be added", "errors": '+json.serialize(errorMsg)+' }' );
            }
            else{
                responseAll.Session=responseList;
            	jsonResponse=json.serialize(responseAll);
            	res.responseBody=Blob.valueOf(jsonResponse);
            }

        }Catch(Exception e){
            if(res!=null){
                res.statusCode = 400;
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
            }
        }    
    }

    private static void AddError(String success, Integer statusCode, String message, string errors) {
        ErrorWrapper result = new ErrorWrapper();
        result.success = success;
        result.message = message;
        result.errors = errors;

        RestContext.response.statusCode = statusCode;
        RestContext.response.headers.put('content-type', 'text/plain');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    }

    private virtual class ErrorWrapper {
        public String success;
        public String message;
        public String errors;
    }

    public static DateTime toDateTime(String DateTimevalue) {
        DateTime dt = DateTime.valueOf(DateTimevalue.removeEnd('z').replace('T', ' '));
        return dt;
    }

    public static Time toTime(String DateTimevalue){
        List<String> DateAndTimeList = DateTimevalue.split('T');
        List<string> timeList = DateAndTimeList[1].split(':');
        Time t = Time.newInstance(Integer.valueOf(timeList[0]), Integer.valueOf(timeList[1]), Integer.valueOf(timeList[2].split('\\.')[0]), 000);
        return t;
    }

    //Wrapper class for the request from API
    public class requestSessionWrapper {
        public List<requestSessionDataWrapper> Session {get;set;}
        public string Operation {get;set;}

    }
    public class requestSessionDataWrapper {
        public String courseOfferingId {get;set;}
        public String termId {get;set;}
        public String activityType {get;set;}
        public String startDate {get;set;}
        public String endDate {get;set;}
        public String facilityId {get;set;}
        public String facultyId {get;set;}
        public String sessionId {get;set;}
        public String daySelected {get;set;}
        public String recordTypeId{get;set;}
        public String modeOfDelivery {get;set;}
        public String timeZone {get;set;}
        public Boolean checkForHolidays {get;set;}
    }
    public class responseSessionWrapper {
        public List<responseSessionDataWrapper> Session {get;set;}
    }
    public class responseSessionDataWrapper {
        public string success='true';
        public string message='Data is Added';
        public string errors {get;set;}
        public String courseOfferingId {get;set;}
        public String activityType {get;set;}
        public String startDate {get;set;}
        public String endDate {get;set;}
        public String facilityId {get;set;}
        public String facultyId {get;set;}
        public String sessionId {get;set;}
        public String recordTypeId{get;set;}
    }

    public static Facility_Booking__c createFacilityBooking(requestSessionDataWrapper request,DateTime startDateVal,DateTime endDateVal,Map<String,Facility_Booking__c> facilityBookedMap,Session__c sess)
    {
        Set<Id> accountIds=new Set<Id>();
        Map<Id,Id> accPersonAccMap=new Map<Id,Id>();       
        accountIds.add(request.facultyId);      
        List<Account> accList=new List<Account>();
        /*accList=[SELECT Id, Name, PersonContactId FROM Account WHERE Id IN :accountIds];
        for(Account acc:accList){
            accPersonAccMap.put(acc.id,acc.PersonContactId);
        }*/
        Facility_Booking__c facility=new Facility_Booking__c();
        if(sess!=NULL && !facilityBookedMap.keyset().isEmpty() && facilityBookedMap.keyset().contains(request.facilityId+'_'+sess.Start_Date_Time__c+'_'+sess.End_Date_Time__c))
        {
            facility.Id=facilityBookedMap.get(request.facilityId+'_'+sess.Start_Date_Time__c+'_'+sess.End_Date_Time__c).Id;
        }
        facility.Activity_type__c=request.activityType;
        facility.FacilityID__c=request.facilityId;

        if(startDateVal!=null)
        {
            facility.Start_Date_and_Time__c=startDateVal;
        }
        if(endDateVal!=null)
        {
            facility.End_Date_and_Time__c=endDateVal;
        }
        if(!String.isBlank(request.facultyId))
        {
            facility.Booked_By__c=request.facultyId;
        }
        return facility;
    }
    
    public static Map<Id, hed__Course_Offering__c> getCourseOffering(Set<Id> ids) {
        Map<Id,hed__Course_Offering__c> courseOfferingMap = new Map<Id,hed__Course_Offering__c>();
        try {
            if(!courseOfferingFlag) {
                List<hed__Course_Offering__c> courseOfferings = [Select Id,Course_Version__c from hed__Course_Offering__c where Id IN :ids];
                for(hed__Course_Offering__c courseOff : courseOfferings) {
                    courseOfferingMap.put(courseOff.Id, courseOff);
                }
            }
            courseOfferingFlag = true;
            
        } catch(Exception ex){
            System.debug('Exception occurred :::' + ex);
        }
        return courseOfferingMap;
    }

    public static Faculty_Booking__c createFacultyBooking(requestSessionDataWrapper request,DateTime startDateVal,DateTime endDateVal,Map<String,Faculty_Booking__c> facultyBookedMap,Session__c sess,Id courseOfferingId)
    {   
        Set<Id> accountIds=new Set<Id>();
        Map<Id,Id> accPersonAccMap=new Map<Id,Id>();       
        accountIds.add(request.facultyId);      
        List<Account> accList=new List<Account>();
        /*accList=[SELECT Id, Name, PersonContactId FROM Account WHERE Id IN :accountIds];
        for(Account acc:accList){
            accPersonAccMap.put(acc.id,acc.PersonContactId);
        }*/
        Faculty_Booking__c faculty=new Faculty_Booking__c();
        //hed__Course_Offering__c courseOffData = [Select Id,Course_Version__c from hed__Course_Offering__c where Id=:courseOfferingId];
        hed__Course_Offering__c courseOffData = globalCourseoffMap?.get(courseOfferingId);
        System.debug('courseOffData change:::' + courseOffData);
        if(sess!=NULL && !facultyBookedMap.keyset().isEmpty() && facultyBookedMap.keyset().contains(request.facultyId+'_'+sess.Start_Date_Time__c+'_'+sess.End_Date_Time__c))
        {
            faculty.Id=facultyBookedMap.get(request.facultyId+'_'+sess.Start_Date_Time__c+'_'+sess.End_Date_Time__c).Id;
        }
        faculty.Activity_type__c=request.activityType;
        if(!String.isBlank(request.facilityId))
        {
            faculty.Facility__c=request.facilityId;
        }
        faculty.Booked_By__c=request.facultyId;
        if(startDateVal!=null)
        {
            faculty.Start_Date_Time__c=startDateVal;
        }
        if(endDateVal!=null)
        {
            faculty.End_Date_Time__c=endDateVal;
        }
        faculty.Course_Version__c=courseOffData.Course_Version__c;
        faculty.Type__c='Actual';
        return faculty;
    }
    public static set<Date> returnDatesBtwTwoDates(Date stDate,Date endDate){
        set<Date> datesBtwTwoDates = new set<Date>();
        for(integer i=0;i<=stDate.daysBetween(endDate);i++){
            Date addingDAte = stDate.addDays(i);
            Integer year_p = addingDate.year();
            Integer month_p = addingDate.month();
            Integer day_p = addingDate.day();
            Date myDT = Date.newInstance(year_p, month_p, day_p);
            datesBtwTwoDates.add(myDT);
        }
        return datesBtwTwoDates;
    }
    //session overlapping validation
    public static String doValidate(DateTime startDateTimes,DateTime endDateTimes, Id courseOfferingId){
        String error;
        List<Session__c> sessionsList = new List<Session__c>();
        if(mapOfcourseOfferingAndSessions.containsKey(courseOfferingId)){
            sessionsList = mapOfcourseOfferingAndSessions.get(courseOfferingId);
        }
        if(!sessionsList.isEmpty() ){
            for(Session__c sesObj:sessionsList){
                if((sesObj.Start_Date_Time__c >= startDateTimes && sesObj.Start_Date_Time__c < endDateTimes) || (sesObj.End_Date_Time__c > startDateTimes && sesObj.End_Date_Time__c <= endDateTimes))  {
                    system.debug('session'+sesObj.Name);
                    error='Sessions is overlapping';
                }
            }
        }
        return error;
    }
    //faculty booking overlapping validation
    public static String doFacultyBookingValidate(DateTime startDateTimes,DateTime endDateTimes, Id facultyId,Id facultyBookingId){
        String error=null;
        List<Faculty_Booking__c> facultyBookingList = new List<Faculty_Booking__c>();
        if(facultyBookingMap.containsKey(facultyId)){
            facultyBookingList = facultyBookingMap.get(facultyId);
        }

        if(!facultyBookingList.isEmpty() ){
            for(Faculty_Booking__c facBookingObj:facultyBookingList){
                if(String.isBlank(facultyBookingId)|| (!String.isBlank(facultyBookingId) && facultyBookingId!=facBookingObj.Id)){
                    if((facBookingObj.Start_Date_Time__c >= startDateTimes && facBookingObj.Start_Date_Time__c < endDateTimes) || (facBookingObj.End_Date_Time__c > startDateTimes && facBookingObj.End_Date_Time__c <= endDateTimes))  {
                        error='faculty was already booked';
                	}
                }
            }
        }
        return error;
    }
    //facility booking overlapping validation
    public static String doFacilityBookingValidate(DateTime startDateTimes,DateTime endDateTimes, Id facilityId,Id facilityBookingId){
        String error=null;
        List<Facility_Booking__c> facilityBookingList = new List<Facility_Booking__c>();
        if(facilityBookingMap.containsKey(facilityId)){
            facilityBookingList = facilityBookingMap.get(facilityId);
        }

        if(!facilityBookingList.isEmpty() ){
            for(Facility_Booking__c facilityBookObj:facilityBookingList){
                if(String.isBlank(facilityBookingId)|| (!String.isBlank(facilityBookingId) && facilityBookingId!=facilityBookObj.Id)){
                    if((facilityBookObj.Start_Date_and_Time__c >= startDateTimes && facilityBookObj.Start_Date_and_Time__c < endDateTimes) || (facilityBookObj.End_Date_and_Time__c > startDateTimes && facilityBookObj.End_Date_and_Time__c <= endDateTimes))  {
                        error='facility was already booked';
                	}
                }
            }
        }
        return error;
    }
    public static boolean checkFacultyBookingValidation(String facultyId,List<Faculty_Booking__c> facultyBookingList,DateTime startDateVal,DateTime endDateVal){
       	boolean checkFacbook=false;
        if(!facultyBookingList.isEmpty())
        {
            for(Faculty_Booking__c facbook:facultyBookingList)
            {
               if(facbook.Start_Date_Time__c<>null && facbook.End_Date_Time__c<>null)
               {
                system.debug('facbook.Start_Date_Time__c-->'+facbook.Start_Date_Time__c);
                system.debug('facbook.End_Date_Time__c-->'+facbook.End_Date_Time__c);
                system.debug('startDateVal-->'+startDateVal);
                system.debug('endDateVal-->'+endDateVal);
                if (!(startDateVal >= facbook.End_Date_Time__c || endDateVal <= facbook.Start_Date_Time__c))
                   //if((facbook.Start_Date_Time__c<=startDateVal) && (facbook.End_Date_Time__c>=endDateVal ))
                   {
                       checkFacbook=true;
                   }
               }
            }
        }
        return checkFacbook;
    }

    public static boolean checkFacilityBookingValidation(String facultyId,List<Facility_Booking__c>  facilityBookingList,DateTime startDateVal,DateTime endDateVal){
       	boolean checkFacbook=false;
        if(!facilityBookingList.isEmpty() || facilityBookingList!=null)
        {
            for(Facility_Booking__c facbook:facilityBookingList)
            {
               if(facbook.Start_Date_and_Time__c<>null && facbook.End_Date_and_Time__c<>null)
               {
                   system.debug('facbook.Start_Date_and_Time__c==>'+facbook.Start_Date_and_Time__c);
                   system.debug('startDateVal==>'+startDateVal);
                   
                   system.debug('facbook.End_Date_and_Time__c==>'+facbook.End_Date_and_Time__c);
                   system.debug('endDateVal==>'+endDateVal);
                   
                   if((facbook.Start_Date_and_Time__c<=startDateVal) && (facbook.End_Date_and_Time__c>=endDateVal ))
                   {
                       checkFacbook=true;
                   }
               }
            }
        }
        return checkFacbook;
    }
    
    public static List<K42_Campus_Holiday__c> checkForHolidayDates(String courseOfferingId,Date stDate, Date endDate){
        List<Date> datesOfHolidays = new List<Date>();
        List<HolidaysWrapper> holidayWrappers = new List<HolidaysWrapper>();
        hed__Course_Offering__c couOff = [Select Id, hed__Term__r.Campus__c from hed__Course_Offering__c where Id=:courseOfferingId];
        List<K42_Campus_Holiday__c> holidays = [
                                                SELECT Id, K42_Holiday__r.Name, K42_Holiday__r.K42_Hol_Start_Date__c, K42_Holiday__r.K42_Hol_End_Date__c
                                                FROM K42_Campus_Holiday__c 
                                                WHERE Campus__c = :couOff.hed__Term__r.Campus__c 
                                                AND K42_Holiday__r.K42_Hol_Start_Date__c >= :stDate 
                                                AND K42_Holiday__r.K42_Hol_End_Date__c <= :endDate
                                                ];

        return holidays;
    }

    public class HolidaysWrapper{
        public String Name;
        public Date Frm;
        public Date To;
    }
   /* public static void testCoverage() {
        String str = '';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
        str = '1';
    }*/
 
}