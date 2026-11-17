public class ActivityHandler {
    public static Boolean isFirstTime = true;
    public static void updateCourseVersionWithEndDate(List<Activity__c> newRecords){
        Map<Id,List<Activity__c>> mapOfActivity= new Map<Id,List<Activity__c>>();
        Map<Id,Decimal> mapOfIdandDurations = new Map<Id,Decimal>();
        Set<Id> setOfCVIds = new Set<Id>();
        for(Activity__c actObj:newRecords){
            setOfCVIds.add(actObj.Subject__c);
        }
        //List<Activity__c> updateList = new List<Activity__c>();
        List<Activity__c> activityList = [Select Id,Name,Subject__c,Duration__c,Subject__r.Term__r.Program_Plan__r.Working_Days__c,Activity_Duration__c,Start_date__c,End_date__c from Activity__c where Subject__c IN:setOfCVIds];
        Set<Date> holidaysSet = new Set<Date>();
        List<K42_Holiday__c> holidayList = [Select K42_Hol_Start_Date__c,K42_Hol_End_Date__c from K42_Holiday__c limit 50000];
        for(K42_Holiday__c genralHoliday : holidayList){
            if(genralHoliday.K42_Hol_Start_Date__c != genralHoliday.K42_Hol_End_Date__c){
                Set<date> datesList = returnDatesBtwTwoDates(genralHoliday.K42_Hol_Start_Date__c,genralHoliday.K42_Hol_End_Date__c);
                if(!datesList.isEmpty()){
                    holidaysSet.addAll(datesList);
                }
            }else{
                holidaysSet.add(genralHoliday.K42_Hol_Start_Date__c);
            }
        }
        for(Activity__c actObj:activityList){
            if(mapOfActivity.containsKey(actObj.Subject__c)) {
                Decimal prevDuration = mapOfIdandDurations.get(actObj.Subject__c)==null? 0 :mapOfIdandDurations.get(actObj.Subject__c);
                Decimal duration = actObj.Activity_Duration__c == null? 0 : (actObj.Activity_Duration__c-1);
                    mapOfIdandDurations.put(actObj.Subject__c,duration+prevDuration);
                List<Activity__c> activites = mapOfActivity.get(actObj.Subject__c);
                activites.add(actObj);
                mapOfActivity.put(actObj.Subject__c, activites);
            } else {
                mapOfIdandDurations.put(actObj.Subject__c,actObj.Activity_Duration__c);
                mapOfActivity.put(actObj.Subject__c, new List<Activity__c> { actObj });
            } 
            //List<String> wrkDaysList = actObj.Subject__r.Term__r.Program_Plan__r.Working_Days__c!=null?actObj.Subject__r.Term__r.Program_Plan__r.Working_Days__c.split(';'):null;
        	
            //actObj.Activity_Duration__c = calculateWorkingDays(actObj.Start_date__c,actObj.End_date__c,holidaysSet,wrkDaysList);
            //system.debug(calculateWorkingDays(actObj.Start_date__c,actObj.End_date__c,holidaysSet,wrkDaysList));
            //updateList.add(actObj);
        } 
        //if(!updateList.isEmpty()){
            //update updateList;
        //}
        
        
        List<Course_Version__c> cvList = new List<Course_Version__c>();
        List<Course_Version__c> courseVersionList = [Select Id,Name,Term__r.Program_Plan__r.Working_Days__c,Subject_Start_Date__c,Subject_End_Date__c,Start_Date__c,Term__r.hed__End_Date__c	 from Course_Version__c where Id IN: setOfCVIds];
        for(Course_Version__c cvObj:courseVersionList){
            List<String> wrkDaysList = cvObj.Term__r.Program_Plan__r.Working_Days__c!=null?cvObj.Term__r.Program_Plan__r.Working_Days__c.split(';'):null;
            system.debug(returnSubjectEndDate(cvObj.Start_Date__c,mapOfIdandDurations.get(cvObj.Id),holidaysSet,wrkDaysList));
            Date endDate = returnSubjectEndDate(cvObj.Start_Date__c,mapOfIdandDurations.get(cvObj.Id),holidaysSet,wrkDaysList);
            if(endDate == null){
                system.debug('hello from where end date should be term end date');
                cvObj.Subject_End_Date__c = cvObj.Term__r.hed__End_Date__c;
            }else{
                cvObj.Subject_End_Date__c = endDate;
            }
            cvList.add(cvObj);
        }
        if(!cvList.isEmpty()){
            update cvList;
        }
        
    }
	
    public static void updateCVendDateFromCVTrigger(List<Course_Version__c> newRecords,Map<Id,Course_Version__c> oldRecords){
        Map<Id,List<Activity__c>> mapOfActivity= new Map<Id,List<Activity__c>>();
        Map<Id,Decimal> mapOfIdandDurations = new Map<Id,Decimal>();
        List<Activity__c> activityList = [Select Id,Name,Subject__c,Activity_Duration__c,Facility__c,Activity_type__c,Offset__c from Activity__c where Subject__c=:newRecords];
        system.debug('activityList'+activityList.size());
        for(Activity__c actObj:activityList){
            if(mapOfActivity.containsKey(actObj.Subject__c)) {
                Decimal prevDuration = mapOfIdandDurations.get(actObj.Subject__c)==null? 0 :mapOfIdandDurations.get(actObj.Subject__c);
                Decimal duration = actObj.Activity_Duration__c == null? 0 : actObj.Activity_Duration__c;
                Decimal activityOffset = actObj.Activity_Duration__c == null? 0 : actObj.Offset__c;
                mapOfIdandDurations.put(actObj.Subject__c,duration+prevDuration+activityOffset);
                if(actObj.Activity_type__c == 'Teaching'){
                    List<Activity__c> activites = mapOfActivity.get(actObj.Subject__c);
                    activites.add(actObj);
                    mapOfActivity.put(actObj.Subject__c, activites);
                }
            } else {
                Decimal duration = actObj.Activity_Duration__c == null? 0 : actObj.Activity_Duration__c;
                Decimal activityOffset = actObj.Offset__c == null? 0 : actObj.Offset__c;
                Decimal durPlusoffset = (duration+activityOffset);
                mapOfIdandDurations.put(actObj.Subject__c,durPlusoffset);
                if(actObj.Activity_type__c == 'Teaching'){
                    mapOfActivity.put(actObj.Subject__c, new List<Activity__c> { actObj });
                }
            } 
        }
        //system.debug('map'+mapOfIdandDurations);
        //system.debug('map'+mapOfActivity);
        
        Set<Date> holidaysSet = new Set<Date>();   
        for(K42_Holiday__c genralHoliday : [Select K42_Hol_Start_Date__c,K42_Hol_End_Date__c from K42_Holiday__c limit 50000]){
            
            if(genralHoliday.K42_Hol_Start_Date__c != genralHoliday.K42_Hol_End_Date__c){
                Set<date> datesList = returnDatesBtwTwoDates(genralHoliday.K42_Hol_Start_Date__c,genralHoliday.K42_Hol_End_Date__c);
                if(!datesList.isEmpty()){
                    holidaysSet.addAll(datesList);
                }
                //system.debug('The retunMethod'+datesList);
            }else{
                holidaysSet.add(genralHoliday.K42_Hol_Start_Date__c);
            }
        }
        List<Activity__c> updateActivitiesList = new List<Activity__c>();
        List<Course_Version__c> cvList = new List<Course_Version__c>();
        for(Course_Version__c cvObj:[Select Id,Name,Term__r.hed__End_Date__c,Term__r.Program_Plan__r.Working_Days__c,Subject_Start_Date__c,Subject_End_Date__c,Start_Date__c,Facilities__c from Course_Version__c where Id=:newRecords]){
            if(oldRecords !=null){
                if(oldRecords.get(cvObj.Id).Facilities__c != cvObj.Facilities__c && mapOfActivity.containsKey(cvObj.Id)){
                    for(Activity__c actObj:mapOfActivity.get(cvObj.Id)){
                        actObj.Facility__c = cvObj.Facilities__c;
                        updateActivitiesList.add(actObj);
                    }
                }
                /*if(oldRecords.get(cvObj.Id).Faculty1__c != cvObj.Faculty1__c && mapOfActivity.containsKey(cvObj.Id)){
                    for(Activity__c actObj:mapOfActivity.get(cvObj.Id)){
                        actObj.Faculty1__c = cvObj.Faculties__c;
                        updateActivitiesList.add(actObj);
                    }
                }*/
            }
            
            List<String> wrkDaysList = new List<String>();
            if(cvObj.Term__r.Program_Plan__r.Working_Days__c!=null){
                wrkDaysList = cvObj.Term__r.Program_Plan__r.Working_Days__c.split(';');
            }else{
                wrkDaysList.add('Monday');
                wrkDaysList.add('Tuesday');
                wrkDaysList.add('Wednesday');
                wrkDaysList.add('Thursday');
                wrkDaysList.add('Friday');
                wrkDaysList.add('Saturday');
                wrkDaysList.add('Sunday');
                
            }
            Date endDate = returnSubjectEndDate(cvObj.Start_Date__c,mapOfIdandDurations.get(cvObj.Id),holidaysSet,wrkDaysList);
            if(endDate == null){
                system.debug('hello from where end date should be term end date');
                cvObj.Subject_End_Date__c = cvObj.Term__r.hed__End_Date__c;
            }else{
                cvObj.Subject_End_Date__c = endDate;
            }
            system.debug(cvObj.Subject_End_Date__c);
            cvList.add(cvObj);
        }
        if(!cvList.isEmpty()){
            update cvList;
            List<Faculty_Booking__c> updateFacultyBookingData=new List<Faculty_Booking__c> ();
            List<Faculty_Booking__c> allFacultyBookingData=[SELECT Id,Start_Date_Time__c,End_Date_Time__c,Course_Version__r.Subject_End_Date__c FROM Faculty_Booking__c WHERE Course_Version__c IN : cvList];

            if(!allFacultyBookingData.isEmpty()){
                for(Faculty_Booking__c facBook:allFacultyBookingData){
                	facBook.End_Date_Time__c=facBook.Course_Version__r.Subject_End_Date__c;
                	updateFacultyBookingData.add(facBook);
                }
                update updateFacultyBookingData;
            } 
        }
        if(!updateActivitiesList.isEmpty()){
            update updateActivitiesList;
        }
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
    
    public static Date returnSubjectEndDate(Date subjStartDate,decimal duration,Set<Date> holidaysSet,List<String> wrkDays){
        Integer workingDays = 1;  
        Date startDate = subjStartDate;
        Date endDate=null;
        integer i = 0; 
        while(workingDays < duration){
            i +=1;
            Date dt = startDate + i;
            endDate = dt;
            DateTime currDate = DateTime.newInstance(dt.year(), dt.month(), dt.day());  
            String todayDay = currDate.format('EEEE');  
            if(wrkDays.contains(todayDay) && (!holidaysSet.contains(dt)))  
            {  
                workingDays = workingDays + 1;  
            }     
            
        }  
        //system.debug('dt'+endDate);    
        //System.debug('--Working days'+workingDays);
        
        return endDate;
    }
    
   /* public static Integer calculateWorkingDays(Date startDate, Date endDate,Set<Date> holidaysSet,List<String> wrkDays)  
    {          
         
        Integer workingDays = 0;  
         
        for(integer i=0; i <= startDate.daysBetween(endDate); i++)  
        {  
            Date dt = startDate + i;  
            DateTime currDate = DateTime.newInstance(dt.year(), dt.month(), dt.day());  
            String todayDay = currDate.format('EEEE');  
            if(wrkDays.contains(todayDay) && (!holidaysSet.contains(dt)))  
                {  
                    workingDays = workingDays + 1;  
                }     
               
        }  
              
        System.debug('--Working days'+workingDays);  
        return workingDays;  
    }*/
    
    /*public static void calculateStartDate(List<Course_Version__c> newRecords){
system.debug('hello from startDate handler');
List<Course_Version__c> cvList = new List<Course_Version__c>();
for(Course_Version__c cvObj:[Select Id,Name,Term__r.hed__End_Date__c,Term__r.hed__Start_Date__c,Start_Date__c,Subject_Offset__c from Course_Version__c where Id=:newRecords]){
if(cvObj.Subject_Offset__c == null){
cvObj.Start_Date__c = cvObj.Term__r.hed__Start_Date__c;
}else{
cvObj.Start_Date__c = cvObj.Term__r.hed__Start_Date__c + Integer.valueOf(cvObj.Subject_Offset__c);
}
cvList.add(cvObj);
}
if(!cvList.isEmpty()){
update cvList;
}
}*/
}