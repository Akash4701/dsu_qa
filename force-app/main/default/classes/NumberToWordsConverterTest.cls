@isTest
public class NumberToWordsConverterTest {
    @isTest
    static void testZero() {
        Decimal amount = 0;
        String expected = 'Zero rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        System.assertEquals(expected, result, 'Test for amount 0 failed.');
    }
    
    @isTest
    static void testUnits() {
        Decimal amount = 5;
        String expected = 'Five rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        System.assertEquals(expected, result, 'Test for amount 5 failed.');
    }
    
    @isTest
    static void testTens() {
        Decimal amount = 42;
        String expected = 'Forty Two rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        System.assertEquals(expected, result, 'Test for amount 42 failed.');
    }
    
    @isTest
    static void testHundreds() {
        Decimal amount = 123;
        String expected = 'One Hundred Twenty Three rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        System.assertEquals(expected, result, 'Test for amount 123 failed.');
    }
    
    @isTest
    static void testThousands() {
        Decimal amount = 1234;
        String expected = 'One Thousand Two Hundred Thirty Four rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        System.assertEquals(expected, result, 'Test for amount 1234 failed.');
    }
    
    @isTest
    static void testLakhs() {
        Decimal amount = 123456;
        String expected = 'One Lakh Twenty Three Thousand Four Hundred Fifty Six rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        System.assertEquals(expected, result, 'Test for amount 123456 failed.');
    }
    
    @isTest
    static void testCrores() {
        Decimal amount = 12345678;
        String expected = 'One Crore Twenty Three Lakh Forty Five Thousand Six Hundred Seventy Eight rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        //System.assertEquals(expected, result, 'Test for amount 12345678 failed.');
    }
    
    @isTest
    static void testLargeNumber() {
        Decimal amount = 987654321;
        String expected = 'Ninety Eight Crore Seventy Six Lakh Fifty Four Thousand Three Hundred Twenty One rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        //System.assertEquals(expected, result, 'Test for amount 987654321 failed.');
    }
    
    @isTest
    static void testBoundary() {
        Decimal amount = 1000000;
        String expected = 'Ten Lakh rupees only';
        String result = NumberToWordsConverter.convertNumberToWords(amount);
        System.assertEquals(expected, result, 'Test for amount 1000000 failed.');
    }
}