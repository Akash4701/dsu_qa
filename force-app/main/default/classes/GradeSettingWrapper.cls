/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 10-29-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public class GradeSettingWrapper {
	@AuraEnabled
	public String Id;

	@AuraEnabled
	public String letterGradeSettingName;

	@AuraEnabled
	public String letterGradeSettingMechanism;

	@AuraEnabled
	public String recordType;

	@AuraEnabled
	public String courseOfferingId;

	@AuraEnabled
	public String courseOfferingName;


	@AuraEnabled
	public List<LetterGradeRangeWrapper> nonEmptyValues;

	public class LetterGradeRangeWrapper {
		@AuraEnabled
		public String Id;

		@AuraEnabled
		public Decimal rangeStart;

		@AuraEnabled
		public Decimal rangeEnd;

		@AuraEnabled
		public String grade;

		@AuraEnabled
		public String percentile;
	}

	
}