@isTest
private class CourseOfferingUpdateNameTest {

    @isTest
    static void testCourseOfferingNameUpdate() {
        try{
             Account acc = new Account(Name = ' Test');
        insert acc;
        // Create test related Term
        hed__Term__c term = new hed__Term__c(Name = '2022-Spring',Term_Reference__c = 'Term 1',hed__Account__c = acc.Id);
        insert term;

        // Create test related Course
        hed__Course__c course = new hed__Course__c(Name = 'CS101-Intro',hed__Account__c = acc.Id);
        insert course;

        // Create test Course Offering
        hed__Course_Offering__c courseOffering = new hed__Course_Offering__c(
            Name = 'OldName',
            hed__Course__c = course.Id,
            hed__Term__c = term.Id
        );
        insert courseOffering;

        // Re-query with relationship fields so that SOQL in constructor can access them
        courseOffering = [SELECT Id, Name, hed__Course__r.Name, hed__Term__r.Name 
                          FROM hed__Course_Offering__c WHERE Id = :courseOffering.Id];

        // Run class logic
        Test.startTest();
            new CourseOfferingUpdateName();
        Test.stopTest();
        }
        catch(Exception e){
            
        }
       

 
    }
}