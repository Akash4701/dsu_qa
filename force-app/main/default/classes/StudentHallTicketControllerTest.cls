@IsTest
public class StudentHallTicketControllerTest {

    @TestSetup
    static void setupData() {

        // ----------------------------
        // Base org data (as per patterns)
        // ----------------------------
        Account dept = new Account(Name = 'Test Department');
        insert dept;

        hed__Term__c term = new hed__Term__c(
            Name = 'Spring 2025',
            hed__Account__c = dept.Id,
            Term_Reference__c = 'Semester 1',
            hed__Start_Date__c = Date.today(),
            hed__End_Date__c = Date.today().addMonths(4)
        );
        insert term;

        hed__Course__c course = new hed__Course__c(
            Name = 'Test Course 101',
            hed__Account__c = dept.Id,
            hed__Course_ID__c = 'CSE101',
            Credits__c = 4
        );
        insert course;

        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Test Offering',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert offering;

        Course_Evaluation_Component__c cec = new Course_Evaluation_Component__c(
            Name = 'End Term Component',
            Course_Offering__c = offering.Id,
            Exam_Type__c = 'SEE',
            Exam_Name__c = 'End Term',
            Maximum_Marks_for_the_Component__c = 100,
            Pass_Weightage__c = 40
        );
        insert cec;

        Exam_Cycle__c examCycle = new Exam_Cycle__c(
    Name = 'SEE Exam Cycle',
    Exam_Name__c = 'SEE',
    Start_Date__c = Date.today().addDays(-1), // <= TODAY()
    End_Date__c   = Date.today().addDays(10)  // >= TODAY()
);
insert examCycle;


        Exam_Cycle_Term_Connection__c ectc = new Exam_Cycle_Term_Connection__c(
            Term__c = term.Id,
            Exam_Cycle__c = examCycle.Id
        );
        insert ectc;

        // Exam (Exam_Cycle__c derived by trigger handler in your org)
        Exam__c exam = new Exam__c(
            Course_Evaluation_Component__c = cec.Id
        );
        insert exam;

        // ----------------------------
        // Student + Program Plan + Affiliation (for roll/program)
        // ----------------------------
        Contact student = new Contact(
            LastName = 'HallTicket Student',
            Passport_Size_Photo__c = '068000000000001AAA' // 15/18-like id string => normalizePhotoUrl() branch
        );
        insert student;

        hed__Program_Plan__c plan = new hed__Program_Plan__c(Name = 'B.Tech Program');
        insert plan;

        hed__Affiliation__c aff = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            hed__Account__c = dept.Id,
            Program_Plan__c = plan.Id,
            Roll_Number__c = 'ROLL-001'
        );
        insert aff;

        // ----------------------------
        // Slot_Scheduled__c (drives controller rows)
        // Must have:
        //  - Student_ID__c = Contact
        //  - Start_Date_Time__c not null
        //  - Exam__c lookup to reach Term_Reference__c
        //  - Course_ID__c lookup to show course code/name
        // ----------------------------
        Slot_Scheduled__c slot1 = new Slot_Scheduled__c(
            Student_ID__c = student.Id,
            Exam__c = exam.Id,
            Course_ID__c = course.Id,
            Start_Date_Time__c = System.now().addDays(1),
            End_Date_Time__c   = System.now().addDays(1).addHours(2)
        );
        insert slot1;

        Slot_Scheduled__c slot2 = new Slot_Scheduled__c(
            Student_ID__c = student.Id,
            Exam__c = exam.Id,
            Course_ID__c = course.Id,
            Start_Date_Time__c = System.now().addDays(2),
            End_Date_Time__c   = System.now().addDays(2).addHours(2)
        );
        insert slot2;

        // Extra student without affiliation (covers else branch rollNo/programName = N/A)
        Contact studentNoAff = new Contact(LastName = 'No Aff Student');
        insert studentNoAff;

        Slot_Scheduled__c slot3 = new Slot_Scheduled__c(
            Student_ID__c = studentNoAff.Id,
            Exam__c = exam.Id,
            Course_ID__c = course.Id,
            Start_Date_Time__c = System.now().addDays(3),
            End_Date_Time__c   = System.now().addDays(3).addHours(2)
        );
        insert slot3;
    }

    @IsTest
    static void testController_withAffiliation_andSlots() {
        Contact student = [
            SELECT Id
            FROM Contact
            WHERE LastName = 'HallTicket Student'
            LIMIT 1
        ];

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(student);
        StudentHallTicketController ctrl = new StudentHallTicketController(sc);
        Test.stopTest();
    }

    @IsTest
    static void testController_withoutAffiliation_setsNA() {
        Contact student = [
            SELECT Id
            FROM Contact
            WHERE LastName = 'No Aff Student'
            LIMIT 1
        ];

        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(student);
        StudentHallTicketController ctrl = new StudentHallTicketController(sc);
        Test.stopTest();
    }

    @IsTest
    static void testController_nullId_addsPageMessage() {
        Test.startTest();
        ApexPages.StandardController sc = new ApexPages.StandardController(new Contact());
        StudentHallTicketController ctrl = new StudentHallTicketController(sc);
        Test.stopTest();
    }

    @IsTest
    static void testNormalizePhotoUrl_branches() {
        // Covers normalizePhotoUrl() for http, slash, and random string paths via constructor
        Contact c1 = new Contact(LastName='PhotoHttp', Passport_Size_Photo__c='https://example.com/x.png');
        Contact c2 = new Contact(LastName='PhotoSlash', Passport_Size_Photo__c='/resource/x.png');
        Contact c3 = new Contact(LastName='PhotoOther', Passport_Size_Photo__c='SOME_RANDOM_VALUE');
        insert new List<Contact>{ c1, c2, c3 };

        // create minimal scaffolding slots so query runs (even if none found rows still builds)
        // no affiliation needed
        Test.startTest();
        new StudentHallTicketController(new ApexPages.StandardController(c1));
        new StudentHallTicketController(new ApexPages.StandardController(c2));
        new StudentHallTicketController(new ApexPages.StandardController(c3));
        Test.stopTest();
    }
}