/**
* @description : Enhanced utility class with percentile-based range calculation and subcomponent support
* @author : ChangeMeIn@UserSettingsUnder.SFDoc
* @group : 
* @last modified on : 12-10-2024
* @last modified by : Assistant
**/
public with sharing class GradeDistrubutionUtils {
    
    @AuraEnabled
    public static List<LetterGradeWrapper> calculateRelativeRanges(String recordTypeId) {
        try {
            List<hed__Course_Enrollment__c> courseConnections = [
                SELECT Id, Component_Final_Score__c
                FROM hed__Course_Enrollment__c
                WHERE hed__Course_Offering__c = :recordTypeId
                AND Component_Final_Score__c != null
                AND Enrollment_Status__c = 'Enrolled'
                ORDER BY Component_Final_Score__c ASC
            ];
            
            if (courseConnections.isEmpty()) {
                throw new AuraHandledException('No student scores found for this course offering.');
            }
            
            hed__Course_Offering__c offering = [
                SELECT Letter_Grade_Setting__c
                FROM hed__Course_Offering__c
                WHERE Id = :recordTypeId
                LIMIT 1
            ];
            
            List<Letter_Grading__c> gradeSettings = [
                SELECT Id, Letter_Grade__c, Percentile__c
                FROM Letter_Grading__c
                WHERE Letter_Grade_Setting__c = :offering.Letter_Grade_Setting__c
                ORDER BY Percentile__c DESC
            ];
            
            List<LetterGradeWrapper> calculatedRanges = new List<LetterGradeWrapper>();
            Integer totalStudents = courseConnections.size();
            Decimal previousRangeEnd = 100;
            
            for (Letter_Grading__c gradeSetting : gradeSettings) {
                LetterGradeWrapper gradeWrapper = new LetterGradeWrapper();
                gradeWrapper.Id = gradeSetting.Id;
                gradeWrapper.grade = gradeSetting.Letter_Grade__c;
                gradeWrapper.percentile = String.valueOf(gradeSetting.Percentile__c);
                
                Decimal percentileValue = 0;
                if (gradeSetting.Percentile__c != null && gradeSetting.Percentile__c != '') {
                    percentileValue = Decimal.valueOf(gradeSetting.Percentile__c);
                }
                
                Integer studentIndex = Integer.valueOf(Math.floor((percentileValue / 100) * totalStudents));
                if (studentIndex >= totalStudents) {
                    studentIndex = totalStudents - 1;
                }
                if (studentIndex < 0) {
                    studentIndex = 0;
                }
                
                Decimal rangeStart = courseConnections[studentIndex].Component_Final_Score__c;
                gradeWrapper.rangeEnd = previousRangeEnd;
                gradeWrapper.rangeStart = rangeStart;
                previousRangeEnd = rangeStart - 0.01;
                
                calculatedRanges.add(gradeWrapper);
            }
            
            return calculatedRanges;
        } catch (Exception e) {
            throw new AuraHandledException('Error calculating relative ranges: ' + e.getMessage());
        }
    }
    
    private class RangeStartDescComparator implements Comparator<LetterGradeWrapper> {
        public Integer compare(LetterGradeWrapper a, LetterGradeWrapper b) {
            if (a.rangeStart == null && b.rangeStart == null) return 0;
            if (a.rangeStart == null) return 1;
            if (b.rangeStart == null) return -1;
            if (a.rangeStart < b.rangeStart) return 1;
            if (a.rangeStart > b.rangeStart) return -1;
            return 0;
        }
    }
    
    private static void applyRelativeGradesToStudents(
        List<CourseConnectionWrapper> enrolments,
        List<LetterGradeWrapper> gradeRanges
    ) {
        gradeRanges.sort(new RangeStartDescComparator());
        
        LetterGradeWrapper fGrade;
        for (LetterGradeWrapper g : gradeRanges) {
            if (g.grade == 'F') {
                fGrade = g;
                break;
            }
        }
        
        for (CourseConnectionWrapper student : enrolments) {
            
            if (String.isNotBlank(student.manualGrade)) {
                student.grade = student.manualGrade;
                student.finalGrade = student.manualGrade;
                continue;
            }
            
            Decimal score = student.componentFinalScore;
            if (score == null) continue;
            
            if (fGrade != null && score >= 0 && score <= fGrade.rangeEnd) {
                student.grade = 'F';
                student.finalGrade = 'F';
                continue;
            }
            
            String assignedGrade = null;
            for (LetterGradeWrapper g : gradeRanges) {
                if (score >= g.rangeStart && score <= g.rangeEnd) {
                    assignedGrade = g.grade;
                    break;
                }
            }
            
            student.grade = (assignedGrade != null) ? assignedGrade : 'F';
            student.finalGrade = student.grade;
        }
        
        
    }
    
    @AuraEnabled
    public static GradeRangeResult getGradeSettingCounts(String recordTypeId) {
        hed__Course_Offering__c offering = [
            SELECT Name, Letter_Grade_Setting__c, hed__Course__r.Name,
            hed__Term__r.Name, Grade_Scheme__r.Name, Id,
            Grade_Scheme__r.RecordType.DeveloperName,
            Grade_Scheme__r.RecordType.Name,
            Letter_Grade_Setting__r.Mechanism__c,
            Letter_Grade_Setting__r.RecordType.Name,
            Letter_Grade_Setting__r.RecordType.DeveloperName,
            Minimum_Passing_Score__c,
            hed__Faculty__c,
            hed__Faculty__r.Name
            FROM hed__Course_Offering__c
            WHERE Id = :recordTypeId
        ];
        
        List<Course_Evaluation_Component__c> examComponents = [
            SELECT Id, Name
            FROM Course_Evaluation_Component__c
            WHERE Course_Offering__c = :recordTypeId
            AND Exam_Name__c = 'End Term'
            LIMIT 1
        ];
        
        String finalExamCompName = examComponents.isEmpty() ? null : examComponents[0].Name;
        Id finalExamComponentId = examComponents.isEmpty() ? null : examComponents[0].Id;
        
        CourseOfferingWrapper enrollment = new CourseOfferingWrapper();
        enrollment.Id = offering.Id;
        enrollment.courseName = offering.hed__Course__r.Name;
        enrollment.termName = offering.hed__Term__r.Name;
        enrollment.courseOfferingName = offering.Name;
        enrollment.gradeSchemeName = offering.Grade_Scheme__r.Name;
        enrollment.gradeSchemeType = offering.Grade_Scheme__r.RecordType.DeveloperName;
        enrollment.mechanism = offering.Letter_Grade_Setting__r.Mechanism__c;
        enrollment.gradeName = offering.Grade_Scheme__r.RecordType.Name;
        enrollment.gradeType = offering.Letter_Grade_Setting__r.RecordType.Name;
        enrollment.minimumPassingScore = offering.Minimum_Passing_Score__c;
        enrollment.finalExamComponentName = finalExamCompName;
        enrollment.primaryFaculty = offering.hed__Faculty__r.Name;
        
        
        Set<Id> courseOfferingIds = new Set<Id>{ recordTypeId };
            
            if (offering.Grade_Scheme__r.RecordType.DeveloperName == 'Course') {
                courseOfferingIds.addAll(
                    new Map<Id, hed__Course_Offering__c>(
                        [
                            SELECT Id
                            FROM hed__Course_Offering__c
                            WHERE hed__Term__c = :offering.hed__Term__c
                            AND hed__Course__c = :offering.hed__Course__c
                        ]
                    ).keySet()
                );
            }
        
        List<hed__Course_Enrollment__c> courseConnectionRecords = [
            SELECT Id, Percentile__c, Component_Final_Score__c, Letter_Grade__c,
            hed__Contact__r.Name, hed__Course_Offering__r.Letter_Grade_Setting__c,
            hed__contact__r.Registration_Number__c, Reason_for_Penality__c,
            Reason_for_Grade__c, Override_Grade__c, Comments__c, Final_Grade__c,Name,Manual_Letter_Grade__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c IN :courseOfferingIds
            AND hed__Contact__r.RecordType.DeveloperName = 'Student'
            AND Enrollment_Status__c = 'Enrolled'
        ];
        
        Map<Id, List<ComponentScoreWrapper>> componentScoresByConnection = new Map<Id, List<ComponentScoreWrapper>>();
        Map<Id, List<SubComponentScoreWrapper>> subComponentScoresByConnection = new Map<Id, List<SubComponentScoreWrapper>>();
        
        Set<Id> courseConnectionIds = new Set<Id>();
        for (hed__Course_Enrollment__c conn : courseConnectionRecords) {
            courseConnectionIds.add(conn.Id);
        }
        
        List<Component_Scores__c> componentScores = [
            SELECT Id, Course_Connection__c, Component_Name__c,
            Component_Name__r.Name, Marks_Obtained__c
            FROM Component_Scores__c
            WHERE Course_Connection__c IN :courseConnectionIds
            AND RecordType.Name = 'Component Score'
        ];
        
        for (Component_Scores__c compScore : componentScores) {
            ComponentScoreWrapper wrapper = new ComponentScoreWrapper();
            wrapper.componentId = compScore.Component_Name__c;
            wrapper.componentName = compScore.Component_Name__r.Name;
            wrapper.marksObtained = compScore.Marks_Obtained__c;
            wrapper.courseConnectionId = compScore.Course_Connection__c;
            
            if (!componentScoresByConnection.containsKey(compScore.Course_Connection__c)) {
                componentScoresByConnection.put(compScore.Course_Connection__c, new List<ComponentScoreWrapper>());
            }
            componentScoresByConnection.get(compScore.Course_Connection__c).add(wrapper);
        }
        
        Map<Id, Id> componentScoreToConnection = new Map<Id, Id>();
        for (Component_Scores__c cs : componentScores) {
            componentScoreToConnection.put(cs.Id, cs.Course_Connection__c);
        }
        
        List<Component_Scores__c> subComponentScores = [
            SELECT Id, Name, Sub_Component_Marks_Obtained__c, Component_Scores__c,
            Component_Scores__r.Component_Name__r.Name,
            Course_Evaluation_Subcomponent__c
            FROM Component_Scores__c
            WHERE Component_Scores__c IN :componentScoreToConnection.keySet()
            AND RecordType.Name = 'Subcomponent Score'
            ORDER BY Course_Evaluation_Subcomponent__c
        ];
        
        System.debug('Queried ' + subComponentScores.size() + ' subcomponent scores');
        
        for (Component_Scores__c subCompScore : subComponentScores) {
            Id connectionId = componentScoreToConnection.get(subCompScore.Component_Scores__c);
            if (connectionId != null) {
                SubComponentScoreWrapper subWrapper = new SubComponentScoreWrapper();
                subWrapper.subComponentId = subCompScore.Id;
                subWrapper.componentName = subCompScore.Course_Evaluation_Subcomponent__c;
                subWrapper.marksObtained = subCompScore.Sub_Component_Marks_Obtained__c;
                subWrapper.parentComponentName = subCompScore.Component_Scores__r.Component_Name__r.Name;
                
                if (!subComponentScoresByConnection.containsKey(connectionId)) {
                    subComponentScoresByConnection.put(connectionId, new List<SubComponentScoreWrapper>());
                }
                subComponentScoresByConnection.get(connectionId).add(subWrapper);
                
                System.debug('Subcomponent for ' + connectionId + ': ' + 
                             'SubcompID=' + subWrapper.componentName + ', marks=' + subWrapper.marksObtained + 
                             ' (parent: ' + subWrapper.parentComponentName + ')');
            }
        }
        
        List<CourseConnectionWrapper> courseConnectionList = new List<CourseConnectionWrapper>();
        
        for (hed__Course_Enrollment__c eachCourseConnection : courseConnectionRecords) {
            CourseConnectionWrapper courseConnection = new CourseConnectionWrapper();
            courseConnection.id = eachCourseConnection.Id;
            courseConnection.percentile = eachCourseConnection.Percentile__c;
            courseConnection.componentFinalScore = eachCourseConnection.Component_Final_Score__c;
            courseConnection.Name = eachCourseConnection.hed__Contact__r.Name;
            courseConnection.registrationNumber = eachCourseConnection.hed__contact__r.Registration_Number__c;
            courseConnection.comments = eachCourseConnection.Comments__c;
            courseConnection.reasonOfPenality = eachCourseConnection.Reason_for_Penality__c;
            courseConnection.reasonForgrade = eachCourseConnection.Reason_for_Grade__c;
            courseConnection.grade = eachCourseConnection.Letter_Grade__c;
            courseConnection.overgrade = eachCourseConnection.Override_Grade__c;
            courseConnection.finalGrade = eachCourseConnection.Final_Grade__c;
            courseConnection.componentScores = componentScoresByConnection.get(eachCourseConnection.Id);
            courseConnection.subComponents = subComponentScoresByConnection.get(eachCourseConnection.Id);
            courseConnection.courseConnectionName = eachCourseConnection.Name;
            courseConnection.manualGrade =eachCourseConnection.Manual_Letter_Grade__c;
            
            if (courseConnection.componentScores == null) {
                courseConnection.componentScores = new List<ComponentScoreWrapper>();
            }
            if (courseConnection.subComponents == null) {
                courseConnection.subComponents = new List<SubComponentScoreWrapper>();
            }
            
            courseConnectionList.add(courseConnection);
        }
        
        if (courseConnectionList.isEmpty()) {
            GradeRangeResult result = new GradeRangeResult();
            result.courseDetail = enrollment;
            return result;
        }
        
        List<Letter_Grading__c> settings = [
            SELECT Id, Letter_Grade__c, Range_Start__c, Range_End__c, Percentile__c,
            Letter_Grade_Setting__r.RecordType.DeveloperName,
            Letter_Grade_Setting__r.Name,
            Letter_Grade_Setting__r.Mechanism__c,
            Letter_Grade_Setting__c
            FROM Letter_Grading__c
            WHERE Letter_Grade_Setting__c = :courseConnectionRecords[0].hed__Course_Offering__r.Letter_Grade_Setting__c
            ORDER BY Letter_Grade__c ASC
        ];
        
        List<LetterGradeWrapper> letterGradeList = new List<LetterGradeWrapper>();
        Boolean isCustomOverride = false;
        Boolean isRelativeMechanism = false;
        
        if (!settings.isEmpty()) {
            isRelativeMechanism = settings[0].Letter_Grade_Setting__r.Mechanism__c == 'Relative';
            isCustomOverride = settings[0].Letter_Grade_Setting__r.RecordType.DeveloperName == 'Custom';
        }
        
        for (Letter_Grading__c eachLetter : settings) {
            LetterGradeWrapper letterGrade = new LetterGradeWrapper();
            letterGrade.Id = eachLetter.Id;
            letterGrade.grade = eachLetter.Letter_Grade__c;
            letterGrade.percentile = String.valueOf(eachLetter.Percentile__c);
            letterGrade.letterGradeSettingMechanism = eachLetter.Letter_Grade_Setting__r.Mechanism__c;
            letterGrade.letterGradeSettingName = eachLetter.Letter_Grade_Setting__r.Name;
            letterGrade.recordType = eachLetter.Letter_Grade_Setting__r.RecordType.DeveloperName;
            letterGrade.letterGradeId = eachLetter.Letter_Grade_Setting__c;
            
            if (isCustomOverride || !isRelativeMechanism) {
                letterGrade.rangeStart = eachLetter.Range_Start__c;
                letterGrade.rangeEnd = eachLetter.Range_End__c;
            }
            
            letterGradeList.add(letterGrade);
        }
        
        if (!isCustomOverride && isRelativeMechanism && !courseConnectionList.isEmpty()) {
            letterGradeList = calculateRelativeRangesInternal(
                courseConnectionList,
                letterGradeList
            );
        }
        
        applyRelativeGradesToStudents(courseConnectionList, letterGradeList);
        
        GradeRangeResult result = new GradeRangeResult();
        result.courseDetail = enrollment;
        result.enrolments = courseConnectionList;
        result.gradeRanges = letterGradeList;
        
        return result;
    }
    private static List<LetterGradeWrapper> calculateRelativeRangesInternal(
        List<CourseConnectionWrapper> courseConnections,
        List<LetterGradeWrapper> gradeSettings
    ) {
        List<Decimal> scores = new List<Decimal>();
        for (CourseConnectionWrapper conn : courseConnections) {
            if (conn.componentFinalScore != null) {
                scores.add(conn.componentFinalScore);
            }
        }
        
        scores.sort();
        List<Decimal> descendingScores = new List<Decimal>();
        for (Integer i = scores.size() - 1; i >= 0; i--) {
            descendingScores.add(scores[i]);
        }
        
        Integer totalStudents = descendingScores.size();
        if (totalStudents == 0) {
            return gradeSettings;
        }
        
        Decimal sum = 0;
        for (Decimal s : descendingScores) sum += s;
        Decimal mean = sum / totalStudents;
        
        Decimal variance = 0;
        for (Decimal s : descendingScores) {
            variance += (s - mean) * (s - mean);
        }
        Decimal sd = Math.sqrt(variance / (totalStudents - 1));
        
        Decimal fMax = mean - (2 * sd);
        if (fMax < 0) fMax = 0;
        
        List<LetterGradeWrapper> sortedGrades = new List<LetterGradeWrapper>(gradeSettings);
        sortedGrades.sort(new PercentileComparator());
        
        Decimal nextGradeEnd = null;
        
        for (LetterGradeWrapper gradeWrapper : sortedGrades) {
            Decimal percentileValue = 0;
            if (gradeWrapper.percentile != null && gradeWrapper.percentile != '') {
                percentileValue = Decimal.valueOf(gradeWrapper.percentile);
            }
            
            Decimal percentileDecimal = percentileValue / 100;
            Decimal thresholdScore = percentileInc(descendingScores, percentileDecimal);
            
            if (gradeWrapper.grade == 'F') {
                gradeWrapper.rangeStart = 0;
                gradeWrapper.rangeEnd = fMax.setScale(0, RoundingMode.HALF_UP) - 1;
                nextGradeEnd = gradeWrapper.rangeStart - 0.01;
            } else if (gradeWrapper.grade == 'D') {
                Decimal dStart = fMax.setScale(0, RoundingMode.HALF_UP);
                gradeWrapper.rangeStart = dStart;
                gradeWrapper.rangeEnd = (nextGradeEnd != null) ? nextGradeEnd : 100;
                nextGradeEnd = dStart - 0.01;
            } else {
                gradeWrapper.rangeStart = thresholdScore;
                gradeWrapper.rangeEnd = (nextGradeEnd != null) ? nextGradeEnd : 100;
                nextGradeEnd = thresholdScore - 0.01;
            }
        }
        
        return sortedGrades;
    }
    
    public static Decimal percentileInc(List<Decimal> values, Decimal p) {
        values.sort();
        Integer n = values.size();
        if (n == 0) return null;
        
        Decimal index = p * (n - 1);
        Integer lower = Integer.valueOf(Math.floor(index));
        Integer upper = Integer.valueOf(Math.ceil(index));
        
        if (lower == upper) {
            return values[lower].setScale(0, RoundingMode.HALF_UP);
        }
        
        Decimal fraction = index - lower;
        Decimal lowerValue = values[lower];
        Decimal upperValue = values[upper];
        Decimal interpolated = lowerValue + (fraction * (upperValue - lowerValue));
        
        return interpolated.setScale(0, RoundingMode.HALF_UP);
    }
    
    private class PercentileComparator implements Comparator<LetterGradeWrapper> {
        public Integer compare(LetterGradeWrapper a, LetterGradeWrapper b) {
            Decimal aPercentile = 0;
            Decimal bPercentile = 0;
            
            if (a.percentile != null && a.percentile != '') {
                aPercentile = Decimal.valueOf(a.percentile);
            }
            if (b.percentile != null && b.percentile != '') {
                bPercentile = Decimal.valueOf(b.percentile);
            }
            
            if (aPercentile > bPercentile) return -1;
            if (aPercentile < bPercentile) return 1;
            return 0;
        }
    }
    
    public static Statistics getStatistics(String recordTypeId) {
        Statistics stats = new Statistics();
        Double totalMarks = 0;
        Double variance = 0;
        
        List<hed__Course_Enrollment__c> courseConnectionList = [
            SELECT Id, Component_Final_Score__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c = :recordTypeId
            ORDER BY Component_Final_Score__c
        ];
        
        Integer numberOfStudents = courseConnectionList.size();
        
        for (hed__Course_Enrollment__c eachCourseConnection : courseConnectionList) {
            totalMarks += eachCourseConnection.Component_Final_Score__c;
        }
        
        stats.Mean = totalMarks / numberOfStudents;
        
        for (hed__Course_Enrollment__c eachCourseConnection : courseConnectionList) {
            variance += Math.pow((Integer) (stats.Mean - eachCourseConnection.Component_Final_Score__c), 2);
        }
        
        stats.Standard_Deviation = Math.sqrt(variance / (numberOfStudents - 1));
        stats.Median = Math.mod(numberOfStudents, 2) == 1
            ? courseConnectionList[numberOfStudents / 2].Component_Final_Score__c
            : (courseConnectionList[numberOfStudents / 2].Component_Final_Score__c +
               courseConnectionList[(numberOfStudents / 2) - 1].Component_Final_Score__c) / 2;
        stats.Minimum = courseConnectionList[0].Component_Final_Score__c;
        
        return stats;
    }
    
    public static List<LabelValuePair> getPenaltyPickListValues() {
        List<LabelValuePair> pickListValuesList = new List<LabelValuePair>();
        Schema.DescribeFieldResult fieldResult = hed__Course_Enrollment__c.Reason_for_Penality__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        
        for (Schema.PicklistEntry pickListVal : ple) {
            LabelValuePair option = new LabelValuePair();
            option.label = pickListVal.getLabel();
            option.value = pickListVal.getValue();
            pickListValuesList.add(option);
        }
        
        return pickListValuesList;
    }
    
    public static List<hed__Course_Enrollment__c> saveStudentGrade(List<GradeRequestWrapper> postGrades) {
        List<hed__Course_Enrollment__c> courseConnectionsToUpdate = new List<hed__Course_Enrollment__c>();
        
        for (GradeRequestWrapper grade : postGrades) {
            hed__Course_Enrollment__c courseConnection = new hed__Course_Enrollment__c();
            courseConnection.Id = grade.Id;
            courseConnection.Override_Grade__c = grade.overrideGrade;
            courseConnection.Comments__c = grade.comment;
            courseConnection.Reason_for_Grade__c = grade.reasonForDownFall;
            courseConnectionsToUpdate.add(courseConnection);
        }
        
        if (!courseConnectionsToUpdate.isEmpty()) {
            Database.update(courseConnectionsToUpdate, false);
        }
        
        return courseConnectionsToUpdate;
    }
    
    public static void saveGradeSetting(GradeSettingWrapper setting) {
        Letter_Grade_Setting__c letterGradeSetting = new Letter_Grade_Setting__c();
        List<Letter_Grading__c> letterGradeToUpdate = new List<Letter_Grading__c>();
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c();
        
        RecordType recordTypeId = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Letter_Grade_Setting__c'
            AND Name = 'Custom'
            LIMIT 1
        ];
        
        letterGradeSetting.RecordTypeId = recordTypeId.Id;
        letterGradeSetting.Mechanism__c = setting?.letterGradeSettingMechanism;
        letterGradeSetting.Name = 'Overriden_' + System.now();
        letterGradeSetting.Is_Active__c = true;
        insert letterGradeSetting;
        
        courseOffering.Id = setting?.courseOfferingId;
        courseOffering.Letter_Grade_Setting__c = letterGradeSetting.Id;
        update courseOffering;
        
        Map<String, Letter_Grading__c> gradeRangesByGrade = new Map<String, Letter_Grading__c>();
        for (Letter_Grading__c range : [
            SELECT Id, Range_Start__c, Range_End__c, Definition__c,
            Grade_Point__c, Letter_Grade__c
            FROM Letter_Grading__c
            WHERE Letter_Grade_Setting__c = :setting.Id
        ]) {
            gradeRangesByGrade.put(range.Letter_Grade__c, range);
        }
        
        for (Object gradeWrapperObj : setting.nonEmptyValues) {
            GradeSettingWrapper.LetterGradeRangeWrapper gradeWrapper = (GradeSettingWrapper.LetterGradeRangeWrapper) gradeWrapperObj;
            Letter_Grading__c existingGrade = gradeRangesByGrade.get(gradeWrapper.grade);
            Letter_Grading__c letterGrade = existingGrade.clone(false, false, false, false);
            letterGrade.Letter_Grade_Setting__c = letterGradeSetting.Id;
            letterGrade.Range_Start__c = gradeWrapper.rangeStart;
            letterGrade.Range_End__c = gradeWrapper.rangeEnd;
            letterGrade.Percentile__c = gradeWrapper.percentile;
            letterGradeToUpdate.add(letterGrade);
        }
        
        insert letterGradeToUpdate;
        GradeDistrubutionUtils.recalcAndPersistGrades(setting.courseOfferingId);
        
    }
    
    public static List<GradeSettingRequest> getGradeSetting(String recordTypeId) {
        List<GradeSettingRequest> gradeSettings = new List<GradeSettingRequest>();
        
        List<Letter_Grading__c> gradeSetting = [
            SELECT id, Letter_Grade__c, Range_Start__c, Range_End__c,
            Grade_Point__c, Definition__c
            FROM Letter_Grading__c
            WHERE Course_Offering__c = :recordTypeId
        ];
        
        for (Letter_Grading__c eachSetting : gradeSetting) {
            GradeSettingRequest grade = new GradeSettingRequest();
            grade.Id = eachSetting.id;
            grade.letterGrade = eachSetting.Letter_Grade__c;
            grade.Definition = eachSetting.Definition__c;
            grade.rangeStart = eachSetting.Range_Start__c;
            grade.rangeEnd = eachSetting.Range_End__c;
            grade.gradePoint = eachSetting.Grade_Point__c;
            gradeSettings.add(grade);
        }
        
        return gradeSettings;
    }
    
    @AuraEnabled(cacheable=true)
