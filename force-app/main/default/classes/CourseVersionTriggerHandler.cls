public class CourseVersionTriggerHandler {
    
    public static void checkRelatedExams(List<Course_Version__c> courseVersions) {
        Set<Id> courseVersionIds = new Set<Id>();
        Map<Id,List<Exam__c>> courseVersIdVsTotalExm = new Map<Id,List<Exam__c>>();
        Map<Id,List<Exam__c>> courseVersIdVsErrorExm = new Map<Id,List<Exam__c>>();
        List<Exam__c> deleteExm =new List<Exam__c>();
        List<Exam__c> errorExm =new List<Exam__c>();
        for (Course_Version__c courseVersion : courseVersions) {
            if(courseVersion.Exam_Required__c == false){
                courseVersionIds.add(courseVersion.Id);
            }
        }
        if(!courseVersionIds.isEmpty()){
            for(Exam__c exm : [SELECT Id, Date_of_Exam__c,Course_Version__c FROM Exam__c WHERE Course_Version__c IN :courseVersionIds]){
                if(exm.Date_of_Exam__c == null){
                	deleteExm.add(exm);
            	}
                if(exm.Date_of_Exam__c != null){
                    errorExm.add(exm);
                    if(courseVersIdVsErrorExm.containsKey(exm.Course_Version__c)){
                        List<Exam__c> exmlistnew = courseVersIdVsErrorExm.get(exm.Course_Version__c);
                        exmlistnew.add(exm);
                        courseVersIdVsErrorExm.put(exm.Course_Version__c, exmlistnew);
                    }else{
                        courseVersIdVsErrorExm.put(exm.Course_Version__c, new List<Exam__c>{exm});
                    }
                }
                if(courseVersIdVsTotalExm.containsKey(exm.Course_Version__c)){
                    List<Exam__c> exmlistnew = courseVersIdVsTotalExm.get(exm.Course_Version__c);
                    exmlistnew.add(exm);
                    courseVersIdVsTotalExm.put(exm.Course_Version__c, exmlistnew);
                }else{
                    courseVersIdVsTotalExm.put(exm.Course_Version__c, new List<Exam__c>{exm});
                }
            }
        }
        if(!deleteExm.isEmpty()){
            delete deleteExm;
        }
        for (Course_Version__c courseVersion : courseVersions) {
            if(courseVersIdVsErrorExm.containsKey(courseVersion.Id)){
                if(courseVersion.Exam_Required__c == false && courseVersIdVsErrorExm.get(courseVersion.Id).size() == courseVersIdVsTotalExm.get(courseVersion.Id).size()){
                    courseVersion.Exam_Required__c.addError('Related exam Date was already Declare Can not Modified The Record');
                }
            }
        }
    }
}