@isTest
public class FeeAssignmentHandlerTest {

    @testSetup
    static void setupData() {
        // ----- Create Account hierarchy -----
        Account institute = new Account(Name = 'Test Institute', Institute_Code__c = 'TST');
        insert institute;

        Account dept = new Account(Name = 'Engineering Department', ParentId = institute.Id);
        insert dept;

        Account program = new Account(Name = 'Bachelor of Technology', Alias__c = 'BT', ParentId = dept.Id);
        insert program;

        // ----- Program Plan -----
        hed__Program_Plan__c plan = new hed__Program_Plan__c(
            hed__Account__c = program.Id,
            Batch__c = '2025',
            Intake_Number__c = 1,
            Sequence_Number__c = 1
        );
        insert plan;

        // ----- Terms -----
        hed__Term__c term1 = new hed__Term__c(
            Program_Plan__c = plan.Id,
            Term_Reference__c = 'Semester 1',
            hed__Account__c = program.Id
        );
        insert term1;

        hed__Term__c term2 = new hed__Term__c(
            Program_Plan__c = plan.Id,
            Term_Reference__c = 'Semester 2',
            hed__Account__c = program.Id
        );
        insert term2;

        // ----- Fee Types -----
        Fee_Type__c feeTypeSem = new Fee_Type__c(
            Program__c = program.Id,
            Semester__c = term1.Id,
            Fee_Preference__c = 'Semester-wise fee',
            Fee_Head__c = 'Semester Fee',
            Amount__c = 50000
        );
        insert feeTypeSem;

        Fee_Type__c feeTypeYear = new Fee_Type__c(
            Program__c = program.Id,
            Semester__c = term1.Id,
            Fee_Preference__c = 'Year-wise fee',
            Fee_Head__c = 'Year Wise Fee',
            Amount__c = 120000
        );
        insert feeTypeYear;

        // ----- Contact -----
        Contact student = new Contact(FirstName = 'John', LastName = 'Doe');
        insert student;

        // ----- Applications -----
        Application__c appSem = new Application__c(
            Status__c = 'Approved for USN',
            Fee_Preference__c = 'Semester-wise fee',
			External_Application_Number__c = 'asdfg123',
			Program_Level__c = 'UG'
        );
        insert appSem;

        Application__c appYear = new Application__c(
            Status__c = 'Approved for USN',
            Fee_Preference__c = 'Year-wise fee',
			External_Application_Number__c = 'lkjhg0987',
			Program_Level__c = 'UG'
        );
        insert appYear;

        // ----- Affiliations -----
        hed__Affiliation__c affSem = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            Program_Plan__c = plan.Id,
            Individual_Application__c = appSem.Id
        );
        insert affSem;

        hed__Affiliation__c affYear = new hed__Affiliation__c(
            hed__Contact__c = student.Id,
            Program_Plan__c = plan.Id,
            Individual_Application__c = appYear.Id
        );
        insert affYear;

        // ----- Program Enrollments -----
        hed__Program_Enrollment__c enrollSem = new hed__Program_Enrollment__c(
            hed__Affiliation__c = affSem.Id,
            hed__Program_Plan__c = plan.Id,
            hed__Contact__c = student.Id,
            Term__c = term1.Id
        );
        insert enrollSem;

        hed__Program_Enrollment__c enrollYear = new hed__Program_Enrollment__c(
            hed__Affiliation__c = affYear.Id,
            hed__Program_Plan__c = plan.Id,
            hed__Contact__c = student.Id,
            Term__c = term1.Id
        );
        insert enrollYear;
    }

    @isTest
    static void testSemesterWiseFeeAssignments() {
        hed__Program_Enrollment__c enroll = [
            SELECT Id, hed__Affiliation__c, Term__c
            FROM hed__Program_Enrollment__c
            LIMIT 1
        ];

        Test.startTest();
        FeeAssignmentHandler.prepareAndCreateFeeAssignments(new List<hed__Program_Enrollment__c>{ enroll });
        Test.stopTest();
    }

    @isTest
    static void testYearWiseFeeAssignments() {
        hed__Program_Enrollment__c enroll = [
            SELECT Id, hed__Affiliation__c, Term__c
            FROM hed__Program_Enrollment__c
            WHERE hed__Affiliation__r.Individual_Application__r.Fee_Preference__c = 'Year-wise fee'
            LIMIT 1
        ];

        Test.startTest();
        FeeAssignmentHandler.prepareAndCreateFeeAssignments(new List<hed__Program_Enrollment__c>{ enroll });
        Test.stopTest();
    }

    @isTest
    static void testNoEnrollments() {
        Test.startTest();
        FeeAssignmentHandler.prepareAndCreateFeeAssignments(new List<hed__Program_Enrollment__c>());
        Test.stopTest();
    }
    
    @isTest
