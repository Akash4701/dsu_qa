@isTest
public class TaskClass_Test {
    
    @isTest
    static void testTaskTriggerSetsTaskSubtype() {
        // Create a Task record
        Task t = new Task(
            Subject = 'Follow up call',
            Status = 'Not Started',
            Priority = 'Normal',
            WhatId = null, // Optional depending on your org setup
            OwnerId = UserInfo.getUserId()
        );

        Test.startTest();
        insert t;
        Test.stopTest();

        // Query the inserted task and assert TaskSubtype
        Task insertedTask = [SELECT Id, TaskSubtype FROM Task WHERE Id = :t.Id];
        System.assertEquals('Call', insertedTask.TaskSubtype, 'TaskSubtype should be set to Call by the trigger');
    }
}