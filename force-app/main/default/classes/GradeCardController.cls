public with sharing class GradeCardController {

    // Shown in the CIA/SEE Result column when no Component_Scores__c record
    // exists at all for that exam type (student never attempted it).
    private static final String NO_COMPONENT_SCORE_LABEL = 'In Complete';

    // ===== VF Parameters =====
    public Id termId { get; private set; }
    public Id programEnrollmentId { get; private set; }

    // ===== Header / Student details =====
    public String studentName { get; private set; }
    public String rollNumber { get; private set; }
    public String programName { get; private set; }
    public String semester { get; private set; }     // Term_Reference__c
    public String examination { get; private set; }  // Parent Term Name
    public Decimal sgpa { get; private set; }
    public String studentPhotoUrl { get; private set; }
    public String aadhaarNumber { get; private set; }   // Contact.Aadhar_Number__c

    // ===== Template fields =====
    public String gcNumber { get; private set; }
    public String modeOfExam { get; private set; }
    public String modeOfDelivery { get; private set; }
    public List<String> barcodeBars { get; set; }
    public List<String> barcodeRunStyles { get; set; }


    // For VF table
    public List<CourseRow> courseRows { get; private set; }

    // Drives the compact CSS layout in GradeCardPdf.page so the SGPA/signature
    // block stays on page 1 regardless of how many courses the student has.
    public Boolean isCompact {
        get { return courseRows != null && courseRows.size() > 5; }
    }

    // ===== Constructor used by VF =====
    public GradeCardController() {
        courseRows = new List<CourseRow>();

        termId = (Id) ApexPages.currentPage().getParameters().get('termId');
        programEnrollmentId = (Id) ApexPages.currentPage().getParameters().get('peId');

        // defaults
        studentName = '';
        rollNumber = '';
        programName = '';
        semester = '';
        examination = '';
        sgpa = 0;
        studentPhotoUrl = null;
        aadhaarNumber = '';

        gcNumber = '';
        modeOfExam = 'Online Remote Proctored Examination';
        modeOfDelivery = 'Online';
        barcodeBars = new List<String>();
        barcodeRunStyles = new List<String>();

        if (termId != null && programEnrollmentId != null) {
            buildPdfData(termId, programEnrollmentId);
        }
    }

    // ===== LWC response wrapper =====
    public class GenerateResponse {
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer failCount;
        @AuraEnabled public List<String> errors;
    }

    // ===== LWC entry point =====
    @AuraEnabled
    public static GenerateResponse generateGradeCards(Id termId) {
        if (termId == null) {
            throw new AuraHandledException('Term Id is required.');
        }

        GenerateResponse resp = new GenerateResponse();
        resp.successCount = 0;
        resp.failCount = 0;
        resp.errors = new List<String>();

        List<hed__Program_Enrollment__c> peList = [
            SELECT Id,
                   hed__Contact__r.Name,
                   hed__Affiliation__r.Roll_Number__c
            FROM hed__Program_Enrollment__c
            WHERE Term__c = :termId
            ORDER BY CreatedDate ASC
        ];

        if (peList.isEmpty()) return resp;

        // PDF generation has limits in one transaction
      //  Integer MAX_PDFS_PER_TXN = 5;
        Integer processed = 0;

        for (hed__Program_Enrollment__c pe : peList) {

       /*     if (processed >= MAX_PDFS_PER_TXN) {
                Integer remaining = peList.size() - processed;
                resp.failCount += remaining;
                resp.errors.add(
                    'Stopped after ' + MAX_PDFS_PER_TXN +
                    ' PDFs due to Salesforce PDF generation limits. Run again to generate remaining.'
                );
                break;
            }*/

            try {
                PageReference pr = Page.GradeCardPdf; // VF page name
                pr.getParameters().put('termId', String.valueOf(termId));
                pr.getParameters().put('peId', String.valueOf(pe.Id));

                Blob pdfBlob;
                if (Test.isRunningTest()) {
                    pdfBlob = Blob.valueOf('TEST_PDF');
                } else {
                    pdfBlob = pr.getContentAsPDF();
                }

                storePdfOnProgramEnrollment(
                    pe.Id,
                    pdfBlob,
                    'E-Grade Card',
                    (pe.hed__Contact__r != null) ? pe.hed__Contact__r.Name : null,
                    (pe.hed__Affiliation__r != null) ? pe.hed__Affiliation__r.Roll_Number__c : null
                );

                resp.successCount++;
                processed++;

            } catch (Exception ex) {
                resp.failCount++;
                resp.errors.add('PE ' + pe.Id + ': ' + ex.getMessage());
            }
        }

        return resp;
    }

    // ===== Store the PDF at Program Enrollment level =====
    private static void storePdfOnProgramEnrollment(Id peId, Blob pdfBody, String prefix) {
        storePdfOnProgramEnrollment(peId, pdfBody, prefix, null, null);
    }

    private static void storePdfOnProgramEnrollment(
        Id peId,
        Blob pdfBody,
        String prefix,
        String studentName,
        String rollNumber
    ) {
        String resolvedStudentName = studentName;
        String resolvedRollNumber = rollNumber;

        if (String.isBlank(resolvedStudentName) || String.isBlank(resolvedRollNumber)) {
            hed__Program_Enrollment__c pe = [
                SELECT Id,
                       hed__Contact__r.Name,
                       hed__Affiliation__r.Roll_Number__c
                FROM hed__Program_Enrollment__c
                WHERE Id = :peId
                LIMIT 1
            ];
            if (String.isBlank(resolvedStudentName) && pe.hed__Contact__r != null) {
                resolvedStudentName = pe.hed__Contact__r.Name;
            }
            if (String.isBlank(resolvedRollNumber) && pe.hed__Affiliation__r != null) {
                resolvedRollNumber = pe.hed__Affiliation__r.Roll_Number__c;
            }
        }

        String title = buildGradeCardTitle(prefix, resolvedStudentName, resolvedRollNumber, peId);

        ContentVersion cv = new ContentVersion();
        cv.Title = title;
        cv.PathOnClient = title + '.pdf';
        cv.VersionData = pdfBody;
        cv.Document_Type__c='Grade Card';
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = peId; // ✅ Program Enrollment record
        cdl.ContentDocumentId = insertedCv.ContentDocumentId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        insert cdl;
    }

    private static String buildGradeCardTitle(
        String prefix,
        String studentName,
        String rollNumber,
        Id peId
    ) {
        String safePrefix = String.isBlank(prefix) ? 'E-Grade Card' : prefix.trim();
        String cleanName = String.isBlank(studentName) ? null : studentName.trim();
        String cleanRoll = String.isBlank(rollNumber) ? null : rollNumber.trim();

        if (!String.isBlank(cleanName) && !String.isBlank(cleanRoll)) {
            return cleanName + '(' + cleanRoll + ')_' + safePrefix;
        }
        if (!String.isBlank(cleanName)) {
            return cleanName + '_' + safePrefix;
        }
        if (!String.isBlank(cleanRoll)) {
            return cleanRoll + '_' + safePrefix;
        }
        return String.valueOf(peId) + '_' + safePrefix;
    }

    // ===== Build data for VF PDF =====
    private void buildPdfData(Id termId, Id peId) {

        hed__Term__c termRec = [
            SELECT Id, Term_Reference__c, hed__Parent_Term__r.Name
            FROM hed__Term__c
            WHERE Id = :termId
            LIMIT 1
        ];

        hed__Program_Enrollment__c pe = [
            SELECT Id, SGPA__c,
                   hed__Contact__c,
                   hed__Contact__r.Name,
                   hed__Contact__r.Registration_Number__c,
                   hed__Contact__r.Aadhar_Number__c,
                   hed__Contact__r.Passport_Size_Photo__c,
                   hed__Account__r.Name
            FROM hed__Program_Enrollment__c
            WHERE Id = :peId
            LIMIT 1
        ];
        System.debug('programenrollment' + pe);

        // ===== MINIMAL SAFE CHANGE START =====
        // Old code could throw "List has no rows for assignment to SObject"
        // when the Contact has no Affiliation record.
        List<hed__Affiliation__c> afList = [
            SELECT Id, Roll_Number__c
            FROM hed__Affiliation__c
            WHERE hed__Contact__c = :pe.hed__Contact__c
            LIMIT 1
        ];
        hed__Affiliation__c af = (!afList.isEmpty()) ? afList[0] : null;
        // ===== MINIMAL SAFE CHANGE END =====

        studentName = (pe.hed__Contact__r != null && pe.hed__Contact__r.Name != null)
            ? pe.hed__Contact__r.Name
            : '';

        programName = (pe.hed__Account__r != null && pe.hed__Account__r.Name != null)
            ? pe.hed__Account__r.Name
            : '';

        aadhaarNumber = (pe.hed__Contact__r != null && pe.hed__Contact__r.Aadhar_Number__c != null)
            ? pe.hed__Contact__r.Aadhar_Number__c
            : '';

        rollNumber = (pe.hed__Contact__r != null && af != null && af.Roll_Number__c != null)
            ? String.valueOf(af.Roll_Number__c)
            : '';

        // GC number: use roll number by default (matches your generated PDF sample)
        gcNumber = (String.isBlank(rollNumber)) ? String.valueOf(pe.Id) : rollNumber;
        
        // Generate barcode strictly from gcNumber only.
        barcodeBars = new List<String>();
        barcodeRunStyles = new List<String>();
        if (!String.isBlank(gcNumber)) {
            Code39 barcode = new Code39();
            barcode.sourceCodeValue = gcNumber.trim();
            barcode.shouldCheckDigit = false;
            barcodeBars = barcode.getBarCodeString();
            barcodeRunStyles = buildBarcodeRunStyles(barcodeBars, 0.45);
        }

        semester = (termRec.Term_Reference__c != null)
            ? String.valueOf(termRec.Term_Reference__c)
            : '';

        examination = (termRec.hed__Parent_Term__r != null) ? termRec.hed__Parent_Term__r.Name : '';
        sgpa = (pe.SGPA__c == null) ? 0 : pe.SGPA__c;

        studentPhotoUrl = (pe.hed__Contact__r != null && pe.hed__Contact__r.Passport_Size_Photo__c != null)
            ? String.valueOf(pe.hed__Contact__r.Passport_Size_Photo__c)
            : null;

        // (keep as template text)
        modeOfExam = 'Online Remote Proctored Examination';
        modeOfDelivery = 'Online';

        List<hed__Course_Enrollment__c> ceList = [
            SELECT Id,
                   hed__Course_Offering__c,
                   hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c,
                   hed__Course_Offering__r.hed__Course__r.Name,
                   hed__Course_Offering__r.hed__Course__r.Credits__c,
                   Final_Grade__c,
                   Grade_Point__c,
                   Component_Final_Score__c,
                   Exam_Result_Status__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Program_Enrollment__c = :peId AND hed__Course_Offering__r.hed__Course__r.Exclude_From_Official_Records__c = false
            ORDER BY hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c
        ];

        Set<Id> ceIds = new Set<Id>();
        Set<Id> courseOfferingIds = new Set<Id>();
        for (hed__Course_Enrollment__c ce : ceList) {
            ceIds.add(ce.Id);
            if (ce.hed__Course_Offering__c != null) courseOfferingIds.add(ce.hed__Course_Offering__c);
        }

        // ===== Component definitions (Max/Min) per Course Offering + Exam Type =====
        // Sourced independently of Component_Scores__c so Max/Min still shows the
        // configured values even when the student never attempted that exam type
        // (no Component_Scores__c record exists for them).
        Map<String, Totals> componentDefMap = new Map<String, Totals>();
        if (!courseOfferingIds.isEmpty()) {
            for (Course_Evaluation_Component__c cec : [
                SELECT Course_Offering__c, Exam_Type__c,
                       Maximum_Marks_for_the_Component__c, Pass_Weightage__c
                FROM Course_Evaluation_Component__c
                WHERE Course_Offering__c IN :courseOfferingIds
                  AND Exam_Type__c IN ('CIA','SEE')
            ]) {
                if (cec.Course_Offering__c == null || cec.Exam_Type__c == null) continue;

                Decimal maxMark = (cec.Maximum_Marks_for_the_Component__c == null) ? 0 : cec.Maximum_Marks_for_the_Component__c;
                Decimal passWeightage = (cec.Pass_Weightage__c == null) ? 0 : cec.Pass_Weightage__c;

                Totals def = new Totals();
                def.max = maxMark;
                def.pass = (maxMark * passWeightage) / 100;
                componentDefMap.put(cec.Course_Offering__c + '|' + cec.Exam_Type__c, def);
            }
        }

        // ===== Exam Cycle per course connection (latest Exam Connection by CreatedDate) =====
        Map<Id, String> examCycleByCourseConn = new Map<Id, String>();
        if (!ceIds.isEmpty()) {
            for (Exam_Connections__c ec : [
                SELECT Course_Connection_ID__c, Exam_Name__r.Exam_Cycle__r.Name, CreatedDate
                FROM Exam_Connections__c
                WHERE Course_Connection_ID__c IN :ceIds
                ORDER BY CreatedDate DESC
            ]) {
                if (ec.Course_Connection_ID__c == null) continue;
                if (!examCycleByCourseConn.containsKey(ec.Course_Connection_ID__c)) {
                    examCycleByCourseConn.put(
                        ec.Course_Connection_ID__c,
                        (ec.Exam_Name__r != null && ec.Exam_Name__r.Exam_Cycle__r != null)
                            ? ec.Exam_Name__r.Exam_Cycle__r.Name
                            : null
                    );
                }
            }
        }

        // ===== Component Scores (CIA/SEE) =====
        // ✅ Requirement: Do NOT add/sum across multiple component score rows.
        // We will pick ONE active record per CE per Exam_Type (latest by CreatedDate) and display it.
        List<Component_Scores__c> scList = new List<Component_Scores__c>();
        if (!ceIds.isEmpty()) {
            scList = [
                SELECT Id,
                       Course_Connection__c,
                       Exam_Type__c,
                       Marks_Obtained__c,
                       Component_Score_Result__c,
                       Component_Name__r.Maximum_Marks_for_the_Component__c,
                       Component_Name__r.Pass_Weightage__c,
                       CreatedDate
                FROM Component_Scores__c
                WHERE Is_Active__c = true
                  AND Course_Connection__c IN :ceIds
                  AND Exam_Type__c IN ('CIA','SEE')
                ORDER BY CreatedDate DESC
            ];
        }

        Map<Id, Totals> ciaMap = new Map<Id, Totals>();
        Map<Id, Totals> seeMap = new Map<Id, Totals>();

        for (Component_Scores__c sc : scList) {
            if (sc.Course_Connection__c == null || sc.Exam_Type__c == null) continue;

            Map<Id, Totals> targetMap = (sc.Exam_Type__c == 'CIA') ? ciaMap : seeMap;

            // keep only ONE record per CE per exam type (latest because of ORDER BY CreatedDate DESC)
            if (targetMap.containsKey(sc.Course_Connection__c)) continue;

            Decimal maxMark = (sc.Component_Name__r != null && sc.Component_Name__r.Maximum_Marks_for_the_Component__c != null)
                ? sc.Component_Name__r.Maximum_Marks_for_the_Component__c
                : 0;

            Decimal passWeightage = (sc.Component_Name__r != null && sc.Component_Name__r.Pass_Weightage__c != null)
                ? sc.Component_Name__r.Pass_Weightage__c
                : 0;

            Decimal passMark = (maxMark * passWeightage) / 100;

            Totals t = new Totals();
            // ✅ NO addition: set values directly from the chosen record
            t.max = maxMark;
            t.pass = passMark;
            t.scored = (sc.Marks_Obtained__c == null) ? 0 : sc.Marks_Obtained__c;
            if (sc.Component_Score_Result__c != null) {
                t.resultSet.add(String.valueOf(sc.Component_Score_Result__c));
            }
            targetMap.put(sc.Course_Connection__c, t);
        }

        courseRows.clear();

        for (hed__Course_Enrollment__c ce : ceList) {
            Boolean hasCia = ciaMap.containsKey(ce.Id);
            Boolean hasSee = seeMap.containsKey(ce.Id);
            Totals cia = hasCia ? ciaMap.get(ce.Id) : new Totals();
            Totals see = hasSee ? seeMap.get(ce.Id) : new Totals();

            // Max/Min always comes from the course's component definition, not
            // from the (possibly absent) Component_Scores__c record, so it still
            // shows the configured values when the exam was never attempted.
            Totals ciaDef = (ce.hed__Course_Offering__c != null && componentDefMap.containsKey(ce.hed__Course_Offering__c + '|CIA'))
                ? componentDefMap.get(ce.hed__Course_Offering__c + '|CIA')
                : cia;
            Totals seeDef = (ce.hed__Course_Offering__c != null && componentDefMap.containsKey(ce.hed__Course_Offering__c + '|SEE'))
                ? componentDefMap.get(ce.hed__Course_Offering__c + '|SEE')
                : see;

            CourseRow r = new CourseRow();
            r.courseCode = (ce.hed__Course_Offering__r != null &&
                            ce.hed__Course_Offering__r.hed__Course__r != null &&
                            ce.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c != null)
                ? String.valueOf(ce.hed__Course_Offering__r.hed__Course__r.hed__Course_ID__c)
                : '';

            r.courseTitle = (ce.hed__Course_Offering__r != null &&
                             ce.hed__Course_Offering__r.hed__Course__r != null)
                ? ce.hed__Course_Offering__r.hed__Course__r.Name
                : '';

            r.examCycle = examCycleByCourseConn.containsKey(ce.Id) && examCycleByCourseConn.get(ce.Id) != null
                ? examCycleByCourseConn.get(ce.Id)
                : '';

            r.credits = (ce.hed__Course_Offering__r != null &&
                         ce.hed__Course_Offering__r.hed__Course__r != null)
                ? ce.hed__Course_Offering__r.hed__Course__r.Credits__c
                : null;

            // ===== CIA =====
            r.ciaMax = formatMaxMin(ciaDef.max, ciaDef.pass);     // max/passmark (from component definition)
            r.ciaScored = cia.scored;                       // Marks_Obtained__c (no sum)
            r.ciaResult = hasCia ? joinSet(cia.resultSet, '/') : NO_COMPONENT_SCORE_LABEL;

            // ===== SEE =====
            r.seeMax = formatMaxMin(seeDef.max, seeDef.pass);     // max/passmark (from component definition)
            r.seeScored = see.scored;                       // Marks_Obtained__c (no sum)
            r.seeResult = hasSee ? joinSet(see.resultSet, '/') : NO_COMPONENT_SCORE_LABEL;

            r.finalResult = (ce.Exam_Result_Status__c == null) ? '' : String.valueOf(ce.Exam_Result_Status__c);
            r.gradeLetter = (ce.Final_Grade__c == null) ? '' : String.valueOf(ce.Final_Grade__c);
            r.gradePoint = ce.Grade_Point__c;

            courseRows.add(r);
        }
    }

    private static String formatMaxMin(Decimal maxMark, Decimal passMark) {
        Decimal mx = (maxMark == null) ? 0 : maxMark;
        Decimal ps = (passMark == null) ? 0 : passMark;
        return String.valueOf(mx.setScale(0)) + '/' + String.valueOf(ps.setScale(0));
    }

    private static String joinSet(Set<String> s, String delim) {
        if (s == null || s.isEmpty()) return '';
        List<String> l = new List<String>();
        l.addAll(s);
        l.sort();
        return String.join(l, delim);
    }

    // ===== Helper inner classes =====
    private class Totals {
        public Decimal max = 0;                 // Maximum marks (single record)
        public Decimal pass = 0;                // Pass marks = (max/100)*pass_weightage (single record)
        public Decimal scored = 0;              // Marks_Obtained__c (single record)
        public Set<String> resultSet = new Set<String>();  // Component_Score_Result__c (single record)
    }

    // ✅ IMPORTANT: use PROPERTIES so VF can access them
    public class CourseRow {
        public String courseCode { get; set; }
        public String courseTitle { get; set; }
        public String examCycle { get; set; }
        public Decimal credits { get; set; }

        public String ciaMax { get; set; }      //  max/passmark
        public Decimal ciaScored { get; set; }
        public String ciaResult { get; set; }

        public String seeMax { get; set; }      //  max/passmark
        public Decimal seeScored { get; set; }
        public String seeResult { get; set; }

        public String finalResult { get; set; }
        public String gradeLetter { get; set; }
        public Decimal gradePoint { get; set; }
    }

    // Convert continuous 0/1 bits into compact run segments.
    // This allows narrower barcode rendering in VF PDF where 1px bars are often rounded up.
    private static List<String> buildBarcodeRunStyles(List<String> bits, Decimal widthScalePx) {
        List<String> runStyles = new List<String>();
        if (bits == null || bits.isEmpty()) return runStyles;

        String current = bits[0];
        Integer runLen = 1;

        for (Integer i = 1; i < bits.size(); i++) {
            String b = bits[i];
            if (b == current) {
                runLen++;
            } else {
                runStyles.add(makeRunStyle(current, runLen, widthScalePx));
                current = b;
                runLen = 1;
            }
        }
        runStyles.add(makeRunStyle(current, runLen, widthScalePx));
        return runStyles;
    }

    private static String makeRunStyle(String bit, Integer runLen, Decimal widthScalePx) {
        Decimal widthPx = Decimal.valueOf(runLen) * widthScalePx;
        String bg = (bit == '1') ? 'black' : 'transparent';
        return 'width:' + String.valueOf(widthPx.setScale(2)) + 'px;background-color:' + bg + ';';
    }

		@AuraEnabled
public static String startGradeCardBatch(Id termId) {
    if (termId == null) throw new AuraHandledException('Term Id is required.');
    Id jobId = Database.executeBatch(new GradeCardBatch(termId), 1); // batch size 1 safest for PDFs
    return String.valueOf(jobId);
}

/**
 * Batch can’t call your private method.
 * This wrapper keeps your existing logic unchanged.
 */
public static void storePdfFromBatch(Id peId, Blob pdfBody, String prefix) {
    storePdfOnProgramEnrollment(peId, pdfBody, prefix, null, null);
}

public static void storePdfFromBatch(
    Id peId,
    Blob pdfBody,
    String prefix,
    String studentName,
    String rollNumber
) {
    storePdfOnProgramEnrollment(peId, pdfBody, prefix, studentName, rollNumber);
}

}