static void testCalculateScholarship_AmountAndPercentage() {

    // Get one Fee Assignment created by earlier tests
    // Paid_Amount__c is read by calculateScholarship; a trigger record always carries it, a test query must select it.
    Fee_Assignment__c fa = [
        SELECT Id, Fee_Amount__c, Remaining_Amount__c, Paid_Amount__c
        FROM Fee_Assignment__c
        LIMIT 1
    ];

    // Create two scholarships
    Fee_Discount__c amountScholarship = new Fee_Discount__c(
        Name = 'Flat Scholarship',
        Discount_Type__c = 'Amount',
        Discount_Amount__c = 10000
    );
    insert amountScholarship;

    Fee_Discount__c percentScholarship = new Fee_Discount__c(
        Name = 'Percentage Scholarship',
        Discount_Type__c = 'Percentage',
        Discount_Percentage__c = 10
    );
    insert percentScholarship;

    // -------- Amount based scholarship --------
    fa.Scholarship__c = amountScholarship.Id;
    update fa;

    Fee_Assignment__c oldFa = [
        SELECT Id, Fee_Amount__c
        FROM Fee_Assignment__c
        WHERE Id = :fa.Id
    ];

    Test.startTest();
    FeeAssignmentHandler.calculateScholarship(
        new List<Fee_Assignment__c>{ fa },
        new Map<Id, Fee_Assignment__c>{ fa.Id => oldFa }
    );

    // -------- Percentage based scholarship --------
    fa.Scholarship__c = percentScholarship.Id;
    update fa;

    oldFa = [
        SELECT Id, Fee_Amount__c
        FROM Fee_Assignment__c
        WHERE Id = :fa.Id
    ];

    FeeAssignmentHandler.calculateScholarship(
        new List<Fee_Assignment__c>{ fa },
        new Map<Id, Fee_Assignment__c>{ fa.Id => oldFa }
    );
    Test.stopTest();
}
    
    @isTest
static void testUpdateInstallments() {

    Fee_Assignment__c fa = [
        SELECT Id, Fee_Amount__c
        FROM Fee_Assignment__c
        LIMIT 1
    ];

    // Manually set scholarship on FA
    fa.Scholarship_Amount__c = 15000;
    update fa;
    
    Account institute = new Account(Name = 'Test Institute', Institute_Code__c = 'TST');
        insert institute;
    
    Account dept = new Account(Name = 'Engineering Department', ParentId = institute.Id);
        insert dept;
    
    Account program = new Account(Name = 'Bachelor of Technology', Alias__c = 'BT', ParentId = dept.Id);
        insert program;
    
    hed__Program_Plan__c plan = new hed__Program_Plan__c(
            hed__Account__c = program.Id,
            Batch__c = '2025',
            Intake_Number__c = 1,
            Sequence_Number__c = 1
        );
        insert plan;
    
    hed__Term__c term1 = new hed__Term__c(
            Program_Plan__c = plan.Id,
            Term_Reference__c = 'Semester 1',
            hed__Account__c = program.Id
        );
        insert term1;
    
    Fee_Type__c feeTypeSem = new Fee_Type__c(
        Program__c = program.Id,
        Semester__c = term1.Id,
        Fee_Preference__c = 'Semester-wise fee',
        Fee_Head__c = 'Semester Fee',
        Amount__c = 30000
    );
    insert feeTypeSem;
    
    Fee_Type__c feeTypeSem2 = new Fee_Type__c(
        Program__c = program.Id,
        Semester__c = term1.Id,
        Fee_Preference__c = 'Semester-wise fee',
        Fee_Head__c = 'Semester Fee',
        Amount__c = 20000
    );
    insert feeTypeSem2;

    // Create multiple installments
    Fee_Installment__c inst1 = new Fee_Installment__c(
        Fee_Assignment__c = fa.Id,
		Fee_Type__c = feeTypeSem.Id,
        Remaining_Amount__c = 30000
    );

    Fee_Installment__c inst2 = new Fee_Installment__c(
        Fee_Assignment__c = fa.Id,
        Fee_Type__c = feeTypeSem2.Id,
        Remaining_Amount__c = 20000
    );

    insert new List<Fee_Installment__c>{ inst1, inst2 };

    Test.startTest();
    FeeAssignmentHandler.updateInstallments(
        new List<Fee_Assignment__c>{ fa }
    );
    Test.stopTest();
}


}