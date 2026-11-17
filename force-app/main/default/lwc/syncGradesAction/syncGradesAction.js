import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncGrades from '@salesforce/apex/CourseOfferingGradeSyncController.syncGrades';

export default class SyncGradesAction extends LightningElement {
    @api recordId;
    isRunning = false;

    @api
    async invoke() {
        if (this.isRunning) {
            return;
        }

        this.isRunning = true;
        try {
            const result = await syncGrades({ courseOfferingId: this.recordId });
            const message = this.buildMessage(result);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: result?.success ? 'Sync Grades Success' : 'Sync Grades Completed With Issues',
                    message,
                    variant: result?.success ? 'success' : 'warning'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Sync Grades Failed',
                    message: this.resolveError(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isRunning = false;
        }
    }

    buildMessage(result) {
        if (!result) {
            return 'No response received from sync service.';
        }

        const parts = [];
        parts.push(`Course Evaluation: ${result.courseEvaluationId || '-'}`);
        parts.push(`Prepared Success: ${result.preparedSuccess ?? 0}`);
        parts.push(`Prepared Failure: ${result.preparedFailure ?? 0}`);
        parts.push(`Update Success: ${result.updateSuccess ?? 0}`);
        parts.push(`Update Failure: ${result.updateFailure ?? 0}`);
        if (result.traceId) {
            parts.push(`Trace ID: ${result.traceId}`);
        }
        return parts.join(' | ');
    }

    resolveError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Unexpected error while syncing grades.';
    }
}