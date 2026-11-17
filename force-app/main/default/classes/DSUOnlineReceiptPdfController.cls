public with sharing class DSUOnlineReceiptPdfController {
    public String StudentName { get; set; }
    public String ApplicationNo { get; set; }
    public String USN { get; set; }
    public String Program { get; set; }
    public String Semester { get; set; }
    public String SemesterNumber { get; set; }
    public String ReceiptNo { get; set; }
    public String ReceiptDate { get; set; }
    public String ReceiptDateTime { get; set; }
    public String AcademicSession { get; set; }
    public String StartingYear { get; set; }
    public String Particular { get; set; }
    public String Amount { get; set; }
    public String PaymentMode { get; set; }
    public String PaymentRefNo { get; set; }
    public String PaymentRefDate { get; set; }
    public String Total { get; set; }
    public String amountInWords { get; set; }
    public String settlementUtr { get; set; }
    public String FeePreference { get; set; }

    // Exam (Backlog / Re-Evaluation) fee receipt only
    public String CourseCode { get; set; }
    public String CourseName { get; set; }
    public String NumberOfSubjects { get; set; }
    public Boolean isExamFee { get; set; }
    // One row per course paid in the same exam-fee transaction (consolidated receipt).
    public List<PaymentReceiptService.ExamRow> ExamRows { get; set; }

    public DSUOnlineReceiptPdfController() {
        StudentName = ApexPages.currentPage().getParameters().get('StudentName');
        ApplicationNo = ApexPages.currentPage().getParameters().get('ApplicationNo');
        USN = ApexPages.currentPage().getParameters().get('USN');
        Program = ApexPages.currentPage().getParameters().get('Program');
        Semester = ApexPages.currentPage().getParameters().get('Semester');
		SemesterNumber = ApexPages.currentPage().getParameters().get('SemesterNumber');
        ReceiptNo = ApexPages.currentPage().getParameters().get('ReceiptNo');
        ReceiptDate = ApexPages.currentPage().getParameters().get('ReceiptDate');
		ReceiptDateTime = ApexPages.currentPage().getParameters().get('ReceiptDateTime');
        AcademicSession = ApexPages.currentPage().getParameters().get('AcademicSession');
		StartingYear = ApexPages.currentPage().getParameters().get('StartingYear');
        Particular = ApexPages.currentPage().getParameters().get('Particular');
        Amount = ApexPages.currentPage().getParameters().get('Amount');
        PaymentMode = ApexPages.currentPage().getParameters().get('PaymentMode');
        PaymentRefNo = ApexPages.currentPage().getParameters().get('PaymentRefNo');
        PaymentRefDate = ApexPages.currentPage().getParameters().get('PaymentRefDate');
        Total = ApexPages.currentPage().getParameters().get('Total');
        amountInWords = ApexPages.currentPage().getParameters().get('amountInWords');
        settlementUtr = ApexPages.currentPage().getParameters().get('settlementUtr');
		FeePreference = ApexPages.currentPage().getParameters().get('FeePreference');

        CourseCode = ApexPages.currentPage().getParameters().get('CourseCode');
        CourseName = ApexPages.currentPage().getParameters().get('CourseName');
        NumberOfSubjects = ApexPages.currentPage().getParameters().get('NumberOfSubjects');
        isExamFee = (ApexPages.currentPage().getParameters().get('IsExamFee') == 'true');

        ExamRows = new List<PaymentReceiptService.ExamRow>();
        String examRowsJson = ApexPages.currentPage().getParameters().get('ExamRows');
        if (String.isNotBlank(examRowsJson)) {
            try {
                ExamRows = (List<PaymentReceiptService.ExamRow>)
                    JSON.deserialize(examRowsJson, List<PaymentReceiptService.ExamRow>.class);
            } catch (Exception e) {
                ExamRows = new List<PaymentReceiptService.ExamRow>();
            }
        }
        
        /*StudentName = 'John Doe'; 
        ApplicationNo = 'APP2025001';
        USN = '1AB20CS001';
        Program = 'Bachelor of Computer Application';
        Semester = 'Semester 1';
        SemesterNumber = '1';
        ReceiptNo = 'RCPT-12345';
        ReceiptDate = '2025-08-01';
		ReceiptDateTime = '05/08/2025 15:42';
        AcademicSession = 'OCT-SEP';
        StartingYear = '2025';
        Particular = 'Semester Fee';
        Amount = '125000';
        PaymentMode = 'Online';
        PaymentRefNo = 'TXN789654123';
        PaymentRefDate = '2025-07-30';
        Total = '125000';
        amountInWords = 'Twenty Five Thousand Rupees Only';
        settlementUtr = 'UDVHBJWK8761';
        FeePreference = 'Semester wise fee';*/

    }
}