@RestResource(urlMapping='/getDataForCourseEnrolment/*')
global class RestApi_GetDataForCourseEnrolment{
    @HttpGet
    global static void doGetDataForCourseEnrolment(){
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        string jsonResponse;
        Map<String,List<Object>> app=new Map<String,List<Object>>();
        Map<Id,List<hed__Plan_Requirement__c>> mapOfTermsListWithPlanRequirements = new Map<Id,List<hed__Plan_Requirement__c>>();
        String instituteId=RestContext.request.params.get('instituteId');
        system.debug('The reqInstituteId'+instituteId);
        //instituteId = '0011y00000P7qFEAAZ';
        Set<Id> setOfDefaultTermIds = new Set<Id>();
        if(String.isNotEmpty(instituteId)){

            Map<Id, List<hed__Term__c>> mapOfTermsWithProgramPlanId = new Map<Id, List<hed__Term__c>>();
            Map<Id, List<hed__Program_Plan__c>> mapOfProgramPlansWithAccountId = new Map<Id, List<hed__Program_Plan__c>>();
            Map<Id, List<Account>> mapOfSpecializationAccountWithAccountId = new Map<Id, List<Account>>();
            Set<Id> setOfAcademicaProgramId = new Set<Id>();
            Set<Id> setPfProgramPlanIds = new Set<Id>();
            Map<Id,List<AcademicProgram>> mapOfAcdemicProgramForDepartmentData = new Map<Id,List<AcademicProgram>>();
            Map<Id,List<ProgramSpecialization>> mapOfProgramSpecializationForAcedemicProgramData = new Map<Id,List<ProgramSpecialization>>();
            Map<Id,List<ProgramPlan>> mapOfProgramPlanWithAcademicProgramData = new Map<Id,List<ProgramPlan>>();
            Map<Id,List<Term>> mapOfTermForProgramPlan = new Map<Id,List<Term>>();
            List<Department> DepartmentsListData = new List<Department>();
            Map<Id, Set<String>> mapOfSectionsWithTermId = new Map<Id, Set<String>>();
            Set<Id> setOfTermId = new Set<Id>();
            Map<Id,List<Section>> mapOfSectionsWithTermData = new Map<Id,List<Section>>();
            List<Account> accList= [select id, Name, RecordType.Name, (select id, Name,recordtype.name from ChildAccounts where RecordType.Name ='Academic Program' Order By Name) from account where parentId = :instituteId and RecordType.Name ='University Department' Order By Name];
            //system.debug(accList[0].ChildAccounts);
            for(Account acc :accList){
                for(Account childAcc :acc.ChildAccounts){
                    setOfAcademicaProgramId.add(childAcc.Id);
                }
            }
           
            List<Account> accListOfProgramSpecal= [select id, Name, RecordType.Name,ParentId from account where parentId IN :setOfAcademicaProgramId and RecordType.Name ='Program Specialization' Order By Name];
            for(Account acc :accListOfProgramSpecal){
                if(!mapOfSpecializationAccountWithAccountId.containsKey(acc.parentId)){
                    mapOfSpecializationAccountWithAccountId.put(acc.parentId,new List<Account>());
                }
                mapOfSpecializationAccountWithAccountId.get(acc.parentId).add(acc);
            }
            for(hed__Program_Plan__c programPlan :[select id, Name,hed__Start_Date__c,hed__End_Date__c,hed__Description__c,hed__Account__c  from hed__Program_Plan__c where hed__Account__c IN :setOfAcademicaProgramId and Recordtype.Name = 'Program Version' Order By Name]){
                setPfProgramPlanIds.add(programPlan.Id);
                if(!mapOfProgramPlansWithAccountId.containsKey(programPlan.hed__Account__c)){
                    mapOfProgramPlansWithAccountId.put(programPlan.hed__Account__c,new List<hed__Program_Plan__c>());
                }
                mapOfProgramPlansWithAccountId.get(programPlan.hed__Account__c).add(programPlan);
            }

            for(hed__Term__c term :[select id, Name,hed__Start_Date__c,hed__End_Date__c,hed__Type__c,Program_Plan__c from hed__Term__c where Program_Plan__c IN : setPfProgramPlanIds Order By Name]){
                setOfTermId.add(term.Id);
                if(!mapOfTermsWithProgramPlanId.containsKey(term.Program_Plan__c)){
                    mapOfTermsWithProgramPlanId.put(term.Program_Plan__c,new List<hed__Term__c>());
                }
                mapOfTermsWithProgramPlanId.get(term.Program_Plan__c).add(term);
            }

            for(hed__Course_Offering__c co : [select id,name,hed__Term__c,hed__Term__r.Name,hed__Section_ID__c from hed__Course_Offering__c where hed__Term__c IN :setOfTermId and hed__Section_ID__c!=null Order By hed__Section_ID__c]){
                if(!mapOfSectionsWithTermId.containsKey(co.hed__Term__c)){
                    mapOfSectionsWithTermId.put(co.hed__Term__c,new Set<String>());
                }
                mapOfSectionsWithTermId.get(co.hed__Term__c).add(co.hed__Section_ID__c);
            }
            
            for(Account acc :accList){
                Department department = new Department();
                department.DepartmentName = acc.Name;
                department.DepartmentId = acc.Id;
                DepartmentsListData.add(department);
                for(Account childAcc :acc.ChildAccounts){
                    
                    /* Academic Program Map */
                    AcademicProgram acProgram =new AcademicProgram();
                    acProgram.AcademicProgramName = childAcc.Name;
                    acProgram.AcademicProgramId = childAcc.Id;
                    if(!mapOfAcdemicProgramForDepartmentData.containsKey(acc.Id)){
                        mapOfAcdemicProgramForDepartmentData.put(acc.Id, new List<AcademicProgram>());
                    }
                    mapOfAcdemicProgramForDepartmentData.get(acc.Id).add(acProgram);
                    /* End Academic Program Map */

                    /* Program Specializtion Map */
                    if(mapOfSpecializationAccountWithAccountId.containsKey(childAcc.Id)){
                        for(Account programSpecializationAccount :mapOfSpecializationAccountWithAccountId.get(childAcc.Id)){
                            ProgramSpecialization pSpecialization = new ProgramSpecialization();
                            pSpecialization.ProgramSpecializationName = programSpecializationAccount.Name;
                            pSpecialization.ProgramSpecializationId = programSpecializationAccount.Id;

                            if(!mapOfProgramSpecializationForAcedemicProgramData.containsKey(childAcc.Id)){
                                mapOfProgramSpecializationForAcedemicProgramData.put(childAcc.Id, new List<ProgramSpecialization>());
                            }
                            mapOfProgramSpecializationForAcedemicProgramData.get(childAcc.Id).add(pSpecialization);
                        }
                    }
                     /* End Program Specializtion Map */

                     /* Program Plan Map */
                    if(mapOfProgramPlansWithAccountId.containsKey(childAcc.Id)){
                        for(hed__Program_Plan__c programPlan :mapOfProgramPlansWithAccountId.get(childAcc.Id)){
                            ProgramPlan programPlanData = new ProgramPlan();
                            programPlanData.ProgramPlanName = programPlan.Name;
                            programPlanData.ProgramPlanId = programPlan.Id;

                            if(!mapOfProgramPlanWithAcademicProgramData.containsKey(childAcc.Id)){
                                mapOfProgramPlanWithAcademicProgramData.put(childAcc.Id, new List<ProgramPlan>());
                            }
                            mapOfProgramPlanWithAcademicProgramData.get(childAcc.Id).add(programPlanData);

                            /* Term Map */

                            if(mapOfTermsWithProgramPlanId.containsKey(programPlan.Id)){
                                for(hed__Term__c term :mapOfTermsWithProgramPlanId.get(programPlan.Id)){
                                    Term termData = new Term();
                                    termData.TermName = term.Name;
                                    termData.TermId = term.Id;

                                    if(!mapOfTermForProgramPlan.containsKey(programPlan.Id)){
                                        mapOfTermForProgramPlan.put(programPlan.Id, new List<Term>());
                                    }
                                    mapOfTermForProgramPlan.get(programPlan.Id).add(termData);

                                    /*Section Loop*/ 
                                    if(mapOfSectionsWithTermId.containsKey(term.Id)){
                                        for(String sectionName :mapOfSectionsWithTermId.get(term.Id)){
                                            Section sectionData = new Section();
                                            sectionData.SectionName = sectionName;
    
                                            if(!mapOfSectionsWithTermData.containsKey(term.Id)){
                                                mapOfSectionsWithTermData.put(term.Id, new List<Section>());
                                            }
                                            mapOfSectionsWithTermData.get(term.Id).add(sectionData);
                                        }
                                	}

                                }
                            }


                            /* End Map */

                        }
                    }
                     /* End Program Plan Map */

                }
            }
            TermEnrolmentData finalData = new TermEnrolmentData();
            finalData.DepartmentsList = DepartmentsListData;
            finalData.AcdemicProgramsForEachDepartment = mapOfAcdemicProgramForDepartmentData;
            finalData.ProgramSpecializationForEachAcedemicProgram = mapOfProgramSpecializationForAcedemicProgramData;
            finalData.ProgramPlanForEachAcedemicProgram = mapOfProgramPlanWithAcademicProgramData;
            finalData.TermForEachProgramPlan = mapOfTermForProgramPlan;
            finalData.SectionsForEachTerm = mapOfSectionsWithTermData;
            system.debug('finalData');
            if(finalData.DepartmentsList.size()>0){
                jsonResponse = JSON.serialize(finalData);
                if(finalData!=null){  
                    res.statusCode = 200;
                    res.responseBody=Blob.valueOf(jsonResponse); 
                }
                else
                {
                    res.statusCode = 200;
                    res.responseBody=Blob.valueOf('[]'); 
                }
            } 
            
        }
        else{
            res.responseBody = Blob.valueOf( '{ "success": "true" , "message": "No Data Found"}' );
        }
    }
    
    public class TermEnrolmentData{
        public List<Department> DepartmentsList{get;set;}
        public Map<Id,List<AcademicProgram>> AcdemicProgramsForEachDepartment{get;set;}
        public Map<Id,List<ProgramSpecialization>> ProgramSpecializationForEachAcedemicProgram{get;set;}
        public Map<Id,List<ProgramPlan>> ProgramPlanForEachAcedemicProgram{get;set;}
        public Map<Id,List<Term>> TermForEachProgramPlan{get;set;}
        public Map<Id,List<Section>> SectionsForEachTerm{get;set;} 
    }
    public class Department{
        public String DepartmentName{get;set;}
        public String DepartmentId{get;set;}
    }
    public class AcademicProgram{
        public String AcademicProgramName{get;set;}
        public String AcademicProgramId{get;set;}
    }
    public class ProgramSpecialization{
        public String ProgramSpecializationName{get;set;}
        public String ProgramSpecializationId{get;set;}
    }

    public class ProgramPlan{
        public String ProgramPlanName{get;set;}
        public String ProgramPlanId{get;set;}
    }

    public class Term{
        public String TermName{get;set;}
        public String TermId{get;set;}
    }

    public class Section{
        public String SectionName{get;set;}
    }
    
}