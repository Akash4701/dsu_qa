@RestResource(urlMapping='/validateSession')
global class RestApi_ValidateSession {
    @HttpPost
    global static void doValidateSession(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
        try{ 
            requestSessionWrapper requestAll = (requestSessionWrapper) JSON.deserialize(RestContext.request.requestBody.toString(),requestSessionWrapper.class);
            responseSessionWrapper responseAll=new responseSessionWrapper();
            List<requestSessionDataWrapper> requestList=new List<requestSessionDataWrapper>();
            List<responseSessionDataWrapper> responseList=new List<responseSessionDataWrapper>();
            requestList=requestAll.Session;
            if(requestAll.Operation=='Delete')
            {
                if(!requestList.isEmpty())
                {
                    List<String> allSesssionListDelete=new  List<String>();
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
                        List<Session__c> sessionList=new List<Session__c>([SELECT Id,Name FROM Session__c WHERE Id IN:allSesssionListDelete]);
                        if(!sessionList.isEmpty())
                        {
                            for(Session__c session:sessionList)
                            {
                                checkAllSessionRecord.put(session.Id,session);
                            }
                        }
                    }

                    for(requestSessionDataWrapper request:requestList)
                    {
                        Map<String,String> message=new Map<String,String>();
                        responseSessionDataWrapper response=new responseSessionDataWrapper();
                        if(!String.isBlank(request.sessionId))
                        { 
                            if(checkAllSessionRecord.keyset().contains(request.sessionId))
                            {
                                response.success='true';
                                message.put('success','Data is Present to Delete');
                                response.message=message;
                                response.sessionId=request.sessionId;
                            }
                            else
                            {
                                response.success='true';
                                message.put('sessionId','Data is Not Present to Delete');
                                response.message=message;
                                response.sessionId=request.sessionId;
                            }
                            
                        }
                        else 
                        {
                            response.success='true';
                            message.put('sessionId','No Data Found');
                            response.message=message;
                        }
                        responseList.add(response);
                    }
                }
            }
            else
            {
                if(!requestList.isEmpty())
                {
                    Set<String> courseString=new Set<String>();
                    List<String> allFacilityListUpdate=new  List<String>();
                    List<String> allFacultyEmailUpdate=new  List<String>();
                    List<String> allCourseUpdate=new  List<String>();
                    List<String> allActivityType=new  List<String>();
                    List<String> allTerm=new  List<String>();
                    Map<String,Contact> checkFacultyRecord=new Map<String,Contact>();
                    Map<String,hed__Facility__c> checkFacilityRecord=new Map<String,hed__Facility__c>();
                    Map<String,hed__Course_Offering__c> checkCourseOfferingRecord=new Map<String,hed__Course_Offering__c>();
                    Map<String,hed__Course_Enrollment__c> checkCourseEnrollRecord=new Map<String,hed__Course_Enrollment__c>();
                    Map<String,List<Facility_Booking__c>> facilityBookMap=new Map<String,List<Facility_Booking__c>>();
                    Map<String,List<Facility_Booking__c>> termMap=new Map<String,List<Facility_Booking__c>>();
                    Map<String,List<Faculty_Availability__c>> facultyAvailabilityMap=new Map<String,List<Faculty_Availability__c>>();
                    Map<String,List<Faculty_Booking__c>> facultyBookingMap=new Map<String,List<Faculty_Booking__c>>();
                    
                    Schema.DescribeFieldResult F = Facility_Booking__c.Activity_type__c.getDescribe();
                    Schema.sObjectField T = F.getSObjectField();
                    List<PicklistEntry> entries = T.getDescribe().getPicklistValues();
                    for(PicklistEntry pickListVal:entries)
                    {
                        allActivityType.add(String.ValueOf(pickListVal.getLabel()));
                    }
                    for(requestSessionDataWrapper request:requestList)
                    {
                        if(!String.isBlank(request.facultyEmail1))
                        {
                            allFacultyEmailUpdate.add(request.facultyEmail1);
                        }
                        if(!String.isBlank(request.facultyEmail2))
                        {
                            allFacultyEmailUpdate.add(request.facultyEmail2);
                        }
                        if(!String.isBlank(request.facultyEmail3))
                        {
                            allFacultyEmailUpdate.add(request.facultyEmail3);
                        }
                        if(!String.isBlank(request.facilityName))
                        {
                            allFacilityListUpdate.add(request.facilityName);
                        }
                        if(!String.isBlank(request.courseName))
                        {
                            allCourseUpdate.add(request.courseName);
                        }
                        if(!String.isBlank(request.termName))
                        {
                            allTerm.add(request.termName);
                        }
                    }
                    
                    if(!allFacultyEmailUpdate.isEmpty() || !allFacilityListUpdate.isEmpty() || !allCourseUpdate.isEmpty())
                    {
                        List<Contact> contactList=new List<Contact>([SELECT Id,Name,Email FROM Contact WHERE Email IN:allFacultyEmailUpdate AND RecordType.Name='Faculty']);
                        List<hed__Facility__c> facilityList=new List<hed__Facility__c>([SELECT Id,Name FROM hed__Facility__c WHERE Name IN:allFacilityListUpdate]);
                        List<hed__Course__c> courseValidList=new List<hed__Course__c>([SELECT Id,Name FROM hed__Course__c WHERE Name IN:allCourseUpdate]);
                        List<hed__Course_Offering__c> courseList=new List<hed__Course_Offering__c>([SELECT Id,Name,hed__Section_ID__c,hed__Course__r.Name,hed__Term__r.Name,hed__Term__r.hed__Start_Date__c,hed__Term__r.hed__End_Date__c,hed__Start_Date__c,hed__End_Date__c FROM hed__Course_Offering__c WHERE hed__Course__r.Name IN:allCourseUpdate AND hed__Term__r.Name IN:allTerm]);
                        List<hed__Course_Enrollment__c> courseEnrollList=new List<hed__Course_Enrollment__c>();
                            
                        
                        if(!courseValidList.isEmpty())
                        {
                            for(hed__Course__c cou:courseValidList)
                            {
                                courseString.add(cou.Name);
                            }
                        }
                        
                        if(!facilityList.isEmpty())
                        {
                            List<Facility_Booking__c> facilityBookList=new List<Facility_Booking__c>([SELECT Id,Name,Start_Date_and_Time__c,End_Date_and_Time__c,FacilityID__r.Name FROM Facility_Booking__c WHERE FacilityID__c IN: facilityList]);
                            system.debug('@@@facilityBookList'+facilityBookList);
                            if(!facilityBookList.isEmpty())
                            {
                                for(Facility_Booking__c facbook:facilityBookList)
                                {
                                    List<Facility_Booking__c> facList=new List<Facility_Booking__c>();
                                    if(facilityBookMap.keyset().contains(facbook.FacilityID__r.Name))
                                    {
                                        facList=facilityBookMap.get(facbook.FacilityID__r.Name);
                                    }
                                    facList.add(facbook);
                                    facilityBookMap.put(facbook.FacilityID__r.Name,facList);
                                }
                            }
                        }
                        
                        if(!contactList.isEmpty())
                        {
                            List<Faculty_Availability__c> facultyAvailabilityList=new List<Faculty_Availability__c>([SELECT Id,Name,Available_Start_Time__c,Available_End_Time__c,Contact__r.Name,Contact__r.Email FROM Faculty_Availability__c WHERE Contact__c IN: contactList]);
                            List<Faculty_Booking__c> facultyBookingList=new List<Faculty_Booking__c>([SELECT Id,Name,Start_Date_Time__c,End_Date_Time__c,Booked_By__r.Name,Booked_By__r.Email FROM Faculty_Booking__c WHERE Booked_By__c IN: contactList]);
                            if(!facultyAvailabilityList.isEmpty())
                            {
                                for(Faculty_Availability__c facAvailability:facultyAvailabilityList)
                                {
                                    List<Faculty_Availability__c> facAvaList=new List<Faculty_Availability__c>();
                                    if(facultyAvailabilityMap.keyset().contains(facAvailability.Contact__r.Email))
                                    {
                                        facAvaList=facultyAvailabilityMap.get(facAvailability.Contact__r.Email);
                                    }
                                    facAvaList.add(facAvailability);
                                    facultyAvailabilityMap.put(facAvailability.Contact__r.Email,facAvaList);
                                }
                            }
                            if(!facultyBookingList.isEmpty())
                            {
                                for(Faculty_Booking__c facBooking:facultyBookingList)
                                {
                                    List<Faculty_Booking__c> facBookList=new List<Faculty_Booking__c>();
                                    if(facultyBookingMap.keyset().contains(facBooking.Booked_By__r.Email))  
                                    {   
                                        facBookList=facultyBookingMap.get(facBooking.Booked_By__r.Email);   
                                    }   
                                    facBookList.add(facBooking);    
                                    facultyBookingMap.put(facBooking.Booked_By__r.Email,facBookList);
                                }
                            }
                        }

                        if(!contactList.isEmpty())
                        {
                            for(Contact cont:contactList)
                            {
                                if(allFacultyEmailUpdate.contains(cont.Email))
                                {
                                    checkFacultyRecord.put(cont.Email,cont);
                                }
                            }
                        }
                        if(!facilityList.isEmpty())
                        {
                            for(hed__Facility__c facility:facilityList)
                            {
    
                                checkFacilityRecord.put(facility.Name,facility);
                            }
                        }
                        if(!courseList.isEmpty())
                        {
                            courseEnrollList=[SELECT Id,hed__Course_Offering__r.hed__Course__r.Name,hed__Course_Offering__r.hed__Section_ID__c,
                                              hed__Course_Offering__r.hed__Term__r.Name,hed__Contact__r.Email
                                              FROM hed__Course_Enrollment__c WHERE hed__Course_Offering__c IN:courseList AND hed__Contact__c IN:contactList];
                            for(hed__Course_Offering__c course:courseList)
                            {
    
                                checkCourseOfferingRecord.put(course.hed__Course__r.Name+'_'+course.hed__Section_ID__c+'_'+course.hed__Term__r.Name,course);
                            }
                            if(!courseEnrollList.isEmpty())
                        	{
                                for(hed__Course_Enrollment__c courseEnroll:courseEnrollList)
                                {
        
                                    checkCourseEnrollRecord.put(courseEnroll.hed__Contact__r.Email+'_'+courseEnroll.hed__Course_Offering__r.hed__Course__r.Name+'_'+courseEnroll.hed__Course_Offering__r.hed__Section_ID__c+'_'+courseEnroll.hed__Course_Offering__r.hed__Term__r.Name,courseEnroll);
                                }
                            }
                        }
                    }

                    Map<DateTime,DateTime> startEnddata=new Map<DateTime,DateTime>();
                    Map<String,String> doValidateSession=new Map<String,String>();
                    if(!checkCourseOfferingRecord.keyset().isEmpty()){
                    	doValidateSession=doValidate(requestList,checkCourseOfferingRecord.values());
                    }
                    
                    for(requestSessionDataWrapper request:requestList)
                    {
                        responseSessionDataWrapper response=new responseSessionDataWrapper();
                        Boolean invalid=false;
                        Boolean invalidTerm=false;
                        Map<String,String> messageError=new Map<String,String>();
                        DateTime startDateVal;
                        DateTime endDateVal;
                        Date startDate;
                        Date endDate;
                        
                        if(String.isBlank(request.startDate) && String.isBlank(request.endDate))
                        { 
                            messageError.put('startDate','Data is mandatory for Start Date');
                            messageError.put('endDate','Data is mandatory for End Date');
                            response.message=messageError;
                            invalid=true;
                        }
                        else
                        {
                            startDateVal=toDateTime(request.startDate);
                            endDateVal=toDateTime(request.endDate);
                            startDate=toDate(request.startDate);
                            endDate=toDate(request.endDate);

                            if(startDateVal>=endDateVal){
                                messageError.put('startDate','Start Date/Time cannot be greater then End Date/Time');
                                messageError.put('endDate','End Date/Time cannot be lesser then Start Date/Time');
                                response.message=messageError;
                                invalid=true;
                            }
                            else {
                                system.debug(startDateVal);
                                if(startDateVal<=system.now()){
                                    messageError.put('startDate','Start Date/Time cannot be Past Date/Time');
                                    response.message=messageError;
                                    invalid=true;
                                }
                                system.debug(endDateVal);
                                if(endDateVal<=system.now()){
                                    messageError.put('endDate','End Date/Time cannot be Past Date/Time');
                                    response.message=messageError;
                                    invalid=true;
                                }
                            }
                            if(invalid){
                                startDateVal=null;
                                endDateVal=null;
                                startDate=null;
                                endDate=null;
                            }
                        }
                        
                        if(!String.isBlank(request.activityType) && !allActivityType.contains(request.activityType))
                        { 
                            messageError.put('activityType',request.activityType+' Actvity Type is Incorrect');
                            response.message=messageError;
                            invalid=true;
                        }
                        if(String.isBlank(request.termName))
                        { 
                            messageError.put('termName','Data is mandatory');
                            response.message=messageError;
                            invalid=true;
                        }
                        if(String.isBlank(request.courseName))
                        { 
                            messageError.put('courseName','Data is mandatory');
                            response.message=messageError;
                            invalid=true;
                        }
                        else if(!courseString.contains(request.courseName)){
                            messageError.put('courseName',request.courseName+' Course Name is Incorrect');
                            response.message=messageError;
                            invalid=true;
                        }
                        else if(!String.isBlank(request.facultyEmail1+'_'+request.courseName+'_'+request.sectionName+'_'+request.termName) && !checkCourseEnrollRecord.keyset().contains(request.facultyEmail1+'_'+request.courseName+'_'+request.sectionName+'_'+request.termName)){
                            messageError.put('courseName',request.courseName+' Course is not Enrolled with Faculty ' +request.facultyName1);
                            response.message=messageError;
                            invalid=true;
                        	invalidTerm=true;
                        }
                        if(String.isBlank(request.sectionName))
                        { 
                            messageError.put('sectionName','Data is mandatory');
                            response.message=messageError;
                            invalid=true;
                        }
                        if(!String.isBlank(request.courseName+'_'+request.sectionName+'_'+request.termName) && !checkCourseOfferingRecord.keyset().contains(request.courseName+'_'+request.sectionName+'_'+request.termName))
                        { 
                            messageError.put('sectionName',request.sectionName+' Section Name is Incorrect');
                            response.message=messageError;
                            invalid=true;
                            if(invalidTerm){
                                messageError.put('termName',request.termName+' Term Name is Incorrecnt');
                            	response.message=messageError;
                            }
                        }
                        else if(courseString.contains(request.courseName) && !String.isBlank(request.courseName+'_'+request.sectionName+'_'+request.termName) && checkCourseOfferingRecord.keyset().contains(request.courseName+'_'+request.sectionName+'_'+request.termName))
                        { 
                            
                            if(!String.isBlank(request.startDate) && !String.isBlank(request.endDate))
                            {
                                boolean checkCourse=false;
                                boolean checkTerm=false;
                                hed__Course_Offering__c courseOff=new hed__Course_Offering__c();
                                courseOff=checkCourseOfferingRecord.get(request.courseName+'_'+request.sectionName+'_'+request.termName);
                                if(courseOff.hed__Term__r.hed__Start_Date__c<>null && courseOff.hed__Term__r.hed__End_Date__c<>null)
                                { 
                                    if(courseOff.hed__Term__r.hed__Start_Date__c>=startDate ||  courseOff.hed__Term__r.hed__End_Date__c<=endDate)
                                    {
                                        checkTerm=true;
                                    }
                                }

                                if(courseOff.hed__Start_Date__c<>null && courseOff.hed__End_Date__c<>null)
                                { 
                                    if(courseOff.hed__Start_Date__c>=startDate ||  courseOff.hed__End_Date__c<=endDate)
                                    {
                                        checkCourse=true;
                                    }
                                }
                                if(checkCourse==true)
                                {
                                    messageError.put('sectionName','CourseOffering is not Available in this timeslot');
                                    response.message=messageError;
                                    invalid=true;
                                }
                                else
                                {
                                    response.courseOfferingId=checkCourseOfferingRecord.get(request.courseName+'_'+request.sectionName+'_'+request.termName).Id;
                                }
                                if(checkTerm==true)
                                {
                                    messageError.put('termName','Term is not Available in this timeslot');
                                    response.message=messageError;
                                    invalid=true;
                                }
                                else
                                {
                                    response.courseOfferingId=checkCourseOfferingRecord.get(request.courseName+'_'+request.sectionName+'_'+request.termName).Id;
                                    if(!doValidateSession.keyset().isEmpty() && doValidateSession.keyset().contains(request.termName+'_'+request.courseName+'_'+request.sectionName+'_'+request.activityType+'_'+request.startDate+'_'+request.endDate)){
                                        String sessionOverLap=doValidateSession.get(request.termName+'_'+request.courseName+'_'+request.sectionName+'_'+request.activityType+'_'+request.startDate+'_'+request.endDate);
                                        if(!String.isBlank(sessionOverLap)){
                                            messageError.put('courseName',sessionOverLap);
                                            response.message=messageError;
                                            invalid=true;
                                        }
                                    }
                                }
                            }
                        }

                        if(!String.isBlank(request.facilityName) && !checkFacilityRecord.keyset().contains(request.facilityName))
                        { 
                            messageError.put('facilityName',request.facilityName+' Facility name is Incorrect');
                            response.message=messageError;
                            invalid=true;
                        }
                        else if(!String.isBlank(request.facilityName) && checkFacilityRecord.keyset().contains(request.facilityName))
                        {
                            if(!String.isBlank(request.startDate) && !String.isBlank(request.endDate))
                            {
                                boolean checkFbook=false;
                                if(facilityBookMap.keyset().contains(request.facilityName))
                                {
                                    List<Facility_Booking__c> facilityBList=new List<Facility_Booking__c>();
                                    facilityBList=facilityBookMap.get(request.facilityName);
                                    if(!facilityBList.isEmpty())
                                    {
                                        for(Facility_Booking__c fbook:facilityBList)
                                        {
                                           if(fbook.Start_Date_and_Time__c<>null && fbook.End_Date_and_Time__c<>null)
                                           {
                                               if(fbook.Start_Date_and_Time__c<=startDateVal &&  fbook.End_Date_and_Time__c>=startDateVal)
                                               {
                                                   checkFbook=true;
                                               }  
                                               else if(fbook.Start_Date_and_Time__c<=endDateVal &&  fbook.End_Date_and_Time__c>=endDateVal)
                                               {
                                                   checkFbook=true;
                                               }
                                           }
                                           
                                        }
                                    }
                                }
                                else{
                                    response.facilityId=checkFacilityRecord.get(request.facilityName).Id;
                                }
                                if(checkFbook==true)
                                {
                                    messageError.put('facilityName','Facility is already Booked in this timeslot');
                                    response.message=messageError;
                                    invalid=true;
                                }
                                else
                                {
                                    response.facilityId=checkFacilityRecord.get(request.facilityName).Id;
                                }
                            }
                            
                        }
                            
                        if(!String.isBlank(request.facultyEmail1) && !checkFacultyRecord.keyset().contains(request.facultyEmail1))
                        { 
                            messageError.put('facultyEmail1',request.facultyEmail1+' Faculty email is Incorrect');
                            response.message=messageError;
                            invalid=true;
                        }
                        else{
                            if(!String.isBlank(response.facultyId))
                            {
                                response.facultyId=response.facultyId+';'+checkFacultyRecord.get(request.facultyEmail1).Id;
                            }
                            else{
                                response.facultyId=checkFacultyRecord.get(request.facultyEmail1).Id;
                            }
                        }
                        if(!String.isBlank(request.facultyEmail2) && !checkFacultyRecord.keyset().contains(request.facultyEmail2))
                        { 
                            messageError.put('facultyEmail2',request.facultyEmail2+' Faculty email is Incorrect');
                            response.message=messageError;
                            invalid=true;
                        }
                        else if (!String.isBlank(request.facultyEmail2)){
                            if(!String.isBlank(response.facultyId))
                            {
                                response.facultyId=response.facultyId+';'+checkFacultyRecord.get(request.facultyEmail2).Id;
                            }
                            else{
                                response.facultyId=checkFacultyRecord.get(request.facultyEmail2).Id;
                            }
                        }
                        if(!String.isBlank(request.facultyEmail3) && !checkFacultyRecord.keyset().contains(request.facultyEmail3))
                        { 
                            messageError.put('facultyEmail3',request.facultyEmail3+' Faculty email is Incorrect');
                            response.message=messageError;
                            invalid=true;
                        }
                        else if (!String.isBlank(request.facultyEmail3)){
                            if(!String.isBlank(response.facultyId))
                            {
                                response.facultyId=response.facultyId+';'+checkFacultyRecord.get(request.facultyEmail3).Id;
                            }
                            else{
                                response.facultyId=checkFacultyRecord.get(request.facultyEmail3).Id;
                            }
                        }
                        if(!String.isBlank(request.startDate) && !String.isBlank(request.endDate))
                        {
                            boolean checkFacbook1=false; 
                            boolean checkFacbook2=false; 
                            boolean checkFacbook3=false; 
                            boolean checkAavbook1=false;
                            boolean checkAavbook2=false;
                            boolean checkAavbook3=false;
                            //Check the Faculty Available Data
                            /*if(!String.isBlank(request.facultyEmail1) && checkFacultyRecord.keyset().contains(request.facultyEmail1) && facultyAvailabilityMap.keyset().contains(request.facultyEmail1))
                            {
                                checkAavbook1=checkFacultyAvailability(request.facultyEmail1,facultyAvailabilityMap,startDateVal,endDateVal);
                            }
                            else
                            {
                                checkAavbook1=true;
                            }
                            if(!String.isBlank(request.facultyEmail2) && checkFacultyRecord.keyset().contains(request.facultyEmail2) && facultyAvailabilityMap.keyset().contains(request.facultyEmail2))
                            {
                                checkAavbook2=checkFacultyAvailability(request.facultyEmail2,facultyAvailabilityMap,startDateVal,endDateVal);
                            }
                            else
                            {
                                checkAavbook2=true;
                            }
                            if(!String.isBlank(request.facultyEmail3) && checkFacultyRecord.keyset().contains(request.facultyEmail3) && facultyAvailabilityMap.keyset().contains(request.facultyEmail3))
                            {
                                checkAavbook3=checkFacultyAvailability(request.facultyEmail3,facultyAvailabilityMap,startDateVal,endDateVal);
                            }
                            else
                            {
                                checkAavbook3=true;
                            }*/
              
                            //Check the Faculty Booking Data
                            if(!String.isBlank(request.facultyEmail1) && checkFacultyRecord.keyset().contains(request.facultyEmail1) && facultyBookingMap.keyset().contains(request.facultyEmail1))
                            {
                                checkFacbook1=checkFacultyBooking(request.facultyEmail1,facultyBookingMap,startDateVal,endDateVal);
                            }
                            else
                            {
                                checkFacbook1=false;
                            }
                            if(!String.isBlank(request.facultyEmail2) && checkFacultyRecord.keyset().contains(request.facultyEmail2) && facultyBookingMap.keyset().contains(request.facultyEmail2))
                            {
                                checkFacbook2=checkFacultyBooking(request.facultyEmail2,facultyBookingMap,startDateVal,endDateVal);                            
                            }
                            else
                            {
                                checkFacbook2=false;
                            }
                            if(!String.isBlank(request.facultyEmail3) && checkFacultyRecord.keyset().contains(request.facultyEmail3) && facultyBookingMap.keyset().contains(request.facultyEmail3))
                            {
                                checkFacbook3=checkFacultyBooking(request.facultyEmail3,facultyBookingMap,startDateVal,endDateVal);
                            }
                            else
                            {
                                checkFacbook3=false;
                            }

                            //Check the Faculty Eligible Data for Booking on Availablity
                            if(!String.isBlank(request.facultyEmail1) && checkFacultyRecord.keyset().contains(request.facultyEmail1) && checkAavbook1==false && checkFacbook1==false)
                            {
                                response.facultyIdEligibleForBooking=checkFacultyRecord.get(request.facultyEmail1).Id;
                            }
                            else if(!String.isBlank(request.facultyEmail2) && checkFacultyRecord.keyset().contains(request.facultyEmail2) && checkAavbook2==false && checkFacbook2==false)
                            {
                                response.facultyIdEligibleForBooking=checkFacultyRecord.get(request.facultyEmail2).Id;
                            }
                            else if(!String.isBlank(request.facultyEmail3) && checkFacultyRecord.keyset().contains(request.facultyEmail3) && checkAavbook3==false && checkFacbook3==false)
                            {
                                response.facultyIdEligibleForBooking=checkFacultyRecord.get(request.facultyEmail3).Id;
                            }
                            
                            if(checkAavbook1==true && checkAavbook2==true && checkAavbook3==true  )
                            {
                                if(!String.isBlank(request.facultyEmail1) && checkFacultyRecord.keyset().contains(request.facultyEmail1))
                                {
                                   messageError.put('facultyEmail1','Faculty is not Available in this timeslot');
                                }
                                if(!String.isBlank(request.facultyEmail2) && checkFacultyRecord.keyset().contains(request.facultyEmail2))
                                {
                                   messageError.put('facultyEmail2','Faculty is not Available in this timeslot');
                                }
                                if(!String.isBlank(request.facultyEmail3) && checkFacultyRecord.keyset().contains(request.facultyEmail3))
                                {
                                   messageError.put('facultyEmail3','Faculty is not Available in this timeslot');
                                }
                                response.message=messageError;
                                invalid=true;
                            }
                            else if(checkFacbook1==true && checkFacbook2==true && checkFacbook3==true  )
                            {
                                if(!String.isBlank(request.facultyEmail1) && checkFacultyRecord.keyset().contains(request.facultyEmail1))
                                {
                                   messageError.put('facultyEmail1','Faculty is already Booked in this timeslot');
                                }
                                if(!String.isBlank(request.facultyEmail2) && checkFacultyRecord.keyset().contains(request.facultyEmail2))
                                {
                                   messageError.put('facultyEmail2','Faculty is already Booked in this timeslot');
                                }
                                if(!String.isBlank(request.facultyEmail3) && checkFacultyRecord.keyset().contains(request.facultyEmail3))
                                {
                                   messageError.put('facultyEmail3','Faculty is already Booked in this timeslot');
                                }
                                response.message=messageError;
                                invalid=true;
                            }
                            else if (response.facultyIdEligibleForBooking==null)
                            {
                                if(!String.isBlank(request.facultyEmail1) && checkFacultyRecord.keyset().contains(request.facultyEmail1))
                                {
                                   messageError.put('facultyEmail1','Faculty either Booked in this timeslot');
                                }
                                if(!String.isBlank(request.facultyEmail2) && checkFacultyRecord.keyset().contains(request.facultyEmail2))
                                {
                                   messageError.put('facultyEmail2','Faculty either Booked in this timeslot');
                                }
                                if(!String.isBlank(request.facultyEmail3) && checkFacultyRecord.keyset().contains(request.facultyEmail3))
                                {
                                   messageError.put('facultyEmail3','Faculty either Booked in this timeslot');
                                }
                                response.message=messageError;
                                invalid=true;
                            }
                        }
                        if(invalid==false)
                        {
                            response.success='true';
                            messageError.put('success','Data can be added');
                            response.message=messageError;
                            
                        }
                        else{
                            response.success='false';
                        }
                        response.courseName=request.courseName;
                        response.sectionName=request.sectionName;
                        response.activityType=request.activityType;
                        response.startDate=request.startDate;
                        response.endDate=request.endDate;
                        response.facilityName=request.facilityName;
                        response.facultyName1=request.facultyName1;
                        response.facultyEmail1=request.facultyEmail1;
                        response.facultyName2=request.facultyName2;
                        response.facultyEmail2=request.facultyEmail2;
                        response.facultyName3=request.facultyName3;
                        response.facultyEmail3=request.facultyEmail3;
                        response.sessionId=request.sessionId;
                        response.termName=request.termName;
                        response.sessionTopic=request.sessionTopic;
                        response.presentationNumber=request.presentationNumber;
                        response.sessionPlan=request.sessionPlan;
                        response.dayNo=request.dayNo;
                        responseList.add(response);
                    }
                }
            }
            List<responseSessionDataWrapper> responseListFinal=new List<responseSessionDataWrapper>();
            Set<String> duplicateSet=new Set<String>();
            //Check for Duplicate in the Excel
            if(!responseList.isEmpty()){
                for(responseSessionDataWrapper response: responseList){
                    
                    if(response.success=='true'){
                        if(duplicateSet.contains(response.facilityId+'_'+response.activityType+'_'+response.facultyId+'_'+response.courseOfferingId+'_'+response.termName+'_'+response.startDate+'_'+response.endDate)){
                        	response.success='false';
                            Map<String,String> messageError=new Map<String,String>();
                            messageError.put('termName','Duplicate record present in same load file');
                            messageError.put('activityType','Duplicate record present in same load file');
                            messageError.put('facultyEmail1','Duplicate record present in same load file');
                            messageError.put('startDate','Duplicate record present in same load file');
                            messageError.put('endDate','Duplicate record present in same load file');
                            messageError.put('facultyName1','Duplicate record present in same load file');
                            messageError.put('facilityName','Duplicate record present in same load file');
                            messageError.put('sectionName','Duplicate record present in same load file');
                            messageError.put('courseName','Duplicate record present in same load file');
                            response.message=messageError;
                        }
                        else{
                           duplicateSet.add(response.facilityId+'_'+response.activityType+'_'+response.facultyId+'_'+response.courseOfferingId+'_'+response.termName+'_'+response.startDate+'_'+response.endDate); 
                        }
                        responseListFinal.add(response);
                    }
                    else{
                        responseListFinal.add(response);
                    }
                }
            }
            responseAll.Session=responseListFinal;
            jsonResponse=json.serialize(responseAll);
            res.responseBody=Blob.valueOf(jsonResponse); 
            res.statusCode = 200;
        }Catch(Exception e){
            res.statusCode = 400;         
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
                                                                                                           
    //Wrapper class for the request from API 
    public class requestSessionWrapper {
        public List<requestSessionDataWrapper> Session {get;set;}
        public string Operation {get;set;}
   
    }
    public class requestSessionDataWrapper {
        public String courseName {get;set;}
        public String sectionName {get;set;}
        public String activityType {get;set;}
        public String startDate {get;set;}
        public String endDate {get;set;}
        public String facilityName {get;set;}  
        public String facultyName1 {get;set;}  
        public String facultyEmail1 {get;set;} 
        public String facultyName2 {get;set;}  
        public String facultyEmail2 {get;set;} 
        public String facultyName3 {get;set;}  
        public String facultyEmail3 {get;set;} 
        public String sessionId {get;set;}
        public String termName {get;set;}
        public String sessionTopic {get;set;}
        public String presentationNumber {get;set;}
        public String sessionPlan {get;set;}
        public String dayNo {get;set;}
    }
    public class responseSessionWrapper {
        public List<responseSessionDataWrapper> Session {get;set;}
    }
    public class responseSessionDataWrapper {
        public String courseName {get;set;}
        public String sectionName {get;set;}
        public String sessionId {get;set;}
        public String activityType {get;set;}
        public String startDate {get;set;}
        public String endDate {get;set;}
        public String facilityName {get;set;}  
        public String facultyName1 {get;set;}  
        public String facultyEmail1 {get;set;} 
        public String facultyName2 {get;set;}  
        public String facultyEmail2 {get;set;} 
        public String facultyName3 {get;set;}  
        public String facultyEmail3 {get;set;} 
        public string success='true';
        public Map<String,String> message;
        public String courseOfferingId {get;set;}
        public String facultyId {get;set;}
        public String facultyIdEligibleForBooking {get;set;}  
        public String facilityId {get;set;}
        public String termName {get;set;}
        public String sessionTopic {get;set;}
        public String presentationNumber {get;set;}
        public String sessionPlan {get;set;}
        public String dayNo {get;set;}
    }  
    public static DateTime toDateTime(String DateTimevalue) {
        List<String> DateAndTimeList = DateTimevalue.split('T');
        List<String> dayList = DateAndTimeList[0].split('-');
        List<string> timeList = DateAndTimeList[1].split(':');
        DateTime dt = DateTime.newInstance(Integer.valueOf(dayList[0]), Integer.valueOf(dayList[1]),Integer.valueOf(dayList[2]), Integer.valueOf(timeList[0]), Integer.valueOf(timeList[1]),  Integer.valueOf(timeList[2].split('\\.')[0]));
        return dt;
    }  
    public static Date toDate(String DateTimevalue) {
        List<String> DateAndTimeList = DateTimevalue.split('T');
        List<String> dayList = DateAndTimeList[0].split('-');
        List<string> timeList = DateAndTimeList[1].split(':');
        Date dt = Date.newInstance(Integer.valueOf(dayList[0]), Integer.valueOf(dayList[1]),Integer.valueOf(dayList[2]));
        return dt;
    }  
    
    public static boolean checkFacultyAvailability(String facultyEmail,Map<String,List<Faculty_Availability__c>>  facultyAvailabilityMap,DateTime startDateVal,DateTime endDateVal)
    {
        boolean checkAavbook=false;
        List<Faculty_Availability__c> facultyAList=new List<Faculty_Availability__c>();
        facultyAList=facultyAvailabilityMap.get(facultyEmail);
        if(!facultyAList.isEmpty())
        {
            for(Faculty_Availability__c facAvailable:facultyAList)
            {
               if(facAvailable.Available_Start_Time__c<>null && facAvailable.Available_End_Time__c<>null)
               {
                   if(facAvailable.Available_Start_Time__c>=startDateVal && facAvailable.Available_End_Time__c<=endDateVal)
                   {
                       checkAavbook=true;
                   }                                               
               }
            }
        }
        return checkAavbook;
    }
    public static boolean checkFacultyBooking(String facultyEmail,Map<String,List<Faculty_Booking__c>>  facultyBookingMap,DateTime startDateVal,DateTime endDateVal)
    {
        boolean checkFacbook=false;
        List<Faculty_Booking__c> facultyBList=new List<Faculty_Booking__c>();
        facultyBList=facultyBookingMap.get(facultyEmail);
        if(!facultyBList.isEmpty())
        {
            for(Faculty_Booking__c facbook:facultyBList)
            {
               if(facbook.Start_Date_Time__c<>null && facbook.End_Date_Time__c<>null)
               {
                   if((facbook.Start_Date_Time__c<=startDateVal) && (facbook.End_Date_Time__c>=endDateVal ))
                   {
                       system.debug('@@@facbook'+facbook.Id);
                       checkFacbook=true;
                   }                                               
               }
            }
        }
        return checkFacbook;
    }
    public static Map<String,String> doValidate(List<requestSessionDataWrapper> requestList, List<hed__Course_Offering__c> courseOfferingVal){
        Set<String> allTerm=new Set<String>();
        Map<String,String> courseOfferingdata=new Map<String,String>();
        hed__Course_Offering__c[] getTermIdfromCourseOffering = [Select Id,Name,hed__Term__c from hed__Course_Offering__c where Id IN:courseOfferingVal];
        if(!getTermIdfromCourseOffering.isEmpty())
        {
            for(hed__Course_Offering__c course:getTermIdfromCourseOffering){
                allTerm.add(course.hed__Term__c);
            }
        }
        if(!allTerm.isEmpty()){
            for(Session__c sesObj:[Select Id,Name,Start_Date_Time__c,End_Date_Time__c from Session__c where Course_Offering__r.hed__Term__c IN:allTerm]){
                for(requestSessionDataWrapper request:requestList){
                    if(!String.isBlank(request.startDate) && !String.isBlank(request.endDate)){
                        DateTime startDateTimes=toDateTime(request.startDate);
                        DateTime endDateTimes=toDateTime(request.endDate);
                        if((sesObj.Start_Date_Time__c >= startDateTimes && sesObj.Start_Date_Time__c < endDateTimes) || (sesObj.End_Date_Time__c > startDateTimes && sesObj.End_Date_Time__c <= endDateTimes)){
                            courseOfferingdata.put(request.termName+'_'+request.courseName+'_'+request.sectionName+'_'+request.activityType+'_'+request.startDate+'_'+request.endDate,sesObj.Name+' these session was overlapping');
                		}
                    }
                }
        	}
        }
        return courseOfferingdata;
    }
       
}