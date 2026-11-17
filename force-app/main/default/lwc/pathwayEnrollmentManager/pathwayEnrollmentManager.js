import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getProgramPathways from '@salesforce/apex/PathwayEnrollmentController.getProgramPathways';
import createPathwayEnrollments from '@salesforce/apex/PathwayEnrollmentController.createPathwayEnrollments';
import updatePathwayEnrollments from '@salesforce/apex/PathwayEnrollmentController.updatePathwayEnrollments';


export default class PathwayEnrollmentManager extends LightningElement {
    @api recordId;
    @track showActionButtons = true;
    @track showDataTable = false;
    @track isLoading = false;
    @track error = null;
    @track enrollmentData = [];
    @track selectedRows = [];
    @track draftValues = [];
    @track isCreateMode = false;
    @track isUpdateMode = false;


    // Columns will be set dynamically
    @track columns = [];


    handleCreateClick() {
        this.isLoading = true;
        this.error = null;
        this.isCreateMode = true;
        this.isUpdateMode = false;
        
        getProgramPathways({ programPlanId: this.recordId, checkForEnrollments: false })
            .then(result => {
                const pathwaysWithoutEnrollments = result.filter(pathway => !pathway.hasEnrollment);
                
                if (pathwaysWithoutEnrollments.length === 0) {
                    this.showToast('Info', 'All Program Pathways already have enrollments.', 'info');
                    return;
                }
                
                // Prepare data for creation (removed Academic_Term__c)
                this.enrollmentData = pathwaysWithoutEnrollments.map(pathway => {
                    return {
                        key: pathway.Id,
                        programPathwayId: pathway.Id,
                        programPathwayName: pathway.Name,
                        Start_Date__c: '',
                        End_Date__c: '',
                        Is_Active__c: true,
                        No_of_Pathway_Connections__c: 0,
                        Program_Pathway__c: pathway.Id,
                        isNewRecord: true
                    };
                });
                
                // Define columns for creation mode - 'No of Pathway Connections' is now non-editable
                this.columns = [
                    { label: 'Program Pathway Name', fieldName: 'programPathwayName', type: 'text' },
                    { 
                        label: 'Start Date', 
                        fieldName: 'Start_Date__c', 
                        type: 'date-local', 
                        editable: true 
                    },
                    { 
                        label: 'End Date', 
                        fieldName: 'End_Date__c', 
                        type: 'date-local', 
                        editable: true 
                    },
                    { label: 'Is Active', fieldName: 'Is_Active__c', type: 'boolean', editable: true },
                    { label: 'No of Pathway Connections', fieldName: 'No_of_Pathway_Connections__c', type: 'number', editable: false }
                ];


                this.showActionButtons = false;
                this.showDataTable = true;
                // Reset draft values for new mode
                this.draftValues = [];
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }


    handleUpdateClick() {
        this.isLoading = true;
        this.error = null;
        this.isCreateMode = false;
        this.isUpdateMode = true;
        
        getProgramPathways({ programPlanId: this.recordId, checkForEnrollments: true })
            .then(result => {
                const pathwaysWithEnrollments = result.filter(pathway => pathway.hasEnrollment);
                
                if (pathwaysWithEnrollments.length === 0) {
                    this.showToast('Info', 'No Program Pathways have enrollments to update.', 'info');
                    return;
                }
                
                // Prepare data for update - now handles multiple enrollments per pathway
                this.enrollmentData = pathwaysWithEnrollments.map(pathway => {
                    const enrollment = pathway.enrollment;
                    return {
                        key: enrollment.Id, // Use enrollment ID as unique key
                        Id: enrollment.Id,
                        programPathwayId: pathway.Id,
                        programPathwayName: pathway.Name,
                        Academic_Term__c: enrollment.Academic_Term__c || '',
                        Academic_Term_Name__c: enrollment.Academic_Term__r?.Name || '',
                        Start_Date__c: enrollment.Start_Date__c ? this.formatDateForDisplay(enrollment.Start_Date__c) : '',
                        End_Date__c: enrollment.End_Date__c ? this.formatDateForDisplay(enrollment.End_Date__c) : '',
                        Is_Active__c: enrollment.Is_Active__c,
                        No_of_Pathway_Connections__c: enrollment.No_of_Pathway_Connections__c,
                        Program_Pathway__c: pathway.Id,
                        CreatedDate: enrollment.CreatedDate ? this.formatDateForDisplay(enrollment.CreatedDate) : '',
                        isNewRecord: false
                    };
                });
                
                // Define columns for update mode (only Start/End Date editable)
                this.columns = [
                    { label: 'Program Pathway Name', fieldName: 'programPathwayName', type: 'text' },
                    { label: 'Academic Term', fieldName: 'Academic_Term_Name__c', type: 'text' },
                    { label: 'Start Date', fieldName: 'Start_Date__c', type: 'date-local', editable: true },
                    { label: 'End Date', fieldName: 'End_Date__c', type: 'date-local', editable: true },
                    { label: 'Is Active', fieldName: 'Is_Active__c', type: 'boolean' },
                    { label: 'No of Pathway Connections', fieldName: 'No_of_Pathway_Connections__c', type: 'number' },
                    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date-local' }
                ];


                this.showActionButtons = false;
                this.showDataTable = true;
                // Reset draft values for new mode
                this.draftValues = [];
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }


    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows.map(row => row.key);
    }


    handleCellChange(event) {
        // Merge new draft values with existing ones to prevent data loss
        const newDraftValues = event.detail.draftValues;
        
        // Create a map of existing draft values by key
        const existingDraftMap = new Map();
        this.draftValues.forEach(draft => {
            existingDraftMap.set(draft.key, draft);
        });
        
        // Merge new values with existing ones
        newDraftValues.forEach(newDraft => {
            const existingDraft = existingDraftMap.get(newDraft.key);
            if (existingDraft) {
                // Merge the values, keeping existing values and adding new ones
                Object.keys(newDraft).forEach(field => {
                    if (field !== 'key') {
                        existingDraft[field] = newDraft[field];
                    }
                });
            } else {
                // Add new draft if it doesn't exist
                existingDraftMap.set(newDraft.key, newDraft);
            }
        });
        
        // Convert map back to array
        this.draftValues = Array.from(existingDraftMap.values());
    }


    get isSaveDisabled() {
        return this.selectedRows.length === 0;
    }


    formatDateForDisplay(dateValue) {
        if (!dateValue) return '';
        
        try {
            let date;
            if (typeof dateValue === 'string') {
                date = new Date(dateValue);
            } else {
                date = dateValue;
            }
            
            if (isNaN(date.getTime())) {
                return '';
            }
            
            // Format as YYYY-MM-DD for date-local type
            return date.toISOString().split('T');
        } catch (error) {
            console.error('Error formatting date:', error);
            return '';
        }
    }


    handleSaveClick() {
        if (this.selectedRows.length === 0) {
            this.showToast('Warning', 'Please select at least one record.', 'warning');
            return;
        }


        this.isLoading = true;
        this.error = null;


        if (this.isCreateMode) {
            // Filter draft values for selected rows only
            const selectedDrafts = this.draftValues.filter(draft => 
                this.selectedRows.includes(draft.key)
            );


            console.log('Selected Rows:', this.selectedRows);
            console.log('All Draft Values:', this.draftValues);
            console.log('Selected Drafts:', selectedDrafts);
            console.log('Enrollment Data:', this.enrollmentData);


            // Validate required fields (removed Academic Term validation)
            const invalidRecords = selectedDrafts.filter(draft => {
                return !draft.Start_Date__c || !draft.End_Date__c;
            });


            if (invalidRecords.length > 0) {
                this.showToast('Error', 'Please fill in Start Date and End Date for selected records.', 'error');
                this.isLoading = false;
                return;
            }


            // Validate date logic
            const dateErrors = selectedDrafts.filter(draft => {
                const startDate = new Date(draft.Start_Date__c);
                const endDate = new Date(draft.End_Date__c);
                return startDate > endDate;
            });


            if (dateErrors.length > 0) {
                this.showToast('Error', 'Start Date cannot be after End Date.', 'error');
                this.isLoading = false;
                return;
            }


            // Prepare records for creation (removed Academic_Term__c)
            const recordsToCreate = selectedDrafts.map(draft => {
                // Find the original enrollment data to get the Program_Pathway__c value
                const originalRecord = this.enrollmentData.find(record => record.key === draft.key);
                
                console.log('Draft:', draft);
                console.log('Original Record:', originalRecord);
                console.log('Program_Pathway__c value:', originalRecord?.Program_Pathway__c);
                console.log('programPathwayId value:', originalRecord?.programPathwayId);
                
                const record = {
                    Start_Date__c: draft.Start_Date__c,
                    End_Date__c: draft.End_Date__c,
                    Is_Active__c: draft.Is_Active__c !== undefined ? draft.Is_Active__c : true,
                    No_of_Pathway_Connections__c: draft.No_of_Pathway_Connections__c || 0,
                    Program_Pathway__c: originalRecord?.Program_Pathway__c || originalRecord?.programPathwayId
                };
                
                console.log('Final record to create:', record);
                return record;
            });


            createPathwayEnrollments({ enrollments: recordsToCreate })
                .then(result => {
                    this.showToast('Success', `${result.length} enrollment(s) created successfully.`, 'success');
                    // Refresh the data
                    this.handleCreateClick();
                })
                .catch(error => {
                    this.handleError(error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else if (this.isUpdateMode) {
            // Filter draft values for selected rows only
            const selectedDrafts = this.draftValues.filter(draft => 
                this.selectedRows.includes(draft.key)
            );


            if (selectedDrafts.length === 0) {
                this.showToast('Warning', 'No changes detected in selected records.', 'warning');
                this.isLoading = false;
                return;
            }


            // Validate date logic
            const dateErrors = selectedDrafts.filter(draft => {
                if (draft.Start_Date__c && draft.End_Date__c) {
                    const startDate = new Date(draft.Start_Date__c);
                    const endDate = new Date(draft.End_Date__c);
                    return startDate > endDate;
                }
                return false;
            });


            if (dateErrors.length > 0) {
                this.showToast('Error', 'Start Date cannot be after End Date.', 'error');
                this.isLoading = false;
                return;
            }


            // Prepare records for update (only Start_Date__c and End_Date__c)
            const recordsToUpdate = selectedDrafts.map(draft => {
                return {
                    Id: draft.key,
                    Start_Date__c: draft.Start_Date__c,
                    End_Date__c: draft.End_Date__c
                };
            });


            updatePathwayEnrollments({ enrollments: recordsToUpdate })
                .then(result => {
                    this.showToast('Success', `${result.length} enrollment(s) updated successfully.`, 'success');
                    // Refresh the data
                    this.handleUpdateClick();
                })
                .catch(error => {
                    this.handleError(error);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }


    handleCancelClick() {
        this.showActionButtons = true;
        this.showDataTable = false;
        this.enrollmentData = [];
        this.selectedRows = [];
        this.draftValues = [];
        this.isCreateMode = false;
        this.isUpdateMode = false;
    }


    handleError(error) {
        const errorMsg = error.body && error.body.message ? error.body.message : 'An unknown error occurred';
        this.error = errorMsg;
        this.showToast('Error', errorMsg, 'error');
    }


    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}