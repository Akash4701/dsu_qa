import { LightningElement, track, wire, api } from 'lwc';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAcademicPrograms from '@salesforce/apex/AcademicCalenderScreenController.getAcademicPrograms';
import getProgramPlans from '@salesforce/apex/AcademicCalenderScreenController.getProgramPlans';
import getTerms from '@salesforce/apex/AcademicCalenderScreenController.getTerms';
import getTermActivities from '@salesforce/apex/AcademicCalenderScreenController.getTermActivities';
import updateTermDates from '@salesforce/apex/AcademicCalenderScreenController.updateTermDates';
import addActivity from '@salesforce/apex/AcademicCalenderScreenController.addActivity';
import updateActivity from '@salesforce/apex/AcademicCalenderScreenController.updateActivity';
import ACADEMIC_CALENDAR_OBJECT from '@salesforce/schema/Academic_Calendar__c';
import TYPE_OF_ACTIVITY_FIELD from '@salesforce/schema/Academic_Calendar__c.Type_of_Activity__c';
import DURATION_TYPE_FIELD from '@salesforce/schema/Academic_Calendar__c.Duration_Type__c';
import deleteActivity from '@salesforce/apex/AcademicCalenderScreenController.deleteActivity';
import LightningConfirm from "lightning/confirm";

// NEW IMPORTS FOR CUSTOM METADATA
import getAcademicConfiguration from '@salesforce/apex/AcademicConfigController.getAcademicConfiguration';
import getAllConfigurations from '@salesforce/apex/AcademicConfigController.getAllConfigurations';
import parseWorkingDays from '@salesforce/apex/AcademicConfigController.parseWorkingDays';

export default class AcademicProgramPlan extends LightningElement {
    currentTab = 'academic';
    
    // Dropdown selections
    @track selectedAcademicProgram; 
    @track selectedProgramPlan;
    
    // Data containers
    @track academicPrograms = [];
    @track programPlans = [];
    @track workingDays = '';
    @track terms = [];
    @track expandedTerms = new Set();

    // For lightning-datatable
    @track editedActivityDraftValues = [];

    // Modal state
    @track isModalOpen = false;
    @track selectedTermIdForActivity;

    // New activity
    @track newActivity = {
        typeOfActivity: '',
        durationType: '',
        numberOfWeeks: null,
        description: '',
        startDate: '',
        endDate: ''
    };

    // Picklist options for Type of Activity
    @track typeOfActivityOptions = [];
    // Picklist options for Duration Type
    @track durationTypeOptions = [];

    // Loading states
    @track isLoading = false;
    @track isSaving = false;

    // EXISTING CHECKBOX PROPERTIES (kept for backward compatibility)
    @track localRequirementMode;
    _localRequirementMode;
    @track isCheckboxChecked = false;
    _isCheckboxChecked = false;

    // NEW PROPERTIES FOR CUSTOM METADATA
    @track masterConfiguration = null;
    @track configurationOptions = [];
    @track selectedInstitutionType = 'College'; // Default
    @track isConfigurationLoaded = false;
    @track masterRequirementMode = false; // Master control from metadata
    @track useCustomMetadata = true; // Toggle to enable/disable custom metadata

    // Validation
    preventSave = false;
    @track isEditMode = false;
    
    // Datatable columns configuration
    @track columns = [
        { label: 'Week No.', fieldName: 'weekNo', type: 'text' },
        { 
            label: 'Activity',
            fieldName: 'typeOfActivity',
            type: 'text'
        },
        { label: 'Description', fieldName: 'description', type: 'text' },
        {
            label: 'Duration Type',
            fieldName: 'durationType',
            type: 'text'
        },
        { label: 'Duration', fieldName: 'duration', type: 'number' },
        {
            label: 'Start Date',
            fieldName: 'startDateFormatted',
            type: 'text'
        },
        {
            label: 'End Date',
            fieldName: 'endDateFormatted',
            type: 'text'
        },
        {
            type: 'action',
            typeAttributes: {
                rowActions: [
                    { label: 'Edit', name: 'edit' },
                    { label: 'Delete', name: 'delete' }
                ]
            }
        }
    ];

    // NEW: Property for real-time validation feedback
@track activityValidationMessage = '';

// NEW: Getter for selected term information in modal
get selectedTermForActivity() {
    if (!this.selectedTermIdForActivity) {
        return null;
    }
    
    const term = this.terms.find(t => t.id === this.selectedTermIdForActivity);
    if (!term) {
        return null;
    }
    
    return {
        ...term,
        startDateFormatted: this.formatDateDisplay(term.startDate),
        endDateFormatted: this.formatDateDisplay(term.endDate)
    };
}

    /**
 * NEW: Validate activity against term boundaries
 * @param {Object} activity - The activity object to validate
 * @param {String} termId - The term ID
 * @return {Object} Validation result with isValid and errorMessage
 */

    validateActivityAgainstTerm(activity, termId) {
    // Find the term
    const term = this.terms.find(t => t.id === termId);
    
    if (!term) {
        return {
            isValid: false,
            errorMessage: 'Term not found'
        };
    }

    // Check if term has required dates
    if (!term.startDate || !term.endDate || !term.termDuration) {
        return {
            isValid: false,
            errorMessage: 'Term must have complete date information before adding activities'
        };
    }

    const errors = [];
    
    // Convert dates for comparison
    const termStartDate = new Date(term.startDate);
    const termEndDate = new Date(term.endDate);
    const activityStartDate = new Date(activity.startDate);
    const activityEndDate = new Date(activity.endDate);
    
    // Validate activity start date is within term bounds
    if (activityStartDate < termStartDate) {
        errors.push(`Activity start date (${this.formatDateForDisplay(activity.startDate)}) cannot be before term start date (${this.formatDateForDisplay(term.startDate)})`);
    }
    
    // Validate activity end date is within term bounds
    if (activityEndDate > termEndDate) {
        errors.push(`Activity end date (${this.formatDateForDisplay(activity.endDate)}) cannot be after term end date (${this.formatDateForDisplay(term.endDate)})`);
    }
    
    // Validate activity start date is within term bounds
    if (activityStartDate > termEndDate) {
        errors.push(`Activity start date (${this.formatDateForDisplay(activity.startDate)}) cannot be after term end date (${this.formatDateForDisplay(term.endDate)})`);
    }
    
    // Validate activity end date is not before term start
    if (activityEndDate < termStartDate) {
        errors.push(`Activity end date (${this.formatDateForDisplay(activity.endDate)}) cannot be before term start date (${this.formatDateForDisplay(term.startDate)})`);
    }

    // Additional validation: Check if activity duration is reasonable within term duration
    if (activity.durationType === 'Weeks' && activity.numberOfWeeks) {
        const activityWeeks = parseInt(activity.numberOfWeeks);
        const termWeeks = parseInt(term.termDuration);
        
        if (activityWeeks > termWeeks) {
            errors.push(`Activity duration (${activityWeeks} weeks) cannot exceed term duration (${termWeeks} weeks)`);
        }
    }

    // Calculate actual activity duration in days and compare with term
    const activityDurationDays = Math.ceil((activityEndDate - activityStartDate) / (1000 * 60 * 60 * 24)) + 1;
    const termDurationDays = Math.ceil((termEndDate - termStartDate) / (1000 * 60 * 60 * 24)) + 1;
    
    if (activityDurationDays > termDurationDays) {
        errors.push(`Activity spans ${activityDurationDays} days which exceeds the term duration of ${termDurationDays} days`);
    }

    return {
        isValid: errors.length === 0,
        errorMessage: errors.join('\n')
    };
}

checkActivityOverlap(newActivity, termId) {
    const term = this.terms.find(t => t.id === termId);
    
    if (!term || !term.activities) {
        return { isValid: true, errorMessage: '' };
    }

    const newStartDate = new Date(newActivity.startDate);
    const newEndDate = new Date(newActivity.endDate);
    
    const overlappingActivities = term.activities.filter(activity => {
        // Skip if this is the same activity being edited
        if (this.isEditMode && activity.id === newActivity.id) {
            return false;
        }
        
        const activityStartDate = new Date(activity.startDate);
        const activityEndDate = new Date(activity.endDate);
        
        // Check for overlap: new activity starts before existing ends AND new activity ends after existing starts
        return (newStartDate <= activityEndDate && newEndDate >= activityStartDate);
    });

    if (overlappingActivities.length > 0) {
        const overlapNames = overlappingActivities.map(a => a.typeOfActivity).join(', ');
        return {
            isValid: false,
            errorMessage: `This activity overlaps with existing activities: ${overlapNames}. Please verify the dates.`
        };
    }

    return { isValid: true, errorMessage: '' };
}

    // EXISTING API PROPERTIES (kept for backward compatibility)
    @api
    get localRequirementMode() {
        console.log('get localRequirementMode called:', this._localRequirementMode);
        return this._localRequirementMode;
    }

    @api get isCheckboxChecked() {
        return this._isCheckboxChecked;
    }

    set isCheckboxChecked(value) {
        this._isCheckboxChecked = value;
        this.handleCheckboxChange(value);
    }

    get modalTitle() {
        return this.isEditMode ? 'Edit Activity' : 'Add New Activity';
    }

