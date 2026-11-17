public class CourseCalloutHandler {
    @future(callout=true)
    public static void sendCourses(List<Id> courseIds) {
        List<hed__Course__c> courseList = [
            SELECT Id, Name, hed__Course_ID__c, hed__Account__r.LMS_Id__c 
            FROM hed__Course__c 
            WHERE Id IN :courseIds
        ];
        LMS_URL__c bulkEnroll = [SELECT Bulk_Enroll__c FROM LMS_URL__c WHERE Name = 'course url' LIMIT 1];
        List<CourseCalloutWrapper.CourseData> wrapperCourses = new List<CourseCalloutWrapper.CourseData>();
        Map<Id, hed__Course__c> courseMap = new Map<Id, hed__Course__c>();
        for(hed__Course__c c : courseList) {
            wrapperCourses.add(new CourseCalloutWrapper.CourseData(c.Name, c.hed__Course_ID__c, String.valueOf(c.hed__Account__r.LMS_Id__c)));
            courseMap.put(c.Id, c);
        }
        Http http = new Http();
        for(CourseCalloutWrapper.CourseData courseWrapper : wrapperCourses) {
            HttpRequest request = new HttpRequest();
            request.setEndpoint(bulkEnroll.Bulk_Enroll__c);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setBody(JSON.serialize(courseWrapper));
            HttpResponse response = http.send(request);
            if(response.getStatusCode() == 200) {
                Map<String, Object> respMap = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                if(respMap.containsKey('data')) {
                    Map<String, Object> data = (Map<String, Object>)respMap.get('data');
                    String identifier = (String)data.get('Identifier');
                    for(hed__Course__c c : courseList) {
                        if(c.Name == courseWrapper.Name) {
                            c.LMS_Id__c = identifier;
                            break;
                        }
                    }
                }
            }
        }
        if(!courseList.isEmpty()) update courseList;
    }
}