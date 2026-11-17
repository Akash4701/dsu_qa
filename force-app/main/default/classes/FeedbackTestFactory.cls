/**
 * Test data factory for the scheduler / item-generation tests. One place to change when the Term,
 * Course Offering, Enrollment or Scheduler schema changes. Every make* method returns an unsaved record,
 * every create* method inserts it.
 */
@IsTest
public class FeedbackTestFactory {

    public static void enableIntegrationSettings() {
        // Contact/Enrollment triggers read this hierarchy setting; the callouts they would make are mocked.
        insert new Blackboard_Integration__c(
            SetupOwnerId = UserInfo.getOrganizationId(), Username__c = 'testUser', Password__c = 'testPass'
        );
        Test.setMock(HttpCalloutMock.class, new NoopCallout());
    }

    public static Id contactRecordType(String name) {
        return Schema.SObjectType.Contact.getRecordTypeInfosByName().get(name).getRecordTypeId();
    }

    public static Id enrolmentRecordType(String developerName) {
        return Schema.SObjectType.hed__Course_Enrollment__c.getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
    }

    public static Account createAccount() {
        Account account = new Account(Name = 'Feedback Test University');
        insert account;
        return account;
    }

    public static hed__Term__c createTerm(Id accountId) {
        hed__Term__c term = new hed__Term__c(Name = 'Feedback Term', hed__Account__c = accountId, Term_Reference__c = 'Term 1');
        insert term;
        return term;
    }

    public static hed__Course__c createCourse(Id accountId) {
        hed__Course__c course = new hed__Course__c(Name = 'Feedback Course', hed__Course_ID__c = 'FB-001', hed__Account__c = accountId);
        insert course;
        return course;
    }

    public static hed__Course_Offering__c createOffering(Id courseId, Id termId, Id facultyId, Date startDate, Date endDate) {
        hed__Course_Offering__c offering = new hed__Course_Offering__c(
            Name = 'Feedback Offering', hed__Course__c = courseId, hed__Term__c = termId,
            hed__Faculty__c = facultyId, hed__Start_Date__c = startDate, hed__End_Date__c = endDate
        );
        insert offering;
        return offering;
    }

    public static List<Contact> createStudents(Integer count) {
        List<Contact> students = new List<Contact>();
        for (Integer i = 0; i < count; i++) {
            students.add(new Contact(RecordTypeId = contactRecordType('Student'), FirstName = 'Student', LastName = 'FB' + i));
        }
        insert students;
        return students;
    }

    public static Contact createFaculty() {
        Contact faculty = new Contact(RecordTypeId = contactRecordType('Faculty'), FirstName = 'Faculty', LastName = 'FB');
        insert faculty;
        return faculty;
    }

    /** One program enrolment per student in the term: the audience of term-level feedback. */
    public static void createProgramEnrolments(List<Contact> students, Id termId) {
        List<hed__Program_Enrollment__c> rows = new List<hed__Program_Enrollment__c>();
        for (Contact student : students) {
            rows.add(new hed__Program_Enrollment__c(hed__Contact__c = student.Id, Term__c = termId));
        }
        insert rows;
    }

    public static hed__Course_Enrollment__c createCourseEnrolment(Id contactId, Id offeringId, String recordTypeDeveloperName) {
        hed__Course_Enrollment__c enrolment = new hed__Course_Enrollment__c(
            hed__Contact__c = contactId, hed__Course_Offering__c = offeringId,
            RecordTypeId = enrolmentRecordType(recordTypeDeveloperName)
        );
        insert enrolment;
        return enrolment;
    }

    public static Questionnaire_Metadata__c createSection(String feedbackType) {
        Questionnaire_Metadata__c section = new Questionnaire_Metadata__c(
            Name = 'FB ' + feedbackType, RecordTypeId = FeedbackTestRecordTypes.questionnaire(),
            Feedback_Type__c = feedbackType, Active__c = true
        );
        insert section;
        return section;
    }

    public static Feedback_Scheduler__c makeScheduler(Id sectionId, Id termId, Date startDate, Date endDate) {
        return new Feedback_Scheduler__c(
            Feedback_Master__c = sectionId, Term__c = termId, Start_Date__c = startDate, End_Date__c = endDate
        );
    }

    public static Feedback_Scheduler__c createScheduler(Id sectionId, Id termId, Date startDate, Date endDate) {
        Feedback_Scheduler__c scheduler = makeScheduler(sectionId, termId, startDate, endDate);
        insert scheduler;
        return scheduler;
    }

    public static Integer itemCount(Id schedulerId) {
        return [SELECT COUNT() FROM Feedback_Item__c WHERE Feedback_Scheduler__c = :schedulerId];
    }

    /** Swallows any callout the Contact/Enrollment triggers attempt, so tests never reach out. */
    public class NoopCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{}');
            return response;
        }
    }
}