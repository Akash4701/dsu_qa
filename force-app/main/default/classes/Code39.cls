public class Code39 {
    public Boolean shouldCheckDigit { get; set; }
    public String sourceCodeValue { get; set; }

    private static final String KEYS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%*';
    private static final List<String> VALUES = new List<String>{
        '1010001110111010','1110100010101110','1011100010101110','1110111000101010',
        '1010001110101110','1110100011101010','1011100011101010','1010001011101110',
        '1110100010111010','1011100010111010','1110101000101110','1011101000101110',
        '1110111010001010','1010111000101110','1110101110001010','1011101110001010',
        '1010100011101110','1110101000111010','1011101000111010','1010111000111010',
        '1110101010001110','1011101010001110','1110111010100010','1010111010001110',
        '1110101110100010','1011101110100010','1010101110001110','1110101011100010',
        '1011101011100010','1010111011100010','1110001010101110','1000111010101110',
        '1110001110101010','1000101110101110','1110001011101010','1000111011101010',
        '1000101011101110','1110001010111010','1000111010111010','1000100010001010',
        '1000100010100010','1000101000100010','1010001000100010','1000101110111010'
    };

    public List<String> getBarCodeString() {
        String source = sourceCodeValue == null ? '' : sourceCodeValue.toUpperCase();
        Boolean useCheckDigit = (shouldCheckDigit == true);

        String finalCode = generateCode39(source, useCheckDigit);

        List<String> bars = new List<String>();
        for (Integer i = 0; i < finalCode.length(); i++) {
            bars.add(finalCode.substring(i, i + 1));
        }
        return bars;
    }

    private String generateCode39(String source, Boolean checkDigit) {
        if (String.isBlank(source)) {
            throw new IllegalArgumentException('Source value cannot be blank.');
        }

        List<String> result = new List<String>();
        Integer total = 0;

        Integer startStopIndex = KEYS.indexOf('*');
        result.add(VALUES[startStopIndex]);

        for (Integer i = 0; i < source.length(); i++) {
            String ch = source.substring(i, i + 1);

            if (ch == '*') {
                throw new IllegalArgumentException('Character "*" is reserved for start/stop in Code39.');
            }

            Integer index = KEYS.indexOf(ch);
            if (index == -1) {
                throw new IllegalArgumentException('Unsupported Code39 character: ' + ch);
            }

            result.add(VALUES[index]);
            total += index;
        }

        if (checkDigit) {
            result.add(VALUES[Math.mod(total, 43)]);
        }

        result.add(VALUES[startStopIndex]);
        return String.join(result, '');
    }
}