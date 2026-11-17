@IsTest
public with sharing class GradeRequestWrapperTest {

    @TestSetup
    static void setupData() {
        // Base org-style data (consistent with your earlier tests)
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

        Letter_Grade_Setting__c baseSetting = new Letter_Grade_Setting__c(
            Name = 'Base Setting',
            Mechanism__c = 'Relative',
            Is_Active__c = true
        );
        insert baseSetting;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id,
            Letter_Grade_Setting__c = baseSetting.Id,
            Minimum_Passing_Score__c = '35'
        );
        insert offering;

        // Student RecordType (optional in some orgs)
        Id studentRtId;
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Contact' AND DeveloperName = 'Student'
            LIMIT 1
        ];
        if (!rts.isEmpty()) studentRtId = rts[0].Id;

        Contact student = new Contact(
            LastName = 'Test Student',
            Registration_Number__c = 'REG-1'
        );
        if (studentRtId != null) student.RecordTypeId = studentRtId;
        insert student;

        // Course Enrollment to supply a valid Id for wrapper.Id
        hed__Course_Enrollment__c ce = new hed__Course_Enrollment__c(
            hed__Contact__c = student.Id,
            hed__Course_Offering__c = offering.Id,
            Enrollment_Status__c = 'Enrolled',
            Exam_Eligibility__c = 'Eligible',
            Component_Final_Score__c = 80
        );
        insert ce;
    }

    @IsTest
    static void testWrapperAssignment() {
        // Use real Course Enrollment Id from setup so wrapper.Id matches org data style
        hed__Course_Enrollment__c ce = [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1];

        GradeRequestWrapper w = new GradeRequestWrapper();
        w.Id = String.valueOf(ce.Id);
        w.overrideGrade = 'A';
        w.reasonForDownFall = 'Test reason';
        w.comment = 'Test comment';
    }

    @IsTest
    static void testWrapperListUsage() {
        hed__Course_Enrollment__c ce = [SELECT Id FROM hed__Course_Enrollment__c LIMIT 1];

        List<GradeRequestWrapper> reqs = new List<GradeRequestWrapper>();

        GradeRequestWrapper w1 = new GradeRequestWrapper();
        w1.Id = String.valueOf(ce.Id);
        w1.overrideGrade = 'B';
        w1.reasonForDownFall = 'Penalty';
        w1.comment = 'Updated in bulk';
        reqs.add(w1);

        GradeRequestWrapper w2 = new GradeRequestWrapper();
        w2.Id = String.valueOf(ce.Id);
        w2.overrideGrade = 'C';
        w2.reasonForDownFall = 'Late';
        w2.comment = 'Second payload';
        reqs.add(w2);
    }
}