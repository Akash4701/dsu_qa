public class SemesterReportController {
    private static final Integer MAX_PROGRAM_PLANS = 500;
    private static final Integer MAX_SEMESTERS = 1000;
    private static final Integer MAX_COURSE_OFFERINGS = 10000;

    private static final List<String> REPORT_GRADES =
        new List<String>{
            'O', 'A+', 'A', 'B+', 'B', 'C', 'P', 'F', 'AB', 'NE'
        };

    // ============================================================
    // 1. PROGRAM PLAN OPTIONS
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static List<ProgramPlanOption> getProgramPlans() {
        List<ProgramPlanOption> results =
            new List<ProgramPlanOption>();

        for (hed__Program_Plan__c plan : [
            SELECT Id, Name
            FROM hed__Program_Plan__c
            ORDER BY Name
            LIMIT :MAX_PROGRAM_PLANS
        ]) {
            ProgramPlanOption option = new ProgramPlanOption();
            option.id = plan.Id;
            option.name = plan.Name;
            results.add(option);
        }

        return results;
    }

    // ============================================================
    // 2. LOAD COMPLETE REPORT FOR A PROGRAM PLAN
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static SemesterReport getSemesterSubjectReport(
        String programPlanId
    ) {
        if (String.isBlank(programPlanId)) {
            throw new AuraHandledException(
                'Please select a Program Plan.'
            );
        }

        try {
            Id planId = Id.valueOf(programPlanId);

            if (planId.getSObjectType() !=
                hed__Program_Plan__c.SObjectType) {
                throw new AuraHandledException(
                    'Invalid Program Plan ID.'
                );
            }

            SemesterReport report = new SemesterReport();

            hed__Program_Plan__c plan = [
                SELECT Id, Name
                FROM hed__Program_Plan__c
                WHERE Id = :planId
                LIMIT 1
            ];

            report.programPlanId = plan.Id;
            report.programPlanName = plan.Name;

            // Fetch every semester associated with this plan.
            List<SemesterSortRow> semesterRows =
                new List<SemesterSortRow>();

            // A plan can contain multiple Term records with the same display
            // name. Show that semester name only once in the report.
            Map<String, hed__Term__c> canonicalTermByName =
                new Map<String, hed__Term__c>();
            Map<Id, Id> canonicalTermIdByTermId = new Map<Id, Id>();
            Set<Id> semesterIds = new Set<Id>();

            for (hed__Term__c term : [
                SELECT Id,
                       Name,
                       Program_Plan__c,
                       Term_Reference__c,
                       Term_Number__c,
                       hed__Start_Date__c,
                       hed__End_Date__c
                FROM hed__Term__c
                WHERE Program_Plan__c = :planId
                ORDER BY hed__Start_Date__c, Name
                LIMIT :MAX_SEMESTERS
            ]) {
                semesterIds.add(term.Id);
                String semesterNameKey = term.Name == null
                    ? ''
                    : term.Name.trim().toUpperCase();

                if (!canonicalTermByName.containsKey(semesterNameKey)) {
                    canonicalTermByName.put(semesterNameKey, term);
                    semesterRows.add(
                        new SemesterSortRow(
                            term,
                            getSemesterNumber(term)
                        )
                    );
                }
                canonicalTermIdByTermId.put(
                    term.Id,
                    canonicalTermByName.get(semesterNameKey).Id
                );
            }

            semesterRows.sort();

            // One report row per semester + course. All offerings for that
            // course and semester map to the same row so all enrollments count.
            Map<Id, List<CourseReportRow>> rowsBySemester =
                new Map<Id, List<CourseReportRow>>();

            Map<String, CourseReportRow> rowBySemesterCourse =
                new Map<String, CourseReportRow>();

            Map<Id, String> groupKeyByOffering =
                new Map<Id, String>();

            Set<Id> offeringIds = new Set<Id>();

            if (!semesterIds.isEmpty()) {
                for (hed__Course_Offering__c offering : [
                    SELECT Id,
                           Name,
                           hed__Term__c,
                           hed__Course__c,
                           hed__Course__r.Name,
                           hed__Course__r.hed__Course_ID__c,
                           hed__Course__r.Exclude_From_Official_Records__c,
                           hed__Faculty__c,
                           hed__Faculty__r.Name,
                           Letter_Grade_Setting__c,
                           Parent_Course_Code__c
                    FROM hed__Course_Offering__c
                    WHERE hed__Term__c IN :semesterIds AND hed__Course__r.Exclude_From_Official_Records__c = False
                    ORDER BY hed__Course__r.hed__Course_ID__c,
                             hed__Course__r.Name,
                             Name
                    LIMIT :MAX_COURSE_OFFERINGS
                ]) {
                    if (offering.hed__Term__c == null ||
                        offering.hed__Course__c == null) {
                        continue;
                    }

                    Id canonicalTermId = canonicalTermIdByTermId.get(
                        offering.hed__Term__c
                    );
                    if (canonicalTermId == null) {
                        continue;
                    }

                    String groupKey =
                        String.valueOf(canonicalTermId) + '-' +
                        String.valueOf(offering.hed__Course__c);

                    if (!rowBySemesterCourse.containsKey(groupKey)) {
                        CourseReportRow courseRow =
                            new CourseReportRow();

                        // Keep the first offering ID for the existing LWC key.
                        courseRow.courseOfferingId = offering.Id;
                        courseRow.courseId = offering.hed__Course__c;

                        courseRow.courseCode =
                            offering.hed__Course__r == null
                            ? ''
                            : offering.hed__Course__r.hed__Course_ID__c;

                        courseRow.courseName =
                            offering.hed__Course__r == null
                            ? ''
                            : offering.hed__Course__r.Name;

                        courseRow.facultyId = offering.hed__Faculty__c;
                        courseRow.facultyName =
                            offering.hed__Faculty__r == null
                            ? ''
                            : offering.hed__Faculty__r.Name;

                        courseRow.letterGradeSettingId =
                            offering.Letter_Grade_Setting__c;

                        courseRow.letterGradeSettingName =
                            offering.Letter_Grade_Setting__c == null
                            ? ''
                            : String.valueOf(
                                offering.Letter_Grade_Setting__c
                            );

                        courseRow.gradeO = 0;
                        courseRow.gradeAPlus = 0;
                        courseRow.gradeA = 0;
                        courseRow.gradeBPlus = 0;
                        courseRow.gradeB = 0;
                        courseRow.gradeC = 0;
                        courseRow.gradeP = 0;
                        courseRow.gradeF = 0;
                        courseRow.gradeAB = 0;
                        courseRow.gradeNE = 0;
                        courseRow.passed = 0;
                        courseRow.appeared = 0;
                        courseRow.percentage = 0;

                        rowBySemesterCourse.put(groupKey, courseRow);

                        if (!rowsBySemester.containsKey(canonicalTermId)) {
                            rowsBySemester.put(
                                canonicalTermId,
                                new List<CourseReportRow>()
                            );
                        }

                        rowsBySemester.get(canonicalTermId).add(courseRow);
                    }

                    // Map every offering, not just the first, to the shared row.
                    groupKeyByOffering.put(offering.Id, groupKey);
                    offeringIds.add(offering.Id);
                }
            }

            // Aggregate every enrollment from every offering into its shared row.
            if (!offeringIds.isEmpty()) {
                for (hed__Course_Enrollment__c enrollment : [
                    SELECT Id,
                           hed__Course_Offering__c,
                           Final_grade__c,
                           Exam_Result_Status__c,
                           Exam_Eligibility__c
                    FROM hed__Course_Enrollment__c
                    WHERE hed__Course_Offering__c IN :offeringIds
                    AND hed__Course_Offering__r.hed__Course__r.Exclude_From_Official_Records__c = false
                ]) {
                    String groupKey =
                        groupKeyByOffering.get(
                            enrollment.hed__Course_Offering__c
                        );

                    CourseReportRow courseRow =
                        groupKey == null
                        ? null
                        : rowBySemesterCourse.get(groupKey);

                    if (courseRow == null) {
                        continue;
                    }

                    String grade = enrollment.Final_grade__c == null
                        ? ''
                        : String.valueOf(enrollment.Final_grade__c)
                            .trim()
                            .toUpperCase();

                    String resultStatus = enrollment.Exam_Result_Status__c == null
                        ? ''
                        : String.valueOf(enrollment.Exam_Result_Status__c).trim();

                    if (resultStatus.equalsIgnoreCase('In Complete')) {
                        courseRow.gradeAB++;
                        continue;
                    }

                    String eligibility = enrollment.Exam_Eligibility__c == null
                        ? ''
                        : String.valueOf(enrollment.Exam_Eligibility__c).trim();

                    if (eligibility.equalsIgnoreCase('Non-Eligible')) {
                        courseRow.gradeNE++;
                    }

                    // Preserve the existing grade and percentage rules.
                    switch on grade {
                        when 'O' {
                            courseRow.gradeO++;
                            courseRow.passed++;
                            courseRow.appeared++;
                        }
                        when 'A+' {
                            courseRow.gradeAPlus++;
                            courseRow.passed++;
                            courseRow.appeared++;
                        }
                        when 'A' {
                            courseRow.gradeA++;
                            courseRow.passed++;
                            courseRow.appeared++;
                        }
                        when 'B+' {
                            courseRow.gradeBPlus++;
                            courseRow.passed++;
                            courseRow.appeared++;
                        }
                        when 'B' {
                            courseRow.gradeB++;
                            courseRow.passed++;
                            courseRow.appeared++;
                        }
                        when 'C' {
                            courseRow.gradeC++;
                            courseRow.passed++;
                            courseRow.appeared++;
                        }
                        when 'P' {
                            courseRow.gradeP++;
                            courseRow.passed++;
                            courseRow.appeared++;
                        }
                        when 'F' {
                            courseRow.gradeF++;
                            courseRow.appeared++;
                        }
                        when 'AB' {
                            courseRow.gradeAB++;
                        }
                        when 'NE' {
                            courseRow.gradeNE++;
                        }
                        when else {
                            // Blank or unrecognized final grades are not counted.
                        }
                    }
                }
            }

            // Assemble the dynamic semester sections.
            for (SemesterSortRow sortedRow : semesterRows) {
                hed__Term__c term = sortedRow.term;

                SemesterReportSection section =
                    new SemesterReportSection();

                section.semesterId = term.Id;
                section.semesterName = term.Name;
                section.semesterReference =
                    term.Term_Reference__c;

                List<CourseReportRow> courseRows =
                    rowsBySemester.containsKey(term.Id)
                    ? rowsBySemester.get(term.Id)
                    : new List<CourseReportRow>();

                // Re-number courses separately in every semester.
                Integer serialNumber = 1;

                for (CourseReportRow courseRow : courseRows) {
                    courseRow.serialNumber = serialNumber++;

                    if (courseRow.appeared > 0) {
                        courseRow.percentage =
                            ((Decimal) courseRow.passed /
                            courseRow.appeared * 100)
                            .setScale(
                                2,
                                System.RoundingMode.HALF_UP
                            );
                    } else {
                        courseRow.percentage = 0;
                    }

                    section.courses.add(courseRow);
                }

                section.totalCourses = section.courses.size();
                report.semesters.add(section);
            }

            report.totalSemesters = report.semesters.size();

            return report;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'Unable to generate the semester subject report: ' +
                e.getMessage()
            );
        }
    }

    // ============================================================
    // 3. SEMESTER SORTING
    // ============================================================

    private static Integer getSemesterNumber(
        hed__Term__c term
    ) {
        if (term.Term_Number__c != null) {
            return term.Term_Number__c.intValue();
        }

        if (String.isNotBlank(term.Term_Reference__c)) {
            Matcher matcher = Pattern.compile('\\d+').matcher(
                term.Term_Reference__c
            );

            if (matcher.find()) {
                return Integer.valueOf(matcher.group());
            }
        }

        return 9999;
    }

    private class SemesterSortRow implements Comparable {
        hed__Term__c term;
        Integer semesterNumber;

        SemesterSortRow(
            hed__Term__c term,
            Integer semesterNumber
        ) {
            this.term = term;
            this.semesterNumber = semesterNumber;
        }

        public Integer compareTo(Object other) {
            SemesterSortRow otherRow =
                (SemesterSortRow) other;

            if (semesterNumber != otherRow.semesterNumber) {
                return semesterNumber - otherRow.semesterNumber;
            }

            return term.Name.compareTo(otherRow.term.Name);
        }
    }

    // ============================================================
    // 4. RESPONSE WRAPPERS FOR LWC
    // ============================================================

    public class ProgramPlanOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    public class SemesterReport {
        @AuraEnabled public Id programPlanId;
        @AuraEnabled public String programPlanName;
        @AuraEnabled public Integer totalSemesters = 0;

        @AuraEnabled
        public List<SemesterReportSection> semesters =
            new List<SemesterReportSection>();
    }

    public class SemesterReportSection {
        @AuraEnabled public Id semesterId;
        @AuraEnabled public String semesterName;
        @AuraEnabled public String semesterReference;
        @AuraEnabled public Integer totalCourses = 0;

        @AuraEnabled
        public List<CourseReportRow> courses =
            new List<CourseReportRow>();
    }

    public class CourseReportRow {
        @AuraEnabled public Integer serialNumber;

        @AuraEnabled public Id courseOfferingId;
        @AuraEnabled public Id courseId;
        @AuraEnabled public String courseCode;
        @AuraEnabled public String courseName;

        @AuraEnabled public Id facultyId;
        @AuraEnabled public String facultyName;

        @AuraEnabled public Id letterGradeSettingId;
        @AuraEnabled public String letterGradeSettingName;

        @AuraEnabled public Integer gradeO = 0;
        @AuraEnabled public Integer gradeAPlus = 0;
        @AuraEnabled public Integer gradeA = 0;
        @AuraEnabled public Integer gradeBPlus = 0;
        @AuraEnabled public Integer gradeB = 0;
        @AuraEnabled public Integer gradeC = 0;
        @AuraEnabled public Integer gradeP = 0;
        @AuraEnabled public Integer gradeF = 0;
        @AuraEnabled public Integer gradeAB = 0;
        @AuraEnabled public Integer gradeNE = 0;

        @AuraEnabled public Integer passed = 0;
        @AuraEnabled public Integer appeared = 0;
        @AuraEnabled public Decimal percentage = 0;
    }
}