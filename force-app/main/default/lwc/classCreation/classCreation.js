import { LightningElement, api, wire } from 'lwc';
import getCourseConnectionCount from '@salesforce/apex/CreateClassController.getCourseConnectionCount';
import createClassAllocationsAndAssignEnrollments from '@salesforce/apex/CreateClassController.createClassAllocationsAndAssignEnrollments';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ClassCreation extends LightningElement {
    @api recordId;
    courseOfferingNames = [];
    totalConnections = 0;
    error;
    isLoading = true;
    
    numClasses;
    studentsPerClass;

    @wire(getCourseConnectionCount, { ipcId: '$recordId' })
    wiredConnectionCount({ error, data }) {
        this.isLoading = false;
        if (data !== undefined) {
            this.totalConnections = data;
            console.log('Enrollment count fetched:', data);
        } else if (error) {
            this.error = 'Error fetching connection count';
            console.error(error);
        }
    }

    handleNumClassesChange(event) {
        this.numClasses = parseInt(event.target.value, 10);
    }

    handleStudentsPerClassChange(event) {
        this.studentsPerClass = parseInt(event.target.value, 10);
    }

    handleValidateAndCreate() {
        if (!this.numClasses || !this.studentsPerClass) {
            this.showToast('Error', 'Please fill in all fields.', 'error');
            return;
        }

        const totalCapacity = this.numClasses * this.studentsPerClass;
        if (totalCapacity < this.enrollmentCount) {
            const missing = this.enrollmentCount - totalCapacity;
            this.showToast('Insufficient Capacity', `You are short of ${missing} student slots.`, 'error');
            return;
        }

        this.isLoading = true;

        createClassAllocationsAndAssignEnrollments({
            ipcId: this.recordId,
            numClasses: this.numClasses,
            studentsPerClass: this.studentsPerClass
        })
        .then(() => {
            this.showToast('Success', 'Class Allocations created successfully.', 'success');
        })
        .catch(error => {
            console.error(error);
            this.showToast('Error', 'An error occurred while creating classes.', 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}