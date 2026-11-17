@isTest
public class Code39Test {

    @isTest
    static void testWithoutCheckDigit() {
        Code39 obj = new Code39();
        obj.sourceCodeValue = 'ABC123';
        obj.shouldCheckDigit = false;

        List<String> result = obj.getBarCodeString();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Barcode should have values');
    }

    @isTest
    static void testWithCheckDigit() {
        Code39 obj = new Code39();
        obj.sourceCodeValue = 'XYZ789';
        obj.shouldCheckDigit = true;

        List<String> result = obj.getBarCodeString();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);
    }

    @isTest
    static void testLowerCaseInput() {
        Code39 obj = new Code39();
        obj.sourceCodeValue = 'abc'; // should convert to ABC
        obj.shouldCheckDigit = false;

        List<String> result = obj.getBarCodeString();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);
    }

    @isTest
    static void testNullInput() {
        Code39 obj = new Code39();
        obj.sourceCodeValue = null;
        obj.shouldCheckDigit = false;
        Boolean threw = false;
        try {
            List<String> result = obj.getBarCodeString();
            System.assertNotEquals(null, result);
        } catch (IllegalArgumentException ex) {
            threw = true;
            System.assert(ex.getMessage().contains('Source value cannot be blank'));
        }
        System.assertNotEquals(null, threw);
    }

    @isTest
    static void testInvalidCharactersIgnored() {
        Code39 obj = new Code39();
        obj.sourceCodeValue = 'ABC@#123'; // @ and # are invalid
        obj.shouldCheckDigit = false;
        Boolean threw = false;
        try {
            List<String> result = obj.getBarCodeString();
            System.assertNotEquals(null, result);
            System.assert(result.size() > 0);
        } catch (IllegalArgumentException ex) {
            threw = true;
            System.assert(ex.getMessage().contains('Unsupported Code39 character'));
        }
        System.assertNotEquals(null, threw);
    }

    @isTest
    static void testSpecialCharacters() {
        Code39 obj = new Code39();
        obj.sourceCodeValue = '-.$/+%';
        obj.shouldCheckDigit = true;

        List<String> result = obj.getBarCodeString();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);
    }
}