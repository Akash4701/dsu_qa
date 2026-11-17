public with sharing class CreateProgramTermCampusMappingController {
	@AuraEnabled(cacheable=true)
	public static ComboBoxValuesWrapper getLookUpValues() {
		List<Campus__c> campusList = new List<Campus__c>();
		List<PicklistWrapper> currencyOptions = new List<PicklistWrapper>();
		ComboBoxValuesWrapper wrapperObj;
		try {
			campusList = [SELECT Id, Name FROM Campus__c];
			currencyOptions = getCurrencyPickListValues();
			wrapperObj = new ComboBoxValuesWrapper(campusList, currencyOptions);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}

		return wrapperObj;
	}

	@AuraEnabled(cacheable=true)
	public static List<hed__Term__c> getTermLookUpValues(String programId) {
		List<hed__Term__c> termList = new List<hed__Term__c>();
		try {
			termList = [
				SELECT Id, Name, Term_Reference__c
				FROM hed__Term__c
				WHERE hed__Account__c = :programId AND Program_Plan__c = NULL
				ORDER BY Term_Reference__c, Name
			];

			return termList;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static void saveMappings(String recordsString) {
		try {
			ProgramCampusCombinationWarpper obj = (ProgramCampusCombinationWarpper) (JSON.deserialize(
				recordsString,
				ProgramCampusCombinationWarpper.class
			));

			List<Program_Campus_Relationship__c> programCamputRelationshipList = [
				SELECT id
				FROM Program_Campus_Relationship__c
				WHERE Combination_Name__c = :obj.combinationName AND Program__c = :obj.program
			];

			if (programCamputRelationshipList.size() > 0) {
				String errorMessage =
					'Combination with given Combination Name for this Program already Exists: ' + obj.combinationName;
				AuraHandledException auraEx = new AuraHandledException(errorMessage);
				auraEx.setMessage(errorMessage);

				throw auraEx;
			}

			Id recordTypeId = Schema.SObjectType.Program_Campus_Relationship__c.getRecordTypeInfosByName()
				.get('Program Level Campus Combination')
				.getRecordTypeId();

			Program_Campus_Relationship__c pcr = new Program_Campus_Relationship__c(
				recordTypeId = recordTypeId,
				Program__c = obj.program,
				Combination_Name__c = obj.combinationName
			);

			Database.insert(pcr);

			createTermCampusRelationshipRecords(pcr, obj);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static List<PicklistWrapper> getCurrencyPickListValues() {
		List<PicklistWrapper> pickListValuesList = new List<PicklistWrapper>();
		Schema.DescribeFieldResult fieldResult = Term_Campus_Relationship__c.CurrencyIsoCode.getDescribe();
		List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
		for (Schema.PicklistEntry pickListVal : ple) {
			pickListValuesList.add(new PicklistWrapper(pickListVal.getLabel(), pickListVal.getValue()));
		}

		return pickListValuesList;
	}

	private static void createTermCampusRelationshipRecords(
		Program_Campus_Relationship__c pcr,
		ProgramCampusCombinationWarpper obj
	) {
		List<Term_Campus_Relationship__c> newRecordsList = new List<Term_Campus_Relationship__c>();
		for (TermCampusMappingWrapper tcm : obj.termCampusList) {
			Term_Campus_Relationship__c tcr = new Term_Campus_Relationship__c(
				Term__c = tcm.term,
				Campus__c = tcm.campus,
				Program_Campus_Combination__c = pcr.Id,
				Sequence_Number__c = Integer.valueOf(tcm.sequenceNumber),
				CurrencyIsoCode = tcm.currencyValue
			);
			newRecordsList.add(tcr);
		}

		Database.insert(newRecordsList);
	}

	public class ComboBoxValuesWrapper {
		@AuraEnabled
		public List<Campus__c> campusList;
		@AuraEnabled
		public List<PicklistWrapper> currencyOptions;

		ComboBoxValuesWrapper(List<Campus__c> campusList, List<PicklistWrapper> currencyOptions) {
			this.campusList = campusList;
			this.currencyOptions = currencyOptions;
		}
	}

	public class ProgramCampusCombinationWarpper {
		public String program;
		public String combinationName;
		public List<TermCampusMappingWrapper> termCampusList;
	}

	public class TermCampusMappingWrapper {
		public String sequenceNumber;
		public String term;
		public String campus;
		public String currencyValue;
	}

	public class PicklistWrapper {
		@AuraEnabled
		public String label;
		@AuraEnabled
		public String value;

		PicklistWrapper(String label, String value) {
			this.label = label;
			this.value = value;
		}
	}
       
}