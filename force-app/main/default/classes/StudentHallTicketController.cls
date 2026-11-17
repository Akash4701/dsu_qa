public with sharing class StudentHallTicketController {

    public String studentName { get; private set; }
    public String rollNo { get; private set; }
    public String programName { get; private set; }

    public String studentPhotoUrl { get; private set; }
    public Boolean hasPhoto { get { return String.isNotBlank(studentPhotoUrl); } }

    public String generatedOn { get; private set; }
    public List<ExamRow> rows { get; private set; }

    public StudentHallTicketController(ApexPages.StandardController stdController) {
        Id contactId = stdController.getId();
        if (contactId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Contact ID is required.'));
            return;
        }

        generatedOn = DateTime.now().format('dd-MMM-yyyy hh:mm a');

        // 1) Contact details + photo
        Contact con = [
            SELECT Name, Passport_Size_Photo__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        studentName = con.Name;
        studentPhotoUrl = normalizePhotoUrl(con.Passport_Size_Photo__c);

        // 2) Roll No & Programme from Affiliation
        List<hed__Affiliation__c> affiliations = [
            SELECT Roll_Number__c, Program_Plan__r.Name
            FROM hed__Affiliation__c
            WHERE hed__Contact__c = :contactId
              AND Roll_Number__c != null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!affiliations.isEmpty()) {
            rollNo = affiliations[0].Roll_Number__c;
            programName = affiliations[0].Program_Plan__r != null ? affiliations[0].Program_Plan__r.Name : 'N/A';
        } else {
            rollNo = 'N/A';
            programName = 'N/A';
        }

        // 3) Exam slots sorted by date + timing
        String examCycleIdParam = ApexPages.currentPage().getParameters().get('examCycleId');
        Id examCycleId = String.isNotBlank(examCycleIdParam) ? (Id) examCycleIdParam : null;

        List<Slot_Scheduled__c> examSlots;
        if (examCycleId != null) {
            examSlots = [
                SELECT
                    Id,
                    Start_Date_Time__c,
                    End_Date_Time__c,
                    Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c,
                    Course_ID__r.hed__Course_ID__c,
                    Course_ID__r.Name,
                    Exam_Connection__r.Exam_Type__c
                FROM Slot_Scheduled__c
                WHERE Student_ID__c = :contactId
                  AND Exam__r.Exam_Cycle__c = :examCycleId
                  AND Start_Date_Time__c != null
                  AND Is_Expired__c = false
                ORDER BY Start_Date_Time__c ASC
            ];
        } else {
            examSlots = [
                SELECT
                    Id,
                    Start_Date_Time__c,
                    End_Date_Time__c,
                    Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c,
                    Course_ID__r.hed__Course_ID__c,
                    Course_ID__r.Name,
                    Exam_Connection__r.Exam_Type__c
                FROM Slot_Scheduled__c
                WHERE Student_ID__c = :contactId
                  AND Start_Date_Time__c != null
                  AND Is_Expired__c = false
                ORDER BY Start_Date_Time__c ASC
            ];
        }

        // Build picklist API value -> label map so the PDF shows the label (e.g. "Backlog") not the API name (e.g. "Retest")
        Map<String, String> examTypeLabelByValue = new Map<String, String>();
        for (Schema.PicklistEntry pe : Schema.SObjectType.Exam_Connections__c.fields.Exam_Type__c.getPicklistValues()) {
            examTypeLabelByValue.put(pe.getValue(), pe.getLabel());
        }

        rows = new List<ExamRow>();
        Integer i = 1;

        for (Slot_Scheduled__c s : examSlots) {
            ExamRow r = new ExamRow();
            r.sno = i;

            // Sem numeric only (e.g., "Semester 1" -> "1")
            String termRef = (s.Exam__r != null &&
                              s.Exam__r.Course_Evaluation_Component__r != null &&
                              s.Exam__r.Course_Evaluation_Component__r.Course_Offering__r != null &&
                              s.Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r != null)
                              ? s.Exam__r.Course_Evaluation_Component__r.Course_Offering__r.hed__Term__r.Term_Reference__c
                              : null;

            r.sem = extractFirstNumber(termRef); // returns "" if null/no number

            r.subjectName = (s.Course_ID__r == null) ? '' : s.Course_ID__r.Name;
            r.subjectCode = (s.Course_ID__r == null) ? '' : s.Course_ID__r.hed__Course_ID__c;

            String examTypeApiVal = (s.Exam_Connection__r == null || s.Exam_Connection__r.Exam_Type__c == null)
                ? '' : s.Exam_Connection__r.Exam_Type__c;
            r.examType = examTypeLabelByValue.containsKey(examTypeApiVal) ? examTypeLabelByValue.get(examTypeApiVal) : examTypeApiVal;

            if (s.Start_Date_Time__c != null) {
                DateTime startDt = s.Start_Date_Time__c;
                r.dateStr = startDt.format('dd-MMM-yyyy');
                r.dayStr  = startDt.format('EEE');

                String endPart = (s.End_Date_Time__c != null) ? s.End_Date_Time__c.format('hh:mm a') : '';
                r.timeStr = startDt.format('hh:mm a') + ' to ' + endPart + ' (IST)';
            } else {
                r.dateStr = '';
                r.dayStr = '';
                r.timeStr = '';
            }

            rows.add(r);
            i++;
        }
    }

    public class ExamRow {
        public Integer sno { get; set; }
        public String sem { get; set; }
        public String subjectName { get; set; }
        public String subjectCode { get; set; }
        public String examType { get; set; }
        public String dateStr { get; set; }
        public String dayStr { get; set; }
        public String timeStr { get; set; }
    }

    private static String extractFirstNumber(String input) {
        if (String.isBlank(input)) return '';
        // Replace non-digits, keep digits
        String digits = input.replaceAll('[^0-9]', '');
        return String.isBlank(digits) ? '' : digits;
    }

    private static String normalizePhotoUrl(String raw) {
        if (String.isBlank(raw)) return null;

        String v = raw.trim();

        if (v.startsWith('http://') || v.startsWith('https://') || v.startsWith('/')) {
            return v;
        }

        if (v.length() == 15 || v.length() == 18) {
            return '/sfc/servlet.shepherd/version/download/' + v;
        }

        return v;
    }
}