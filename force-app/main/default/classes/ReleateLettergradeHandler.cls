public class ReleateLettergradeHandler extends TriggerHandler {
	public static Integer count = 0;
	public override void processAfterInsert() {
		// gradeSchemeUpdate(Trigger.new);
	}

	public override void processAfterUpdate() {
		if (count == 0) {
			gradeSchemeUpdate(Trigger.new);
		}
	}

	public override void processBeforeUpdate() {
		if (count < 2) {
			gradeSchemeRemoved(Trigger.new);
			populateLetterGradeSetting((hed__Course_Offering__c) Trigger.new[0]);
		}
	}

	private static void gradeSchemeRemoved(List<hed__Course_Offering__c> courseOfferingList) {
		List<hed__Course_Offering__c> updateCourseOffering = new List<hed__Course_Offering__c>();
		for (hed__Course_Offering__c eachCourseOffering : courseOfferingList) {
			if (
				eachCourseOffering.Grade_Scheme__c != null ||
				eachCourseOffering.Grade_Scheme__c ==
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme__c
			)
				continue;
			eachCourseOffering.Letter_Grade_Setting__c = null;
		}
	}

	public static void gradeSchemeUpdate(List<hed__Course_Offering__c> courseOffering) {
		List<hed__Course_Offering__c> courseLevelCourseOffering = new List<hed__Course_Offering__c>();
		Set<Id> termIds = new Set<Id>();
		Set<Id> courseIds = new Set<Id>();
		List<hed__Course_Offering__c> relatedCourseOfferingToUpdate = new List<hed__Course_Offering__c>();
		Map<Id, Id> gradeSchemeIdByCourseOffering = new Map<Id, Id>();

		for (hed__Course_Offering__c eachCourseOffering : courseOffering) {
			if (
				(eachCourseOffering.Grade_Scheme__c ==
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme__c) ||
				((((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme__c == null ||
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme_RecordType_Name__c ==
				'Course_Section') && eachCourseOffering.Grade_Scheme_RecordType_Name__c == 'Course_Section') ||
				(((hed__Course_Offering__c)Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme_RecordType_Name__c ==
				'Course_Section' && eachCourseOffering.Grade_Scheme__c == null)
			)
				continue;

			if (eachCourseOffering.Grade_Scheme_RecordType_Name__c == 'Course') {
				gradeSchemeIdByCourseOffering.put(eachCourseOffering.Id, eachCourseOffering.Grade_Scheme__c);
			} else if (
				eachCourseOffering.Grade_Scheme__c == null ||
				((hed__Course_Offering__c) Trigger.oldMap.get(eachCourseOffering.Id)).Grade_Scheme_RecordType_Name__c ==
				'Course'
			) {
				gradeSchemeIdByCourseOffering.put(eachCourseOffering.Id, null);
			}
			courseLevelCourseOffering.add(eachCourseOffering);
			termIds.add(eachCourseOffering.hed__Term__c);
			courseIds.add(eachCourseOffering.hed__Course__c);
		}
		// Most Course Offering updates (e.g. enrollment counts) don't touch the grade scheme
		if (courseLevelCourseOffering.isEmpty()) {
			return;
		}

		List<hed__Course_Offering__c> relatedCourseOffering = [
			SELECT Id, hed__Term__c, hed__Course__c, Grade_Scheme__c
			FROM hed__Course_Offering__c
			WHERE hed__Course__c IN :courseIds AND hed__Term__c IN :termIds AND Id NOT IN :courseLevelCourseOffering
		];

		for (hed__Course_Offering__c eachCourseOffering : courseLevelCourseOffering) {
			for (hed__Course_Offering__c eachRelatedCourseOffering : relatedCourseOffering) {
				if (
					eachCourseOffering.Grade_Scheme__c != eachRelatedCourseOffering.Grade_Scheme__c &&
					eachCourseOffering.hed__Term__c == eachRelatedCourseOffering.hed__Term__c &&
					eachCourseOffering.hed__Course__c == eachRelatedCourseOffering.hed__Course__c
				) {

					eachRelatedCourseOffering.Grade_Scheme__c = gradeSchemeIdByCourseOffering.get(
						eachCourseOffering.Id
					);
					relatedCourseOfferingToUpdate.add(eachRelatedCourseOffering);
				}
			}
		}

		if (!relatedCourseOfferingToUpdate.isEmpty()) {
			count++;
			update relatedCourseOfferingToUpdate;
		}
	}

	public void populateLetterGradeSetting(hed__Course_Offering__c courseOffering) {
		String mechanismType;
		Set<Id> courseOfferingIds = new Set<Id>{ courseOffering.Id };

		if(courseOffering.Grade_Scheme__c == ((hed__Course_Offering__c)Trigger.oldMap.get(courseOffering.Id)).Grade_Scheme__c)
			return;

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

		List<Grade_Scheme_Critera__c> criterias = [
			SELECT Id, Range_From__c, Range_To__c, Mechanism_Type__c
			FROM Grade_Scheme_Critera__c
			WHERE Grade_Scheme__c = :courseOffering.Grade_Scheme__c
		];
		List<hed__Course_Enrollment__c> courseConnectionRecords = [
			SELECT Id
			FROM hed__Course_Enrollment__c
			WHERE hed__Course_Offering__c = :courseOfferingIds AND RecordType.DeveloperName = 'Student'
		];

		Integer studentStrength = courseConnectionRecords.size();
		for (Grade_Scheme_Critera__c eachGradeSchemeCriteria : criterias) {
			if (
				studentStrength < eachGradeSchemeCriteria.Range_From__c ||
				studentStrength > eachGradeSchemeCriteria.Range_To__c
			)
				continue;
			mechanismType = eachGradeSchemeCriteria.Mechanism_Type__c;
		}

		if (String.isBlank(mechanismType))
			return;

		List<Letter_Grade_Setting__c> settings = [
			SELECT Id
			FROM Letter_Grade_Setting__c
			WHERE RecordType.DeveloperName = 'Master' AND Mechanism__c = :mechanismType AND Is_Active__c = TRUE
		];

		if (settings.isEmpty())
			return;

		courseOffering.Letter_Grade_Setting__c = settings[0].Id;
	}
    
    public static void testCoverage() {}
}