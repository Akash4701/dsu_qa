@RestResource(urlMapping='/createProgramBatchSpecialization')
global class RestApi_CreateProgramBatchSpecialization {
	@HttpPost
    global static void doCreateProgramBatchSpecialization(){
        RestResponse res = RestContext.response;
        string jsonResponse='';
        try{
            requestCreateProgramBatchSpecializationWrapper request = (requestCreateProgramBatchSpecializationWrapper) JSON.deserialize(RestContext.request.requestBody.toString(),requestCreateProgramBatchSpecializationWrapper.class);
            //system.debug('The request'+request.Batch.year);
            responseWrapper response=new responseWrapper();
            List<String> accountSet = new List<String> {request.Program.academicProgramsName,request.Program.levelOfAcademicProgram,request.Batch.academicProgramsName,request.Specialization.academicProgramsName,request.Specialization.specializationName};
            Map<String,Account> accMap=new Map<String,Account>();
            Map<String, Campus__c> campusMap=new Map<String, Campus__c>();
            Map<String,String> campTermMap=new Map<String,String> ();
            Map<String,String> pgmAliasMap=new Map<String,String> ();
            Map<String,List<String>> campusWithTermNumbers = new Map<String,List<String>>();
            List<hed__Term__c> termList=new List<hed__Term__c>();
            Id prgCampusCombRecordId;
            Map<Id,Campus__c> mapOfCampus = new Map<Id,Campus__c>([Select Id,CurrencyIsoCode from Campus__c]);
            Map<String,String> termDurationMap = new Map<String,String>();
            if(!accountSet.isEmpty())
            {
                for(Account acc:[SELECT ID,Name,Parent.Name,Number_of_Terms__c,ParentId FROM Account WHERE Name IN:accountSet])
                {
                    accMap.put(acc.Name,acc);
                }
            }
                
            if(!String.isBlank(request.Program.academicProgramsName) && !String.isBlank(request.Program.levelOfAcademicProgram))
            {
                List<K42_Program_Alias__c> pgmAliasList=new List<K42_Program_Alias__c>();               
                if(accMap.keyset().contains(request.Program.academicProgramsName))
                {
                    if(accMap.keyset().contains(request.Program.levelOfAcademicProgram))
                    {
                        Account accPgm=new Account();
                        accPgm.Id=accMap.get(request.Program.academicProgramsName).Id;
                        accPgm.Course_duration__c=request.Program.duration.year+' years '+request.Program.duration.months+' month';
                        accPgm.Number_of_Terms__c=request.Program.numberofTerms;
                        accPgm.Program_Duration_in_Weeks__c=Decimal.valueOf(request.Program.termduration);
                        accPgm.Course_duration__c=request.Program.programDuration;
                        update accPgm;
                        response.programId=accMap.get(request.Program.academicProgramsName).Id;
                    }
                }
                else
                {
                    if(accMap.keyset().contains(request.Program.levelOfAcademicProgram))
                    {
                        Account accPgm=new Account();
                        accPgm.Name=request.Program.academicProgramsName;
                        accPgm.ParentId=accMap.get(request.Program.levelOfAcademicProgram).Id;
                        accPgm.Course_duration__c=request.Program.duration.year+' years '+request.Program.duration.months+' month';
                        system.debug(request.Program.duration.year+' years '+request.Program.duration.months+' month');
                        accPgm.Number_of_Terms__c=request.Program.numberofTerms;
                        accPgm.Program_Duration_in_Weeks__c=Decimal.valueOf(request.Program.termduration);
                        //accPgm.Course_duration__c=request.Program.programDuration;
                        accPgm.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Academic Program').getRecordTypeId();
                        insert accPgm;
                        response.programId=accPgm.Id;
                    }
                }
                if(!String.isBlank(request.Program.academicProgramsAlias) && !String.isBlank(response.programId))
                {
					pgmAliasList=[SELECT ID,Name,Program__c,Program__r.Name FROM K42_Program_Alias__c WHERE Name=:request.Program.academicProgramsAlias];
                    if(!pgmAliasList.isEmpty())
                    {
                        if(pgmAliasList[0].Program__c!=response.programId)
                        {
                            K42_Program_Alias__c alias=new K42_Program_Alias__c();
                            alias.Name=request.Program.academicProgramsAlias;
                            alias.Program__c=response.programId;
                            insert alias;
                        }
                    }
                    else
                    {
                        K42_Program_Alias__c alias=new K42_Program_Alias__c();
                        alias.Name=request.Program.academicProgramsAlias;
                        alias.Program__c=response.programId;
                        insert alias;
                    }
                }

            }
            if(!String.isBlank(request.Batch.academicProgramsName) && !String.isBlank(request.Batch.batchName))
            {
                for(K42_Program_Alias__c alias:[SELECT Id,Name,Program__r.Name FROM K42_Program_Alias__c])
                {
                    pgmAliasMap.put(alias.Program__r.Name,alias.Name);
                }
                /*if(!String.isBlank(request.Batch.campus))
                {
 					List<String> reqCampus = String.valueOf(request.Batch.campus).split(';');
                    for(String str:reqCampus){
                        str=str.replace('Term', '');
                        str=str.replace(' ', '');
                        List<String> reqCampusAll = String.valueOf(str).split('&');
                        if(reqCampusAll.isEmpty())
                        {
                            reqCampusAll.add(str);
                        }
                        
                        for(String strCampus:reqCampusAll)
                        {
                            //system.debug(strCampus);
                            List<String> reqCampusAllVal = strCampus.contains(',')? String.valueOf(strCampus).split(','):String.valueOf(strCampus).split('-');
                            //system.debug(reqCampusAllVal);
                            Integer lastElementNumber = reqCampusAllVal.size()>0? reqCampusAllVal.size() - 1:0;
                            List<String> lastElements = reqCampusAllVal[lastElementNumber].split('-');
                            //system.debug(lastElements);
                            String campusName = lastElements.size()>1?lastElements[1]:lastElements[0];
                            //system.debug(campusName);
                            List<String> campusVal=new List<String>();
                            campusVal.add(reqCampusAllVal[0]);
                            String forLastNumber = lastElements[0];
                            if(forLastNumber.isNumeric()){
                                campusVal.add(lastElements[0]);
                            }else{
                                campusVal.add(reqCampusAllVal[0]);
                            }
                            if(campusWithTermNumbers.keyset().contains(campusName))
                            {
                                campusVal=new List<String>();
                                List<String> campusValOLD=new List<String>();
                                 
                                campusValOLD=campusWithTermNumbers.get(campusName);
                                if(campusValOLD[0]>reqCampusAllVal[0])
                                {
                                    campusVal.add(reqCampusAllVal[0]);
                                }
                                else
                                {
                                    campusVal.add(campusValOLD[0]);
                                }
                                if(campusValOLD[1]>lastElements[0])
                                {
                                    campusVal.add(campusValOLD[1]);
                                }
                                else
                                {
                                    //campusVal.add(lastElements[0]);
                                    if(forLastNumber.isNumeric()){
                                        campusVal.add(lastElements[0]);
                                    }else{
                                        campusVal.add(reqCampusAllVal[0]);
                                    }
                                }
                            }
                            campusWithTermNumbers.put(campusName,campusVal);
                        }
                    }
				}*/
                for(Campus__c camp:[SELECT Id,Name FROM Campus__c])
                {
                    campusMap.put(camp.Name,camp);
                }
                String name=request.Batch.year+'-'+request.Batch.intake+'-'+pgmAliasMap.get(request.Batch.academicProgramsName);
                List<hed__Program_Plan__c> batchList=new List<hed__Program_Plan__c>([SELECT Id,Name,(SELECT Id,Name FROM Terms__r) FROM hed__Program_Plan__c WHERE hed__Account__r.Name=:request.Batch.academicProgramsName AND Name=:name]);
                List<String> termData=new List<String>();
                if(!batchList.isEmpty())
                {
                    if(!batchList[0].Terms__r.isEmpty())
                    {
                        for(hed__Term__c termVal:batchList[0].Terms__r)
                        {
                            termData.add(termVal.Name);
                        }
                    }
                }
				if(!batchList.isEmpty())
                {
                    hed__Program_Plan__c batch=new hed__Program_Plan__c();
                    batch.Id=batchList[0].Id;
                    if(!String.isBlank(request.Batch.startDate))
                    {
                        batch.hed__Start_Date__c=date.valueOf(request.Batch.startDate);
                    }
                    if(!String.isBlank(request.Batch.endDate))
                    {
                        batch.hed__End_Date__c=date.valueOf(request.Batch.endDate);
                    }	
                    if(!String.isBlank(request.Batch.batchStrength))
                    {
                        batch.Capacity__c=Integer.valueOf(request.Batch.batchStrength);
                    }
                    batch.Batch__c=request.Batch.year;
                    batch.Intake__c=request.Batch.intake;
                    system.debug('days'+request.Batch.workingDays);
                    batch.Working_Days__c=request.Batch.workingDays;
                    
                     if(!String.isBlank(request.Batch.termDuration))
                        {
                            for(String durationlist : request.Batch.termDuration.split(';')){
                                termDurationMap.put(durationlist.SubStringBefore('-'),durationlist.substringAfter('-'));
                            }	
                            system.debug('mapvalues====>'+termDurationMap);
                        }
                   
                    update batch;
                    response.batchId=batchList[0].Id;
                    response.batchName=batchList[0].Name;

                }
                else
                {
                    if(accMap.keyset().contains(request.Batch.academicProgramsName))
                    {
                        hed__Program_Plan__c batch=new hed__Program_Plan__c();
                        batch.Name=request.Batch.year+'-'+request.Batch.intake+'-'+pgmAliasMap.get(request.Batch.academicProgramsName);
                        batch.hed__Account__c=accMap.get(request.Batch.academicProgramsName).Id;
                        if(!String.isBlank(request.Batch.startDate))
                        {
                            batch.hed__Start_Date__c=date.valueOf(request.Batch.startDate);
                        }
                        if(!String.isBlank(request.Batch.endDate))
                        {
                            batch.hed__End_Date__c=date.valueOf(request.Batch.endDate);
                        }	
                        if(!String.isBlank(request.Batch.batchStrength))
                        {
                        	batch.Capacity__c=Integer.valueOf(request.Batch.batchStrength);
                        }
                        batch.Batch__c=request.Batch.year;
                        batch.Intake__c=request.Batch.intake;
                        batch.Working_Days__c=request.Batch.workingDays;
                        
                     if(!String.isBlank(request.Batch.termDuration))
                        {
                            system.debug(request.Batch.termDuration);
                            for(String durationlist : request.Batch.termDuration.split(';')){
                                termDurationMap.put(durationlist.SubStringBefore('-'),durationlist.substringAfter('-'));
                            }
                             system.debug('mapvalues====>'+termDurationMap);
                        }
                      
                          
                        batch.RecordTypeId=Schema.SObjectType.hed__Program_Plan__c.getRecordTypeInfosByName().get('Program Version').getRecordTypeId();
                        insert batch;
                        response.batchId=batch.Id;
                        response.batchName=batch.Name;
                    }
                }
                System.debug(String.isBlank(response.batchId) +' '+String.isBlank(request.Batch.academicProgramsName) +' '+request.Batch.campus.size());
                if(!String.isBlank(response.batchId) && !String.isBlank(request.Batch.academicProgramsName) && request.Batch.campus.size()!=0)
                {
                    system.debug(request.Batch.termDuration);
                    if(!String.isBlank(request.Batch.termDuration))
                    {
                        system.debug(request.Batch.termDuration);
                        for(String durationlist : request.Batch.termDuration.split(';')){
                            termDurationMap.put(durationlist.SubStringBefore('-'),durationlist.substringAfter('-'));
                        }
                        system.debug('mapvalues====>'+termDurationMap);
                    }
                    
                    List<Term_Campus_Relationship__c> termCampusRel = new List<Term_Campus_Relationship__c>(); 
                    Map<String,List<Term_Campus_Relationship__c>> prgCmpsRel = new Map<String,List<Term_Campus_Relationship__c>>();
                    for(Term_Campus_Relationship__c trmCampusObj:[Select Id,Term__c,Term__r.Term_Reference__c,Campus__c,Campus__r.Name,CurrencyIsoCode,Program_Campus_Combination__c,Program_Campus_Combination__r.Master_Program_Campus_Combination__c from Term_Campus_Relationship__c where Program_Campus_Combination__c IN:request.Batch.campus]){
                        //termCampusRel.add(trmCampusObj);
                        system.debug('trmCampusObj.Campus__r.Name==>'+trmCampusObj.Campus__r);
                        system.debug('trmCampusObj.Term_Reference__c==>'+trmCampusObj.Term__r.Term_Reference__c);
                        //commented for checking
                        if(prgCmpsRel.containsKey(trmCampusObj.Campus__r.Name+'-'+trmCampusObj.Term__r.Term_Reference__c)) {
                            List<Term_Campus_Relationship__c> usersId = prgCmpsRel.get(trmCampusObj.Campus__r.Name+'-'+trmCampusObj.Term__r.Term_Reference__c);
                            usersId.add(trmCampusObj);
                            prgCmpsRel.put(trmCampusObj.Campus__r.Name+'/'+trmCampusObj.Term__r.Term_Reference__c, usersId);
                        } else {
                            prgCmpsRel.put(trmCampusObj.Campus__r.Name+'/'+trmCampusObj.Term__r.Term_Reference__c, new List<Term_Campus_Relationship__c> { trmCampusObj });
                        	
                        }
                        
                    }
                    system.debug('prgCmpsRel1==>'+prgCmpsRel);
                    //system.debug(prgCmpsRel);
                    Map<String,hed__Term__c> mapOfMasterTermIds = new Map<String,hed__Term__c>();
                    for(hed__Term__c mstTerm:[Select Id,Name,Term_Reference__c,hed__Type__c from hed__Term__c where recordType.Name='Master Record' and hed__Account__c=:accMap.get(request.Batch.academicProgramsName).Id]){
                        mapOfMasterTermIds.put(mstTerm.Term_Reference__c,mstTerm);
                    } 
                    /*for(Term_Campus_Relationship__c term:termCampusRel){
                        hed__Term__c termObj = new hed__Term__c();
                        termObj.hed__Parent_Term__c = term.Term__c;
                        termObj.Name=request.Batch.year+'-'+request.Batch.intake+'-'+pgmAliasMap.get(request.Batch.academicProgramsName)+'-'+term.Term__r.Term_Reference__c+'-'+term.Campus__r.Name;
                        termObj.hed__Account__c=accMap.get(request.Batch.academicProgramsName).Id;
                        termObj.Program_Plan__c=response.batchId;
                        termObj.Campus__c=term.Campus__c;
                        termObj.RecordTypeId=Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
                        termObj.Term_Duration__c = termDurationMap.get(term.Term__r.Term_Reference__c);
                        termObj.Term_Reference__c = term.Term__r.Term_Reference__c;
                        termObj.Master_Term_Campus_Relationship__c = term.Id;
                        system.debug('duration===>'+ termObj.Term_Duration__c);
                        termList.add(termObj);
                    }*/
                    system.debug('prgCmpsRel.keySet()==>'+prgCmpsRel.keySet());
                    for(String str:prgCmpsRel.keySet()){
                        List<String> termRef = str.split('/');
                        
                        /*List<Term_Campus_Relationship__c> termCampusRelList = prgCmpsRel.get(str);
    
                        // Iterate through each Term_Campus_Relationship__c object in the list
                        for (Term_Campus_Relationship__c termCampusRelation : termCampusRelList) {
                            // Create a new hed__Term__c record
                            hed__Term__c termObj = new hed__Term__c();
                            
                            // Populate termObj properties based on the current termCampusRel and other available data
                            termObj.hed__Parent_Term__c = (mapOfMasterTermIds != null && !mapOfMasterTermIds.isEmpty()) ? 
                                mapOfMasterTermIds.get(termCampusRelation.Term__r.Term_Reference__c).Id : null;
                            
                            termObj.Name = request.Batch.year + '-' + request.Batch.intake + '-' + pgmAliasMap.get(request.Batch.academicProgramsName) + '-' + 
                                ((mapOfMasterTermIds != null && !mapOfMasterTermIds.isEmpty()) ? mapOfMasterTermIds.get(termCampusRelation.Term__r.Term_Reference__c).Term_Reference__c + '-' : '') + 
                                termCampusRelation.Campus__r.Name;
                            
                            termObj.hed__Account__c = accMap.get(request.Batch.academicProgramsName).Id;
                            termObj.Program_Plan__c = response.batchId;
                            termObj.Term_Reference__c = termCampusRelation.Term__r.Term_Reference__c;
                            termObj.Campus__c = termCampusRelation.Campus__c;
                            termObj.RecordTypeId = Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
                            termObj.Term_Duration__c = termDurationMap.get(termCampusRelation.Term__r.Term_Reference__c);
                            termObj.hed__Type__c = (mapOfMasterTermIds != null && !mapOfMasterTermIds.isEmpty()) ? 
                                mapOfMasterTermIds.get(termCampusRelation.Term__r.Term_Reference__c).hed__Type__c : null;
                            
                            // Add the newly created termObj to the list of hed__Term__c records
                            termList.add(termObj);
                        }*/
                        hed__Term__c termObj = new hed__Term__c();
                        system.debug('termRef==>'+termRef);
                        system.debug('mapOfMasterTermIds==>'+mapOfMasterTermIds);
                        string replacetermwithsemester = '';
                        if(mapOfMasterTermIds != null && !mapOfMasterTermIds.isEmpty() && mapOfMasterTermIds.containsKey(termRef[1])){
                            string semesterName =  mapOfMasterTermIds.get(termRef[1]).Term_Reference__c;
                            System.debug('SemesterName--->'+semesterName);
                            replacetermwithsemester = semestername.replace('Term','Sem');
                            System.debug('replacetermwithsemester-->'+replacetermwithsemester);
                        }
                        termObj.hed__Parent_Term__c = (mapOfMasterTermIds != null && !mapOfMasterTermIds.isEmpty() && mapOfMasterTermIds.containsKey(termRef[1])) ?mapOfMasterTermIds.get(termRef[1]).Id:null;
                        //termObj.Name=request.Batch.year+'-'+request.Batch.intake+'-'+pgmAliasMap.get(request.Batch.academicProgramsName)+'-'+(mapOfMasterTermIds != null && !mapOfMasterTermIds.isEmpty()) ? mapOfMasterTermIds.get(termRef[1]).Term_Reference__c:''+'-'+prgCmpsRel.get(str)[0].Campus__r.Name;
                        termObj.Name = request.Batch.year + '-' + request.Batch.intake + '-' + pgmAliasMap.get(request.Batch.academicProgramsName) + '-' + 
                            ((string.isNotBlank(replacetermwithsemester)) ? 
                             replacetermwithsemester+ '-' : 
                             '') + prgCmpsRel.get(str)[0].Campus__r.Name;
                        termObj.hed__Account__c=accMap.get(request.Batch.academicProgramsName).Id;
                        termObj.Program_Plan__c=response.batchId;
                        termObj.Term_Reference__c=termRef[1];
                        termObj.Campus__c=prgCmpsRel.get(str)[0].Campus__c;
                        termObj.RecordTypeId=Schema.SObjectType.hed__Term__c.getRecordTypeInfosByName().get('Default Record').getRecordTypeId();
                        termObj.Term_Duration__c = termDurationMap.get(termRef[1]);
                        termObj.hed__Type__c=(mapOfMasterTermIds != null && !mapOfMasterTermIds.isEmpty() && mapOfMasterTermIds.containsKey(termRef[1])) ?mapOfMasterTermIds.get(termRef[1]).hed__Type__c:null;
                        system.debug('duration===>'+ termObj.Name);
                        
                        termList.add(termObj);
                    }
                    //system.debug(termList.size());
                    if(!termList.isEmpty()){
                        insert termList;
                        List<K42_Academic_Planner__c> academicList=new List<K42_Academic_Planner__c>();
                        List<Term_Campus_Relationship__c> termCampusCombList = new List<Term_Campus_Relationship__c>();
                        for(hed__Term__c termVal:termList)
                        {
                            K42_Academic_Planner__c academic=new K42_Academic_Planner__c();
                            academic.Name=termVal.Name+'-Planner';
                            academic.K42_Program__c=termVal.hed__Account__c;
                            academic.Program_Plan__c=termVal.Program_Plan__c;
                            academic.Term__c=termVal.Id;
                            academic.RecordTypeId=Schema.SObjectType.K42_Academic_Planner__c.getRecordTypeInfosByName().get('Default').getRecordTypeId();
                            academicList.add(academic);
                        }
                        system.debug(academicList.size());
                        if(!academicList.isEmpty())
                        {
							insert academicList;
                        }
                    }
                    Map<String,hed__Term__c> mapOfTermsAndCampus = new Map<String,hed__Term__c>();
                    for(hed__Term__c trmList:[Select Id,Name,campus__c,hed__Parent_Term__r.Term_Reference__c,Master_Term_Campus_Relationship__r.Program_Campus_Combination__c from hed__Term__c where Id=:termList]){
                        mapOfTermsAndCampus.put(trmList.campus__c+'-'+trmList.hed__Parent_Term__r.Term_Reference__c,trmList);
                    }
                    List<Term_Campus_Relationship__c> termCampusCombList = new List<Term_Campus_Relationship__c>();
                    for(Program_Campus_Relationship__c prgCmpsObj:[SELECT Id,Name,Combination_Name__c,(Select Id,Name,Term__c,Term__r.Term_Reference__c,Campus__c,Campus__r.Name,CurrencyIsoCode,Program_Campus_Combination__c from Term_Campus_Relationships__r) from Program_Campus_Relationship__c where Id=:request.Batch.campus]){
                        Program_Campus_Relationship__c prgCampusRelObj = new Program_Campus_Relationship__c();
                        prgCampusRelObj.Combination_Name__c = prgCmpsObj.Combination_Name__c;
                        prgCampusRelObj.Program_Plan__c = response.batchId;
                        prgCampusRelObj.Master_Program_Campus_Combination__c = prgCmpsObj.Id;
                        prgCampusRelObj.RecordTypeId = Schema.SObjectType.Program_Campus_Relationship__c.getRecordTypeInfosByName().get('Program Plan Level Campus Combination').getRecordTypeId();
                        insert prgCampusRelObj;
                        for(Term_Campus_Relationship__c trmCmpsList:prgCmpsObj.Term_Campus_Relationships__r){
                            Term_Campus_Relationship__c trmCampusRelObj = new Term_Campus_Relationship__c();
                            trmCampusRelObj.Program_Campus_Combination__c = prgCampusRelObj.Id;
                            trmCampusRelObj.Term__c = mapOfTermsAndCampus.containsKey(trmCmpsList.Campus__c+'-'+trmCmpsList.Term__r.Term_Reference__c)?mapOfTermsAndCampus.get(trmCmpsList.Campus__c+'-'+trmCmpsList.Term__r.Term_Reference__c).Id:null;
                            trmCampusRelObj.Campus__c = trmCmpsList.Campus__c;
                            trmCampusRelObj.CurrencyIsoCode = trmCmpsList.CurrencyIsoCode;
                            termCampusCombList.add(trmCampusRelObj);
                        }
                    }
                    if(!termCampusCombList.isEmpty()){
                        insert termCampusCombList;
                    }
                }
            }
            if(!String.isBlank(request.Specialization.academicProgramsName) && !String.isBlank(request.Specialization.specializationName))
            {
               
                if(accMap.keyset().contains(request.Specialization.specializationName))
                {
                    if(accMap.keyset().contains(request.Specialization.academicProgramsName))
                    {
                        response.specializationId=accMap.get(request.Specialization.specializationName).Id;
                    }
                }
                else
                {
                    if(accMap.keyset().contains(request.Specialization.academicProgramsName))
                    {
                        Account accPgm=new Account();
                        accPgm.Name=request.Specialization.specializationName;
                        accPgm.ParentId=accMap.get(request.Specialization.academicProgramsName).Id;
                        accPgm.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Program Specialization').getRecordTypeId();
                        insert accPgm;
                        response.specializationId=accPgm.Id;
                    }
                }
            }
            res.statusCode = 200;
            if(!String.isBlank(response.programId)||!String.isBlank(response.batchId)||!String.isBlank(response.specializationId))
            {
                jsonResponse=json.serialize(response);
                res.responseBody=Blob.valueOf(jsonResponse); 
            }
            else 
            {
                 res.responseBody = Blob.valueOf( '{ "success": "true" , "message": No Data Found}' );
            }
        }Catch(Exception e){
            system.debug(e.getMessage()+'at Line Number'+e.getLineNumber());
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    //Wrapper class for the request from API 
    public class requestCreateProgramBatchSpecializationWrapper {
        public requestProgramWrapper Program {get;set;}
        public requestBatchWrapper Batch {get;set;}
        public requestSpecializationWrapper Specialization {get;set;}
        
    }
    
    public class requestProgramWrapper {
        public String academicProgramsName {get;set;}
        public String levelOfAcademicProgram {get;set;}
        public String academicProgramsAlias {get;set;}
        public requestDurationWrapper duration {get;set;}
        public String numberofTerms {get;set;}   
        public String termduration {get;set;}  
        public string programDuration {get;set;}
       
   }
    
    public class requestBatchWrapper {
        public String academicProgramsName {get;set;}
        public String batchName {get;set;}
        public String startDate {get;set;}
        public String endDate {get;set;}
        public String batchStrength {get;set;}
        public String year {get;set;}
        public String intake {get;set;}
        public String workingDays {get;set;}
        public List<Id> campus {get;set;}
        public string termDuration {get;set;}
    }
    
    public class requestSpecializationWrapper {
        public String academicProgramsName {get;set;}
        public String specializationName {get;set;}
    }
    
    public class requestDurationWrapper {
        public String year {get;set;}
        public String months {get;set;}
    }
    
    public class responseWrapper {
        public string success='true';
        public string message='Data is Added';
        public String programId {get;set;}
        public String batchId {get;set;}
        public String batchName {get;set;}
        public String specializationId {get;set;}
    }
   
}