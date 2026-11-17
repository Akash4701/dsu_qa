public with sharing class populateGradingOnFinalSubController {
    @AuraEnabled
    public static void populateGrade(Id courseOfferingId) {
        try {
            List<hed__Course_Enrollment__c> courseConnectionToUpdate = new List<hed__Course_Enrollment__c>();
            Set<Id> courseOfferingIds = new Set<Id>{ courseOfferingId };

            hed__Course_Offering__c courseOffering = [
                SELECT Id, Grade_Scheme_RecordType_Name__c, hed__Term__c, hed__Course__c
                FROM hed__Course_Offering__c
                WHERE Id = :courseOfferingId
            ];

            if (courseOffering.Grade_Scheme_RecordType_Name__c == 'Course') {
                courseOfferingIds.addAll(
                    new Map<Id, hed__Course_Offering__c>(
                            [
                                SELECT Id
                                FROM hed__Course_Offering__c
                                WHERE
                                    hed__Term__c = :courseOffering.hed__Term__c
                                    AND hed__Course__c = :courseOffering.hed__Course__c
                            ]
                        )
                        .keySet()
                );
            }

            List<Letter_Grading__c> allLetterGradings = [
                SELECT
                    Id,
                    Range_Start__c,
                    Range_End__c,
                    Letter_Grade_Setting__r.Mechanism__c,
                    Letter_Grade__c,
                    Grade_Point__c
                FROM Letter_Grading__c
                WHERE
                    Letter_Grade_Setting__c IN (
                        SELECT Letter_Grade_Setting__c
                        FROM hed__Course_Offering__c
                        WHERE Id = :courseOfferingId
                    )
                ORDER BY Course_Offering__c DESC
            ];

            List<hed__Course_Enrollment__c> courseConnectionRecords = [
                SELECT Id, Percentile__c, Component_Final_Score__c, Exam_Result_Status__c
                FROM hed__Course_Enrollment__c
                WHERE hed__Course_Offering__c IN :courseOfferingIds AND RecordType.DeveloperName = 'Student'
                ORDER BY Component_Final_Score__c DESC NULLS LAST
            ];
            
            // Separate records based on Exam_Result_Status
            List<hed__Course_Enrollment__c> passRecords = new List<hed__Course_Enrollment__c>();
            List<hed__Course_Enrollment__c> failRecords = new List<hed__Course_Enrollment__c>();
            List<hed__Course_Enrollment__c> incompleteRecords = new List<hed__Course_Enrollment__c>();
            
            for (hed__Course_Enrollment__c eachCourseConnection : courseConnectionRecords) {
                if (eachCourseConnection.Exam_Result_Status__c == 'Pass') {
                    passRecords.add(eachCourseConnection);
                } else if (eachCourseConnection.Exam_Result_Status__c == 'Fail') {
                    failRecords.add(eachCourseConnection);
                } else if (eachCourseConnection.Exam_Result_Status__c == 'In Complete') {
                    incompleteRecords.add(eachCourseConnection);
                }
            }
            
            // Process PASS records with existing functionality
            Integer count = 0;
            Double commonScore = -1;
            Integer commonScoreCount = 0;
            
            for (hed__Course_Enrollment__c eachCourseConnection : passRecords) {
                if (commonScore == eachCourseConnection.Component_Final_Score__c) {
                    commonScoreCount++;
                } else {
                    commonScore = eachCourseConnection.Component_Final_Score__c;
                    count += commonScoreCount;
                    commonScoreCount = 0;
                    count++;
                }
                if (
                    eachCourseConnection.Component_Final_Score__c != null &&
                    eachCourseConnection.Component_Final_Score__c != 0
                ) {
                    eachCourseConnection.Percentile__c =
                        (((Double) passRecords.size() - ((Double) count - 1)) /
                        (Double) passRecords.size()) * 100;
                }
                for (Integer itr = allLetterGradings.size() - 1; itr >= 0; itr--) {
                    if (
                        allLetterGradings[itr].Letter_Grade_Setting__r.Mechanism__c == 'Absolute' &&
                        (eachCourseConnection.Component_Final_Score__c < allLetterGradings[itr].Range_Start__c ||
                        eachCourseConnection.Component_Final_Score__c > allLetterGradings[itr].Range_End__c)
                    ) {
                        continue;
                    } else if (
                        allLetterGradings[itr].Letter_Grade_Setting__r.Mechanism__c == 'Relative' &&
                        (eachCourseConnection.Percentile__c < allLetterGradings[itr].Range_Start__c ||
                        eachCourseConnection.Percentile__c > allLetterGradings[itr].Range_End__c)
                    ) {
                        continue;
                    }

                    eachCourseConnection.Letter_Grade__c = allLetterGradings[itr].Letter_Grade__c;
                    eachCourseConnection.rio_ed_Grade_Value__c = allLetterGradings[itr].Letter_Grade__c;
                    eachCourseConnection.Grade_Point__c = allLetterGradings[itr].Grade_Point__c;
                    break;
                }
                courseConnectionToUpdate.add(eachCourseConnection);
            }

            // Process FAIL records
            for (hed__Course_Enrollment__c eachCourseConnection : failRecords) {
                eachCourseConnection.Letter_Grade__c = 'F';
                eachCourseConnection.rio_ed_Grade_Value__c = 'F';
                eachCourseConnection.Grade_Point__c = 0;
                courseConnectionToUpdate.add(eachCourseConnection);
            }

            // Process IN COMPLETE records
            for (hed__Course_Enrollment__c eachCourseConnection : incompleteRecords) {
                eachCourseConnection.Letter_Grade__c = 'IC';
                eachCourseConnection.rio_ed_Grade_Value__c = 'IC';
                eachCourseConnection.Grade_Point__c = null;
                courseConnectionToUpdate.add(eachCourseConnection);
            }

            if (!courseConnectionToUpdate.isEmpty()) {
                Database.update(courseConnectionToUpdate, false);
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static void testCoverage() {}
}