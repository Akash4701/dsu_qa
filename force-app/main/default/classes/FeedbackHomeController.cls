/**
 * Thin @AuraEnabled facade for the Feedback Management home LWCs. No logic: it delegates to
 * FeedbackHomeService and converts any failure into a readable AuraHandledException message.
 */
public with sharing class FeedbackHomeController {

    @AuraEnabled(cacheable=true)
    public static FeedbackHomeDto.Overview getOverview() {
        try {
            return FeedbackHomeService.overview();
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FeedbackHomeDto.SectionRow> getParameterSections(String recordTypeDeveloperName) {
        try {
            return FeedbackHomeService.parameterSections(recordTypeDeveloperName);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static FeedbackHomeDto.SectionPage getSectionPage(
        String recordTypeDeveloperName, String search, Boolean activeOnly, Integer pageSize, Integer pageNumber
    ) {
        try {
            return FeedbackHomeService.sectionPage(recordTypeDeveloperName, search, activeOnly, pageSize, pageNumber);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static FeedbackHomeDto.SchedulePage getSchedulePage(
        String search, String status, String sortKey, Integer pageSize, Integer pageNumber
    ) {
        try {
            return FeedbackHomeService.schedulePage(search, status, sortKey, pageSize, pageNumber);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FeedbackHomeDto.ParameterRow> getParameters(Id sectionId) {
        try {
            return FeedbackHomeService.parameters(sectionId);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FeedbackHomeDto.ScheduleRow> getSchedules() {
        try {
            return FeedbackHomeService.schedules();
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FeedbackHomeDto.ItemRow> getScheduleItems(Id schedulerId, String status) {
        try {
            return FeedbackHomeService.scheduleItems(schedulerId, status);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    private static AuraHandledException toAuraException(Exception e) {
        AuraHandledException wrapped = new AuraHandledException(e.getMessage());
        wrapped.setMessage(e.getMessage());
        return wrapped;
    }

    @AuraEnabled(cacheable=true)
    public static FeedbackHomeDto.ReportPage getReportPage(
        String search, String feedbackType, Id termId, Date fromDate, Date toDate, Integer pageSize, Integer pageNumber
    ) {
        try {
            return FeedbackHomeService.reportPage(search, feedbackType, termId, fromDate, toDate, pageSize, pageNumber);
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }

    @AuraEnabled(cacheable=true)
    public static FeedbackHomeDto.ReportFilters getReportFilters() {
        try {
            return FeedbackHomeService.reportFilters();
        } catch (Exception e) {
            throw toAuraException(e);
        }
    }
}