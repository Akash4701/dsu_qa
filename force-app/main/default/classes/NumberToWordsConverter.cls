public class NumberToWordsConverter {
    private static final String[] units = new String[]{
        '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
        'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    };

    private static final String[] tens = new String[]{
        '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    };

    private static final String[] scales = new String[]{
        '', 'Thousand', 'Lakh', 'Crore'
    };

    public static String convertNumberToWords(Decimal numbers) {
        if (numbers == 0) {
            return 'Zero rupees only';
        }

        String numberStr = String.valueOf(numbers.setScale(0)); // Removing decimal points for simplicity
        Integer numLength = numberStr.length();
        Integer scale = 0;
        String words = '';

        while (numLength > 0) {
            Integer endIndex = numLength;
            Integer startIndex = Math.max(0, endIndex - (scale == 1 ? 2 : 3)); // For thousands and higher, handle two digits at a time
            String segment = numberStr.substring(startIndex, endIndex);
            numLength -= segment.length();

            if (Integer.valueOf(segment) != 0) {
                String segmentWords = convertSegmentToWords(segment);
                if (scale > 0) {
                    segmentWords += ' ' + scales[scale];
                }
                if (words != '') {
                    words = segmentWords + ' ' + words;
                } else {
                    words = segmentWords;
                }
            }
            scale++;
        }

        return words + ' rupees only';
    }

    private static String convertSegmentToWords(String segment) {
        Integer numbers = Integer.valueOf(segment);
        String words = '';

        if (numbers >= 100) {
            words += units[numbers / 100] + ' Hundred ';
            numbers = Math.Mod(numbers, 100);
        }
        if (numbers >= 20) {
            words += tens[numbers / 10] + ' ';
            numbers = Math.Mod(numbers, 10);
        }
        if (numbers > 0) {
            words += units[numbers] + ' ';
        }

        return words.trim();
    }
}