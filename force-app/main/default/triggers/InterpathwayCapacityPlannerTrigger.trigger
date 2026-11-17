trigger InterpathwayCapacityPlannerTrigger 
on Interpathway_Capacity_Planner__c (before insert) {
    if (Trigger.isBefore && Trigger.isInsert) {
        CourseConnectionHandler.setDefaultRemainingSeats(Trigger.new);
    }
}