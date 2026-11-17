/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 09-13-2023
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public with sharing class LetterGradeSetupController {
	@AuraEnabled(cacheable=true)
	public static LetterGradeSetting getLetterGradeSettings(String gradeSettingId) {
		if (String.isBlank(gradeSettingId) ) {
			LetterGradeSetting setting = new LetterGradeSetting();
			setting.isActive = true;
			setting.gradeRanges = new List<LetterGradeRange>();

			return setting;
		}

		try {
			Letter_Grade_Setting__c setting = [
				SELECT
					Id,
					Name,
					RecordType.DeveloperName,
					Mechanism__c,
					Is_Active__c,
					(
						SELECT Id, Name, Range_Start__c, Range_End__c, Letter_Grade__c, Grade_Point__c, Definition__c
						FROM Letter_Grade_Range__r
						ORDER BY Letter_Grade__c
					)
				FROM Letter_Grade_Setting__c
				WHERE Id = :gradeSettingId
			];
			return new LetterGradeSetting(setting);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage() + ' ' + e.getStackTraceString());
		}
	}

	@AuraEnabled
	public static void saveLetterGradeSettings(String letterGradeSetting,Boolean activation ) {
		try {
			LetterGradeSetting setting = (LetterGradeSetting) JSON.deserialize(
				letterGradeSetting,
				LetterGradeSetting.class
			);

			Letter_Grade_Setting__c settingRecord = setting.getRecord();
			upsert settingRecord;

			List<Letter_Grading__c> gradeRangeList = new List<Letter_Grading__c>();

			for (LetterGradeRange gradeRange : setting.gradeRanges) {
				Letter_Grading__c gradeRecord = gradeRange.getRecord();

				if (gradeRecord.Id == null)
					gradeRecord.Letter_Grade_Setting__c = settingRecord.Id;

				gradeRangeList.add(gradeRecord);
			}

			upsert gradeRangeList;
			
			// if(activation && setting.recordType == 'Master'){
			// 	deactiveOldLetterGradeSetting(settingRecord);
			// }

			delete [
				SELECT Id
				FROM Letter_Grading__c
				WHERE
					Letter_Grade_Setting__c = :settingRecord.Id
					AND Id NOT IN :new Map<Id, Letter_Grading__c>(gradeRangeList).keySet()
			];
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage() + ' ' + e.getStackTraceString());
		}
	}

	private static void deactiveOldLetterGradeSetting(
		Letter_Grade_Setting__c letterGradeSettings
	) {
		List<Letter_Grade_Setting__c> oldActiveLetterGrades = new List<Letter_Grade_Setting__c>();
		for (Letter_Grade_Setting__c eachLetterGrade : [
			SELECT Id, Is_Active__c
			FROM Letter_Grade_Setting__c
			WHERE Id != :letterGradeSettings.Id AND Mechanism__c =:letterGradeSettings.Mechanism__c AND RecordType.Name = 'Master'
		]) {
			eachLetterGrade.Is_Active__c = false;
			oldActiveLetterGrades.add(eachLetterGrade);
		}
		if (!oldActiveLetterGrades.isEmpty()) {
			update oldActiveLetterGrades;
		}
	}

	public class LetterGradeSetting {
		@AuraEnabled
		public String Id { get; set; }

		@AuraEnabled
		public String name { get; set; }

		@AuraEnabled
		public String recordType { get; set; }

		@AuraEnabled
		public String mechanism { get; set; }

		@AuraEnabled
		public Boolean isActive { get; set; }

		@AuraEnabled
		public List<LetterGradeRange> gradeRanges { get; set; }

		public LetterGradeSetting() {
		}

		// Constructor for LetterGradeSetting
		public LetterGradeSetting(Letter_Grade_Setting__c setting) {
			this.Id = setting.Id;
			this.name = setting.Name;
			this.recordType = setting.RecordType.DeveloperName;
			this.mechanism = setting.Mechanism__c;
			this.isActive = setting.Is_Active__c;

			this.gradeRanges = new List<LetterGradeRange>();
			for (Letter_Grading__c gradeRange : setting.Letter_Grade_Range__r) {
				this.gradeRanges.add(new LetterGradeRange(gradeRange));
			}
		}

		public Letter_Grade_Setting__c getRecord() {
			Letter_Grade_Setting__c setting = new Letter_Grade_Setting__c();
			setting.Id = this.Id;
			setting.Name = this.name;
			setting.Mechanism__c = this.mechanism;
			setting.Is_Active__c = this.isActive;

			if (this.recordType != null) {
				setting.RecordTypeId = [
					SELECT Id
					FROM RecordType
					WHERE SObjectType = 'Letter_Grade_Setting__c' AND DeveloperName = :this.recordType
				]
				.Id;
			}

			return setting;
		}
	}

	@AuraEnabled
	public static Boolean checkActiveLetterGrade(String settingId , String mechanism){
		try {
			List<Letter_Grade_Setting__c> otherActiveSetting = [ SELECT Id FROM Letter_Grade_Setting__c WHERE Id != :settingId AND Mechanism__c =: mechanism AND RecordType.DeveloperName = 'Master' AND Is_Active__c = true];
			
			return otherActiveSetting.size() == 0 ? true : false;
			
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	public class LetterGradeRange {
		@AuraEnabled
		public String Id { get; set; }

		@AuraEnabled
		public Decimal rangeStart { get; set; }

		@AuraEnabled
		public Decimal rangeEnd { get; set; }

		@AuraEnabled
		public String letterGrade { get; set; }

		@AuraEnabled
		public Decimal gradePoint { get; set; }

		@AuraEnabled
		public String definition { get; set; }

		public LetterGradeRange(Letter_Grading__c gradeRange) {
			this.Id = gradeRange.Id;
			this.rangeStart = gradeRange.Range_Start__c;
			this.rangeEnd = gradeRange.Range_End__c;
			this.letterGrade = gradeRange.Letter_Grade__c;
			this.gradePoint = gradeRange.Grade_Point__c;
			this.definition = gradeRange.Definition__c;
		}

		public Letter_Grading__c getRecord() {
			Letter_Grading__c gradeRange = new Letter_Grading__c();
			gradeRange.Id = this.Id;
			gradeRange.Range_Start__c = this.rangeStart;
			gradeRange.Range_End__c = this.rangeEnd;
			gradeRange.Letter_Grade__c = this.letterGrade;
			gradeRange.Grade_Point__c = this.gradePoint;
			gradeRange.Definition__c = this.definition;

			return gradeRange;
		}
	}
    
    public static void testCoverage() {}
}