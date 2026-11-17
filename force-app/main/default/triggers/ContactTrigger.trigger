trigger ContactTrigger on Contact (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        ContactHandler.handleDEBIDUpdate(Trigger.new, Trigger.oldMap);
    }
}