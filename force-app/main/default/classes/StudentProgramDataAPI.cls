@RestResource(urlMapping='/studentProgramData/*')
global with sharing class StudentProgramDataAPI {
    
    @HttpGet
    global static List<StudentProgramResponse> getStudentProgramData() {
        String contactIdStr = RestContext.request.params.get('contactId');
        if (String.isBlank(contactIdStr)) {
            throw new AuraHandledException('Missing required parameter: contactId');
        }
        Id contactId;
        try {
            contactId = (Id)contactIdStr;
        } catch (Exception e) {
            throw new AuraHandledException('Invalid Contact ID: ' + contactIdStr);
        }
        
        if ([SELECT COUNT() FROM Contact WHERE Id = :contactId] == 0) {
            throw new AuraHandledException('Contact not found: ' + contactIdStr);
        }
        
        List<hed__Affiliation__c> affiliations = [
            SELECT Id, hed__Account__c, hed__Account__r.Name, Program_Plan__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c = :contactId
            AND Program_Plan__c != NULL
            AND hed__Status__c != 'Withdrawn'
            WITH SECURITY_ENFORCED
        ];
        
        Set<Id> programPlanIds = new Set<Id>();
        Map<Id, AffiliationInfo> affByPlanMap = new Map<Id, AffiliationInfo>();
        for (hed__Affiliation__c aff : affiliations) {
            programPlanIds.add(aff.Program_Plan__c);
            affByPlanMap.put(aff.Program_Plan__c, new AffiliationInfo(aff));
        }
        if (programPlanIds.isEmpty()) {
            return new List<StudentProgramResponse>();
        }
        
        Map<Id, List<ProgramPathwayInfo>> pathwayByPlanId = new Map<Id, List<ProgramPathwayInfo>>();
        for (Program_Pathway__c pathway : [
            SELECT Id, Name, Specialization_Type__c, Maximum_Credits__c, Program_Plan__c
            FROM Program_Pathway__c
            WHERE Program_Plan__c IN :programPlanIds
            WITH SECURITY_ENFORCED
        ]) {
            ProgramPathwayInfo pInfo = new ProgramPathwayInfo();
            pInfo.ProgramPathwayId = pathway.Id;
            pInfo.Name = pathway.Name;
            pInfo.SpecializationType = pathway.Specialization_Type__c;
            pInfo.MaximumCredits = pathway.Maximum_Credits__c;
            
            if (!pathwayByPlanId.containsKey(pathway.Program_Plan__c)) {
                pathwayByPlanId.put(pathway.Program_Plan__c, new List<ProgramPathwayInfo>());
            }
            pathwayByPlanId.get(pathway.Program_Plan__c).add(pInfo);
        }
        
        Map<Id, List<hed__Term__c>> termsByPlanMap = new Map<Id, List<hed__Term__c>>();
        Set<Id> termIds = new Set<Id>();
        
        for (hed__Term__c term : [
            SELECT Id, Name, hed__Start_Date__c, hed__End_Date__c, Program_Plan__c, Maximum_Credit__c, Minimum_Credit__c,
            (SELECT Id, Name,Minimum_Courses__c,Maximum_Courses__c,Course_Enrollment__c FROM Clusters__r)
            FROM hed__Term__c
            WHERE Program_Plan__c IN :programPlanIds
            WITH SECURITY_ENFORCED
            ORDER BY hed__Start_Date__c NULLS LAST
        ]) {
            if (!termsByPlanMap.containsKey(term.Program_Plan__c)) {
                termsByPlanMap.put(term.Program_Plan__c, new List<hed__Term__c>());
            }
            termsByPlanMap.get(term.Program_Plan__c).add(term);
            termIds.add(term.Id);
        }
        
        Map<Id, List<ProgramEnrollmentInfo>> enrollmentsByTermId = new Map<Id, List<ProgramEnrollmentInfo>>();
        for (hed__Program_Enrollment__c pe : [
            SELECT Id, Name, Term__c, hed__Contact__c, hed__Contact__r.Name
            FROM hed__Program_Enrollment__c
            WHERE Term__c IN :termIds
            AND hed__Contact__c = :contactIdStr
            AND (hed__Affiliation__c = NULL OR hed__Affiliation__r.hed__Status__c != 'Withdrawn')
            WITH SECURITY_ENFORCED
        ]) {
            ProgramEnrollmentInfo peInfo = new ProgramEnrollmentInfo();
            peInfo.ProgramEnrollmentId = pe.Id;
            peInfo.Name = pe.Name;
            peInfo.ContactId = pe.hed__Contact__c;
            peInfo.ContactName = pe.hed__Contact__r != null ? pe.hed__Contact__r.Name : null;
            
            if (!enrollmentsByTermId.containsKey(pe.Term__c)) {
                enrollmentsByTermId.put(pe.Term__c, new List<ProgramEnrollmentInfo>());
            }
            enrollmentsByTermId.get(pe.Term__c).add(peInfo);
        }
        
        Set<Id> peIds = new Set<Id>();
        for (List<ProgramEnrollmentInfo> peList : enrollmentsByTermId.values()) {
            for (ProgramEnrollmentInfo peInfo : peList) {
                peIds.add(peInfo.ProgramEnrollmentId);
            }
        }
        Map<Id, List<CourseInfo>> coursesByPlanId = new Map<Id, List<CourseInfo>>();
        
        if (!peIds.isEmpty()) {
            for (hed__Course_Enrollment__c cc : [
                SELECT Id,
                hed__Program_Enrollment__c,
                hed__Course_Offering__c,
                hed__Course_Offering__r.Parent_Course_Code__c,
                hed__Course_Offering__r.hed__Course__r.Id,
                hed__Course_Offering__r.hed__Course__r.Name,
                hed__Course_Offering__r.hed__Term__r.Program_Plan__c
                FROM hed__Course_Enrollment__c
                WHERE hed__Program_Enrollment__c IN :peIds
                WITH SECURITY_ENFORCED
            ]) {
                CourseInfo ci = new CourseInfo();
                ci.CourseId = cc.hed__Course_Offering__r.hed__Course__c;
                ci.CourseName = cc.hed__Course_Offering__r.hed__Course__r.Name;
                ci.CourseCode = cc.hed__Course_Offering__r.Parent_Course_Code__c;
                ci.ProgramEnrollmentId = cc.hed__Program_Enrollment__c;
                
                Id planId = cc.hed__Course_Offering__r.hed__Term__r.Program_Plan__c;
                if (!coursesByPlanId.containsKey(planId)) {
                    coursesByPlanId.put(planId, new List<CourseInfo>());
                }
                coursesByPlanId.get(planId).add(ci);
            }
        }
        
        Map<Id, Decimal> obtainedCreditsByTerm = new Map<Id, Decimal>();
        
        if (!peIds.isEmpty()) {
            Map<Id, Id> peToTermMap = new Map<Id, Id>();
            for (hed__Program_Enrollment__c pe : [
                SELECT Id, Term__c
                FROM hed__Program_Enrollment__c
                WHERE Id IN :peIds
                WITH SECURITY_ENFORCED
            ]) {
                peToTermMap.put(pe.Id, pe.Term__c);
            }
            
            for (hed__Course_Enrollment__c ce : [
                SELECT Id, 
                hed__Program_Enrollment__c,
                Credits__c
                FROM hed__Course_Enrollment__c
                WHERE hed__Program_Enrollment__c IN :peIds
                AND Credits__c != null
                WITH SECURITY_ENFORCED
            ]) {
                Id termId = peToTermMap.get(ce.hed__Program_Enrollment__c);
                if (termId != null) {
                    Decimal credits = ce.Credits__c != null ? ce.Credits__c : 0;
                    obtainedCreditsByTerm.put(termId, 
                        (obtainedCreditsByTerm.containsKey(termId) ? obtainedCreditsByTerm.get(termId) : 0) + credits);
                }
            }
        }
        
        Set<Id> validAcademicTermIds = new Set<Id>();
        for (hed__Term__c term : [
            SELECT Academic_Term__c
            FROM hed__Term__c
            WHERE Program_Plan__c IN :programPlanIds
            WITH SECURITY_ENFORCED
        ]) {
            if (term.Academic_Term__c != null) {
                validAcademicTermIds.add(term.Academic_Term__c);
            }
        }
        
        Map<Id, List<TermInfo>> termInfoByAcademicTermId = new Map<Id, List<TermInfo>>();
        for (hed__Term__c t : [
            SELECT Id, Name, hed__Start_Date__c, hed__End_Date__c, Academic_Term__c
            FROM hed__Term__c
            WHERE Academic_Term__c IN :validAcademicTermIds
            WITH SECURITY_ENFORCED
        ]) {
            TermInfo ti = new TermInfo();
            ti.TermId = t.Id;
            ti.TermName = t.Name;
            ti.StartDate = t.hed__Start_Date__c;
            ti.EndDate = t.hed__End_Date__c;
            if (!termInfoByAcademicTermId.containsKey(t.Academic_Term__c)) {
                termInfoByAcademicTermId.put(t.Academic_Term__c, new List<TermInfo>());
            }
            termInfoByAcademicTermId.get(t.Academic_Term__c).add(ti);
        }
        
        List<Student_Registration_Window__c> regWindows = [
            SELECT Id, Start_Date__c, End_Date__c, Credits__c, Program_Plan__c,
            Course_Enrollment_Management__c,
            Course_Enrollment_Management__r.Academic_Term__c
            FROM Student_Registration_Window__c
            WHERE Active__c = TRUE
            AND Program_Plan__c IN :programPlanIds
            AND Course_Enrollment_Management__r.Academic_Term__c IN :validAcademicTermIds
            WITH SECURITY_ENFORCED
        ];
                
        Map<Id, List<RegistrationWindowInfo>> regWindowMap = new Map<Id, List<RegistrationWindowInfo>>();
        for (Student_Registration_Window__c rw : regWindows) {
            if (!regWindowMap.containsKey(rw.Program_Plan__c)) {
                regWindowMap.put(rw.Program_Plan__c, new List<RegistrationWindowInfo>());
            }
            RegistrationWindowInfo rwi = new RegistrationWindowInfo();
            rwi.RegistrationStartDate = rw.Start_Date__c;
            rwi.RegistrationEndDate = rw.End_Date__c;
            
            rwi.Terms = new List<TermInfo>();
            if (termInfoByAcademicTermId.containsKey(rw.Course_Enrollment_Management__r.Academic_Term__c)) {
                rwi.Terms.addAll(termInfoByAcademicTermId.get(rw.Course_Enrollment_Management__r.Academic_Term__c));
            }
            
            regWindowMap.get(rw.Program_Plan__c).add(rwi);
        }
        
        Map<Id, hed__Program_Plan__c> plansMap = new Map<Id, hed__Program_Plan__c>([
            SELECT Id, Name
            FROM hed__Program_Plan__c
            WHERE Id IN :programPlanIds
        ]);
        
        List<StudentProgramResponse> results = new List<StudentProgramResponse>();
        for (Id planId : programPlanIds) {
            AffiliationInfo affInfo = affByPlanMap.get(planId);
            hed__Program_Plan__c planRec = plansMap.get(planId);
            
            StudentProgramResponse res = new StudentProgramResponse();
            res.AffiliationId = affInfo.AffiliationId;
            res.AccountId = affInfo.AccountId;
            res.AccountName = affInfo.AccountName;
            res.ProgramPlanId = planId;
            res.ProgramPlanName = (planRec != null ? planRec.Name : null);
            res.ProgramPathways = pathwayByPlanId.containsKey(planId) ? pathwayByPlanId.get(planId) : new List<ProgramPathwayInfo>();
            res.Terms = new List<TermInfo>();
            res.RegistrationWindow = regWindowMap.containsKey(planId) ? regWindowMap.get(planId) : new List<RegistrationWindowInfo>();
            res.Courses = coursesByPlanId.containsKey(planId)? coursesByPlanId.get(planId) : new List<CourseInfo>();
            List<hed__Term__c> termList = termsByPlanMap.get(planId);
            if (termList != null) {
                for (hed__Term__c term : termList) {
                    TermInfo ti = new TermInfo();
                    ti.TermId = term.Id;
                    ti.TermName = term.Name;
                    ti.StartDate = term.hed__Start_Date__c;
                    ti.EndDate = term.hed__End_Date__c;
                    ti.MaximumCredit = term.Maximum_Credit__c;
                    ti.MinimumCredit = term.Minimum_Credit__c;
                    ti.ObtainedCredits = obtainedCreditsByTerm.containsKey(term.Id) ? obtainedCreditsByTerm.get(term.Id) : 0;
                    ti.ProgramEnrollments = enrollmentsByTermId.containsKey(term.Id)
                        ? enrollmentsByTermId.get(term.Id)
                        : new List<ProgramEnrollmentInfo>();
                    ti.Clusters = new List<ClusterInfo>();
                    if (term.Clusters__r != null) {
                        for (Cluster__c cluster : term.Clusters__r) {
                            ClusterInfo ci = new ClusterInfo();
                            ci.ClusterId = cluster.Id;
                            ci.Name = cluster.Name;
                            ci.MaxCourse = cluster.Maximum_Courses__c;
                            ci.MinCourse = cluster.Minimum_Courses__c;
                            ci.courseEnrollmentId = cluster.Course_Enrollment__c;
                            ti.Clusters.add(ci);
                        }
                    }
                    res.Terms.add(ti);
                }
            }
            results.add(res);
        }
        return results;
    }
    
    global class StudentProgramResponse {
        public String AffiliationId;
        public String AccountId;
        public String AccountName;
        public String ProgramPlanId;
        public String ProgramPlanName;
        public List<ProgramPathwayInfo> ProgramPathways;
        public List<TermInfo> Terms;
        public List<RegistrationWindowInfo> RegistrationWindow;
        public List<CourseInfo> Courses;
    }
    
    global class ProgramPathwayInfo {
        public String ProgramPathwayId;
        public String Name;
        public String SpecializationType;
        public Decimal MaximumCredits;
    }
    
    global class TermInfo {
        public String TermId;
        public String TermName;
        public Date StartDate;
        public Date EndDate;
        public Date RegistrationStart;
        public Date RegistrationEnd;
        public Decimal MaximumCredit;
        public Decimal MinimumCredit;
        public Decimal ObtainedCredits;
        public List<ProgramEnrollmentInfo> ProgramEnrollments;
        public List<ClusterInfo> Clusters;
    }
    
    global class ProgramEnrollmentInfo {
        public String ProgramEnrollmentId;
        public String Name;
        public String ContactId;
        public String ContactName;
        public Decimal NoOfPathwayConnections;
    }
    
    global class ClusterInfo {
        public String ClusterId;
        public String Name;
        public Decimal MaxCourse;
        public Decimal MinCourse;
        public String courseEnrollmentId;
    }
    
    global class RegistrationWindowInfo {
        public Date RegistrationStartDate;
        public Date RegistrationEndDate;
        public List<TermInfo> Terms; 
    }
    
    private class AffiliationInfo {
        public String AffiliationId;
        public String AccountId;
        public String AccountName;
        public AffiliationInfo(hed__Affiliation__c aff) {
            AffiliationId = aff.Id;
            AccountId = aff.hed__Account__c;
            AccountName = aff.hed__Account__r != null ? aff.hed__Account__r.Name : null;
        }
    }
    
    global class CourseInfo {
        public String CourseId;
        public String CourseName;
        public String CourseCode;
        public String ProgramEnrollmentId; 
    }
}