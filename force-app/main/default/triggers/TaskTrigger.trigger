trigger TaskTrigger on Task (before insert) {
    if(Trigger.isInsert){
        if(Trigger.isBefore){
            TaskClass.taskMethod(Trigger.New);
        }
    }
}