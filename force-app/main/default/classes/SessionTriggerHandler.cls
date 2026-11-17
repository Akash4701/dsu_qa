public class SessionTriggerHandler {
    public static void sessions(List<Session__c> newSessionRecords,Map<Id,Session__c> oldSessionRecords){
       
        List<Session__c> oldRecords = new List<Session__c>();
        if(oldSessionRecords==null){
            sendEmail(newSessionRecords);
        }else{
            for(Session__c sessionObj:newSessionRecords){
                if((oldSessionRecords.get(sessionObj.Id).Start_Date_Time__c != sessionObj.Start_Date_Time__c) || (oldSessionRecords.get(sessionObj.Id).End_Date_Time__c != sessionObj.End_Date_Time__c)){
                    hed__Course_Offering__c[] courseOffering = [Select Id,Name,hed__Course__r.Name,hed__Section_ID__c,hed__Term__r.Campus__r.Name from hed__Course_Offering__c where Id =:oldSessionRecords.get(sessionObj.Id).Course_Offering__c];
                    hed__Facility__c[] facility = [Select id,Name from hed__Facility__c where Id =:oldSessionRecords.get(sessionObj.Id).Facility__c];
                    sendReScheduleEmail(sessionObj,courseOffering[0].hed__Course__r.Name,courseOffering[0].hed__Section_ID__c,courseOffering[0].hed__Term__r.Campus__r.Name,oldSessionRecords.get(sessionObj.Id).Mode_of_Delivery__c,oldSessionRecords.get(sessionObj.Id).Start_Date_Time__c,oldSessionRecords.get(sessionObj.Id).End_Date_Time__c,facility[0].Name);
                }
            }
        }
        if(!oldRecords.isEmpty()){
            sendEmail(oldRecords);
        } else {
            sendEmail(new List<Session__c>());
        }
    }
    
    public static void sendEmail(List<Session__c> SessionRecords){
               

        List<Session__c> sessions = [Select Id,Name,Course_Offering__c,Course_Offering__r.hed__Course__r.Name,Course_Offering__r.hed__Section_ID__c,
                                     Course_Offering__r.hed__Term__r.Campus__r.Name,Faculty__c,Faculty__r.Name,Faculty__r.Email,
                                     Start_Date_Time__c,End_Date_Time__c,Facility__r.Name,Mode_of_Delivery__c,Type_of_Activity__c 
                                     from Session__c where Id IN: SessionRecords];
        
        Map<String,List<Session__c>> mapOfSessions = new Map<String,List<Session__c>>();
        for(Session__c sessObj:sessions){        
            if(mapOfSessions.containsKey(sessObj.Course_Offering__c+'_'+sessObj.Faculty__c+'_'+sessObj.Facility__c+'_'+sessObj.Type_of_Activity__c+'_'+sessObj.Mode_of_Delivery__c)){
                List<Session__c> sessionsList = mapOfSessions.get(sessObj.Course_Offering__c+'_'+sessObj.Faculty__c+'_'+sessObj.Facility__c+'_'+sessObj.Type_of_Activity__c+'_'+sessObj.Mode_of_Delivery__c);
                sessionsList.add(sessObj);
                mapOfSessions.put(sessObj.Course_Offering__c+'_'+sessObj.Faculty__c+'_'+sessObj.Facility__c+'_'+sessObj.Type_of_Activity__c+'_'+sessObj.Mode_of_Delivery__c,sessionsList);
            }else{
                mapOfSessions.put(sessObj.Course_Offering__c+'_'+sessObj.Faculty__c+'_'+sessObj.Facility__c+'_'+sessObj.Type_of_Activity__c+'_'+sessObj.Mode_of_Delivery__c, new List<Session__c>{ sessObj });
            }
        }
        
        EmailTemplate template = [SELECT Id, Name, Subject, HtmlValue FROM EmailTemplate WHERE Name = 'Session Notification'];
        Messaging.Email[] messages = new Messaging.Email[0];
        String subject=template.Subject;
        String body=template.HtmlValue;
        
        for(String str:mapOfSessions.keySet()){
            List<Session__c> sessionsList = mapOfSessions.get(str);
            Integer lastIndexNumberOfList = sessionsList.size() >= 2?(sessionsList.size()-1):0;
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            if(!String.IsBlank(sessionsList[0].Course_Offering__r.hed__Course__r.Name)){
                subject=subject.replace('{{Session__c.Course_Name__c}}',sessionsList[0].Course_Offering__r.hed__Course__r.Name);
                body=body.replace('{{Session__c.Course_Name__c}}', sessionsList[0].Course_Offering__r.hed__Course__r.Name);
                body=body.replace('{{Session__c.Section}}', sessionsList[0].Course_Offering__r.hed__Section_ID__c);
                if(!String.IsBlank(sessionsList[0].Course_Offering__r.hed__Term__r.Campus__r.Name)){
                    body=body.replace('{{Session.Campus}}', sessionsList[0].Course_Offering__r.hed__Term__r.Campus__r.Name);
                }
            }
            body=body.replace('{{Session__c.Faculty__c}}', sessionsList[0].Faculty__r.Name);
            body=body.replace('{{Session.startDate}}', String.valueOf(Date.valueOf(sessionsList[0].Start_Date_Time__c)));
            body=body.replace('{{Session.endDate}}', String.valueOf(Date.valueOf(sessionsList[lastIndexNumberOfList].End_Date_Time__c)));
            body=body.replace('{{Session.startTime}}', sessionsList[0].Start_Date_Time__c.format('HH:mm:ss z'));
            body=body.replace('{{Session.endTime}}', sessionsList[lastIndexNumberOfList].End_Date_Time__c.format('HH:mm:ss z'));
            body=body.replace('{{Session.Facility}}', sessionsList[0].Facility__r.Name);
            body=body.replace('{{Session.modeOfDelivery}}', sessionsList[0].Mode_of_Delivery__c);
            if(!String.IsBlank(subject)){
                mail.setSubject(subject);
            }
            else{
                mail.setSubject('No subject');
            }
            mail.setHtmlBody(body);
            mail.setToAddresses(new List<String> {sessionsList[0].Faculty__r.Email});
            mail.setSaveAsActivity(true);
            messages.add(mail);
            subject=template.Subject;
            body=template.HtmlValue;
        }
        

       
        
        /*for(Session__c sessObj:sessions){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            if(!String.IsBlank(sessObj.Course_Offering__r.hed__Course__r.Name)){
                subject=subject.replace('{{Session__c.Course_Name__c}}',sessObj.Course_Offering__r.hed__Course__r.Name);
                body=body.replace('{{Session__c.Course_Name__c}}', sessObj.Course_Offering__r.hed__Course__r.Name);
                body=body.replace('{{Session__c.Section}}', sessObj.Course_Offering__r.hed__Section_ID__c);
                if(!String.IsBlank(sessObj.Course_Offering__r.hed__Term__r.Campus__r.Name)){
                    body=body.replace('{{Session.Campus}}', sessObj.Course_Offering__r.hed__Term__r.Campus__r.Name);
                }
            }
            body=body.replace('{{Session__c.Faculty__c}}', sessObj.Faculty__r.Name);
            body=body.replace('{{Session.startDate}}', String.valueOf(Date.valueOf(sessObj.Start_Date_Time__c)));
            body=body.replace('{{Session.endDate}}', String.valueOf(Date.valueOf(sessObj.End_Date_Time__c)));
            body=body.replace('{{Session.startTime}}', sessObj.Start_Date_Time__c.format('HH:mm:ss z'));
            body=body.replace('{{Session.endTime}}', sessObj.End_Date_Time__c.format('HH:mm:ss z'));
            body=body.replace('{{Session.Facility}}', sessObj.Facility__r.Name);
            body=body.replace('{{Session.modeOfDelivery}}', sessObj.Mode_of_Delivery__c);
            if(!String.IsBlank(subject)){
                mail.setSubject(subject);
            }
            else{
                mail.setSubject('No subject');
            }
            mail.setHtmlBody(body);
            mail.setToAddresses(new List<String> {sessObj.Faculty__r.Email});
            mail.setSaveAsActivity(true);
            messages.add(mail);
            subject=template.Subject;
            body=template.HtmlValue;
        }*/
        
        Messaging.sendEmail(messages, false);
    }
    
    public static void sendReScheduleEmail(Session__c newSessionRecord,String oldCourse, String oldSection, String oldCampus, String oldMode, DateTime oldStart, DateTime oldEnd, String oldFacility){
               
        List<Session__c> newsessions = [Select Id,Name,Course_Offering__c,Course_Offering__r.hed__Course__r.Name,Course_Offering__r.hed__Section_ID__c,
                                        Course_Offering__r.hed__Term__r.Campus__r.Name,Faculty__r.Name,Faculty__r.Email,
                                        Start_Date_Time__c,End_Date_Time__c,Facility__r.Name,Mode_of_Delivery__c 
                                        from Session__c where Id =: newSessionRecord.Id];
        
        system.debug(newsessions[0].Start_Date_Time__c);
        EmailTemplate template = [SELECT Id, Name, Subject, HtmlValue FROM EmailTemplate WHERE Name = 'Session Re-scheduled Notification'];
        Messaging.Email[] messages = new Messaging.Email[0];
        String subject=template.Subject;
        String body=template.HtmlValue;
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        subject=subject.replace('{{Session__c.Course_Name__c}}',newsessions[0].Course_Offering__r.hed__Course__r.Name);
        body=body.replace('{{Session__c.Faculty__c}}', newsessions[0].Faculty__r.Name);
        //newInfo
        body=body.replace('{{Session__c.Course_Name__c}}', newsessions[0].Course_Offering__r.hed__Course__r.Name);
        body=body.replace('{{Session__c.Section}}', newsessions[0].Course_Offering__r.hed__Section_ID__c);
        body=body.replace('{{Session.Campus}}', newsessions[0].Course_Offering__r.hed__Term__r.Campus__r.Name);
        if(newsessions[0].Start_Date_Time__c != null)
        	body=body.replace('{{Session.startDate}}', String.valueOf(Date.valueOf(newsessions[0].Start_Date_Time__c)));
        if(newsessions[0].End_Date_Time__c != null)
        	body=body.replace('{{Session.endDate}}', String.valueOf(Date.valueOf(newsessions[0].End_Date_Time__c)));
        if(newsessions[0].Start_Date_Time__c != null)
        	body=body.replace('{{Session.startTime}}', newsessions[0].Start_Date_Time__c.format('HH:mm:ss z'));
        if(newsessions[0].End_Date_Time__c != null)
        	body=body.replace('{{Session.endTime}}', newsessions[0].End_Date_Time__c.format('HH:mm:ss z'));
        body=body.replace('{{Session.Facility}}', newsessions[0].Facility__r.Name);
        body=body.replace('{{Session.modeOfDelivery}}', newsessions[0].Mode_of_Delivery__c);
        //oldInfo
        body=body.replace('{{Session__c.OLDCourse_Name__c}}', oldCourse);
        body=body.replace('{{Session__c.OLDSection}}', oldSection);
        body=body.replace('{{Session.OLDCampus}}', oldCampus);
        if(oldStart!=null)
        	body=body.replace('{{Session.OLDstartDate}}', String.valueOf(Date.valueOf(oldStart)));
        if(oldEnd!=null)
        	body=body.replace('{{Session.OLDendDate}}', String.valueOf(Date.valueOf(oldEnd)));
        if(oldStart!=null)
        	body=body.replace('{{Session.OLDstartTime}}', oldStart.format('HH:mm:ss z'));
        if(oldEnd!=null)
        	body=body.replace('{{Session.OLDendTime}}', oldEnd.format('HH:mm:ss z'));
        body=body.replace('{{Session.OLDFacility}}', oldFacility);
        body=body.replace('{{Session.OLDmodeOfDelivery}}', oldMode);
        
        mail.setSubject(subject);
        mail.setHtmlBody(body);
        mail.setToAddresses(new List<String> {newsessions[0].Faculty__r.Email});
        mail.setSaveAsActivity(true);
        messages.add(mail);
        
        Messaging.sendEmail(messages, false);
    }
    
    public static void restrictDuplicateSessions(List<Session__c> newSessionRecords){
            

        Set<Id> courseOfferingIds = new Set<Id>();
        for(Session__c sessionObj:newSessionRecords){
            courseOfferingIds.add(sessionObj.Course_Offering__c);
        }
        system.debug(courseOfferingIds);
        Map<String,Session__c> mapOfcourseOfferingWithDate =  new Map<String,Session__c>();
        for(Session__c sessionObj:[Select Id,Course_Offering__c,Start_Date_Time__c,End_Date_Time__c,Type_of_Activity__c from Session__c where Course_Offering__c IN: courseOfferingIds]){
            mapOfcourseOfferingWithDate.put(sessionObj.Course_Offering__c+'-'+sessionObj.Start_Date_Time__c+'-'+sessionObj.End_Date_Time__c, sessionObj);
        }
        system.debug(mapOfcourseOfferingWithDate);
        for(Session__c sessionObj:newSessionRecords){
            system.debug(sessionObj.Course_Offering__c+'-'+sessionObj.Start_Date_Time__c+'-'+sessionObj.End_Date_Time__c);
            if(mapOfcourseOfferingWithDate.containsKey(sessionObj.Course_Offering__c+'-'+sessionObj.Start_Date_Time__c+'-'+sessionObj.End_Date_Time__c)){
                sessionObj.addError('Session was already created');
            }
        }
    }
    
    public static void sendCancelledEmail(List<Session__c> SessionRecords) {
        List<Session__c> sessions = [Select Id,Name,Course_Offering__c,Course_Offering__r.hed__Course__r.Name,Course_Offering__r.hed__Section_ID__c,
                                     Course_Offering__r.hed__Term__r.Campus__r.Name,Faculty__c,Faculty__r.Name,Faculty__r.Email,
                                     Start_Date_Time__c,End_Date_Time__c,Facility__r.Name,Mode_of_Delivery__c,Type_of_Activity__c 
                                     from Session__c where Id IN: SessionRecords];
        
        Map<String,List<Session__c>> mapOfSessions = new Map<String,List<Session__c>>();
        for(Session__c sessObj:sessions){        
            if(mapOfSessions.containsKey(sessObj.Course_Offering__c+'_'+sessObj.Faculty__c+'_'+sessObj.Facility__c+'_'+sessObj.Type_of_Activity__c+'_'+sessObj.Mode_of_Delivery__c)){
                List<Session__c> sessionsList = mapOfSessions.get(sessObj.Course_Offering__c+'_'+sessObj.Faculty__c+'_'+sessObj.Facility__c+'_'+sessObj.Type_of_Activity__c+'_'+sessObj.Mode_of_Delivery__c);
                sessionsList.add(sessObj);
                mapOfSessions.put(sessObj.Course_Offering__c+'_'+sessObj.Faculty__c+'_'+sessObj.Facility__c+'_'+sessObj.Type_of_Activity__c+'_'+sessObj.Mode_of_Delivery__c,sessionsList);
            }else{
                mapOfSessions.put(sessObj.Course_Offering__c+'_'+sessObj.Faculty__c+'_'+sessObj.Facility__c+'_'+sessObj.Type_of_Activity__c+'_'+sessObj.Mode_of_Delivery__c, new List<Session__c>{ sessObj });
            }
        }
        
        EmailTemplate template = [SELECT Id, Name, Subject, HtmlValue FROM EmailTemplate
                                  WHERE Name = 'Session Cancelled'
                                  limit 1];
        Messaging.Email[] messages = new Messaging.Email[0];
        String subject=template.Subject;
        String body=template.HtmlValue;
        
        for(String str:mapOfSessions.keySet()){
            List<Session__c> sessionsList = mapOfSessions.get(str);
            Integer lastIndexNumberOfList = sessionsList.size() >= 2?(sessionsList.size()-1):0;
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            if(!String.IsBlank(sessionsList[0].Course_Offering__r.hed__Course__r.Name)){
                subject=subject.replace('{{Session__c.Course_Name__c}}',sessionsList[0].Course_Offering__r.hed__Course__r.Name);
                body=body.replace('{{Session__c.Course_Name__c}}', sessionsList[0].Course_Offering__r.hed__Course__r.Name);
                body=body.replace('{{Session__c.Section}}', sessionsList[0].Course_Offering__r.hed__Section_ID__c);
                if(!String.IsBlank(sessionsList[0].Course_Offering__r.hed__Term__r.Campus__r.Name)){
                    body=body.replace('{{Session.Campus}}', sessionsList[0].Course_Offering__r.hed__Term__r.Campus__r.Name);
                }
            }
            body=body.replace('{{Session__c.Faculty__c}}', sessionsList[0].Faculty__r.Name);
            body=body.replace('{{Session.startDate}}', String.valueOf(Date.valueOf(sessionsList[0].Start_Date_Time__c)));
            body=body.replace('{{Session.endDate}}', String.valueOf(Date.valueOf(sessionsList[lastIndexNumberOfList].End_Date_Time__c)));
            body=body.replace('{{Session.startTime}}', sessionsList[0].Start_Date_Time__c.format('HH:mm:ss z'));
            body=body.replace('{{Session.endTime}}', sessionsList[lastIndexNumberOfList].End_Date_Time__c.format('HH:mm:ss z'));
            body=body.replace('{{Session.Facility}}', sessionsList[0].Facility__r.Name);
            body=body.replace('{{Session.modeOfDelivery}}', sessionsList[0].Mode_of_Delivery__c);
            if(!String.IsBlank(subject)){
                mail.setSubject(subject);
            }
            else{
                mail.setSubject('No subject');
            }
            mail.setHtmlBody(body);
            mail.setToAddresses(new List<String> {sessionsList[0].Faculty__r.Email});
            mail.setSaveAsActivity(true);
            messages.add(mail);
            subject=template.Subject;
            body=template.HtmlValue;
        }
        
        Messaging.sendEmail(messages, false);
    } 
}