    // Wire adapter to fetch picklist values for Type_of_Activity__c
    @wire(getObjectInfo, { objectApiName: ACADEMIC_CALENDAR_OBJECT })
    academicCalendarObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$academicCalendarObjectInfo.data.defaultRecordTypeId',
        fieldApiName: TYPE_OF_ACTIVITY_FIELD
    })
    typeOfActivityPicklistValues({ error, data }) {
        if (data) {
            this.typeOfActivityOptions = data.values.map(value => ({
                label: value.label,
                value: value.value
            }));
        } else if (error) {
            this.handleError(error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$academicCalendarObjectInfo.data.defaultRecordTypeId',
        fieldApiName: DURATION_TYPE_FIELD
    })
    durationTypePicklistValues({ error, data }) {
        if (data) {
            this.durationTypeOptions = data.values.map(value => ({
                label: value.label,
                value: value.value
            }));
        } else if (error) {
            this.handleError(error);
        }
    }

    /**
     * UPDATED: connectedCallback with Custom Metadata integration
     */
    async connectedCallback() {
        try {
            this.isLoading = true;
            
            // Try to load custom metadata configuration first
            if (this.useCustomMetadata) {
                await this.loadMasterConfiguration();
            }
            
            // If custom metadata failed or disabled, maintain existing behavior
            if (!this.isConfigurationLoaded) {
                this.initializeExistingBehavior();
            }
            
            // Load academic programs (existing functionality)
            this.loadAcademicPrograms();
            
            this.isLoading = false;
        } catch (error) {
            console.error('Error in connectedCallback:', error);
            // Fallback to existing behavior if custom metadata fails
            this.initializeExistingBehavior();
            this.loadAcademicPrograms();
            this.isLoading = false;
        }
    }

    /**
     * NEW: Load master configuration from Custom Metadata
     */
    async loadMasterConfiguration() {
        try {
            // Load all configurations first
            const configs = await getAllConfigurations();
            this.configurationOptions = configs.map(config => ({
                label: `${config.Institution_Type__c} - ${config.Label}`,
                value: config.Institution_Type__c,
                config: config
            }));

            // Load specific configuration
            this.masterConfiguration = await getAcademicConfiguration({ 
                institutionType: this.selectedInstitutionType 
            });
            
            if (this.masterConfiguration) {
                // Apply master configuration
                this.masterRequirementMode = this.masterConfiguration.Requirement_Mode__c;
                
                // Sync with existing properties
                this._localRequirementMode = this.masterRequirementMode;
                this._isCheckboxChecked = this.masterRequirementMode;
                
                this.isConfigurationLoaded = true;
                
                console.log('Master Configuration Loaded:', {
                    institutionType: this.selectedInstitutionType,
                    masterRequirementMode: this.masterRequirementMode,
                    localRequirementMode: this._localRequirementMode,
                    isCheckboxChecked: this._isCheckboxChecked
                });
            }
        } catch (error) {
            console.error('Error loading master configuration:', error);
            this.isConfigurationLoaded = false;
            throw error;
        }
    }

    /**
     * NEW: Initialize existing behavior when custom metadata is not available
     */
    initializeExistingBehavior() {
        // Keep existing default behavior
        this.masterRequirementMode = false;
        this._localRequirementMode = false;
        this._isCheckboxChecked = false;
        
        console.log('Initialized with existing behavior (no custom metadata)');
    }

    /**
     * NEW: Optional method to allow switching institution types
     */
    async handleInstitutionTypeChange(institutionType) {
        this.selectedInstitutionType = institutionType;
        
        try {
            this.isLoading = true;
            await this.loadMasterConfiguration();
            this.isLoading = false;
            
            this.showToast('Success', `Configuration switched to ${this.selectedInstitutionType}`, 'success');
        } catch (error) {
            this.isLoading = false;
            this.showToast('Error', 'Failed to switch configuration: ' + error.message, 'error');
        }
    }

    /**
     * UPDATED: handleCheckboxChange with Custom Metadata awareness
     */
    handleCheckboxChange(isChecked) {
        this._isCheckboxChecked = isChecked;
        this._localRequirementMode = isChecked;
        
        console.log('Checkbox value received in Child:', isChecked);
        console.log('Master configuration loaded:', this.isConfigurationLoaded);
        
        // If custom metadata is loaded, show info about manual override
        if (this.isConfigurationLoaded && isChecked !== this.masterRequirementMode) {
            this.showToast('Info', 'Manual override applied to master configuration', 'info');
        }

        // Apply logic based on checkbox state
        if (isChecked) {
            console.log('Strict mode enabled');
            this.enableStrictMode();
        } else {
            console.log('Flexible mode enabled');
            this.enableFlexibleMode();
        }
    }

    /**
     * NEW: Enable strict mode functionality
     */
    enableStrictMode() {
        // Strict mode behaviors can be added here
        console.log('Strict mode behaviors applied');
    }

    /**
     * NEW: Enable flexible mode functionality
     */
    enableFlexibleMode() {
        // Flexible mode behaviors can be added here
        console.log('Flexible mode behaviors applied');
    }

    // ALL EXISTING METHODS BELOW (kept unchanged with minimal updates for master config awareness)

    toggleTermExpansion(event) {
        const termId = event.currentTarget.dataset.termId;
        const termIndex = this.terms.findIndex(term => term.id === termId);
        
        if (termIndex !== -1) {
            const termClone = {...this.terms[termIndex]};
            termClone.isExpanded = !termClone.isExpanded;
            
            // Update icon based on expanded state
            if (termClone.isExpanded) {
                termClone.expandIconName = 'utility:chevrondown';
                termClone.expandAltText = 'Collapse';
            } else {
                termClone.expandIconName = 'utility:chevronright';
                termClone.expandAltText = 'Expand';
            }
            
            // Format activities if we're expanding and activities exist
            if (termClone.isExpanded && termClone.activities && termClone.activities.length > 0) {
                termClone.activitiesFormatted = this.formatActivitiesForDatatable(termClone.activities);
            }
            
            // Update the term in the array
            this.terms = [
                ...this.terms.slice(0, termIndex),
                termClone,
                ...this.terms.slice(termIndex + 1)
            ];
        }
    }

    formatActivitiesForDatatable(activities) {
        return activities.map(activity => {
            // Format dates as strings for display
            const startDateFormatted = activity.startDate ? 
                this.formatDateDisplay(activity.startDate) : '';
                
            const endDateFormatted = activity.endDate ? 
                this.formatDateDisplay(activity.endDate) : '';

            return {
                ...activity,
                startDateFormatted: startDateFormatted,
                endDateFormatted: endDateFormatted
            };
        });
    }

    get endDateFormatHint() {
        if (this.newActivity && this.newActivity.endDate) {
            return this.formatDateDisplay(this.newActivity.endDate);
        }
        return 'DD-MMM-YYYY';
    }

    formatDateDisplay(dateInput) {
        if (!dateInput) return '';
        
        try {
            // If it's already a string in YYYY-MM-DD format, parse it
            const dateObj = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;
            
            // Check for valid date
            if (isNaN(dateObj.getTime())) return '';
            
            // Format as DD-MMM-YYYY (e.g., 01-Jan-2024)
            const day = String(dateObj.getDate()).padStart(2, '0');
            const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            const month = monthNames[dateObj.getMonth()];
            const year = dateObj.getFullYear();
            
            return `${day}-${month}-${year}`;
        } catch (error) {
            console.error('Error formatting date:', error);
            return '';
        }
    }

    /**
     * NEW: Format date for user-friendly display in notifications
     * @param {String} dateString - Date in YYYY-MM-DD format
     * @return {String} Formatted date for display
     */
    formatDateForDisplay(dateString) {
        if (!dateString) return '';
        
        try {
            const dateObj = new Date(dateString);
            return dateObj.toLocaleDateString('en-US', {
                weekday: 'short',
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            });
        } catch (error) {
            console.error('Error formatting date for display:', error);
            return dateString;
        }
    }

    loadAcademicPrograms() {
        this.isLoading = true;
        getAcademicPrograms()
            .then(result => {
                this.academicPrograms = result.map(program => {
                    return { label: program.Name, value: program.Id };
                });
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }

    handleAcademicProgramChange(event) {
        this.selectedAcademicProgram = event.detail.value;
        this.selectedProgramPlan = null;
        this.workingDays = '';
        this.terms = [];
        
        if (this.selectedAcademicProgram) {
            this.loadProgramPlans();
        }
        console.log(this.selectedAcademicProgram);
    }

    loadProgramPlans() {
        this.isLoading = true;
        getProgramPlans({ academicProgramId: this.selectedAcademicProgram })
            .then(result => {
                this.programPlans = result.map(plan => {
                    return { label: plan.Name, value: plan.Id };
                });
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }

    handleProgramPlanChange(event) {
        this.selectedProgramPlan = event.detail.value;
        if (this.selectedProgramPlan) {
            this.loadProgramPlanDetails();
        }
        console.log(this.selectedProgramPlan);
    }

    /**
     * UPDATED: loadProgramPlanDetails with error state initialization
     */
    loadProgramPlanDetails() {
        this.isLoading = true;
        
        getTerms({ programPlanId: this.selectedProgramPlan })
            .then(result => {
                // Set working days
                if (result.programPlanDetail) {
                    this.workingDays = result.programPlanDetail.Working_Days__c || '';
                }
                
                // Process terms with error state initialization
                this.terms = result.terms.map(term => {
                    return {
                        id: term.Id,
                        name: term.Name,
                        termDuration: term.Term_Duration__c || '',
                        startDate: term.hed__Start_Date__c,
                        endDate: term.hed__End_Date__c,
                        activities: [],
                        isExpanded: false,
                        expandIconName: 'utility:chevronright',
                        expandAltText: 'Expand',
                        // Add these fields for tracking changes
                        originalStartDate: term.hed__Start_Date__c,
                        originalEndDate: term.hed__End_Date__c,
                        originalTermDuration: term.Term_Duration__c,
                        isDirty: false,
                        // NEW: Error state tracking
                        hasStartDateError: false,
                        hasEndDateError: false,
                        hasDurationError: false
                    };
                });
                
                // Load activities for each term
                this.terms.forEach(term => {
                    this.loadTermActivities(term.id);
                });
                
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    /**
     * UPDATED: handleDateChange method with real-time validation and auto-calculation
     */
    handleDateChange(event) {
        const fieldName = event.target.dataset.field;
        const termId = event.currentTarget.dataset.termId;
        const newValue = event.target.value;
        const termIndex = this.terms.findIndex(term => term.id === termId);

        if (termIndex === -1) return;

        const termClone = { ...this.terms[termIndex] };

        // Clear existing errors for this field
        if (fieldName === 'startDate') {
            termClone.hasStartDateError = false;
        } else if (fieldName === 'endDate') {
            termClone.hasEndDateError = false;
        } else if (fieldName === 'termDuration') {
            termClone.hasDurationError = false;
        }

        if (fieldName === 'startDate') {
            // Handle start date change
            termClone.startDate = newValue;
            
            // Validate required field
            if (!newValue) {
                termClone.hasStartDateError = true;
                this.preventSave = true;
            } else {
                const startDate = new Date(newValue);
                const today = new Date();
                const todayOnly = new Date(today.getFullYear(), today.getMonth(), today.getDate());

                if (startDate < todayOnly) {
                    this.preventSave = true;
                    this.showToast('Error', 'Start date cannot be in the past.', 'error');
                    termClone.startDate = null;
                    termClone.hasStartDateError = true;
                } else {
                    this.preventSave = false;
                    termClone.hasStartDateError = false;
                    
                    // AUTO-CALCULATE END DATE: If start date and duration are available
                    if (termClone.termDuration && parseInt(termClone.termDuration) > 0) {
                        const calculatedEndDate = this.calculateTermEndDate(
                            termClone.startDate, 
                            parseInt(termClone.termDuration), 
                            this.workingDays
                        );
                        if (calculatedEndDate) {
                            termClone.endDate = calculatedEndDate;
                            termClone.hasEndDateError = false;
                            console.log('Auto-calculated end date from start date:', calculatedEndDate);
                            
                            // Show notification about auto-calculation
                            this.showToast('Info', 
                                `End date auto-calculated: ${this.formatDateForDisplay(calculatedEndDate)}`, 
                                'info'
                            );
                        }
                    }
                }
            }

            // Mark as dirty only if value changed
            if (termClone.startDate !== termClone.originalStartDate) {
                termClone.isDirty = true;
            }

        } else if (fieldName === 'endDate') {
            // Handle end date change
            termClone.endDate = newValue;
            
            // Validate required field
            if (!newValue) {
                termClone.hasEndDateError = true;
                this.preventSave = true;
            } else {
                const endDate = new Date(newValue);
                const startDate = new Date(termClone.startDate);

                if (termClone.startDate && endDate <= startDate) {
                    this.preventSave = true;
                    this.showToast('Error', 'End date must be after start date.', 'error');
                    termClone.endDate = null;
                    termClone.hasEndDateError = true;
                } else {
                    this.preventSave = false;
                    termClone.hasEndDateError = false;
                }
            }

            // Mark as dirty only if value changed
            if (termClone.endDate !== termClone.originalEndDate) {
                termClone.isDirty = true;
            }

        } else if (fieldName === 'termDuration') {
            // Handle term duration change
            const newDuration = parseInt(newValue);
            
            // Validate required field and value
            if (!newValue || isNaN(newDuration) || newDuration <= 0) {
                termClone.hasDurationError = true;
                this.preventSave = true;
                if (!newValue) {
                    this.showToast('Error', 'Semester duration is required.', 'error');
                } else {
                    this.showToast('Error', 'Please enter a valid number of weeks (greater than 0).', 'error');
                }
            } else {
                termClone.termDuration = newDuration;
                termClone.hasDurationError = false;
                this.preventSave = false;

                // AUTO-CALCULATE END DATE: If start date and duration are available
                if (termClone.startDate) {
                    const calculatedEndDate = this.calculateTermEndDate(
                        termClone.startDate, 
                        newDuration, 
                        this.workingDays
                    );
                    if (calculatedEndDate) {
                        termClone.endDate = calculatedEndDate;
                        termClone.hasEndDateError = false;
                        console.log('Auto-calculated end date from duration:', calculatedEndDate);
                        
                        // Show notification about auto-calculation
                        this.showToast('Info', 
                            `End date auto-calculated: ${this.formatDateForDisplay(calculatedEndDate)}`, 
                            'info'
                        );
                    }
                }

                // Mark as dirty only if value changed
                if (termClone.termDuration !== termClone.originalTermDuration) {
                    termClone.isDirty = true;
                } else {
                    // Still check other fields for dirtiness
                    termClone.isDirty =
                        termClone.startDate !== termClone.originalStartDate ||
                        termClone.endDate !== termClone.originalEndDate;
                }
            }
        }

        this.terms = [
            ...this.terms.slice(0, termIndex),
            termClone,
            ...this.terms.slice(termIndex + 1)
        ];
    }

    /**
 * Calculate the number of working weeks between two dates
 */
calculateWorkingWeeksBetween(startDateStr, endDateStr) {
    const startDate = new Date(startDateStr);
    const endDate = new Date(endDateStr);

    if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) return 0;

    const workingDayIndices = this.parseWorkingDays(this.workingDays);
    let workingDaysCount = 0;
    let currentDate = new Date(startDate);

    while (currentDate <= endDate) {
        const dayOfWeek = currentDate.getDay();
        if (workingDayIndices.includes(dayOfWeek)) {
            workingDaysCount++;
        }
        currentDate.setDate(currentDate.getDate() + 1);
    }

    const workingDaysPerWeek = workingDayIndices.length || 5;
    return Math.ceil(workingDaysCount / workingDaysPerWeek);
}

    /**
     * NEW: Calculate end date for a term based on start date and duration in weeks
     * @param {String} startDate - The start date in YYYY-MM-DD format
     * @param {Integer} durationWeeks - Duration in weeks
     * @param {String} workingDaysString - Working days configuration
     * @return {String} Calculated end date in YYYY-MM-DD format
     */
    calculateTermEndDate(startDate, durationWeeks, workingDaysString) {
        if (!startDate || !durationWeeks || durationWeeks <= 0) {
            return null;
        }
        
        console.log('Calculating term end date with:');
        console.log('- Start date:', startDate);
        console.log('- Duration weeks:', durationWeeks);
        console.log('- Working days:', workingDaysString);
        
        // Create date object from start date
        const startDateObj = new Date(startDate);
        
        // Parse working days
        const workingDayIndices = this.parseWorkingDays(workingDaysString);
        console.log('Working day indices:', workingDayIndices);
        
        // Calculate total working days needed
        const workingDaysPerWeek = workingDayIndices.length > 0 ? workingDayIndices.length : 5;
        const totalWorkingDaysNeeded = workingDaysPerWeek * durationWeeks;
        
        console.log('Working days per week:', workingDaysPerWeek);
        console.log('Total working days needed:', totalWorkingDaysNeeded);
        
        // Start counting from the start date
        let currentDate = new Date(startDateObj);
        let workingDaysFound = 0;
        
        // Check if start date is a working day
        const startDayOfWeek = startDateObj.getDay();
        if (workingDayIndices.includes(startDayOfWeek)) {
            workingDaysFound = 1;
        }
        
        // Continue until we reach the required number of working days
        while (workingDaysFound < totalWorkingDaysNeeded) {
            // Move to next day
            currentDate.setDate(currentDate.getDate() + 1);
            const dayOfWeek = currentDate.getDay();
            
            // Check if this is a working day
            if (workingDayIndices.includes(dayOfWeek)) {
                workingDaysFound++;
            }
        }
        
        const calculatedEndDate = this.formatDate(currentDate);
        console.log('Calculated end date:', calculatedEndDate);
        
        return calculatedEndDate;
    }

    // calculateTotalProgramWeeks() {
    //     const sortedTerms = [...this.terms].sort((a, b) => new Date(a.startDate) - new Date(b.startDate));
    //     const firstStartDate = new Date(sortedTerms[0]?.startDate);
    //     const lastEndDate = new Date(sortedTerms[sortedTerms.length - 1]?.endDate);

    //     if (!firstStartDate || !lastEndDate) return 0;

    //     const totalDays = Math.floor((lastEndDate - firstStartDate) / (1000 * 60 * 60 * 24)) + 1;
    //     const workingDayIndices = this.parseWorkingDays(this.workingDays);
    //     const workingDaysPerWeek = workingDayIndices.length || 5;

    //     return Math.ceil((totalDays * workingDayIndices.length) / 7 / workingDaysPerWeek);
    // }

    // /**
    //  * UPDATED: saveTermChanges method with comprehensive validation
    //  */
    // saveTermChanges(event) {
    //     const termId = event.currentTarget.dataset.termId;
    //     const termIndex = this.terms.findIndex(term => term.id === termId);

    //     if (termIndex === -1) {
    //         this.showToast('Error', 'Term not found', 'error');
    //         return;
    //     }

    //     const term = this.terms[termIndex];

    //     // COMPREHENSIVE VALIDATION
    //     const validationResult = this.validateTermFields(term, termIndex);
    //     if (!validationResult.isValid) {
    //         this.showToast('Error', validationResult.errorMessage, 'error');
    //         return;
    //     }

    //     if (!term.isDirty) return; // No change to save

    //     // Validate the sequence of dates across all terms
    //     if (!this.validateTermDateSequence()) {
    //         this.showToast('Error', 'End date of a term cannot be after the start date of the next term.', 'error');
    //         return;
    //     }   

    //     // If preventSave flag is set, stop execution
    //     if (this.preventSave) {
    //         this.showToast('Error', 'Please fix all validation errors before saving', 'error');
    //         return;
    //     }

    //     // Calculate total expected weeks from overall date range
    //     const totalExpectedWeeks = this.calculateTotalProgramWeeks();

    //     // Sum of all current term durations
    //     const totalEnteredWeeks = this.terms.reduce((sum, t) => {
    //         const duration = parseInt(t.termDuration);
    //         return sum + (isNaN(duration) ? 0 : duration);
    //     }, 0);

    //     // Compare total weeks
    //     if (totalEnteredWeeks !== totalExpectedWeeks) {
    //         this.showToast(
    //             'Validation Failed',
    //             `Sum of Term Durations (${totalEnteredWeeks} weeks) does not match total program duration (${totalExpectedWeeks} weeks).`,
    //             'error'
    //         );
    //         return;
    //     }

    //     if (term.isDirty) {
    //         this.isSaving = true;

    //         updateTermDates({ 
    //             termId: term.id, 
    //             startDate: term.startDate, 
    //             endDate: term.endDate,
    //             numberOfWeeks: term.termDuration
    //         })
    //         .then(() => {
    //             const updatedTerm = {
    //                 ...term,
    //                 originalStartDate: term.startDate,
    //                 originalEndDate: term.endDate,
    //                 originalTermDuration: term.termDuration,
    //                 isDirty: false,
    //                 // Clear all error states after successful save
    //                 hasStartDateError: false,
    //                 hasEndDateError: false,
    //                 hasDurationError: false
    //             };

    //             this.terms = [
    //                 ...this.terms.slice(0, termIndex),
    //                 updatedTerm,
    //                 ...this.terms.slice(termIndex + 1)
    //             ];

    //             this.isSaving = false;

    //             this.dispatchEvent(
    //                 new ShowToastEvent({
    //                     title: 'Success',
    //                     message: 'Term dates updated successfully',
    //                     variant: 'success'
    //                 })
    //             );
    //         })
    //         .catch(error => {
    //             this.handleError(error);
    //             this.isSaving = false;
    //         });
    //     }
    // }

     // FIXED: calculateTotalProgramWeeks method
calculateTotalProgramWeeks() {
    // Filter out terms that don't have both start and end dates
    const completeTerms = this.terms.filter(term => 
        term.startDate && 
        term.endDate && 
        term.startDate.trim() !== '' && 
        term.endDate.trim() !== ''
    );
    
    // If no complete terms, return 0
    if (completeTerms.length === 0) {
        return 0;
    }
    
    // If not all terms are complete, we can't calculate total program weeks yet
    if (completeTerms.length !== this.terms.length) {
        console.log('Not all terms have complete date information');
        return 0; // Return 0 to indicate incomplete data
    }
    
    try {
        const sortedTerms = [...completeTerms].sort((a, b) => new Date(a.startDate) - new Date(b.startDate));
        const firstStartDate = new Date(sortedTerms[0].startDate);
        const lastEndDate = new Date(sortedTerms[sortedTerms.length - 1].endDate);

        // Validate dates
        if (isNaN(firstStartDate.getTime()) || isNaN(lastEndDate.getTime())) {
            console.error('Invalid dates found in terms');
            return 0;
        }

        if (lastEndDate <= firstStartDate) {
            console.error('Last end date is not after first start date');
            return 0;
        }

        const totalDays = Math.floor((lastEndDate - firstStartDate) / (1000 * 60 * 60 * 24)) + 1;
        const workingDayIndices = this.parseWorkingDays(this.workingDays);
        const workingDaysPerWeek = workingDayIndices.length || 5;

        // FIXED CALCULATION: Calculate total working days, then convert to weeks
        let totalWorkingDays = 0;
        let currentDate = new Date(firstStartDate);
        
        while (currentDate <= lastEndDate) {
            const dayOfWeek = currentDate.getDay();
            if (workingDayIndices.includes(dayOfWeek)) {
                totalWorkingDays++;
            }
            currentDate.setDate(currentDate.getDate() + 1);
        }
        
        const totalWeeks = Math.ceil(totalWorkingDays / workingDaysPerWeek);
        
        console.log('Total program calculation:', {
            firstStartDate: firstStartDate.toDateString(),
            lastEndDate: lastEndDate.toDateString(),
            totalDays,
            totalWorkingDays,
            workingDaysPerWeek,
            totalWeeks
        });
        
        return totalWeeks;
    } catch (error) {
        console.error('Error calculating total program weeks:', error);
        return 0;
    }
}

// UPDATED: saveTermChanges method with improved validation
/**
 * FIXED: saveTermChanges method with proper parameter handling
 */
saveTermChanges(event) {
    const termId = event.currentTarget.dataset.termId;
    const termIndex = this.terms.findIndex(term => term.id === termId);

    if (termIndex === -1) {
        this.showToast('Error', 'Term not found', 'error');
        return;
    }

    const term = this.terms[termIndex];

    // COMPREHENSIVE VALIDATION for the current term only
    const validationResult = this.validateTermFields(term, termIndex);
    if (!validationResult.isValid) {
        this.showToast('Error', validationResult.errorMessage, 'error');
        return;
    }

    if (!term.isDirty) return; // No change to save

    // If preventSave flag is set, stop execution
    if (this.preventSave) {
        this.showToast('Error', 'Please fix all validation errors before saving', 'error');
        return;
    }

    // MODIFIED: Only validate sequence if we have multiple terms with dates
    const completeTerms = this.terms.filter(t => 
        t.startDate && t.endDate && 
        t.startDate.trim() !== '' && t.endDate.trim() !== ''
    );
    
    if (completeTerms.length > 1) {
        if (!this.validateTermDateSequence()) {
            this.showToast('Error', 'End date of a term cannot be after the start date of the next term.', 'error');
            return;
        }
    }

    // MODIFIED: Only validate total weeks if ALL terms are complete
    const allTermsComplete = this.terms.every(t => 
        t.startDate && t.endDate && t.termDuration &&
        t.startDate.trim() !== '' && t.endDate.trim() !== '' && 
        parseInt(t.termDuration) > 0
    );

    if (allTermsComplete) {
        // Calculate total expected weeks from overall date range
        const totalExpectedWeeks = this.calculateTotalProgramWeeks();

        // Sum of all current term durations
        const totalEnteredWeeks = this.terms.reduce((sum, t) => {
            const duration = parseInt(t.termDuration);
            return sum + (isNaN(duration) ? 0 : duration);
        }, 0);

        // Only compare if we have valid calculated weeks
        if (totalExpectedWeeks > 0 && totalEnteredWeeks !== totalExpectedWeeks) {
            this.showToast(
                'Validation Failed',
                `Sum of Term Durations (${totalEnteredWeeks} weeks) does not match total program duration (${totalExpectedWeeks} weeks).`,
                'error'
            );
            return;
        }
    } else {
        console.log('Not all terms are complete, skipping total duration validation');
    }

    // Proceed with saving the term
    if (term.isDirty) {
        this.isSaving = true;

        console.log('=== Saving Term Data ===');
        console.log('Term ID:', term.id);
        console.log('Start Date:', term.startDate);
        console.log('End Date:', term.endDate);
        console.log('Term Duration:', term.termDuration);
        console.log('Term Duration (parsed):', parseInt(term.termDuration));

        // FIXED: Ensure termDuration is passed as integer and all required parameters are included
        const updateParams = {
            termId: term.id, 
            startDate: term.startDate, 
            endDate: term.endDate,
            numberOfWeeks: parseInt(term.termDuration) || 0  // Ensure it's an integer
        };

        console.log('Update parameters being sent:', updateParams);

        updateTermDates(updateParams)
        .then((result) => {
            console.log('Update successful:', result);
            
            const updatedTerm = {
                ...term,
                originalStartDate: term.startDate,
                originalEndDate: term.endDate,
                originalTermDuration: term.termDuration,
                isDirty: false,
                // Clear all error states after successful save
                hasStartDateError: false,
                hasEndDateError: false,
                hasDurationError: false
            };

            this.terms = [
                ...this.terms.slice(0, termIndex),
                updatedTerm,
                ...this.terms.slice(termIndex + 1)
            ];

            this.isSaving = false;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Term dates and duration updated successfully',
                    variant: 'success'
                })
            );
        })
        .catch(error => {
            console.error('Error updating term:', error);
            this.handleError(error);
            this.isSaving = false;
        });
    }
}

// ADDITIONAL: Helper method to check if all terms are ready for final validation
isReadyForFinalValidation() {
    return this.terms.every(term => 
        term.startDate && 
        term.endDate && 
        term.termDuration &&
        term.startDate.trim() !== '' && 
        term.endDate.trim() !== '' && 
        parseInt(term.termDuration) > 0 &&
        !term.hasStartDateError &&
        !term.hasEndDateError &&
        !term.hasDurationError
    );
}

    /**
     * NEW: Comprehensive validation method for term fields
     */
    validateTermFields(term, termIndex) {
        const errors = [];
        let hasErrors = false;

        // Create a clone for updating error states
        const termClone = { ...term };
        
        // Validate Term Duration matches the date range
const expectedWeeks = this.calculateWorkingWeeksBetween(term.startDate, term.endDate);
const enteredDuration = parseInt(term.termDuration);

if (enteredDuration < expectedWeeks) {
    errors.push(`Semester duration (${enteredDuration} week(s)) is less than required for the selected dates (${expectedWeeks} week(s))`);
    hasErrors = true;
}

        // Validate Start Date
        if (!term.startDate || term.startDate.trim() === '') {
            errors.push('Start date is required');
            termClone.hasStartDateError = true;
            hasErrors = true;
        } else {
            termClone.hasStartDateError = false;
        }

        // Validate End Date
        if (!term.endDate || term.endDate.trim() === '') {
            errors.push('End date is required');
            termClone.hasEndDateError = true;
            hasErrors = true;
        } else {
            termClone.hasEndDateError = false;
        }

        // Validate Term Duration
        if (!term.termDuration || term.termDuration === '' || parseInt(term.termDuration) <= 0) {
            errors.push('Semester duration is required and must be greater than 0');
            termClone.hasDurationError = true;
            hasErrors = true;
        } else {
            termClone.hasDurationError = false;
        }

        // Additional validation: End date should be after start date
        if (term.startDate && term.endDate) {
            const start = new Date(term.startDate);
            const end = new Date(term.endDate);

            if (start >= end) {
                errors.push('End date must be after start date');
                termClone.hasEndDateError = true;
                hasErrors = true;
            }
        }

        // Update the term with error states
        if (hasErrors) {
            this.terms = [
                ...this.terms.slice(0, termIndex),
                termClone,
                ...this.terms.slice(termIndex + 1)
            ];
        }

        return {
            isValid: !hasErrors,
            errorMessage: errors.length > 0 ? errors.join('; ') : ''
        };
    }

    /**
     * NEW: Validate all terms before navigation
     */
    validateAllTerms() {
        let allValid = true;
        const errorMessages = [];

        this.terms.forEach((term, index) => {
            const validation = this.validateTermFields(term, index);
            if (!validation.isValid) {
                allValid = false;
                errorMessages.push(`${term.name}: ${validation.errorMessage}`);
            }
        });

        return {
            isValid: allValid,
            errorMessages: errorMessages
        };
    }

    // openAddActivityModal(event) {
    //     this.selectedTermIdForActivity = event.currentTarget.dataset.termId;
        
    //     // Reset edit mode flag - this ensures we're in "add" mode
    //     this.isEditMode = false;
        
    //     console.log('Add Activity clicked for term ID:', this.selectedTermIdForActivity);
    //     console.log('isEditMode set to:', this.isEditMode);
        
    //     // Find the term to initialize start date based on the term
    //     const term = this.terms.find(term => term.id === this.selectedTermIdForActivity);
    //     if (term) {
    //         // Set initial values for a new activity
    //         this.newActivity = {
    //             id: null, // Ensure this is null for new activities
    //             typeOfActivity: '',
    //             durationType: '', 
    //             numberOfWeeks: null,
    //             description: '',
    //             startDate: term.startDate,
    //             endDate: '' // Empty - will be calculated or set manually
    //         };
            
    //         console.log('newActivity initialized for adding:', JSON.stringify(this.newActivity));
    //     } else {
    //         console.error('Term not found with ID:', this.selectedTermIdForActivity);
    //     }
        
    //     this.isModalOpen = true;
    // }

    // UPDATED: openAddActivityModal method with enhanced initialization
openAddActivityModal(event) {
    this.selectedTermIdForActivity = event.currentTarget.dataset.termId;
    
    // Reset edit mode flag - this ensures we're in "add" mode
    this.isEditMode = false;
    
    // Clear any validation messages
    this.activityValidationMessage = '';
    
    console.log('Add Activity clicked for term ID:', this.selectedTermIdForActivity);
    console.log('isEditMode set to:', this.isEditMode);
    
    // Find the term to initialize start date based on the term
    const term = this.terms.find(term => term.id === this.selectedTermIdForActivity);
    if (term) {
        // Set initial values for a new activity
        this.newActivity = {
            id: null, // Ensure this is null for new activities
            typeOfActivity: '',
            durationType: '', 
            numberOfWeeks: null,
            description: '',
            startDate: term.startDate, // Default to term start date
            endDate: '' // Empty - will be calculated or set manually
        };
        
        console.log('newActivity initialized for adding:', JSON.stringify(this.newActivity));
    } else {
        console.error('Term not found with ID:', this.selectedTermIdForActivity);
    }
    
    this.isModalOpen = true;
}

    handleCloseModal() {
    console.log('Closing modal and resetting state');
    
    this.isModalOpen = false;
    this.isEditMode = false;  // Reset edit mode when closing
    this.activityValidationMessage = ''; // Clear validation messages
    this.newActivity = {
        id: null,
        typeOfActivity: '',
        durationType: '',
        numberOfWeeks: null,
        description: '',
        startDate: '',
        endDate: ''
    };
}

    calculateEndDate(startDate, durationType, duration, workingDays) {
        if (!startDate || !durationType || !duration) {
            return null;
        }
        
        console.log('Calculating end date with:');
        console.log('- Start date:', startDate);
        console.log('- Duration type:', durationType);
        console.log('- Duration:', duration);
        console.log('- Working days:', workingDays);
        
        // Parse the duration as an integer
        const durationValue = parseInt(duration, 10);
        if (isNaN(durationValue)) {
            return startDate; // Return start date if duration is invalid
        }
        
        // Special case: if duration is 0 or 1 day, return the start date
        if (durationType === 'Days' && (durationValue === 0 || durationValue === 1)) {
            return startDate;
        }
        
        // Create a new date object from the start date
        const startDateObj = new Date(startDate);
        
        // Parse working days from Working_Days__c field
        const workingDayIndices = this.parseWorkingDays(workingDays);
        console.log('Working day indices:', workingDayIndices);
        
        // Sort working days for proper calculation
        workingDayIndices.sort((a, b) => a - b);
        
        if (durationType === 'Weeks') {
            if (durationValue === 1) {
                // For 1 week, we need to count 5 working days (or the number of working days in a week)
                // Starting from the start date
                
                // First, determine if the start date is a working day
                const startDayOfWeek = startDateObj.getDay();
                const startDateIsWorkingDay = workingDayIndices.includes(startDayOfWeek);
                
                // Count how many working days to add
                const workingDaysInWeek = workingDayIndices.length;
                let daysToAdd = startDateIsWorkingDay ? workingDaysInWeek - 1 : workingDaysInWeek;
                
                // If there are no working days defined, default to 5 working days (Mon-Fri)
                if (workingDaysInWeek === 0) {
                    daysToAdd = 4; // 5 days including start date = add 4 days
                }
                
                // Start with the start date and add working days
                let currentDate = new Date(startDateObj);
                let workingDaysAdded = startDateIsWorkingDay ? 1 : 0;
                
                while (workingDaysAdded < workingDaysInWeek) {
                    // Move to the next day
                    currentDate.setDate(currentDate.getDate() + 1);
                    const dayOfWeek = currentDate.getDay();
                    
                    // Check if this is a working day
                    if (workingDayIndices.includes(dayOfWeek)) {
                        workingDaysAdded++;
                    }
                }
                
                console.log('End date for 1 week:', this.formatDate(currentDate));
                return this.formatDate(currentDate);
            } else if (durationValue > 1) {
                // For multiple weeks, calculate based on workdays
                // For example, 2 weeks with Monday-Friday working days = 10 working days
                
                // Count working days in a week
                const workingDaysPerWeek = workingDayIndices.length;
                
                // Default to 5 working days if none defined
                const effectiveWorkingDaysPerWeek = workingDaysPerWeek > 0 ? workingDaysPerWeek : 5;
                
                // Calculate total working days to add
                const totalWorkingDaysToAdd = effectiveWorkingDaysPerWeek * durationValue;
                
                // Start with the startDate and count working days
                let currentDate = new Date(startDateObj);
                let workingDaysAdded = 0;
                
                // Check if start date is a working day
                const startDayOfWeek = startDateObj.getDay();
                const startDateIsWorkingDay = workingDayIndices.includes(startDayOfWeek);
                
                // If start date is a working day, count it as the first day
                if (startDateIsWorkingDay) {
                    workingDaysAdded = 1;
                }
                
                // Continue adding days until we reach the total working days needed
                while (workingDaysAdded < totalWorkingDaysToAdd) {
                    // Move to the next day
                    currentDate.setDate(currentDate.getDate() + 1);
                    const dayOfWeek = currentDate.getDay();
                    
                    // Check if this is a working day
                    if (workingDayIndices.includes(dayOfWeek)) {
                        workingDaysAdded++;
                    }
                }
                
                console.log('End date for multiple weeks:', this.formatDate(currentDate));
                return this.formatDate(currentDate);
            }
        } else if (durationType === 'Days') {
            // For days, we add (durationValue - 1) working days if durationValue > 1
            // We already handled the durationValue <= 1 case above
            
            // Start with the startDate
            let currentDate = new Date(startDateObj);
            let workingDaysAdded = 0;
            
            // Continue adding days until we reach durationValue - 1
            while (workingDaysAdded < durationValue - 1) {
                // Move to the next day
                currentDate.setDate(currentDate.getDate() + 1);
                const dayOfWeek = currentDate.getDay();
                
                // Check if this is a working day
                if (workingDayIndices.includes(dayOfWeek)) {
                    workingDaysAdded++;
                }
            }
            
            console.log('End date for days:', this.formatDate(currentDate));
            return this.formatDate(currentDate);
        }
        
        // Default fallback - should not reach here
        return startDate;
    }

    getWorkingDayIndices(workingDaysArray) {
        const dayMapping = {
            'sunday': 0,
            'monday': 1,
            'tuesday': 2,
            'wednesday': 3,
            'thursday': 4,
            'friday': 5,
            'saturday': 6
        };
        
        // Handle common formats like "Monday;Tuesday;Wednesday"
        return workingDaysArray
            .map(day => {
                // Clean up the day name (remove any extra text, lowercase it)
                const cleanDay = day.trim().toLowerCase();
                // Look for day names within the string
                for (const [dayName, index] of Object.entries(dayMapping)) {
                    if (cleanDay.includes(dayName)) {
                        return index;
                    }
                }
                return null;
            })
            .filter(index => index !== null);
    }

    formatDate(date) {
        if (!date) return null;
        
        // If it's a string, convert to Date object first
        const dateObj = typeof date === 'string' ? new Date(date) : date;
        
        const year = dateObj.getFullYear();
        const month = String(dateObj.getMonth() + 1).padStart(2, '0');
        const day = String(dateObj.getDate()).padStart(2, '0');
        
        return `${year}-${month}-${day}`;
    }

    parseWorkingDays(workingDaysString) {
        console.log('Parsing working days from:', workingDaysString);
        
        if (!workingDaysString || workingDaysString.trim() === '') {
            console.log('No working days specified, defaulting to Monday-Friday');
            return [1, 2, 3, 4, 5]; // Default to Monday-Friday if not specified
        }
        
        // First split by possible delimiters
        const dayStrings = workingDaysString.split(/[;:,\/|]/).map(d => d.trim());
        console.log('Day strings after splitting:', dayStrings);
        
        const dayMapping = {
            'sun': 0, 'sunday': 0,
            'mon': 1, 'monday': 1,
            'tue': 2, 'tuesday': 2,
            'wed': 3, 'wednesday': 3,
            'thu': 4, 'thursday': 4, 'thurs': 4, 
            'fri': 5, 'friday': 5,
            'sat': 6, 'saturday': 6
        };
        
        const dayIndices = [];
        
        for (const dayString of dayStrings) {
            const dayLower = dayString.toLowerCase();
            
            // Try to match with the mapping
            for (const [abbr, index] of Object.entries(dayMapping)) {
                if (dayLower.includes(abbr)) {
                    dayIndices.push(index);
                    break;
                }
            }
        }
        
        // If no valid days found, default to Monday-Friday
        const result = dayIndices.length > 0 ? dayIndices.sort() : [1, 2, 3, 4, 5];
        console.log('Parsed working day indices:', result);
        return result;
    }

    // handleInputChange(event) {
    //     const field = event.target.dataset.field;
    //     const value = event.target.value;
        
    //     console.log(`Field changed: ${field}, Value: ${value}`);
        
    //     // Update the new activity object first
    //     this.newActivity = { ...this.newActivity, [field]: value };
        
    //     // Now handle the automatic calculations based on which field changed
    //     if (field === 'startDate' && this.newActivity.startDate) {
    //         // Start date changed - calculate end date based on start date and duration
    //         if (this.newActivity.durationType && this.newActivity.numberOfWeeks) {
    //             console.log('Calculating end date from start date change');
    //             const calculatedEndDate = this.calculateEndDate(
    //                 this.newActivity.startDate,
    //                 this.newActivity.durationType,
    //                 this.newActivity.numberOfWeeks,
    //                 this.workingDays
    //             );
                
    //             if (calculatedEndDate) {
    //                 this.newActivity = { ...this.newActivity, endDate: calculatedEndDate };
    //             }
    //         }
    //     } 
    //     else if (field === 'endDate' && this.newActivity.endDate) {
    //         // End date changed - calculate start date or duration based on available data
    //         if (this.newActivity.startDate && this.newActivity.durationType) {
    //             // Both start date and duration type are available, so calculate the duration
    //             console.log('Calculating duration from end date change');
    //             const calculatedDuration = this.calculateDuration(
    //                 this.newActivity.startDate,
    //                 this.newActivity.endDate,
    //                 this.newActivity.durationType,
    //                 this.workingDays
    //             );
                
    //             if (calculatedDuration !== null) {
    //                 this.newActivity = { ...this.newActivity, numberOfWeeks: calculatedDuration };
    //             }
    //         } 
    //         else if (this.newActivity.durationType && this.newActivity.numberOfWeeks) {
    //             // Both duration type and value are available, so calculate the start date
    //             console.log('Calculating start date from end date and duration');
    //             const calculatedStartDate = this.calculateStartDate(
    //                 this.newActivity.endDate,
    //                 this.newActivity.durationType,
    //                 this.newActivity.numberOfWeeks,
    //                 this.workingDays
    //             );
                
    //             if (calculatedStartDate) {
    //                 this.newActivity = { ...this.newActivity, startDate: calculatedStartDate };
    //             }
    //         }
    //     } 
    //     else if ((field === 'durationType' || field === 'numberOfWeeks') && 
    //              this.newActivity.durationType && 
    //              this.newActivity.numberOfWeeks) {
    //         // Duration type or value changed
    //         if (this.newActivity.startDate) {
    //             // Start date is available, so calculate end date
    //             console.log('Calculating end date from duration change');
    //             const calculatedEndDate = this.calculateEndDate(
    //                 this.newActivity.startDate,
    //                 this.newActivity.durationType,
    //                 this.newActivity.numberOfWeeks,
    //                 this.workingDays
    //             );
                
    //             if (calculatedEndDate) {
    //                 this.newActivity = { ...this.newActivity, endDate: calculatedEndDate };
    //             }
    //         } 
    //         else if (this.newActivity.endDate) {
    //             // End date is available, so calculate start date
    //             console.log('Calculating start date from end date and duration');
    //             const calculatedStartDate = this.calculateStartDate(
    //                 this.newActivity.endDate,
    //                 this.newActivity.durationType,
    //                 this.newActivity.numberOfWeeks,
    //                 this.workingDays
    //             );
                
    //             if (calculatedStartDate) {
    //                 this.newActivity = { ...this.newActivity, startDate: calculatedStartDate };
    //             }
    //         }
    //     }
    // }

     handleInputChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    
    console.log(`Field changed: ${field}, Value: ${value}`);
    
    // Update the new activity object first
    this.newActivity = { ...this.newActivity, [field]: value };
    
    // Clear previous validation message
    this.activityValidationMessage = '';
    
    // Perform real-time validation if we have enough data
    if (this.newActivity.startDate && this.newActivity.endDate && this.selectedTermIdForActivity) {
        const validation = this.validateActivityAgainstTerm(this.newActivity, this.selectedTermIdForActivity);
        if (!validation.isValid) {
            this.activityValidationMessage = validation.errorMessage;
        }
    }
    
    // Now handle the automatic calculations based on which field changed
    if (field === 'startDate' && this.newActivity.startDate) {
        // Start date changed - calculate end date based on start date and duration
        if (this.newActivity.durationType && this.newActivity.numberOfWeeks) {
            console.log('Calculating end date from start date change');
            const calculatedEndDate = this.calculateEndDate(
                this.newActivity.startDate,
                this.newActivity.durationType,
                this.newActivity.numberOfWeeks,
                this.workingDays
            );
            
            if (calculatedEndDate) {
                this.newActivity = { ...this.newActivity, endDate: calculatedEndDate };
                // Re-validate after auto-calculation
                const validation = this.validateActivityAgainstTerm(this.newActivity, this.selectedTermIdForActivity);
                if (!validation.isValid) {
                    this.activityValidationMessage = validation.errorMessage;
                }
            }
        }
    } 
    else if (field === 'endDate' && this.newActivity.endDate) {
        // End date changed - calculate start date or duration based on available data
        if (this.newActivity.startDate && this.newActivity.durationType) {
            // Both start date and duration type are available, so calculate the duration
            console.log('Calculating duration from end date change');
            const calculatedDuration = this.calculateDuration(
                this.newActivity.startDate,
                this.newActivity.endDate,
                this.newActivity.durationType,
                this.workingDays
            );
            
            if (calculatedDuration !== null) {
                this.newActivity = { ...this.newActivity, numberOfWeeks: calculatedDuration };
            }
        } 
        else if (this.newActivity.durationType && this.newActivity.numberOfWeeks) {
            // Both duration type and value are available, so calculate the start date
            console.log('Calculating start date from end date and duration');
            const calculatedStartDate = this.calculateStartDate(
                this.newActivity.endDate,
                this.newActivity.durationType,
                this.newActivity.numberOfWeeks,
                this.workingDays
            );
            
            if (calculatedStartDate) {
                this.newActivity = { ...this.newActivity, startDate: calculatedStartDate };
            }
        }
    } 
    else if ((field === 'durationType' || field === 'numberOfWeeks') && 
             this.newActivity.durationType && 
             this.newActivity.numberOfWeeks) {
        // Duration type or value changed
        if (this.newActivity.startDate) {
            // Start date is available, so calculate end date
            console.log('Calculating end date from duration change');
            const calculatedEndDate = this.calculateEndDate(
                this.newActivity.startDate,
                this.newActivity.durationType,
                this.newActivity.numberOfWeeks,
                this.workingDays
            );
            
            if (calculatedEndDate) {
                this.newActivity = { ...this.newActivity, endDate: calculatedEndDate };
                // Re-validate after auto-calculation
                const validation = this.validateActivityAgainstTerm(this.newActivity, this.selectedTermIdForActivity);
                if (!validation.isValid) {
                    this.activityValidationMessage = validation.errorMessage;
                }
            }
        } 
        else if (this.newActivity.endDate) {
            // End date is available, so calculate start date
            console.log('Calculating start date from end date and duration');
            const calculatedStartDate = this.calculateStartDate(
                this.newActivity.endDate,
                this.newActivity.durationType,
                this.newActivity.numberOfWeeks,
                this.workingDays
            );
            
            if (calculatedStartDate) {
                this.newActivity = { ...this.newActivity, startDate: calculatedStartDate };
            }
        }
    }
}

    calculateDuration(startDate, endDate, durationType, workingDays) {
        if (!startDate || !endDate || !durationType) {
            return null;
        }
        
        console.log('Calculating duration with:');
        console.log('- Start date:', startDate);
        console.log('- End date:', endDate);
        console.log('- Duration type:', durationType);
        console.log('- Working days:', workingDays);
        
        // Parse the dates
        const startDateObj = new Date(startDate);
        const endDateObj = new Date(endDate);
        
        // Validate dates
        if (isNaN(startDateObj.getTime()) || isNaN(endDateObj.getTime())) {
            return null;
        }
        
        // Parse working days
        const workingDayIndices = this.parseWorkingDays(workingDays);
        
        // If end date is earlier than start date, return null
        if (endDateObj < startDateObj) {
            return null;
        }
        
        // If same date, return 1 day or 0 weeks depending on durationType
        if (this.formatDate(startDateObj) === this.formatDate(endDateObj)) {
            return durationType === 'Days' ? 1 : 0;
        }
        
        if (durationType === 'Weeks') {
            // Count working days between dates
            let currentDate = new Date(startDateObj);
            let workingDaysCount = 0;
            
            while (currentDate <= endDateObj) {
                const dayOfWeek = currentDate.getDay();
                if (workingDayIndices.includes(dayOfWeek)) {
                    workingDaysCount++;
                }
                
                // Move to next day
                currentDate.setDate(currentDate.getDate() + 1);
            }
            
            // Calculate weeks based on working days per week
            const workingDaysPerWeek = workingDayIndices.length > 0 ? workingDayIndices.length : 5;
            const weeks = Math.ceil(workingDaysCount / workingDaysPerWeek);
            
            return weeks;
        } 
        else if (durationType === 'Days') {
            // Count only working days
            let currentDate = new Date(startDateObj);
            let workingDaysCount = 0;
            
            while (currentDate <= endDateObj) {
                const dayOfWeek = currentDate.getDay();
                if (workingDayIndices.includes(dayOfWeek)) {
                    workingDaysCount++;
                }
                
                // Move to next day
                currentDate.setDate(currentDate.getDate() + 1);
            }
            
            return workingDaysCount;
        }
        
        return null;
    }

    calculateStartDate(endDate, durationType, duration, workingDays) {
        if (!endDate || !durationType || !duration) {
            return null;
        }
        
        console.log('Calculating start date with:');
        console.log('- End date:', endDate);
        console.log('- Duration type:', durationType);
        console.log('- Duration:', duration);
        console.log('- Working days:', workingDays);
        
        // Parse duration as integer
        const durationValue = parseInt(duration, 10);
        if (isNaN(durationValue) || durationValue <= 0) {
            return endDate; // Invalid duration, return end date
        }
        
        // Special case: if duration is 1 day, return the end date for Days
        if (durationType === 'Days' && durationValue === 1) {
            return endDate;
        }
        
        // Create date object from end date
        const endDateObj = new Date(endDate);
        
        // Parse working days
        const workingDayIndices = this.parseWorkingDays(workingDays);
        console.log('Working day indices:', workingDayIndices);
        
        // Sort working days for calculation
        workingDayIndices.sort((a, b) => a - b);
        
        if (durationType === 'Weeks') {
            // For weeks, we need to go backwards from end date
            // First determine if end date is a working day
            const endDayOfWeek = endDateObj.getDay();
            const endDateIsWorkingDay = workingDayIndices.includes(endDayOfWeek);
            
            // Count working days in a week
            const workingDaysPerWeek = workingDayIndices.length || 5; // Default to 5 if not specified
            
            // Calculate total working days to go backwards
            const totalWorkingDays = workingDaysPerWeek * durationValue;
            
            let currentDate = new Date(endDateObj);
            let workingDaysFound = endDateIsWorkingDay ? 1 : 0;
            
            // Go backwards until we find enough working days
            while (workingDaysFound < totalWorkingDays) {
                // Move to previous day
                currentDate.setDate(currentDate.getDate() - 1);
                
                const dayOfWeek = currentDate.getDay();
                if (workingDayIndices.includes(dayOfWeek)) {
                    workingDaysFound++;
                }
            }
            
            console.log('Start date for weeks:', this.formatDate(currentDate));
            return this.formatDate(currentDate);
        }
        else if (durationType === 'Days') {
            // For days, we go back durationValue working days
            let currentDate = new Date(endDateObj);
            let workingDaysFound = 0;
            
            // If the end date is a working day, count it
            const endDayOfWeek = endDateObj.getDay();
            if (workingDayIndices.includes(endDayOfWeek)) {
                workingDaysFound = 1;
            }
            
            // Go backwards until we find enough working days
            while (workingDaysFound < durationValue) {
                // Move to previous day
                currentDate.setDate(currentDate.getDate() - 1);
                
                const dayOfWeek = currentDate.getDay();
                if (workingDayIndices.includes(dayOfWeek)) {
                    workingDaysFound++;
                }
            }
            
            console.log('Start date for days:', this.formatDate(currentDate));
            return this.formatDate(currentDate);
        }
        
        // Fallback
        return null;
    }

    // saveNewActivity() {
    //     // Log the current state to help diagnose issues
    //     console.log('SAVING ACTIVITY:');
    //     console.log('isEditMode:', this.isEditMode);
    //     console.log('Activity ID:', this.newActivity.id);
    //     console.log('Term ID:', this.selectedTermIdForActivity);
    //     console.log('Activity data:', JSON.stringify(this.newActivity));
        
    //     // Basic validation
    //     if (!this.newActivity.typeOfActivity || !this.newActivity.startDate || !this.newActivity.endDate) {
    //         this.dispatchEvent(
    //             new ShowToastEvent({
    //                 title: 'Error',
    //                 message: 'Please fill in all required fields',
    //                 variant: 'error'
    //             })
    //         );
    //         return;
    //     }

    //     // Validate that end date is not before start date
    //     const startDate = new Date(this.newActivity.startDate);
    //     const endDate = new Date(this.newActivity.endDate);
    //     if (endDate < startDate) {
    //         this.dispatchEvent(
    //             new ShowToastEvent({
    //                 title: 'Error',
    //                 message: 'End date should not be earlier than start date',
    //                 variant: 'error'
    //             })
    //         );
    //         return;
    //     }

    //     this.isSaving = true;

    //     // CRITICAL DECISION POINT: Determine if we're updating or creating
    //     if (this.isEditMode === true && this.newActivity.id) {
    //         console.log('UPDATING existing activity with ID:', this.newActivity.id);
            
    //         // Log the exact parameters being sent to the Apex method
    //         const updateParams = {
    //             activityId: this.newActivity.id,
    //             typeOfActivity: this.newActivity.typeOfActivity,
    //             durationType: this.newActivity.durationType,
    //             numberOfWeeks: parseInt(this.newActivity.numberOfWeeks) || 0,
    //             description: this.newActivity.description,
    //             startDate: this.newActivity.startDate,
    //             endDate: this.newActivity.endDate
    //         };
    //         console.log('Update parameters:', JSON.stringify(updateParams));
            
    //         // Call Apex method to update the activity
    //         updateActivity(updateParams)
    //             .then(() => {
    //                 console.log('Activity updated successfully');
                    
    //                 // Update the activity in the UI
    //                 this.updateActivityInUI(this.newActivity.id);
                    
    //                 // Show success message
    //                 this.dispatchEvent(
    //                     new ShowToastEvent({
    //                         title: 'Success',
    //                         message: 'Activity updated successfully',
    //                         variant: 'success'
    //                     })
    //                 );
                    
    //                 // Close the modal and reset
    //                 this.handleCloseModal();
    //                 this.isSaving = false;
    //             })
    //             .catch(error => {
    //                 console.error('Error updating activity:', error);
    //                 this.handleError(error);
    //                 this.isSaving = false;
    //             });
    //     } else {
    //         console.log('ADDING new activity for term:', this.selectedTermIdForActivity);
            
    //         // Prepare parameters for adding new activity
    //         const addParams = {
    //             termId: this.selectedTermIdForActivity,
    //             typeOfActivity: this.newActivity.typeOfActivity,
    //             durationType: this.newActivity.durationType,
    //             numberOfWeeks: parseInt(this.newActivity.numberOfWeeks) || 0,
    //             description: this.newActivity.description || '',
    //             startDate: this.newActivity.startDate,
    //             endDate: this.newActivity.endDate,
    //             accountName: 'Default Account'
    //         };
            
    //         console.log('Add parameters:', JSON.stringify(addParams));
            
    //         // Call Apex method to add a new activity
    //         addActivity(addParams)
    //             .then(result => {
    //                 console.log('New activity created with ID:', result);
                    
    //                 this.dispatchEvent(
    //                     new ShowToastEvent({
    //                         title: 'Success',
    //                         message: 'Activity added successfully',
    //                         variant: 'success'
    //                     })
    //                 );
                    
    //                 const termIndex = this.terms.findIndex(term => term.id === this.selectedTermIdForActivity);
    //                 if (termIndex !== -1) {
    //                     const termClone = {...this.terms[termIndex]};
    //                     const durationValue = parseInt(this.newActivity.numberOfWeeks) || 0;
                        
    //                     const newActivityObj = {
    //                         id: result,
    //                         weekNo: this.calculateWeekNumber(this.newActivity.startDate, termClone.startDate),
    //                         typeOfActivity: this.newActivity.typeOfActivity,
    //                         description: this.newActivity.description,
    //                         durationType: this.newActivity.durationType,
    //                         duration: durationValue,
    //                         startDate: this.newActivity.startDate,
    //                         endDate: this.newActivity.endDate,
    //                         // Add formatted dates
    //                         startDateFormatted: this.formatDateDisplay(this.newActivity.startDate),
    //                         endDateFormatted: this.formatDateDisplay(this.newActivity.endDate),
    //                         // Keep original fields for reference
    //                         Type_of_Activity__c: this.newActivity.typeOfActivity,
    //                         Description__c: this.newActivity.description,
    //                         Duration_Type__c: this.newActivity.durationType,
    //                         Number_Of_Weeks__c: durationValue,
    //                         Start_Date__c: this.newActivity.startDate,
    //                         End_Date__c: this.newActivity.endDate
    //                     };
                        
    //                     termClone.activities = [...termClone.activities, newActivityObj];
                        
    //                     if (termClone.isExpanded) {
    //                         termClone.activitiesFormatted = this.formatActivitiesForDatatable(termClone.activities);
    //                     }
                        
    //                     this.terms = [
    //                         ...this.terms.slice(0, termIndex),
    //                         termClone,
    //                         ...this.terms.slice(termIndex + 1)
    //                     ];
    //                 }
                    
    //                 this.handleCloseModal();
    //                 this.isSaving = false;
    //             })
    //             .catch(error => {
    //                 console.error('Error adding activity:', error);
    //                 this.handleError(error);
    //                 this.isSaving = false;
    //             });
    //     }
    // }
    saveNewActivity() {
    // Log the current state to help diagnose issues
    console.log('SAVING ACTIVITY:');
    console.log('isEditMode:', this.isEditMode);
    console.log('Activity ID:', this.newActivity.id);
    console.log('Term ID:', this.selectedTermIdForActivity);
    console.log('Activity data:', JSON.stringify(this.newActivity));
    
    // Basic validation
    if (!this.newActivity.typeOfActivity || !this.newActivity.startDate || !this.newActivity.endDate) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Please fill in all required fields (Type of Activity, Start Date, End Date)',
                variant: 'error'
            })
        );
        return;
    }

    // Validate that end date is not before start date
    const startDate = new Date(this.newActivity.startDate);
    const endDate = new Date(this.newActivity.endDate);
    if (endDate < startDate) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'End date should not be earlier than start date',
                variant: 'error'
            })
        );
        return;
    }

    // NEW: Validate activity against term boundaries
    const termValidation = this.validateActivityAgainstTerm(this.newActivity, this.selectedTermIdForActivity);
    if (!termValidation.isValid) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Activity Validation Failed',
                message: termValidation.errorMessage,
                variant: 'error'
            })
        );
        return;
    }

    // NEW: Additional validation for overlapping activities (optional)
    const overlapValidation = this.checkActivityOverlap(this.newActivity, this.selectedTermIdForActivity);
    if (!overlapValidation.isValid) {
        // Show warning for overlaps (not blocking, just informative)
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Warning',
                message: overlapValidation.errorMessage,
                variant: 'warning'
            })
        );
        // Continue with save but user is warned
    }

    this.isSaving = true;

    // Rest of the existing save logic...
    if (this.isEditMode === true && this.newActivity.id) {
        console.log('UPDATING existing activity with ID:', this.newActivity.id);
        
        const updateParams = {
            activityId: this.newActivity.id,
            typeOfActivity: this.newActivity.typeOfActivity,
            durationType: this.newActivity.durationType,
            numberOfWeeks: parseInt(this.newActivity.numberOfWeeks) || 0,
            description: this.newActivity.description,
            startDate: this.newActivity.startDate,
            endDate: this.newActivity.endDate
        };
        console.log('Update parameters:', JSON.stringify(updateParams));
        
        updateActivity(updateParams)
            .then(() => {
                console.log('Activity updated successfully');
                this.updateActivityInUI(this.newActivity.id);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Activity updated successfully',
                        variant: 'success'
                    })
                );
                this.handleCloseModal();
                this.isSaving = false;
            })
            .catch(error => {
                console.error('Error updating activity:', error);
                this.handleError(error);
                this.isSaving = false;
            });
    } else {
        console.log('ADDING new activity for term:', this.selectedTermIdForActivity);
        
        const addParams = {
            termId: this.selectedTermIdForActivity,
            typeOfActivity: this.newActivity.typeOfActivity,
            durationType: this.newActivity.durationType,
            numberOfWeeks: parseInt(this.newActivity.numberOfWeeks) || 0,
            description: this.newActivity.description || '',
            startDate: this.newActivity.startDate,
            endDate: this.newActivity.endDate,
            accountName: 'Default Account'
        };
        
        console.log('Add parameters:', JSON.stringify(addParams));
        
        addActivity(addParams)
            .then(result => {
                console.log('New activity created with ID:', result);
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Activity added successfully',
                        variant: 'success'
                    })
                );
                
                // Update UI logic...
                const termIndex = this.terms.findIndex(term => term.id === this.selectedTermIdForActivity);
                if (termIndex !== -1) {
                    const termClone = {...this.terms[termIndex]};
                    const durationValue = parseInt(this.newActivity.numberOfWeeks) || 0;
                    
                    const newActivityObj = {
                        id: result,
                        weekNo: this.calculateWeekNumber(this.newActivity.startDate, termClone.startDate),
                        typeOfActivity: this.newActivity.typeOfActivity,
                        description: this.newActivity.description,
                        durationType: this.newActivity.durationType,
                        duration: durationValue,
                        startDate: this.newActivity.startDate,
                        endDate: this.newActivity.endDate,
                        startDateFormatted: this.formatDateDisplay(this.newActivity.startDate),
                        endDateFormatted: this.formatDateDisplay(this.newActivity.endDate),
                        Type_of_Activity__c: this.newActivity.typeOfActivity,
                        Description__c: this.newActivity.description,
                        Duration_Type__c: this.newActivity.durationType,
                        Number_Of_Weeks__c: durationValue,
                        Start_Date__c: this.newActivity.startDate,
                        End_Date__c: this.newActivity.endDate
                    };
                    
                    termClone.activities = [...termClone.activities, newActivityObj];
                    
                    if (termClone.isExpanded) {
                        termClone.activitiesFormatted = this.formatActivitiesForDatatable(termClone.activities);
                    }
                    
                    this.terms = [
                        ...this.terms.slice(0, termIndex),
                        termClone,
                        ...this.terms.slice(termIndex + 1)
                    ];
                }
                
                this.handleCloseModal();
                this.isSaving = false;
            })
            .catch(error => {
                console.error('Error adding activity:', error);
                this.handleError(error);
                this.isSaving = false;
            });
    }
}

    updateActivityInUI(activityId) {
        console.log('Updating activity in UI with ID:', activityId);
        
        // Find the term containing the activity
        let foundTermIndex = -1;
        let foundActivityIndex = -1;
        
        // Loop through all terms to find the activity
        for (let termIndex = 0; termIndex < this.terms.length; termIndex++) {
            const term = this.terms[termIndex];
            const activityIndex = term.activities.findIndex(a => a.id === activityId);
            
            if (activityIndex !== -1) {
                foundTermIndex = termIndex;
                foundActivityIndex = activityIndex;
                break;
            }
        }
        
        console.log(`Found activity at term index ${foundTermIndex}, activity index ${foundActivityIndex}`);
        
        if (foundTermIndex !== -1 && foundActivityIndex !== -1) {
            // Create clones for immutability
            const termClone = {...this.terms[foundTermIndex]};
            const activities = [...termClone.activities];
            
            // Parse the number of weeks to ensure it's a number
            const numberOfWeeks = parseInt(this.newActivity.numberOfWeeks) || 0;
            
            // Update the activity with new values
            const updatedActivity = {
                ...activities[foundActivityIndex],
                typeOfActivity: this.newActivity.typeOfActivity,
                description: this.newActivity.description,
                durationType: this.newActivity.durationType,
                duration: numberOfWeeks,
                startDate: this.newActivity.startDate,
                endDate: this.newActivity.endDate,
                // Update formatted dates
                startDateFormatted: this.formatDateDisplay(this.newActivity.startDate),
                endDateFormatted: this.formatDateDisplay(this.newActivity.endDate),
                // Update original fields
                Type_of_Activity__c: this.newActivity.typeOfActivity,
                Description__c: this.newActivity.description,
                Duration_Type__c: this.newActivity.durationType,
                Number_Of_Weeks__c: numberOfWeeks,
                Start_Date__c: this.newActivity.startDate,
                End_Date__c: this.newActivity.endDate
            };
            
            // Update the week number based on the new start date
            updatedActivity.weekNo = this.calculateWeekNumber(
                updatedActivity.startDate,
                termClone.startDate
            );
            
            console.log('Updated activity object:', JSON.stringify(updatedActivity));
            
            // Update the activity in the array
            activities[foundActivityIndex] = updatedActivity;
            termClone.activities = activities;
            
            // Update the formatted activities if term is expanded
            if (termClone.isExpanded) {
                termClone.activitiesFormatted = this.formatActivitiesForDatatable(termClone.activities);
            }
            
            // Update the term in the main array
            this.terms = [
                ...this.terms.slice(0, foundTermIndex),
                termClone,
                ...this.terms.slice(foundTermIndex + 1)
            ];
            
            console.log('UI updated successfully');
        } else {
            console.error('Could not find activity with ID:', activityId);
        }
    }

    loadTermActivities(termId) {
        this.isLoading = true;
        getTermActivities({ termId: termId })
            .then(result => {
                const termIndex = this.terms.findIndex(term => term.id === termId);
                if (termIndex !== -1 && result.activities) {
                    const termClone = {...this.terms[termIndex]};
                    
                    // Format the activities for lightning-datatable
                    termClone.activities = result.activities.map(activity => {
                        // Format dates to ensure no time component
                        const startDate = this.formatDate(activity.Start_Date__c);
                        const endDate = this.formatDate(activity.End_Date__c);
                        
                        // Format for display
                        const startDateFormatted = this.formatDateDisplay(startDate);
                        const endDateFormatted = this.formatDateDisplay(endDate);
                        
                        return {
                            id: activity.Id,
                            weekNo: this.calculateWeekNumber(activity.Start_Date__c, termClone.startDate),
                            typeOfActivity: activity.Type_of_Activity__c,
                            description: activity.Description__c,
                            durationType: activity.Duration_Type__c,
                            duration: parseInt(activity.Duration__c) || 0,
                            startDate: startDate,
                            endDate: endDate,
                            // Add formatted dates for display
                            startDateFormatted: startDateFormatted,
                            endDateFormatted: endDateFormatted,
                            // Keep the original fields for reference
                            Type_of_Activity__c: activity.Type_of_Activity__c,
                            Description__c: activity.Description__c,
                            Duration_Type__c: activity.Duration_Type__c,
                            Number_Of_Weeks__c: activity.Duration__c,
                            Start_Date__c: startDate,
                            End_Date__c: endDate
                        };
                    });
                    
                    // Create formatted version with picklist options if the term is expanded
                    if (termClone.isExpanded) {
                        termClone.activitiesFormatted = this.formatActivitiesForDatatable(termClone.activities);
                    }
                    
                    this.terms = [
                        ...this.terms.slice(0, termIndex),
                        termClone,
                        ...this.terms.slice(termIndex + 1)
                    ];
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.handleError(error);
                this.isLoading = false;
            });
    }

    validateTermDateSequence() {
        console.log('Validating term date sequence...');
        for (let i = 0; i < this.terms.length - 1; i++) {
            const currentTerm = this.terms[i];
            const nextTerm = this.terms[i + 1];
            if (!currentTerm.endDate || !nextTerm.startDate) {
                continue; // Skip if either date is missing
            }
            const currentEndDate = new Date(currentTerm.endDate);
            const nextStartDate = new Date(nextTerm.startDate);
            if (currentEndDate > nextStartDate) {
                console.error(`Validation failed: End date of Term ${i + 1} (${currentTerm.name}) is after Start date of Term ${i + 2} (${nextTerm.name})`);
                return false;
            }
        }
        console.log('Date sequence validation passed.');
        return true;
    }

    async handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        
        if (action.name === 'delete') {
            this.handleDeleteActivity(row.id);
        } else if (action.name === 'edit') {
            this.handleEditActivity(row.id);
        }
    }

    async handleDeleteActivity(activityId) {
        // Show confirmation dialog
        const result = await LightningConfirm.open({
            message: 'Are you sure you want to delete this activity?',
             variant: 'header',
             label: 'Confirm Deletion'
        });
        if (!result) {
                return;
            }
        
        this.isSaving = true;
        
        // Call Apex method to delete the activity
        deleteActivity({ activityId: activityId })
            .then(() => {
                // Find the term containing this activity
                let termIndex = -1;
                let activityIndex = -1;
                
                for (let i = 0; i < this.terms.length; i++) {
                    const term = this.terms[i];
                    const index = term.activities.findIndex(activity => activity.id === activityId);
                    
                    if (index !== -1) {
                        termIndex = i;
                        activityIndex = index;
                        break;
                    }
                }
                
                if (termIndex !== -1 && activityIndex !== -1) {
                    // Create a clone of the term
                    const termClone = {...this.terms[termIndex]};
                    
                    // Remove the activity from the array
                    termClone.activities = [
                        ...termClone.activities.slice(0, activityIndex),
                        ...termClone.activities.slice(activityIndex + 1)
                    ];
                    
                    // Update formatted activities if term is expanded
                    if (termClone.isExpanded) {
                        termClone.activitiesFormatted = this.formatActivitiesForDatatable(termClone.activities);
                    }
                    
                    // Update the term in the array
                    this.terms = [
                        ...this.terms.slice(0, termIndex),
                        termClone,
                        ...this.terms.slice(termIndex + 1)
                    ];
                }
                
                this.isSaving = false;
                
                // Show success message
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Activity deleted successfully',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.handleError(error);
                this.isSaving = false;
            });
    }

    handleEditActivity(activityId) {
        console.log('Edit activity requested for ID:', activityId);
        
        // Find the activity in our terms
        let activityToEdit = null;
        
        // Search through all terms to find the activity
        for (const term of this.terms) {
            const activity = term.activities.find(a => a.id === activityId);
            if (activity) {
                activityToEdit = activity;
                this.selectedTermIdForActivity = term.id;
                break;
            }
        }
        
        if (activityToEdit) {
            console.log('Activity found for editing:', JSON.stringify(activityToEdit));
            
            // Set edit mode flag explicitly to true
            this.isEditMode = true;
            
            // Ensure we have the correct ID - this is CRITICAL
            this.newActivity = {
                id: activityId, // Use the exact ID passed to this method
                typeOfActivity: activityToEdit.typeOfActivity || activityToEdit.Type_of_Activity__c,
                durationType: activityToEdit.durationType || activityToEdit.Duration_Type__c,
                numberOfWeeks: activityToEdit.duration || activityToEdit.Number_Of_Weeks__c,
                description: activityToEdit.description || activityToEdit.Description__c,
                startDate: activityToEdit.startDate || activityToEdit.Start_Date__c,
                endDate: activityToEdit.endDate || activityToEdit.End_Date__c
            };
            
            console.log('Edit mode set to TRUE');
            console.log('Activity ID for editing:', this.newActivity.id);
            
            // Open the modal for editing
            this.isModalOpen = true;
        } else {
            console.error('Activity not found for editing with ID:', activityId);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Could not find the activity to edit',
                    variant: 'error'
                })
            );
        }
    }

    calculateWeekNumber(activityStartDate, termStartDate) {
        if (!activityStartDate || !termStartDate) return 1;
        
        const start = new Date(termStartDate);
        const activityDate = new Date(activityStartDate);
        
        const diffTime = Math.abs(activityDate - start);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        const weekNum = Math.floor(diffDays / 7) + 1;
        
        return weekNum > 0 ? weekNum : 1;
    }

    goToPrevious() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: { 
                direction: 'previous',
                currentTab: 'academic'
            },
            bubbles: true, 
            composed: true
        }));
        
        console.log('Dispatching navigate event: previous');
    }

    /**
     * UPDATED: goToNext with validation and Custom Metadata information
     */
    goToNext() {
        // Validate all terms before allowing navigation
        const validation = this.validateAllTerms();
        
        if (!validation.isValid) {
            this.showToast(
                'Validation Error', 
                'Please fill in all required fields for all terms before proceeding:\n' + validation.errorMessages.join('\n'), 
                'error'
            );
            return;
        }

        const selectedAcademicProgram = this.selectedAcademicProgram;
        const selectedProgramPlan = this.selectedProgramPlan;  
        const workingDays = this.workingDays;
        
        console.log('Working Dates', workingDays);
        
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                direction: 'next',
                currentTab: 'academic',
                selectedAcademicProgram,
                selectedProgramPlan,
                workingDays,
                // Include configuration information
                masterRequirementMode: this.masterRequirementMode,
                localRequirementMode: this._localRequirementMode,
                isCheckboxChecked: this._isCheckboxChecked,
                institutionType: this.selectedInstitutionType,
                isConfigurationLoaded: this.isConfigurationLoaded
            },
            bubbles: true,
            composed: true
        }));

        console.log('Dispatching navigate event: next with data', {
            selectedAcademicProgram,
            selectedProgramPlan,
            masterRequirementMode: this.masterRequirementMode,
            localRequirementMode: this._localRequirementMode,
            isCheckboxChecked: this._isCheckboxChecked
        });
    }

    handleCancel() {
        // Reset all selections and data
        this.selectedAcademicProgram = null;
        this.selectedProgramPlan = null;
        this.workingDays = '';
        this.terms = [];
        this.expandedTerms = new Set();
        this.editedActivityDraftValues = [];
        
        // Reset modal state if open
        this.isModalOpen = false;
        this.selectedTermIdForActivity = null;
        this.newActivity = {
            typeOfActivity: '',
            durationType: '',
            numberOfWeeks: null,
            description: '',
            startDate: '',
            endDate: ''
        };
        
        // Show a confirmation message
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Cancelled',
                message: 'All selections have been cleared',
                variant: 'info'
            })
        );
    }

    handleError(error) {
        console.error(error);
        let message = 'Unknown error';
        if (Array.isArray(error.body)) {
            message = error.body.map(e => e.message).join(', ');
        } else if (typeof error.body?.message === 'string') {
            message = error.body.message;
        }
        
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }

    // NEW GETTERS for template use
    get isStrictMode() {
        return this._localRequirementMode; // Use local for UI display
    }
    
    get isFlexibleMode() {
        return !this._localRequirementMode;
    }
    
    get configurationLabel() {
        if (this.isConfigurationLoaded && this.masterConfiguration) {
            return `${this.masterConfiguration.Institution_Type__c} - ${this.masterConfiguration.Label}`;
        }
        return 'Manual Configuration';
    }

    get showConfigurationBanner() {
        return this.isConfigurationLoaded;
    }

    get configurationModeText() {
        if (this.isConfigurationLoaded) {
            const baseMode = this.masterRequirementMode ? 'Strict Mode' : 'Flexible Mode';
            const override = this._isCheckboxChecked !== this.masterRequirementMode ? ' (Overridden)' : '';
            return `${baseMode} (Auto-configured)${override}`;
        }
        return this._localRequirementMode ? 'Strict Mode (Manual)' : 'Flexible Mode (Manual)';
    }

    get effectiveRequirementMode() {
        // This returns the actual mode being used (for template conditions)
        return this._localRequirementMode;
    }
}