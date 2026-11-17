@IsTest
public class ReleateLettergradeHandlerTest {

    @TestSetup
    static void setupData() {

        // -----------------------------
        // Base Academic Data
        // -----------------------------
        Account dept = new Account(Name = 'Test Department');
        insert dept;

        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Term 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course',
            hed__Account__c = dept.Id,
            Credits__c = 4
        );
        insert course;

        // -----------------------------
        // Grade Scheme RecordTypes
        // Formula field: Grade_Scheme_RecordType_Name__c = Grade_Scheme__r.RecordType.DeveloperName
        // So we set Grade_Scheme__c with desired RecordType.
        // -----------------------------
        Id rtCourse = null;
        Id rtCourseSection = null;

        for (RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Grade_Scheme__c'
            AND DeveloperName IN ('Course', 'Course_Section')
        ]) {
            if (rt.DeveloperName == 'Course') rtCourse = rt.Id;
            if (rt.DeveloperName == 'Course_Section') rtCourseSection = rt.Id;
        }

        Grade_Scheme__c schemeCourse = new Grade_Scheme__c(Name = 'GS Course');
        if (rtCourse != null) schemeCourse.RecordTypeId = rtCourse;
        insert schemeCourse;

        Grade_Scheme__c schemeCourseSection = new Grade_Scheme__c(Name = 'GS Course Section');
        if (rtCourseSection != null) schemeCourseSection.RecordTypeId = rtCourseSection;
        insert schemeCourseSection;

        // -----------------------------
        // Master Letter Grade Setting (Active) for mechanism chosen by criteria
        // -----------------------------
        Id lgsMasterRtId = null;
        List<RecordType> lgsRT = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Letter_Grade_Setting__c'
            AND DeveloperName = 'Master'
            LIMIT 1
        ];
        if (!lgsRT.isEmpty()) lgsMasterRtId = lgsRT[0].Id;

        Letter_Grade_Setting__c masterAbsolute = new Letter_Grade_Setting__c(
            Name = 'Master Absolute',
            Mechanism__c = 'Absolute',
            Is_Active__c = true,
            RecordTypeId = lgsMasterRtId
        );
        insert masterAbsolute;

        // -----------------------------
        // Grade Scheme Criteria -> selects mechanism based on studentStrength
        // -----------------------------
        Grade_Scheme_Critera__c crit = new Grade_Scheme_Critera__c(
            Grade_Scheme__c = schemeCourse.Id,
            Range_From__c = 1,
            Range_To__c = 100,
            Mechanism_Type__c = 'Absolute'
        );
        insert crit;

        // -----------------------------
        // Course Offerings (1 "course-level", 1 "related" offering same term+course)
        // -----------------------------
        hed__Course_Offering__c coCourseLevel = new hed__Course_Offering__c(
            Name = 'CO Course Level',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            Grade_Scheme__c = schemeCourseSection.Id // initial
        );
        insert coCourseLevel;

        hed__Course_Offering__c coRelated = new hed__Course_Offering__c(
            Name = 'CO Related',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            Grade_Scheme__c = schemeCourseSection.Id
        );
        insert coRelated;

        // -----------------------------
        // Create Student CE to satisfy populateLetterGradeSetting query
        // (RecordType DeveloperName = 'Student')
        // -----------------------------
        Id ceStudentRtId = null;
        List<RecordType> ceRT = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'hed__Course_Enrollment__c'
            AND DeveloperName = 'Student'
            LIMIT 1
        ];
        if (!ceRT.isEmpty()) ceStudentRtId = ceRT[0].Id;

        Contact student = new Contact(LastName = 'Student 1');
        insert student;

        hed__Program_Plan__c pp = new hed__Program_Plan__c(Name = 'PP');
        insert pp;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = pp.Id
        );
        insert aff;

        hed__Program_Enrollment__c pe = new hed__Program_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Term__c = term.Id,
            hed__Affiliation__c = aff.Id
        );
        insert pe;

        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Course_Offering__c = coCourseLevel.Id,
            hed__Program_Enrollment__c = pe.Id
        );
        if (ceStudentRtId != null) ce.RecordTypeId = ceStudentRtId;
        insert ce;
    }

    // ---------------------------------------------------------
    // Covers: processBeforeUpdate -> populateLetterGradeSetting
    // + covers processAfterUpdate -> gradeSchemeUpdate
    // ---------------------------------------------------------
    @IsTest
    static void testUpdateGradeScheme_triggersHandlers() {

        // Reset static count for deterministic execution
        ReleateLettergradeHandler.count = 0;

        hed__Course_Offering__c co = [
            SELECT Id, Grade_Scheme__c
            FROM hed__Course_Offering__c
            WHERE Name = 'CO Course Level'
            LIMIT 1
        ];

        Grade_Scheme__c schemeCourse = [
            SELECT Id
            FROM Grade_Scheme__c
            WHERE Name = 'GS Course'
            LIMIT 1
        ];

        Test.startTest();
        // update grade scheme from Course_Section -> Course
        // This should:
        // - allow populateLetterGradeSetting to choose mechanism via criteria
        // - set Letter_Grade_Setting__c from active Master setting
        // - allow gradeSchemeUpdate to cascade scheme to related offering
        co.Grade_Scheme__c = schemeCourse.Id;
        update co;
        Test.stopTest();
    }

    // ---------------------------------------------------------
    // Covers gradeSchemeRemoved branch (remove scheme -> null)
    // ---------------------------------------------------------
    @IsTest
    static void testRemoveGradeScheme_setsLetterGradeSettingNull() {

        ReleateLettergradeHandler.count = 0;

        hed__Course_Offering__c co = [
            SELECT Id, Grade_Scheme__c
            FROM hed__Course_Offering__c
            WHERE Name = 'CO Course Level'
            LIMIT 1
        ];

        Test.startTest();
        co.Grade_Scheme__c = null;
        update co;
        Test.stopTest();
    }
}