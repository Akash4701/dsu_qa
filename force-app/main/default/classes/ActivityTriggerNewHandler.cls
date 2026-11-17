public class ActivityTriggerNewHandler {
	public static Boolean isFirstTime = true;
    
    public static void calculateCourseVersionEndDate(List<Activity__c> newRecords){
        
        Map<Id,Date> mapOfActivity= new Map<Id,Date>();
        Set<Id> setOfCVIds = new Set<Id>();
        for(Activity__c actObj:newRecords){
            setOfCVIds.add(actObj.Subject__c);
        }
        List<Activity__c> activityList = [Select Id,Name,Subject__c,Duration__c,Subject__r.Term__r.Program_Plan__r.Working_Days__c,Activity_Duration__c,Start_date__c,End_date__c from Activity__c where Subject__c IN:setOfCVIds and Activity_type__c='Teaching'];
        mapOfActivity = creatingMapOfCvAndActivityHighestEndDate(activityList);
        List<Course_Version__c> cvList = new List<Course_Version__c>();
        List<Course_Version__c> courseVersionList = [Select Id,Name,Term__r.Program_Plan__r.Working_Days__c,Subject_Start_Date__c,Subject_End_Date__c,Start_Date__c,Term__r.hed__End_Date__c from Course_Version__c where Id IN: setOfCVIds];
        for(Course_Version__c cvObj:courseVersionList){
            Date endDate = mapOfActivity.containsKey(cvObj.Id)?mapOfActivity.get(cvObj.Id):cvObj.Term__r.hed__End_Date__c;
			cvObj.Subject_End_Date__c = endDate;
            cvList.add(cvObj);
        }
        if(!cvList.isEmpty()){
            update cvList;
        }
    }
    
    public static void calculateCourseVersionEndDateWithCV(List<Course_Version__c> newRecords){
        Map<Id,Date> mapOfActivity= new Map<Id,Date>();
        List<Activity__c> activityList = [Select Id,Name,Subject__c,Duration__c,Subject__r.Term__r.Program_Plan__r.Working_Days__c,Activity_Duration__c,Start_date__c,End_date__c from Activity__c where Subject__c IN:newRecords and Activity_type__c='Teaching'];
        mapOfActivity = creatingMapOfCvAndActivityHighestEndDate(activityList);
        List<Course_Version__c> cvList = new List<Course_Version__c>();
        List<Course_Version__c> courseVersionList = [Select Id,Name,Term__r.Program_Plan__r.Working_Days__c,Subject_Start_Date__c,Subject_End_Date__c,Start_Date__c,Term__r.hed__End_Date__c from Course_Version__c where Id IN: newRecords];
        for(Course_Version__c cvObj:courseVersionList){
            Date endDate = mapOfActivity.containsKey(cvObj.Id)?mapOfActivity.get(cvObj.Id):cvObj.Term__r.hed__End_Date__c;
			cvObj.Subject_End_Date__c = endDate;
            cvList.add(cvObj);
        }
        if(!cvList.isEmpty()){
            update cvList;
        }
    }
    
    public static Map<Id,Date> creatingMapOfCvAndActivityHighestEndDate(List<Activity__c> activityRecords){
        Map<Id,Date> mapOfActivity= new Map<Id,Date>();
        for(Activity__c actObj:activityRecords){
            if(mapOfActivity.containsKey(actObj.Subject__c)) {
                Date activites = mapOfActivity.get(actObj.Subject__c);
                if(activites < actObj.End_date__c){
                    activites = actObj.End_date__c;
                }
                mapOfActivity.put(actObj.Subject__c, activites);
            } else {
                mapOfActivity.put(actObj.Subject__c,actObj.End_date__c);
            }
        }
        return mapOfActivity;
    }
    
    
    public static void recalculateTheActivityDates(List<Course_Version__c> newRecords, Map<Id,Course_Version__c> oldRecords){
        List<Activity__c> activityList = new List<Activity__c>();
        for(Course_Version__c cvObj:[Select Id,Name,Term__r.hed__End_Date__c,Term__r.Program_Plan__r.Working_Days__c,Subject_Start_Date__c,Subject_End_Date__c,Start_Date__c,Facilities__c,(select Id,Name,Start_date__c,End_date__c,Activity_Duration__c,Offset__c,Working_Days__c from Activities__r ) from Course_Version__c where Id=:newRecords]){
            if(oldRecords.get(cvObj.Id).Start_Date__c != cvObj.Start_Date__c && (cvObj.Activities__r.size()!=0)){
                for(Activity__c actObj:cvObj.Activities__r){
                    List<String> workingDays = actObj.Working_Days__c.split(';');
                    actObj.Start_date__c=cvObj.Start_Date__c.addDays(Integer.valueOf(actObj.Offset__c));
                    actObj.End_date__c=returnEndDate(cvObj.Start_Date__c.addDays(Integer.valueOf(actObj.Offset__c)),actObj.Activity_Duration__c,workingDays);
                    activityList.add(actObj);
                }
            }
        }
        if(!activityList.isEmpty()){
            update activityList;
        }
    }
    
    public static Date returnEndDate(Date activityStartDate,decimal duration,List<String> wrkDays){
        Integer workingDays = 1;  
        Date startDate = activityStartDate;
        Date endDate=null;
        integer i = 0; 
        while(workingDays < duration){
            i +=1;
            Date dt = startDate + i;
            endDate = dt;
            DateTime currDate = DateTime.newInstance(dt.year(), dt.month(), dt.day());  
            String todayDay = currDate.format('EEEE');  
            if(wrkDays.contains(todayDay))  
            {  
                workingDays = workingDays + 1;  
            }     
            
        }  
        //system.debug('dt'+endDate);    
        //System.debug('--Working days'+workingDays);
        
        return endDate;
    }
       
}