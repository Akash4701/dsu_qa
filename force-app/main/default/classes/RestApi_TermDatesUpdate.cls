@RestResource(urlMapping = '/TermDatesUpdate/*')
Global class RestApi_TermDatesUpdate {

    @HttpPost
    global static void updatingTerms(){
        RestResponse res = RestContext.response;
        try{
            List<WrapperClass> request = (List<WrapperClass>)JSON.deserialize(RestContext.request.requestBody.toString(), List<WrapperClass>.class);
            Map<Id,WrapperClass> wrapperMap = new Map<id,WrapperClass>();
            for(WrapperClass wrapper : request){
                wrapperMap.put(wrapper.termId,wrapper);
            }
            List<Course_Version__c> courseVersions = [Select id,Name from Course_Version__c where Term__c =:wrapperMap.keyset()];
            Date startDate=null;
            List<hed__Term__c>TermList = [Select id,hed__End_Date__c,hed__Start_Date__c,Program_Plan__c,hed__Parent_Term__r.Term_Reference__c from hed__Term__c where id =:wrapperMap.keyset()];
         
            List<hed__Term__c> UpdatingList = new List<hed__Term__c>();
            if(!TermList.isEmpty()){
                for(WrapperClass needToUpdate:request){
                    hed__Term__c term = new hed__Term__c();
                    if(needToUpdate.startDate == null){
                        if(!courseVersions.isEmpty()){
                            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST, 'Subjects are already planned');

            				return;
                        }else{
                            term.hed__Start_Date__c = null;
                        }
                    }
                    term.hed__Start_Date__c = date.valueof(needToUpdate.startDate);  
                    startDate = date.valueof(needToUpdate.startDate);
                    
                    if(needToUpdate.startDate == null){
                        if(!courseVersions.isEmpty()){
                            RestApiUtility.addError(RestApiUtility.HTTP_BAD_REQUEST, 'Subjects are already planned');

            				return;
                        }else{
                             term.hed__End_Date__c=null;
                        }
                    }
                    term.hed__End_Date__c = date.valueof(needToUpdate.endDate);

                    if(needToUpdate.termDuration != null && String.isNotBlank(needToUpdate.termDuration)){
                        term.Term_Duration__c = needToUpdate.termDuration;
                    }
                    
                    term.id = needToUpdate.termId;
                    UpdatingList.add(term);
                }
            }
            if(!UpdatingList.isEmpty()){
                update UpdatingList;
                res.responseBody = Blob.valueof('{"success":"true","message":"Updated successfully."}');
                List<hed__Term__c> ForTermRefList = [Select id,hed__End_Date__c,hed__Start_Date__c,Program_Plan__c,hed__Parent_Term__c,hed__Parent_Term__r.Term_Reference__c from hed__Term__c where id =:UpdatingList];
                Set<Id> prgPlanId = new Set<Id>();
                Set<String> termRef = new Set<String>();
                for(hed__Term__c term : TermList){
                    prgplanId.add(term.Program_Plan__c);
                    termRef.add(term.hed__Parent_Term__r.Term_Reference__c);
                }
                List<hed__Term__c> trmList = [Select id,hed__End_Date__c,hed__Start_Date__c,Program_Plan__c,hed__Parent_Term__c,hed__Parent_Term__r.Term_Reference__c from hed__Term__c where Program_Plan__c =:prgplanId and hed__Parent_Term__r.Term_Reference__c=:termRef and Id!=:UpdatingList];
                for(hed__Term__c term: trmList){
                    if(term.hed__Start_Date__c == null){
                        term.hed__Start_Date__c = startDate!=null?startDate:null;
                    }
                    
                    UpdatingList.add(term);
                }
                if(!UpdatingList.isEmpty()){
                    update UpdatingList;
                }
            }else{
                res.responseBody = Blob.valueof('{"success":"false","message":[]}');
            }
        }catch(exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueof('{"success":"false","error":"'+e.getMessage()+' at line number ' +e.getLineNumber()+'"}'); 
        }
        
        
    }
    global class WrapperClass{
        global string termId;
        global string startDate;
        global string endDate;
        global String termDuration;
    }

}