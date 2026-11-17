@isTest
public class DSUOnlineReceiptPdfControllerTest {
    
    @isTest
    static void testConstructorWithParameters() {
        // Create a test page with parameters
        PageReference testPage = new PageReference('/apex/DSUOnlineReceiptPdf');
        testPage.getParameters().put('StudentName', 'John Doe');
        testPage.getParameters().put('ApplicationNo', 'APP2025001');
        testPage.getParameters().put('USN', '1AB20CS001');
        testPage.getParameters().put('Program', 'Bachelor of Computer Application');
        testPage.getParameters().put('Semester', '5');
        testPage.getParameters().put('ReceiptNo', 'RCPT-12345');
        testPage.getParameters().put('ReceiptDate', '2025-08-01');
        testPage.getParameters().put('AcademicSession', '2025-26');
        testPage.getParameters().put('Particular', 'Tuition Fee');
        testPage.getParameters().put('Amount', '125000');
        testPage.getParameters().put('PaymentMode', 'Online');
        testPage.getParameters().put('PaymentRefNo', 'TXN789654123');
        testPage.getParameters().put('PaymentRefDate', '2025-07-30');
        testPage.getParameters().put('Total', '125000');
        testPage.getParameters().put('amountInWords', 'One Lakh Twenty Five Thousand Rupees Only');
        
        Test.setCurrentPage(testPage);
        
        Test.startTest();
        DSUOnlineReceiptPdfController controller = new DSUOnlineReceiptPdfController();
        Test.stopTest();
    }
    
    @isTest
    static void testConstructorWithoutParameters() {
        // Create a test page without parameters
        PageReference testPage = new PageReference('/apex/DSUOnlineReceiptPdf');
        Test.setCurrentPage(testPage);
        
        Test.startTest();
        DSUOnlineReceiptPdfController controller = new DSUOnlineReceiptPdfController();
        Test.stopTest();
    }
}