public class TermTriggerHandler {
    public static Boolean isFirstTime = true;
    public static void updateWithOffsetDates(List<hed__Term__c> newRecords){
        List<Course_Version__c> cvList = new List<Course_Version__c>();
        List<Course_Version__c> couVerList = [Select Id,Term__c,Term__r.hed__Start_Date__c,Term__r.hed__End_Date__c,Offset__c,Start_Date__c,End_Date__c from Course_Version__c where Term__c=:newRecords];
        for(Course_Version__c cvObj:couVerList){
            if(cvObj.Offset__c!=null){
                Date newDate = cvObj.Term__r.hed__Start_Date__c;
                cvObj.Start_Date__c = newDate.addDays(integer.valueOf(cvObj.Offset__c));
            }else{
                cvObj.Start_Date__c = cvObj.Term__r.hed__Start_Date__c;
            }
            cvList.add(cvObj);
        }
        if(!cvList.isEmpty()){
            update cvList;
        }
    }
      
}