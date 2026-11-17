public class AutoCloseResolvedCasesScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new AutoCloseResolvedCases(), 200);
    }
}