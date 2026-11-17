global class CRMTokenScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        CRMTokenService.callNodeAPIWithJWT();
    }
}