import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

// Import fields for Course Enrollment Management
import ACADEMIC_TERM_FIELD from '@salesforce/schema/Course_Enrollment_Management__c.Academic_Term__c';
import ACADEMIC_TERM_NAME from '@salesforce/schema/Course_Enrollment_Management__c.Academic_Term__r.Name';

// Import fields for Program Plan
import PROGRAM_PLAN_NAME from '@salesforce/schema/hed__Program_Plan__c.Name';

export default class StudentRegistrationModal extends LightningElement {
    @api recordId;
    @track academicTermId;
    @track academicTermName;
    @track programPlanName;
    selectedCourseEnrollmentId;

    // Wire to get Academic Term when Course Enrollment Management changes
    @wire(getRecord, { 
        recordId: '$selectedCourseEnrollmentId', 
        fields: [ACADEMIC_TERM_FIELD, ACADEMIC_TERM_NAME] 
    })
    courseEnrollmentRecord({ error, data }) {
        if (data) {
            this.academicTermId = getFieldValue(data, ACADEMIC_TERM_FIELD);
            this.academicTermName = getFieldValue(data, ACADEMIC_TERM_NAME);
        } else if (error) {
            console.error('Error fetching course enrollment:', error);
            this.academicTermId = null;
            this.academicTermName = null;
        }
    }

    // Wire to get Program Plan name
    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [PROGRAM_PLAN_NAME] 
    })
    programPlanRecord({ error, data }) {
        if (data) {
            this.programPlanName = getFieldValue(data, PROGRAM_PLAN_NAME);
        } else if (error) {
            console.error('Error fetching program plan:', error);
            this.programPlanName = null;
        }
    }

    // Getter for academic term value to display in the form (shows name)
    get academicTermDisplayValue() {
        return this.academicTermName;
    }

    // Getter for program plan value to display in the form (shows name)
    get programPlanDisplayValue() {
        return this.programPlanName;
    }

    handleCourseEnrollmentChange(event) {
        this.selectedCourseEnrollmentId = event.target.value;
    }
    
    handleSubmit(event) {
        event.preventDefault(); // Prevent default to modify fields
        const fields = event.detail.fields;
        
        // Ensure Program Plan and Academic Term are set
        fields.Program_Plan__c = this.recordId;
        
        if (this.academicTermId) {
            fields.AcademicTerm = this.academicTermId;
        }
        
        // Debug logging
        console.log('Submitting fields:', fields);
        console.log('Program Plan ID:', this.recordId);
        console.log('Program Plan Name:', this.programPlanName);
        console.log('Academic Term ID:', this.academicTermId);
        console.log('Academic Term Name:', this.academicTermName);
        
        // Submit the form with modified fields
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }
    
    handleSuccess() {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Student Registration Window created successfully',
                variant: 'success'
            })
        );
        
        // Close the action screen
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    
    handleError(event) {
        let errorMessage = 'An error occurred while saving the record.';
        
        if (event.detail && event.detail.detail) {
            errorMessage = event.detail.detail;
        } else if (event.detail && event.detail.message) {
            errorMessage = event.detail.message;
        }
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error', 
                message: errorMessage,
                variant: 'error'
            })
        );
    }
    
    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}