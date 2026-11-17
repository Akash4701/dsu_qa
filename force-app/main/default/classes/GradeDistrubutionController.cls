/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 10-26-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class GradeDistrubutionController {
	@AuraEnabled
	public static void getStatistics(String recordId) {
		try {
			GradeDistrubutionUtils.getStatistics(recordId);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled(cacheable=true)
	public static void getPenaltyPickListValues() {
		try {
			GradeDistrubutionUtils.getPenaltyPickListValues();
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled(cacheable=false)
	public static void saveStudentGrade(String value) {
		try {
			List<GradeRequestWrapper> requestBody = (List<GradeRequestWrapper>) JSON.deserialize(
				value,
				List<GradeRequestWrapper>.class
			);
			GradeDistrubutionUtils.saveStudentGrade(requestBody);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled(cacheable=false)
	public static void saveGradeSetting(String value) {
		try {
			GradeSettingWrapper requestBody = (GradeSettingWrapper) JSON.deserialize(
				value,
				GradeSettingWrapper.class
			);
			GradeDistrubutionUtils.saveGradeSetting(requestBody);
		} catch (Exception e) {
			 throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static List<GradeDistrubutionUtils.GradeSettingRequest> getGradeSetting(String recordId) {
		try {
			return GradeDistrubutionUtils.getGradeSetting(recordId);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}


	@AuraEnabled
	public static GradeDistrubutionUtils.GradeRangeResult getGradeSettingCounts(String recordId){
		try {
			return GradeDistrubutionUtils.getGradeSettingCounts(recordId);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}
    @AuraEnabled
    public static void saveMinimumPassingScore(Id courseOfferingId, String score) {
        hed__Course_Offering__c co = new hed__Course_Offering__c(
            Id = courseOfferingId,
            Minimum_Passing_Score__c = score
        );
        update co;
}

	@AuraEnabled
	public static void updateMeanTwoSD(Id recordId, Decimal meanMinusTwoSd) {
		hed__Course_Offering__c co = new hed__Course_Offering__c(
			Id = recordId,
			Mean_2SD__c = meanMinusTwoSd
		);
		update co;
	}
@AuraEnabled
public static void updateGradeLowerBound(Id recordId, Decimal lowerBoundValue, String mechanism) {
    hed__Course_Offering__c co = new hed__Course_Offering__c(Id = recordId);

    if (mechanism != null && mechanism.toLowerCase().contains('absolute')) {
        co.Mean_2SD__c = lowerBoundValue;     
    } else {
        co.Mean_2SD__c = lowerBoundValue;            
    }
    update co;
}



	
}