public static List<Course_Evaluation_Component__c> getEvaluationComponents(Id courseOfferingId) {
    System.debug('getEvaluationComponents called with courseOfferingId: ' + courseOfferingId);
    
    List<Course_Evaluation_Component__c> components = [
        SELECT Id, Name
        FROM Course_Evaluation_Component__c
        WHERE Course_Offering__c = :courseOfferingId
        ORDER BY Name
    ];
    
    System.debug('Found components: ' + components.size());
    return components;
}

    
  @AuraEnabled(cacheable=true)
public static List<SubComponentWrapper> getEvaluationSubComponents(Id courseOfferingId) {
    System.debug('getEvaluationSubComponents called with courseOfferingId: ' + courseOfferingId);
    
    if (courseOfferingId == null) {
        return new List<SubComponentWrapper>();
    }
    
    hed__Course_Offering__c offering = [
        SELECT hed__Course__c, hed__Term__c
        FROM hed__Course_Offering__c
        WHERE Id = :courseOfferingId
        LIMIT 1
    ];
    
    Set<Id> courseOfferingIds = new Set<Id>{ courseOfferingId };
    courseOfferingIds.addAll(
        new Map<Id, hed__Course_Offering__c>(
            [
                SELECT Id
                FROM hed__Course_Offering__c
                WHERE hed__Course__c = :offering.hed__Course__c
                AND hed__Term__c   = :offering.hed__Term__c
            ]
        ).keySet()
    );
    
    List<Course_Evaluation_Component__c> finalExamComponents = [
        SELECT Id, Name
        FROM Course_Evaluation_Component__c
        WHERE Course_Offering__c IN :courseOfferingIds
        AND Exam_Name__c = 'End Term'
    ];
    
    if (finalExamComponents.isEmpty()) {
        System.debug('No Final Exam component found');
        return new List<SubComponentWrapper>();
    }
    
    String finalExamComponentName = finalExamComponents[0].Name;
    Set<Id> finalExamComponentIds = new Set<Id>();
    for (Course_Evaluation_Component__c c : finalExamComponents) {
        finalExamComponentIds.add(c.Id);
    }
    
    List<Component_Scores__c> parentComponentScores = [
        SELECT Id
        FROM Component_Scores__c
        WHERE Component_Name__c IN :finalExamComponentIds
        AND RecordType.Name = 'Component Score'
    ];
    
    if (parentComponentScores.isEmpty()) {
        System.debug('No component scores found for Final Exam');
        return new List<SubComponentWrapper>();
    }
    
    Set<Id> parentScoreIds = new Set<Id>();
    for (Component_Scores__c cs : parentComponentScores) {
        parentScoreIds.add(cs.Id);
    }
    
    List<Component_Scores__c> subComponentScores = [
        SELECT Id,
               Course_Evaluation_Subcomponent__c,
               Course_Evaluation_Subcomponent__r.Name
        FROM Component_Scores__c
        WHERE Component_Scores__c IN :parentScoreIds
        AND RecordType.Name = 'Subcomponent Score'
        ORDER BY Course_Evaluation_Subcomponent__r.Name
    ];
    
    System.debug('Found ' + subComponentScores.size() + ' subcomponent score records');
    
    Map<String, Set<Id>> nameToIds = new Map<String, Set<Id>>();
    for (Component_Scores__c subComp : subComponentScores) {
        if (subComp.Course_Evaluation_Subcomponent__c != null &&
            subComp.Course_Evaluation_Subcomponent__r.Name != null) {
            
            String name = subComp.Course_Evaluation_Subcomponent__r.Name;
            if (!nameToIds.containsKey(name)) {
                nameToIds.put(name, new Set<Id>());
            }
            nameToIds.get(name).add(subComp.Course_Evaluation_Subcomponent__c);
        }
    }
    
    List<SubComponentWrapper> subComponents = new List<SubComponentWrapper>();
    for (String name : nameToIds.keySet()) {
        SubComponentWrapper wrapper = new SubComponentWrapper();
        wrapper.name = name;
        wrapper.parentComponentName = finalExamComponentName;
        wrapper.subcomponentIds = new List<String>();
        for (Id sid : nameToIds.get(name)) {
            wrapper.subcomponentIds.add(String.valueOf(sid));
        }
        subComponents.add(wrapper);
    }
    
    System.debug('Returning ' + subComponents.size() + ' unique subcomponents (by name)');
    return subComponents;
}

    
    public class SubComponentWrapper {
        @AuraEnabled
        public String name; 
        @AuraEnabled
        public String subcomponentId; 
        @AuraEnabled 
        public List<String> subcomponentIds;
        @AuraEnabled
        public String subcomponentActualName; 
        @AuraEnabled
        public String parentComponentName;
    }
    public class GradeRangeResult {
        @AuraEnabled
        public CourseOfferingWrapper courseDetail { get; set; }
        @AuraEnabled
        public List<CourseConnectionWrapper> enrolments { get; set; }
        @AuraEnabled
        public List<LetterGradeWrapper> gradeRanges { get; set; }
    }
    
    public class CourseOfferingWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String courseName;
        @AuraEnabled public String termName;
        @AuraEnabled public String courseOfferingName;
        @AuraEnabled public String gradeSchemeName;
        @AuraEnabled public String gradeSchemeType;
        @AuraEnabled public String primaryFaculty;
        @AuraEnabled public String mechanism;
        @AuraEnabled public String gradeName;
        @AuraEnabled public String gradeType;
        @AuraEnabled public String minimumPassingScore;
        @AuraEnabled public String finalExamComponentName;
    }
    
    public class CourseConnectionWrapper {
        @AuraEnabled
        public String id;
        @AuraEnabled 
        public String courseConnectionName;
        @AuraEnabled
        public Decimal percentile;
        @AuraEnabled
        public Decimal componentFinalScore;
        @AuraEnabled
        public String Name;
        @AuraEnabled
        public String registrationNumber;
        @AuraEnabled
        public String comments;
        @AuraEnabled
        public String reasonOfPenality;
        @AuraEnabled
        public String reasonForgrade;
        @AuraEnabled
        public String overgrade;
        @AuraEnabled
        public String finalGrade;
        @AuraEnabled
        public String grade;
        @AuraEnabled
        public String manualGrade;
        @AuraEnabled
        public List<ComponentScoreWrapper> componentScores;
        @AuraEnabled
        public List<SubComponentScoreWrapper> subComponents;
    }
    
    public class ComponentScoreWrapper {
        @AuraEnabled public String componentId;
        @AuraEnabled public String componentName;
        @AuraEnabled public Decimal marksObtained;
        @AuraEnabled public String courseConnectionId;
    }
    
    public class LetterGradeWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String grade;
        @AuraEnabled public Decimal rangeStart;
        @AuraEnabled public Decimal rangeEnd;
        @AuraEnabled public String recordType;
        @AuraEnabled public String letterGradeSettingMechanism;
        @AuraEnabled public String letterGradeSettingName;
        @AuraEnabled public String letterGradeId;
        @AuraEnabled public String percentile;
    }
    
    public class Statistics {
        @AuraEnabled public Double Mean;
        @AuraEnabled public Double Median;
        @AuraEnabled public Double Standard_Deviation;
        @AuraEnabled public Double Minimum;
    }
    public class SubComponentScoreWrapper {
        @AuraEnabled
        public String subComponentId;
        @AuraEnabled
        public String componentName;
        @AuraEnabled
        public Decimal marksObtained;
        @AuraEnabled
        public String parentComponentName;
    }
    
    public class LabelValuePair {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
    }
    
    public class GradeSettingRequest {
        public String Id;
        public String letterGrade;
        public Decimal rangeStart;
        public Decimal rangeEnd;
        public Decimal gradePoint;
        public String mechanism;
        public String Definition;
    }
    public static void recalcAndPersistGrades(Id courseOfferingId) {
        GradeRangeResult res = getGradeSettingCounts(courseOfferingId); 
        
        Map<Id, CourseConnectionWrapper> byId = new Map<Id, CourseConnectionWrapper>();
        for (CourseConnectionWrapper w : res.enrolments) {
            byId.put((Id)w.id, w);
        }
        
        List<hed__Course_Enrollment__c> toUpdate = [
            SELECT Id, Manual_Letter_Grade__c, Override_Grade__c
            FROM hed__Course_Enrollment__c
            WHERE hed__Course_Offering__c = :courseOfferingId
            AND Enrollment_Status__c = 'Enrolled'
        ];
        
        for (hed__Course_Enrollment__c ce : toUpdate) {
            CourseConnectionWrapper w = byId.get(ce.Id);
            if (w == null) continue;
            
            if (String.isNotBlank(ce.Manual_Letter_Grade__c)) {
                ce.Letter_Grade__c = ce.Manual_Letter_Grade__c;
            } else if (String.isNotBlank(ce.Override_Grade__c)) {
                ce.Letter_Grade__c = w.grade; 
            } else {
                ce.Letter_Grade__c = w.grade;
            }
        }
        
        update toUpdate;
    }
}