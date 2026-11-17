public class CreateTermCampusMappingController {
	@AuraEnabled(cacheable=true)
	public static List<Account> getProgramValues() {
		try {
			List<Account> programList = [
				SELECT Id, Name
				FROM Account
				WHERE RecordType.DeveloperName = 'Academic_Program'
			];
			return programList;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static ProgramDependentLookups getProgramDependentLookupValues(String programId) {
		ProgramDependentLookups wrapperObj;

		try {
			List<Program_Campus_Relationship__c> combinations = [
				SELECT Id, Combination_Name__c
				FROM Program_Campus_Relationship__c
				WHERE RecordType.DeveloperName = 'Program_Level_Campus_Combination' AND Program__c = :programId
			];
			List<hed__Program_Plan__c> programPlans = [
				SELECT Id, Name
				FROM hed__Program_Plan__c
				WHERE hed__Account__c = :programId
			];

			wrapperObj = new ProgramDependentLookups(combinations, programPlans);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}

		return wrapperObj;
	}

	@AuraEnabled
	public static List<TermCampusMappingWrapper> getTermLookUpValues(
		String programCombinationId,
		String programPlanId
	) {
		try {
			List<hed__Term__c> programPlanTerms = [
				SELECT Id, Name, Term_Reference__c, hed__Parent_Term__c
				FROM hed__Term__c
				WHERE Program_Plan__c = :programPlanId
				ORDER BY Term_Number__c
			];

			List<Term_Campus_Relationship__c> termCampusRelationships = [
				SELECT Term__c, Campus__c, Campus__r.Name, Sequence_Number__c, Currency__c
				FROM Term_Campus_Relationship__c
				WHERE Program_Campus_Combination__c = :programCombinationId
				ORDER BY Sequence_Number__c
			];

			return getTermCampusMappingWrappers(programPlanTerms, termCampusRelationships);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	@AuraEnabled
	public static void saveMappings(String recordsString) {
        System.debug(recordsString);
		try {
			ProgramCampusCombinationWarpper obj = (ProgramCampusCombinationWarpper) (JSON.deserialize(
				recordsString,
				ProgramCampusCombinationWarpper.class
			));

			List<Program_Campus_Relationship__c> programCamputRelationshipList = [
				SELECT Id
				FROM Program_Campus_Relationship__c
				WHERE
					Combination_Name__c = :obj.combinationName
					AND Program_Plan__c = :obj.programPlan
					AND Master_Program_Campus_Combination__c = :obj.masterCombination
					AND Program__c = :obj.program
			];

			if (programCamputRelationshipList.size() > 0) {
				//throw new AuraHandledException('Combination with given name for this Program already Exists.');
				String errorMessage =
					'Combination with given Combination Name, Master Program Cambus Combination and program plan for this Program already Exists: ' +
					obj.combinationName;
				AuraHandledException auraEx = new AuraHandledException(errorMessage);
				auraEx.setMessage(errorMessage);
				throw auraEx;
			}

			Program_Campus_Relationship__c pcr = new Program_Campus_Relationship__c(
				Program_Plan__c = obj.programPlan,
				Combination_Name__c = obj.combinationName,
				Master_Program_Campus_Combination__c = obj.masterCombination
			);

			Database.insert(pcr);

			createTermCampusRelationshipRecords(pcr, obj);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static void createTermCampusRelationshipRecords(
		Program_Campus_Relationship__c pcr,
		ProgramCampusCombinationWarpper obj
	) {
		List<Term_Campus_Relationship__c> newRecordsList = new List<Term_Campus_Relationship__c>();
		for (TermCampusMappingWrapper tcm : obj.termCampusRelationships) {
			Term_Campus_Relationship__c tcr = new Term_Campus_Relationship__c(
				Term__c = tcm.termId,
				Campus__c = tcm.campusId,
				Program_Campus_Combination__c = pcr.Id,
				Sequence_Number__c = Integer.valueOf(tcm.sequenceNumber),
				Currency__c = tcm.currencyValue
			);
			newRecordsList.add(tcr);
		}

		Database.insert(newRecordsList);
	}

	private static List<TermCampusMappingWrapper> getTermCampusMappingWrappers(
		List<hed__Term__c> terms,
		List<Term_Campus_Relationship__c> termRelationships
	) {
        System.debug('termRelationships: ' + termRelationships);
		List<TermCampusMappingWrapper> termCampusMappingWrappers = new List<TermCampusMappingWrapper>();

		Map<String, String> currencyLabelByValue = getCurrencyPicklistMap();

		Map<Id, hed__Term__c> termByParentTerm = new Map<Id, hed__Term__c>();

		for (hed__Term__c term : terms) {
			termByParentTerm.put(term.hed__Parent_Term__c, term);
		}

		for (Term_Campus_Relationship__c relationship : termRelationships) {
			if (!termByParentTerm.containsKey(relationship.Term__c)) {
				continue;
			}

			hed__Term__c term = termByParentTerm.get(relationship.Term__c);

			termCampusMappingWrappers.add(
				new TermCampusMappingWrapper(
					String.valueOf(relationship.Sequence_Number__c),
					term.Name,
					term.Id,
					term.Term_Reference__c,
					relationship.Campus__r.Name,
					relationship.Campus__c,
					currencyLabelByValue.get(relationship.Currency__c)
				)
			);
		}
        System.debug('termCampusMappingWrappers: ' + termCampusMappingWrappers);

		return termCampusMappingWrappers;
	}

	private static Map<String, String> getCurrencyPicklistMap() {
		Map<String, String> labelByValue = new Map<String, String>();

		Schema.DescribeFieldResult fieldResult = Term_Campus_Relationship__c.Currency__c.getDescribe();

		for (Schema.PicklistEntry pickListVal : fieldResult.getPicklistValues()) {
			labelByValue.put(pickListVal.getValue(), pickListVal.getLabel());
		}

		return labelByValue;
	}

	public class ProgramDependentLookups {
		@AuraEnabled
		public List<Program_Campus_Relationship__c> programCampusCombinations;
		@AuraEnabled
		public List<hed__Program_Plan__c> programPlans;

		ProgramDependentLookups(
			List<Program_Campus_Relationship__c> programCampusCombinations,
			List<hed__Program_Plan__c> programPlans
		) {
			this.programCampusCombinations = programCampusCombinations;
			this.programPlans = programPlans;
		}
	}

	public class TermCampusMappingWrapper {
		@AuraEnabled
		public String sequenceNumber;
		@AuraEnabled
		public String term;
		@AuraEnabled
		public String termId;
		@AuraEnabled
		public String termReference;
		@AuraEnabled
		public String campus;
		@AuraEnabled
		public String campusId;
		@AuraEnabled
		public String currencyValue;

		public TermCampusMappingWrapper(
			String sequenceNumber,
			String term,
			String termId,
			String termReference,
			String campus,
			String campusId,
			String currencyValue
		) {
			this.sequenceNumber = sequenceNumber;
			this.term = term;
			this.termId = termId;
			this.termReference = termReference;
			this.campus = campus;
			this.campusId = campusId;
			this.currencyValue = currencyValue;
		}
	}

	public class ProgramCampusCombinationWarpper {
		public String program;
		public String combinationName;
		public String programPlan;
		public String masterCombination;
		public List<TermCampusMappingWrapper> termCampusRelationships;
	}
       
}