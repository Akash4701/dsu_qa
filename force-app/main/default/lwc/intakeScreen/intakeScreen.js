import { LightningElement, track, wire, api } from 'lwc';
import getAcademicPrograms from '@salesforce/apex/IntakeScreenController.getAcademicPrograms';
import getProgramAliases from '@salesforce/apex/IntakeScreenController.getProgramAliases';
import getCampusFormats from '@salesforce/apex/IntakeScreenController.getCampusFormats';
import getNoofTerms from '@salesforce/apex/IntakeScreenController.getNoofTerms';
import getTotalDuration from '@salesforce/apex/IntakeScreenController.getTotalDuration';
import saveProgramPlan from '@salesforce/apex/IntakeScreenController.saveProgramPlan';
import getAcademicTerms from '@salesforce/apex/IntakeScreenController.getAcademicTerms';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAcademicYearPicklistValues from '@salesforce/apex/IntakeScreenController.getAcademicYearPicklistValues'; 

// NEW IMPORTS FOR CUSTOM METADATA
import getAcademicConfiguration from '@salesforce/apex/AcademicConfigController.getAcademicConfiguration';
import getAllConfigurations from '@salesforce/apex/AcademicConfigController.getAllConfigurations';
import parseWorkingDays from '@salesforce/apex/AcademicConfigController.parseWorkingDays';

//
import { createRecord } from 'lightning/uiRecordApi';
import ACADEMIC_TERM_OBJECT from '@salesforce/schema/Academic_Term__c';
import NAME_FIELD from '@salesforce/schema/Academic_Term__c.Name';
import ACADEMIC_YEAR_FIELD from '@salesforce/schema/Academic_Term__c.Academic_Year__c';
import IS_ACTIVE_FIELD from '@salesforce/schema/Academic_Term__c.IsActive__c';
import CREATED_DATE_FIELD from '@salesforce/schema/Academic_Term__c.Created_Date__c';
import END_DATE_FIELD from '@salesforce/schema/Academic_Term__c.End_Date__c';
import LAST_MODIFIED_DATE_FIELD from '@salesforce/schema/Academic_Term__c.Last_Modified_Date__c';
import LATE_REG_DATE_FIELD from '@salesforce/schema/Academic_Term__c.Late_Registration_Date__c';
import REG_CLOSE_DATE_FIELD from '@salesforce/schema/Academic_Term__c.Registration_Close_Date__c';
import REG_OPEN_DATE_FIELD from '@salesforce/schema/Academic_Term__c.Registration_Open_Date__c';
import SEASON_FIELD from '@salesforce/schema/Academic_Term__c.Season__c';
import START_DATE_FIELD from '@salesforce/schema/Academic_Term__c.Start_Date__c';
import getAcademicTermss from '@salesforce/apex/IntakeScreenController.getAcademicTermss';


export default class LightningExampleInputSearch extends LightningElement {
    //////////////////////////////
        @track showModal = false;
         @track academicTermOptions = [];
    @track newAcademicTerm = {
        Name: '',
        Academic_Year__c: '',
        IsActive__c: true,
        Created_Date__c: '',
        End_Date__c: '',
        Last_Modified_Date__c: '',
        Late_Registration_Date__c: '',
        Registration_Close_Date__c: '',
        Registration_Open_Date__c: '',
        Season__c: '',
        Start_Date__c: ''
    };
    @track timeInputs = {
    startTime: '',
    endTime: '',
    registrationOpenTime: '',
    registrationCloseTime: '',
    lateRegistrationTime: '',
    createdTime: '',
    lastModifiedTime: ''
};

    currentTermIndex = null;

    @wire(getAcademicTerms)
    wiredAcademicTerms({ error, data }) {
        if (data) {
            this.academicTermOptions = data.map(term => ({
                label: term.label,
                value: term.value
            }));
        } else if (error) {
            console.error('Error fetching Academic Terms:', error);
        }
    }
    
    @wire(getAcademicTermss)
    wiredAcademicTerms({ error, data }) {
        if (data) {
            this.academicTermOptionss = data.map(term => ({
                label: term.Name,
                value: term.Id
            }));
        } else if (error) {
            console.error('Error fetching Academic Terms:', error);
        }
    }


  @track seasonOptions = [
    { label: '--None--', value: '' }, // Default option
    { label: 'Fall', value: 'Fall' },
    { label: 'Spring', value: 'Spring' },
    { label: 'Summer', value: 'Summer' },
    { label: 'Winter', value: 'Winter' }
];
    @track academicTermOptionss = [];
    currentTermIndex = null;
    handleCreateAcademicTermClick(event) {
    this.currentTermIndex = parseInt(event.currentTarget.dataset.termIndex);
    this.showModal = true;
}
handleInputChange(event) {
    const field = event.target.name;
    const value = event.target.value;
    
    if (event.target.type === 'checkbox') {
        this.newAcademicTerm[field] = event.target.checked;
    } else if (field.includes('Time__c')) {
        // Handle time inputs separately
        const timeKey = this.getTimeKey(field);
        this.timeInputs[timeKey] = value;
        this.combineDateTime(field);
    } else {
        this.newAcademicTerm[field] = value;
        // If it's a date field and we have corresponding time, combine them
        if (field.includes('Date__c')) {
            this.combineDateTime(field);
        }
    }
}

getTimeKey(timeField) {
    const mapping = {
        'Start_Time__c': 'startTime',
        'End_Time__c': 'endTime',
        'Registration_Open_Time__c': 'registrationOpenTime',
        'Registration_Close_Time__c': 'registrationCloseTime',
        'Late_Registration_Time__c': 'lateRegistrationTime',
        'Created_Time__c': 'createdTime',
        'Last_Modified_Time__c': 'lastModifiedTime'
    };
    return mapping[timeField] || '';
}
combineDateTime(changedField) {
    const dateTimeMap = {
        'Start_Date__c': 'startTime',
        'Start_Time__c': 'Start_Date__c',
        'End_Date__c': 'endTime',
        'End_Time__c': 'End_Date__c',
        'Registration_Open_Date__c': 'registrationOpenTime',
        'Registration_Open_Time__c': 'Registration_Open_Date__c',
        'Registration_Close_Date__c': 'registrationCloseTime',
        'Registration_Close_Time__c': 'Registration_Close_Date__c',
        'Late_Registration_Date__c': 'lateRegistrationTime',
        'Late_Registration_Time__c': 'Late_Registration_Date__c',
        'Created_Date__c': 'createdTime',
        'Created_Time__c': 'Created_Date__c',
        'Last_Modified_Date__c': 'lastModifiedTime',
        'Last_Modified_Time__c': 'Last_Modified_Date__c'
    };

    let dateField, timeKey;
    
    if (changedField.includes('Time__c')) {
        dateField = dateTimeMap[changedField];
        timeKey = this.getTimeKey(changedField);
    } else {
        timeKey = dateTimeMap[changedField];
        dateField = changedField;
    }

    if (dateField && timeKey) {
        const dateValue = this.newAcademicTerm[dateField]?.split('T')[0] || this.newAcademicTerm[dateField];
        const timeValue = this.timeInputs[timeKey];

        if (dateValue) {
            try {
                // Create a Date object and format it properly
                const dateTime = new Date(`${dateValue}T${timeValue || '00:00:00'}`);
                this.newAcademicTerm[dateField] = dateTime.toISOString();
            } catch (error) {
                console.error('Error creating datetime:', error);
                // Fallback to just the date
                this.newAcademicTerm[dateField] = `${dateValue}T00:00:00.000Z`;
            }
        }
    }
}

get startDateOnly() {
    return this.newAcademicTerm.Start_Date__c ? 
           this.newAcademicTerm.Start_Date__c.split('T')[0] : '';
}

get endDateOnly() {
    return this.newAcademicTerm.End_Date__c ? 
           this.newAcademicTerm.End_Date__c.split('T')[0] : '';
}

get registrationOpenDateOnly() {
    return this.newAcademicTerm.Registration_Open_Date__c ? 
           this.newAcademicTerm.Registration_Open_Date__c.split('T')[0] : '';
}

get registrationCloseDateOnly() {
    return this.newAcademicTerm.Registration_Close_Date__c ? 
           this.newAcademicTerm.Registration_Close_Date__c.split('T')[0] : '';
}

get lateRegistrationDateOnly() {
    return this.newAcademicTerm.Late_Registration_Date__c ? 
           this.newAcademicTerm.Late_Registration_Date__c.split('T')[0] : '';
}

get createdDateOnly() {
    return this.newAcademicTerm.Created_Date__c ? 
           this.newAcademicTerm.Created_Date__c.split('T')[0] : '';
}

get lastModifiedDateOnly() {
    return this.newAcademicTerm.Last_Modified_Date__c ? 
           this.newAcademicTerm.Last_Modified_Date__c.split('T')[0] : '';
}

async handleSaveAcademicTerm() {
    const fields = {};
    fields[NAME_FIELD.fieldApiName] = this.newAcademicTerm.Name;
    fields[ACADEMIC_YEAR_FIELD.fieldApiName] = this.newAcademicTerm.Academic_Year__c;
    fields[IS_ACTIVE_FIELD.fieldApiName] = this.newAcademicTerm.IsActive__c;
    fields[CREATED_DATE_FIELD.fieldApiName] = this.newAcademicTerm.Created_Date__c;
    fields[END_DATE_FIELD.fieldApiName] = this.newAcademicTerm.End_Date__c;
    fields[LAST_MODIFIED_DATE_FIELD.fieldApiName] = this.newAcademicTerm.Last_Modified_Date__c;
    fields[LATE_REG_DATE_FIELD.fieldApiName] = this.newAcademicTerm.Late_Registration_Date__c;
    fields[REG_CLOSE_DATE_FIELD.fieldApiName] = this.newAcademicTerm.Registration_Close_Date__c;
    fields[REG_OPEN_DATE_FIELD.fieldApiName] = this.newAcademicTerm.Registration_Open_Date__c;
    fields[SEASON_FIELD.fieldApiName] = this.newAcademicTerm.Season__c;
    fields[START_DATE_FIELD.fieldApiName] = this.newAcademicTerm.Start_Date__c;

    const recordInput = { apiName: ACADEMIC_TERM_OBJECT.objectApiName, fields };

    try {
        const result = await createRecord({
            apiName: 'Academic_Term__c',
            fields: this.newAcademicTerm
        });

        // Add new term to options
        this.academicTermOptionss.push({
            label: result.fields.Name.value,
            value: result.id
        });

        // Set the newly created term as selected
        this.termDurations[this.currentTermIndex].academicTermId = result.id;

        this.showToast('Success', 'Academic Term created successfully.', 'success');
        this.handleModalClose();
    } catch (error) {
        console.error('Error creating Academic Term:', error);
        this.showToast('Error', 'Failed to create Academic Term.', 'error');
    }
}
handleModalClose() {
    this.showModal = false;
    this.newAcademicTerm = {
        Name: '',
        Academic_Year__c: '',
        IsActive__c: true,
        Created_Date__c: '',
        End_Date__c: '',
        Last_Modified_Date__c: '',
        Late_Registration_Date__c: '',
        Registration_Close_Date__c: '',
        Registration_Open_Date__c: '',
        Season__c: '',
        Start_Date__c: ''
    };
}
    /////////////////////////////
    @track academicProgramOptions = [];
    @track programAliasMap = {};
    @track noOfTermsMap = {};
    @track totalDurationMap = {};
    @track startingYearOptions = [];
    @track intakeOptions = [];
    @track workingDaysOptions = [];
    @track campusFormatOptions = [];
    @track termDurations = [];
    @track academicYearOptions = [];
    @track allowSameDayTerms = true;
    @track isSaveButtonDisabled = true;
    @track isDuplicateFound = false;

    showSpinner = false;

    @track formData = {
        academicProgram: '',
        programAlias: '',
        startingYear: '',
        intake: '',
        workingDays: [],
        intakeStrength: '',
        startDate: '',
        endDate: '',
        totalDuration: '',
        noOfTerms: '',
        campusFormat: '',
        academicYear: '',
        maximumProgramDuration: ''
    };

    // EXISTING PROPERTIES (kept for backward compatibility)
    @api requirementMode; // Read-only (kept for existing functionality)
    @track localRequirementMode; // Mutable copy (kept for existing logic)
    
    // NEW PROPERTIES FOR CUSTOM METADATA
    @track masterConfiguration = null;
    @track configurationOptions = [];
    @track selectedInstitutionType = 'College'; // Default
    @track isConfigurationLoaded = false;
    @track masterRequirementMode = false; // Master control from metadata
    @track useCustomMetadata = true; // Toggle to enable/disable custom metadata
    
    selectedWorkingDaysForPickList = [];
    @api isChecked;
    saveCalled = false;

    /**
     * UPDATED: connectedCallback with Custom Metadata integration
     */
    async connectedCallback() {
        try {
            this.showSpinner = true;
            
            // Try to load custom metadata configuration first
            if (this.useCustomMetadata) {
                await this.loadMasterConfiguration();
            }
            
            // If custom metadata failed or disabled, fall back to existing logic
            if (!this.isConfigurationLoaded) {
                this.initializeExistingLogic();
            }
            
            // Initialize other dropdowns (existing functionality)
            this.populateStartingYears();
            this.populateIntakeMonths();
            
            this.showSpinner = false;
        } catch (error) {
            console.error('Error in connectedCallback:', error);
            // Fallback to existing logic if custom metadata fails
            this.initializeExistingLogic();
            this.showSpinner = false;
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
                this.localRequirementMode = this.masterRequirementMode; // Sync with existing logic
                
                // Set working days based on configuration
                await this.applyWorkingDaysConfiguration();
                
                this.isConfigurationLoaded = true;
                
                console.log('Master Configuration Loaded:', {
                    institutionType: this.selectedInstitutionType,
                    requirementMode: this.masterRequirementMode,
                    isFlexibleMode: !this.masterRequirementMode
                });
                
                // IMPORTANT: Clear any auto-populated dates if in flexible mode
                if (!this.masterRequirementMode) {
                    this.clearTermDates();
                }
            }
        } catch (error) {
            console.error('Error loading master configuration:', error);
            this.isConfigurationLoaded = false;
            throw error;
        }
    }

    @track academicTermOptions = [];

   
    handleAcademicTermChange(event) {
    const termIndex = parseInt(event.currentTarget.dataset.termIndex, 10);
    const selectedValue = event.detail.value;

    this.termDurations = [...this.termDurations];
    this.termDurations[termIndex].academicTermId = selectedValue;

    // Optional: Sync with formData if needed
    this.formData[`academicTerm_${termIndex + 1}`] = selectedValue;
}

    /**
     * NEW: Apply working days from configuration
     */
    async applyWorkingDaysConfiguration() {
        try {
            if (this.masterConfiguration.Default_Working_Days__c) {
                const workingDaysList = await parseWorkingDays({ 
                    workingDaysString: this.masterConfiguration.Default_Working_Days__c 
                });
                
                // Set up working days options
                const allDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                this.workingDaysOptions = allDays.map(day => ({ label: day, value: day }));
                
                if (this.masterRequirementMode) {
                    // Required mode: Use configured days
                    this.selectedWorkingDaysForPickList = workingDaysList;
                    this.formData.workingDays = [...workingDaysList];
                } else {
                    // Manual mode: All days available, use configured as default
                    this.selectedWorkingDaysForPickList = workingDaysList;
                    this.formData.workingDays = [...workingDaysList];
                }
            } else {
                // Fallback to existing logic
                this.initializeWorkingDaysExisting();
            }
        } catch (error) {
            console.error('Error applying working days configuration:', error);
            // Fallback to existing logic
            this.initializeWorkingDaysExisting();
        }
    }

    /**
     * NEW: Fallback to existing logic when custom metadata fails
     */
    initializeExistingLogic() {
        this.localRequirementMode = this.requirementMode;
        this.masterRequirementMode = this.requirementMode || false;
        this.initializeWorkingDaysExisting();
    }

    /**
     * NEW: Initialize working days using existing logic
     */
    initializeWorkingDaysExisting() {
        // Initialize working days with existing logic
        if (!this.masterRequirementMode) {
            this.populateWorkingDays(); // sets all days as selected
        } else {
            this.clearWorkingDays(); // no selection initially
        }
    }

    // EXISTING METHOD (kept unchanged)
    populateWorkingDays() {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        this.workingDaysOptions = days.map(day => ({ label: day, value: day }));
        this.selectedWorkingDaysForPickList = [...days]; // All days selected
        this.formData.workingDays = [...days];
    }

    // EXISTING METHOD (updated to sync with master configuration)
    handleCheckbox(event) {
        this.localRequirementMode = event.target.checked;
        
        // If custom metadata is loaded, show warning about override
        if (this.isConfigurationLoaded) {
            this.showToast('Info', 'Manual override of master configuration applied', 'info');
        }

        // Toggle working days selection based on checkbox state
        if (event.target.checked) {
            this.clearWorkingDays(); // No days selected
        } else {
            this.populateWorkingDays(); // All days selected
            // Clear auto-calculated term dates when switching to flexible mode
            this.clearTermDates();
        }

        // Regenerate term durations to reflect manual/automatic mode
        this.generateTermDurations();

        // Dispatch navigate event if needed
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                isChecked: event.target.checked,
                currentTab: 'intake',
                direction: null,
                masterRequirementMode: this.masterRequirementMode // Include master config
            }
        }));
    }

    // EXISTING METHOD (kept unchanged)
    clearWorkingDays() {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        this.workingDaysOptions = days.map(day => ({ label: day, value: day }));
        this.selectedWorkingDaysForPickList = []; // No days selected
        this.formData.workingDays = [];
    }

    // EXISTING METHOD (kept unchanged)
    clearTermDates() {
        this.termDurations.forEach(term => {
            this.formData[term.name] = ''; // Clear duration
            this.formData[term.startDateName] = ''; // Clear start date
            this.formData[term.endDateName] = ''; // Clear end date
        });
    }

    // EXISTING METHODS (kept unchanged)
    populateStartingYears() {
        const currentYear = new Date().getFullYear();
        this.startingYearOptions = Array.from({ length: 5 }, (_, i) => ({
            label: `${currentYear + i}`,
            value: `${currentYear + i}`
        }));
    }

    populateIntakeMonths() {
        const months = [
            'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
            'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
        ];
        this.intakeOptions = months.map(month => ({ label: month, value: month }));
    }

    // EXISTING WIRE METHODS (kept unchanged)
    @wire(getAcademicPrograms)
    wiredPrograms({ error, data }) {
        if (data) {
            this.academicProgramOptions = data;
        } else if (error) {
            console.error('Error fetching Academic Programs:', error);
        }
    }

    @wire(getProgramAliases)
    wiredProgramAliases({ error, data }) {
        if (data) {
            this.programAliasMap = data;
        } else if (error) {
            console.error('Error fetching Program Aliases:', error);
        }
    }
    
    @wire(getNoofTerms)
    wiredNoOfTerms({ error, data }) {
        if (data) {
            this.noOfTermsMap = data;
        } else if (error) {
            console.error('Error fetching No of Terms:', error);
        }
    }

    // NEW: Wire method to get Academic Year picklist values
@wire(getAcademicYearPicklistValues)
wiredAcademicYears({ error, data }) {
    if (data) {
        // Transform the list of strings into the format expected by lightning-combobox (label/value pairs)
        this.academicYearOptions = data.map(year => ({ label: year, value: year }));
    } else if (error) {
        console.error('Error fetching Academic Years:', error);
        // Optionally, set a default or show an error message to the user
        this.academicYearOptions = [{ label: 'Error loading options', value: '' }];
    }
}

    @wire(getTotalDuration)
    wiredTotalDuration({ error, data }) {
        if (data) {
            this.totalDurationMap = data;
        } else if (error) {
            console.error('Error fetching Total Duration:', error);
        }
    }
    
    @wire(getCampusFormats)
    wiredCampusFormats({ error, data }) {
        if (data) {
            this.campusFormatOptions = data;
        } else if (error) {
            console.error('Error fetching Campus Formats:', error);
        }
    }

    // FIXED: handleChange method with correct field name mapping
    handleChange(event) {
    const { name, value } = event.target;
    console.log(`Changed ${name}: ${value}`);

    // Handle different field names properly
    if (name === 'workingdays') {
        this.formData.workingDays = value;
        this.selectedWorkingDaysForPickList = value;
        console.log('Working days updated:', this.formData.workingDays);
        // Trigger calculations when working days change
        this.triggerDateCalculations();
    }
    else if (name === 'starting year') { // Note the space in the name from template
        this.formData.startingYear = value;
        console.log('Starting year updated:', this.formData.startingYear);
        // Trigger calculations when starting year changes
        this.triggerDateCalculations();
    }
    else if (name === 'intake') {
        this.formData.intake = value;
        console.log('Intake updated:', this.formData.intake);
        // Trigger calculations when intake changes
        this.triggerDateCalculations();
    }
    else if (name === 'startDate') {
        this.formData.startDate = value;
        // Calculate end date when start date changes manually
        this.calculateEndDate();
    }
     else if (name === 'academicYear') {
        this.formData.academicYear = value;
    }
    else if (name === 'maximumProgramDuration') {
        this.formData.maximumProgramDuration = value;
    }
    else {
        this.formData[name] = value;
    }
    

    // If academic program changes, update related fields
    if (name === 'academicProgram') {
        this.formData = {
            ...this.formData,
            programAlias: this.programAliasMap[value] || '',
            noOfTerms: this.noOfTermsMap[value] || '',
            totalDuration: this.totalDurationMap[value] || ''
        };
        this.generateTermDurations();
        
        // Trigger date calculations if we have all required fields
        setTimeout(() => {
            this.triggerDateCalculations();
        }, 100);
    }

    // Handle term duration changes
    if (name.startsWith('termDuration_')) {
        const termIndex = parseInt(name.split('_')[1], 10) - 1;
        // Validate and update term duration
        if (this.validateTermDurations()) {
            this.termDurations[termIndex].value = value;
            this.formData[name] = value;
        }
        // ONLY recalculate in strict mode
        if (this.masterRequirementMode) {
            this.recalculateFromTerm(termIndex);
        }
    }

    // Handle term start date changes
    else if (name.startsWith('termStartDate_')) {
        const termIndex = parseInt(name.split('_')[1], 10) - 1;
        // Validate and update term start date
        if (this.validateTermDates(event)) {
            this.termDurations[termIndex].startDate = value;
            this.formData[name] = value;
            // ONLY recalculate in strict mode
            if (this.masterRequirementMode) {
                this.recalculateFromTerm(termIndex);
            }
        }
    }

    // Handle term end date changes
    else if (name.startsWith('termEndDate_')) {
        const termIndex = parseInt(name.split('_')[1], 10) - 1;
        // Validate and update term end date
        if (this.validateTermDates(event)) {
            this.termDurations[termIndex].endDate = value;
            this.formData[name] = value;
            // ONLY recalculate subsequent terms in strict mode
            if (this.masterRequirementMode) {
                this.recalculateFromTerm(termIndex + 1);
            }
        }
    }

    // ADD: Handle minimum credit changes
    else if (name.startsWith('termMinCredit_')) {
        const termIndex = parseInt(name.split('_')[1], 10) - 1;
        if (this.validateCreditRange(event, termIndex, 'min')) {
            this.termDurations[termIndex].minCredit = value;
            this.formData[name] = value;
        }
    }

    // ADD: Handle maximum credit changes
    else if (name.startsWith('termMaxCredit_')) {
        const termIndex = parseInt(name.split('_')[1], 10) - 1;
        if (this.validateCreditRange(event, termIndex, 'max')) {
            this.termDurations[termIndex].maxCredit = value;
            this.formData[name] = value;
        }
    }

    // Always update save button state after any change
    setTimeout(() => {
        this.updateSaveButtonState();
    }, 0);
}

validateCreditRange(event, termIndex, type) {
    const { name, value } = event.target;
    const numericValue = parseInt(value, 10);
    
    // Skip validation if value is empty
    if (!value || value === '') {
        event.target.setCustomValidity('');
        event.target.reportValidity();
        return true;
    }
    
    // Validate that value is a positive number
    if (isNaN(numericValue) || numericValue < 0) {
        event.target.setCustomValidity('Credit value must be a positive number.');
        event.target.reportValidity();
        return false;
    }
    
    const currentTerm = this.termDurations[termIndex];
    
    if (type === 'min') {
        // Check if min credit is less than max credit (if max credit exists)
        const maxCredit = parseInt(this.formData[currentTerm.maxCreditName], 10);
        if (!isNaN(maxCredit) && numericValue > maxCredit) {
            event.target.setCustomValidity('Minimum credit cannot be greater than maximum credit.');
            event.target.reportValidity();
            return false;
        }
    } else if (type === 'max') { 
        // Check if max credit is greater than min credit (if min credit exists)
        const minCredit = parseInt(this.formData[currentTerm.minCreditName], 10);
        if (!isNaN(minCredit) && numericValue < minCredit) {
            event.target.setCustomValidity('Maximum credit cannot be less than minimum credit.');
            event.target.reportValidity();
            return false;
        }
    }
    
    // Clear any previous validation errors
    event.target.setCustomValidity('');
    event.target.reportValidity();
    return true;
}

    // NEW: Helper method to trigger date calculations with proper checks
    triggerDateCalculations() {
        console.log('triggerDateCalculations called');
        console.log('Checking required fields:', {
            startingYear: this.formData.startingYear,
            intake: this.formData.intake,
            workingDays: this.formData.workingDays,
            totalDuration: this.formData.totalDuration
        });

        // Only calculate if we have all required fields
        if (this.formData.startingYear && 
            this.formData.intake && 
            this.formData.workingDays && 
            this.formData.workingDays.length > 0) {
            
            console.log('All required fields present, calling populateStartDate');
            this.populateStartDate();
        } else {
            console.log('Missing required fields for date calculation');
        }
    }

    // UPDATED: recalculateFromTerm - only auto-calculate in strict mode
    recalculateFromTerm(startIndex) {
        console.log(`recalculateFromTerm called with startIndex=${startIndex}, masterRequirementMode=${this.masterRequirementMode}`);
        
        // ONLY auto-calculate in strict mode
        if (!this.masterRequirementMode) {
            console.log('Flexible mode: Skipping auto-calculation, preserving manual entries');
            return;
        }
        
        // Ensure valid start index
        if (startIndex < 0 || startIndex >= this.termDurations.length) {
            console.warn(`Invalid startIndex ${startIndex} for recalculateFromTerm`);
            return;
        }
        
        // Create a map of selected working days for faster lookups
        const selectedDays = {};
        this.formData.workingDays.forEach(day => {
            selectedDays[day] = true;
        });
        
        // For each term starting from startIndex, calculate end date (and next term's start date)
        for (let i = startIndex; i < this.termDurations.length; i++) {
            const term = this.termDurations[i];
            const termDuration = parseInt(this.formData[term.name], 10) || 0;
            
            if (termDuration <= 0) {
                console.warn(`Term ${i + 1} has invalid duration: ${termDuration}`);
                continue;
            }
            
            // Skip if start date is missing
            if (!this.formData[term.startDateName]) {
                console.warn(`Term ${i + 1} has missing start date`);
                continue;
            }

            // We already have the start date set, so calculate end date for this term
            const currentDate = new Date(term.startDate);
            const workingDaysPerWeek = this.formData.workingDays.length;
            const totalWorkingDays = termDuration * workingDaysPerWeek;
            
            let workingDaysAdded = 0;
            let termEndDate = new Date(currentDate);
            
            // Check if the start date itself is a working day
            const startDayName = currentDate.toLocaleDateString('en-US', { weekday: 'long' });
            if (selectedDays[startDayName]) {
                workingDaysAdded = 1; // Count the start date as a working day
            }
            
            while (workingDaysAdded < totalWorkingDays) {
                termEndDate.setDate(termEndDate.getDate() + 1);
                const dayName = termEndDate.toLocaleDateString('en-US', { weekday: 'long' });
                
                if (selectedDays[dayName]) {
                    workingDaysAdded++;
                }
            }
            
            // Set the term end date
            term.endDate = termEndDate.toISOString().split('T')[0];
            this.formData[term.endDateName] = term.endDate;
            
            // ONLY auto-set next term's start date in STRICT MODE
            if (i < this.termDurations.length - 1) {
                const nextTerm = this.termDurations[i + 1];
                nextTerm.startDate = term.endDate;
                this.formData[nextTerm.startDateName] = term.endDate;
            }
            
            console.log(`Recalculated Term ${i + 1}: Start=${term.startDate}, End=${term.endDate}, Duration=${termDuration}`);
        }
    }

    // Fixed getMonthNumber method
    getMonthNumber(monthName) {
        const months = [
            'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
            'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
        ];
        return months.indexOf(monthName) + 1;
    }

    // FIXED: populateStartDate method
    populateStartDate() {
        console.log('populateStartDate called');
        console.log('Current form data:', {
            startingYear: this.formData.startingYear,
            intake: this.formData.intake,
            workingDays: this.formData.workingDays,
            totalDuration: this.formData.totalDuration
        });

        const startingYear = this.formData.startingYear;
        const intake = this.formData.intake;
        const selectedWorkingDays = this.formData.workingDays || [];

        if (!startingYear || !intake || !selectedWorkingDays.length) {
            console.warn('Start Date not set: Missing starting year, intake, or working days');
            return;
        }

        const monthIndex = this.getMonthNumber(intake);
        if (monthIndex < 1 || monthIndex > 12) {
            console.error('Invalid month selection:', intake);
            return;
        }

        // Start at the first of the month
        const date = new Date(startingYear, monthIndex - 1, 1); // JS months are 0-indexed

        // Map day names to indexes (include all selected days)
        const allDays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        const workingDayIndexes = allDays
            .map((day, index) => ({ day, index }))
            .filter(entry => selectedWorkingDays.includes(entry.day))
            .map(entry => entry.index);

        // Early exit if no valid working days
        if (workingDayIndexes.length === 0) {
            console.warn('No valid working days selected');
            return;
        }

        // Increment date until it matches a working day, with safety cap
        let attempts = 0;
        while (!workingDayIndexes.includes(date.getDay())) {
            date.setDate(date.getDate() + 1);
            if (++attempts > 31) {
                console.error('Could not find a valid working day in the selected month');
                return;
            }
        }

        // Format the date
        const yyyy = date.getFullYear();
        const mm = (date.getMonth() + 1).toString().padStart(2, '0');
        const dd = date.getDate().toString().padStart(2, '0');
        const formattedDate = `${yyyy}-${mm}-${dd}`;

        this.formData.startDate = formattedDate;
        console.log('Final Start Date set:', this.formData.startDate);

        // Set the start date for the first term in STRICT MODE
        if (this.masterRequirementMode && this.termDurations.length > 0) {
            this.termDurations[0].startDate = formattedDate;
            this.formData[this.termDurations[0].startDateName] = formattedDate;
        }

        // After setting the start date, calculate the end date
        this.calculateEndDate();
    }

    // FIXED: calculateEndDate method
    calculateEndDate() {
        console.log('calculateEndDate called');
        console.log('calculateEndDate inputs:', {
            startDate: this.formData.startDate,
            totalDuration: this.formData.totalDuration,
            workingDays: this.formData.workingDays
        });

        if (
            !this.formData.startDate ||
            !this.formData.totalDuration ||
            !this.formData.workingDays ||
            this.formData.workingDays.length === 0
        ) {
            console.warn('End Date not set: Missing required values', {
                startDate: this.formData.startDate,
                totalDuration: this.formData.totalDuration,
                workingDays: this.formData.workingDays
            });
            return;
        }

        const startDate = new Date(this.formData.startDate);
        const totalWeeks = parseInt(this.formData.totalDuration, 10);
        if (isNaN(totalWeeks) || totalWeeks <= 0) {
            console.warn('Invalid Total Duration:', this.formData.totalDuration);
            return;
        }

        // Use all selected working days
        const validWorkingDays = this.formData.workingDays;
        const totalWorkingDays = totalWeeks * validWorkingDays.length;

        // Create a Set of valid working day indexes (0 = Sunday ... 6 = Saturday)
        const dayNameToIndex = {
            Sunday: 0,
            Monday: 1,
            Tuesday: 2,
            Wednesday: 3,
            Thursday: 4,
            Friday: 5,
            Saturday: 6
        };
        const workingDayIndexes = new Set(validWorkingDays.map(day => dayNameToIndex[day]));

        let endDate = new Date(startDate);
        let workingDaysAdded = 0;

        // Check if start date is a working day and count it
        if (workingDayIndexes.has(endDate.getDay())) {
            workingDaysAdded = 1;
        }

        // Continue adding days until we reach the total working days
        while (workingDaysAdded < totalWorkingDays) {
            endDate.setDate(endDate.getDate() + 1);
            const dayOfWeek = endDate.getDay();
            if (workingDayIndexes.has(dayOfWeek)) {
                workingDaysAdded++;
            }
        }

        // Format the end date as YYYY-MM-DD
        const yyyy = endDate.getFullYear();
        const mm = (endDate.getMonth() + 1).toString().padStart(2, '0');
        const dd = endDate.getDate().toString().padStart(2, '0');
        this.formData.endDate = `${yyyy}-${mm}-${dd}`;

        console.log('Calculated End Date:', this.formData.endDate);
        console.log(`Total working days counted: ${workingDaysAdded}`);

        // Calculate term dates in STRICT MODE
        if (this.masterRequirementMode && this.termDurations && this.termDurations.length > 0) {
            this.calculateTermDates();
        }
    }

    // UPDATED: calculateTermDates to use masterRequirementMode
    calculateTermDates() {
        console.log('calculateTermDates called');
        // FIXED: Check masterRequirementMode instead of localRequirementMode
        if (!this.masterRequirementMode) return; // Skip if not in strict mode
        
        if (!this.formData.startDate || !this.formData.workingDays || this.formData.workingDays.length === 0 || this.termDurations.length === 0) {
            console.warn('Missing required values for calculating term dates.');
            return;
        }
        
        const selectedDays = {};
        this.formData.workingDays.forEach(day => {
            selectedDays[day] = true;
        });
        
        let currentDate = new Date(this.formData.startDate);
        
        for (let i = 0; i < this.termDurations.length; i++) {
            const term = this.termDurations[i];
            const termDuration = parseInt(this.formData[term.name], 10) || 0;
            
            if (i > 0) {
                const prevTermEndDate = new Date(this.termDurations[i - 1].endDate);
                currentDate = new Date(prevTermEndDate);
                currentDate.setDate(currentDate.getDate() + 1);
                term.startDate = currentDate.toISOString().split('T')[0];
            }
            
            const workingDaysPerWeek = this.formData.workingDays.length;
            const totalWorkingDays = termDuration * workingDaysPerWeek;
            let workingDaysAdded = 0;
            let termEndDate = new Date(currentDate);
            
            const startDayName = termEndDate.toLocaleDateString('en-US', { weekday: 'long' });
            if (selectedDays[startDayName]) workingDaysAdded++;
            
            while (workingDaysAdded < totalWorkingDays) {
                termEndDate.setDate(termEndDate.getDate() + 1);
                const dayName = termEndDate.toLocaleDateString('en-US', { weekday: 'long' });
                if (selectedDays[dayName]) workingDaysAdded++;
            }
            
            term.endDate = termEndDate.toISOString().split('T')[0];
            this.formData[term.startDateName] = term.startDate;
            this.formData[term.endDateName] = term.endDate;
            currentDate = new Date(term.endDate);
        }
    }

    handleTextChange(event) {
    const { name, value } = event.target;
    this.formData[name] = value;

    // Check if the field being updated is a Term Duration field
    if (name.startsWith('termDuration_')) {
        this.validateTermDurations();
    }
    
    // ADD: Handle credit field changes
    if (name.startsWith('termMinCredit_') || name.startsWith('termMaxCredit_')) {
        const termIndex = parseInt(name.split('_')[1], 10) - 1;
        const type = name.startsWith('termMinCredit_') ? 'min' : 'max';
        this.validateCreditRange(event, termIndex, type);
    }
    
    // Update save button state after any change
    setTimeout(() => {
        this.updateSaveButtonState();
    }, 0);
}

    // UPDATED: validateTermDurations to use masterRequirementMode
    validateTermDurations() {
        // Use masterRequirementMode instead of localRequirementMode
        if (!this.masterRequirementMode) return true;

        const totalDuration = parseInt(this.formData.totalDuration, 10) || 0;
        const sumOfTerms = this.termDurations.reduce((sum, term) => {
            return sum + (parseInt(this.formData[term.name], 10) || 0);
        }, 0);

        const termInputs = this.template.querySelectorAll('lightning-input[name^="termDuration_"]');
        if (sumOfTerms > totalDuration) {
            this.showToast('Error', `Total term durations (${sumOfTerms}) exceed total program duration (${totalDuration}).`, 'error');
            return false;
        }

        termInputs.forEach(input => {
            input.setCustomValidity('');
            input.reportValidity();
        });

        return true;
    }

    // UPDATED: validateTermDates to use masterRequirementMode
    validateTermDates(event) {
        // Use masterRequirementMode instead of localRequirementMode
        if (!this.masterRequirementMode) {
            event.target.setCustomValidity('');
            event.target.reportValidity();
            return true;
        }

        // Full validation only when in strict mode
        const { name } = event.target;
        const termIndex = parseInt(name.split('_')[1], 10) - 1;
        const currentTerm = this.termDurations[termIndex];
        const currentStartDate = this.formData[currentTerm.startDateName];
        const currentEndDate = this.formData[currentTerm.endDateName];
        
        // Skip validation if start or end date is missing
        if (!currentStartDate || !currentEndDate) return true;

        if (currentStartDate && currentEndDate && new Date(currentStartDate) >= new Date(currentEndDate)) {
            event.target.setCustomValidity('Start date must be before end date.');
            event.target.reportValidity();
            return false;
        }

        if (currentStartDate && this.formData.startDate && new Date(currentStartDate) < new Date(this.formData.startDate)) {
            event.target.setCustomValidity('Term start date cannot be before program start date.');
            event.target.reportValidity();
            return false;
        }

        if (currentEndDate && this.formData.endDate && new Date(currentEndDate) > new Date(this.formData.endDate)) {
            event.target.setCustomValidity('Term end date cannot be after program end date.');
            event.target.reportValidity();
            return false;
        }

        if (termIndex > 0 && name.startsWith('termStartDate_')) {
            const prevTerm = this.termDurations[termIndex - 1];
            const prevEndDate = this.formData[prevTerm.endDateName];
            if (prevEndDate && currentStartDate && new Date(currentStartDate) < new Date(prevEndDate)) {
                event.target.setCustomValidity('Term start date cannot be before previous term end date.');
                event.target.reportValidity();
                return false;
            }
        }

        if (termIndex < this.termDurations.length - 1 && name.startsWith('termEndDate_')) {
            const nextTerm = this.termDurations[termIndex + 1];
            const nextStartDate = this.formData[nextTerm.startDateName];
            if (currentEndDate && nextStartDate && new Date(currentEndDate) > new Date(nextStartDate)) {
                event.target.setCustomValidity('Term end date cannot be after next term start date.');
                event.target.reportValidity();
                return false;
            }
        }

        event.target.setCustomValidity('');
        event.target.reportValidity();
        return true;
    }

    // UPDATED: areRequiredFieldsFilled to use masterRequirementMode
    areRequiredFieldsFilled() {
        // In flexible mode, we have different requirements
        if (!this.masterRequirementMode) return true;

        const requiredInputs = this.template.querySelectorAll('[required]');
        let allFilled = true;
        requiredInputs.forEach(input => {
            if (!input.value || (Array.isArray(input.value) && input.value.length === 0)) {
                allFilled = false;
            }
        });
        return allFilled;
    }

    // UPDATED: hasValidationErrors to use masterRequirementMode
    hasValidationErrors() {
        // In flexible mode, be less strict about validation
        if (!this.masterRequirementMode) return false;

        const allInputs = this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-dual-listbox');
        let hasErrors = false;
        allInputs.forEach(input => {
            if (input.validity && !input.validity.valid) {
                hasErrors = true;
            }
        });
        return hasErrors;
    }

    updateSaveButtonState() {
        const requiredFieldsFilled = this.areRequiredFieldsFilled();
        const noValidationErrors = !this.hasValidationErrors();
        const noDuplicates = !this.isDuplicateFound;

        this.isSaveButtonDisabled = !(requiredFieldsFilled && noValidationErrors && noDuplicates);
    }

    startDateValidation(){
        const curr = new Date().toISOString().split('T')[0];
        if (this.formData.startDate < curr) {
            return true;
        }
    }

    // UPDATED: checkFormValidity to use masterRequirementMode
    checkFormValidity() {
        // In flexible mode, only check basic required fields
        if (!this.masterRequirementMode) return true;

        const requiredFieldsValid = this.validateRequiredFields();
        const termDurationsValid = this.validateTermDurations();
        const termDatesValid = this.validateAllTermDates();

        // Allow saving with partial data in flexible mode
        if (!this.masterRequirementMode) {
            return requiredFieldsValid;
        }

        return requiredFieldsValid && termDurationsValid && termDatesValid;
    }

    validateRequiredFields() {
        const requiredInputs = this.template.querySelectorAll('[required]');
        let allValid = true;
        
        requiredInputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                allValid = false;
            }
        });
        
        return allValid;
    }

    // UPDATED: validateAllTermDates to use masterRequirementMode
    validateAllTermDates() {
        // Skip term date validation in flexible mode
        if (!this.masterRequirementMode) return true;

        const termDateInputs = this.template.querySelectorAll('lightning-input[name^="termStartDate_"], lightning-input[name^="termEndDate_"]');
        let allValid = true;
        termDateInputs.forEach(input => {
            if (!input.checkValidity()) {
                allValid = false;
            }
        });
        return allValid;
    }

    handleTermChange(event) {
        this.formData.noOfTerms = event.target.value;
        this.generateTermDurations();
        this.updateSaveButtonState();
    }

    handleNumberValidation(event) {
        const charCode = event.which ? event.which : event.keyCode;
        if (charCode < 48 || charCode > 57) {
            event.preventDefault();
        }
    }

    // UPDATED: generateTermDurations to preserve manual entries in flexible mode
generateTermDurations() {
    console.log('generateTermDurations called');
    // Use masterRequirementMode for determining number of terms
    const noOfTerms = this.masterRequirementMode
        ? parseInt(this.formData.noOfTerms, 10) || 0
        : 6; // Default to 6 terms in flexible mode

    this.termDurations = Array.from({ length: noOfTerms }, (_, index) => {
        const termId = `term_${index + 1}`;
        const label = `Semester ${index + 1} Duration (Weeks)`;
        const name = `termDuration_${index + 1}`;
        const startDateName = `termStartDate_${index + 1}`;
        const endDateName = `termEndDate_${index + 1}`;
        // ADD: Min and Max Credit field names
        const minCreditName = `termMinCredit_${index + 1}`;
        const maxCreditName = `termMaxCredit_${index + 1}`;
        
        let value = '';
        let startDate = '';
        let endDate = '';
        let academicTermName = '';
        let academicTermId = '';
        // ADD: Min and Max Credit values
        let minCredit = '';
        let maxCredit = '';

        if (this.masterRequirementMode) {
            // STRICT MODE: Auto-calculate durations
            const totalDuration = parseInt(this.formData.totalDuration, 10) || 0;
            const baseDuration = Math.floor(totalDuration / noOfTerms);
            const extra = index >= (noOfTerms - (totalDuration % noOfTerms)) ? 1 : 0;
            value = (baseDuration + extra).toString();
            // Only set start date for first term if program start date exists
            if (index === 0 && this.formData.startDate) {
                startDate = this.formData.startDate;
            }
        } else {
            // FLEXIBLE MODE: Preserve existing user input, don't overwrite
            value = this.formData[name] || '';
            startDate = this.formData[startDateName] || '';
            endDate = this.formData[endDateName] || '';
            // ADD: Preserve credit values
            minCredit = this.formData[minCreditName] || '';
            maxCredit = this.formData[maxCreditName] || '';
        }

        return {
            id: termId,
            label,
            name,
            value,
            startDateName,
            startDate,
            endDateName,
            endDate,
            // ADD: Min and Max Credit properties
            minCreditName,
            minCredit,
            maxCreditName,
            maxCredit,
            academicTermName,
            academicTermId
        };
    });

    // Only update formData for fields that are empty to preserve user input
    this.termDurations.forEach(term => {
        if (this.masterRequirementMode) {
            // In strict mode, always use calculated values
            this.formData[term.name] = term.value;
            this.formData[term.startDateName] = term.startDate;
            this.formData[term.endDateName] = term.endDate;
            // ADD: Set credit values in strict mode
            this.formData[term.minCreditName] = term.minCredit;
            this.formData[term.maxCreditName] = term.maxCredit;
        } else {
            // In flexible mode, only update if formData is empty (preserve user input)
            if (!this.formData[term.name]) this.formData[term.name] = term.value;
            if (!this.formData[term.startDateName]) this.formData[term.startDateName] = term.startDate;
            if (!this.formData[term.endDateName]) this.formData[term.endDateName] = term.endDate;
            // ADD: Preserve credit values in flexible mode
            if (!this.formData[term.minCreditName]) this.formData[term.minCreditName] = term.minCredit;
            if (!this.formData[term.maxCreditName]) this.formData[term.maxCreditName] = term.maxCredit;
        }
    });

    // Only calculate term dates in STRICT MODE
    if (this.masterRequirementMode && this.formData.startDate) {
        this.calculateTermDates();
    }
}
    validateForm() {
        const allComboboxes = this.template.querySelectorAll('lightning-combobox');
        let isValid = true;

        allComboboxes.forEach(combo => {
            if (!combo.value) {
                combo.reportValidity();
                isValid = false;
            }
        });

        return isValid;
    }

    // UPDATED: handleSave method with custom metadata integration
    async handleSave() {
    this.saveCalled = true;

    if (this.startDateValidation()) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Past Value',
            message: 'Start Date should not be in past',
            variant: 'error'
        }));
        return;
    }

    try {
        this.showSpinner = true;

        // Perform comprehensive validation
        if (!this.checkFormValidity()) {
            this.showToast('Error', 'Please fix the validation errors before saving.', 'error');
            this.showSpinner = false;
            return;
        }

        // Check for duplicate program plan
        const isDuplicate = await this.checkDuplicate();
        if (isDuplicate) {
            this.showSpinner = false;
            return;
        }

        // Prepare the working days string (comma-separated)
        const workingDaysString = this.formData.workingDays.join(',');

        const record = {
            academicProgramId: this.formData.academicProgram,
            programAlias: this.formData.programAlias,
            startingYear: this.formData.startingYear,
            intake: this.formData.intake,
            workingDays: workingDaysString,
            intakeStrength: this.formData.intakeStrength,
            startDate: this.formData.startDate,
            endDate: this.formData.endDate,
            totalDuration: this.formData.totalDuration,
            noOfTerms: this.formData.noOfTerms,
            campusFormat: this.formData.campusFormat,
             academicYear: this.formData.academicYear,
            maximumProgramDuration: this.formData.maximumProgramDuration,
            // Include term durations data with credit information
            termDurations: this.termDurations.map(term => ({
                termNumber: term.id.split('_')[1],
                duration: this.formData[term.name] || '', // Allow empty durations
                startDate: this.formData[term.startDateName] || '', // Allow empty start dates
                endDate: this.formData[term.endDateName] || '', // Allow empty end dates
                academicTermId: term.academicTermId || '',
                // ADD: Include credit information
                minCredit: this.formData[term.minCreditName] || '',
                maxCredit: this.formData[term.maxCreditName] || ''
            }))
        };

        console.log('Saving Data:', JSON.stringify(record, null, 2));

        const isSavedSuccess = await saveProgramPlan({ formData: record });
        if (isSavedSuccess) {
            this.showToast('Success', 'Program Plan saved successfully.', 'success');
            this.handleCancel();
        } else {
            this.showToast('Error', 'Failed to save Program Plan.', 'error');
        }
    } catch (error) {
        console.error('Error occurred during save:', JSON.stringify(error));
        this.showToast('Alert', 'Batch Already Exist', 'error');
    } finally {
        this.showSpinner = false;
    }

    // Dispatch navigation event with both configurations
    this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                direction: 'next',
                currentTab: 'intake',
                localRequirementMode: this.localRequirementMode,
                masterRequirementMode: this.masterRequirementMode,
                institutionType: this.selectedInstitutionType,
                isConfigurationLoaded: this.isConfigurationLoaded
            },
            bubbles: true,
            composed: true
        }));
    }

    async checkDuplicate() {
        try {
            if (!this.formData.startingYear || !this.formData.intake || !this.formData.programAlias) {
                this.isDuplicateFound = false;
                return false;
            }
            
            // Note: You'll need to import and implement checkDuplicateProgramPlan
            // For now, this is a placeholder
            const isDuplicate = false; // await checkDuplicateProgramPlan({...});
            
            this.isDuplicateFound = isDuplicate;
            
            if (isDuplicate) {
                this.isSaveButtonDisabled = true;
                return true;
            } else {
                this.updateSaveButtonState();
            }
            
            return false;
        } catch (error) {
            console.error('Error checking for duplicates:', error);
            this.isDuplicateFound = false;
            return false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }

    handleCancel() {
        this.formData = {
            academicProgram: '',
            programAlias: '',
            startingYear: '',
            intake: '',
            workingDays: [],
            intakeStrength: '',
            startDate: '',
            endDate: '',
            totalDuration: '',
            noOfTerms: '',
            campusFormat: '',
            academicYear: '',
            maximumProgramDuration: ''
            // Note: Credit fields will be cleared automatically since they're part of termDurations
        };

        // Reset input values in UI
        this.template.querySelectorAll('lightning-combobox, lightning-input, lightning-dual-listbox').forEach(input => {
            input.value = '';
        });

        // Clear the term durations (this will also clear credit fields)
        this.termDurations = [];
        
        // Reset save button state
        this.isSaveButtonDisabled = true;

        console.log('Form Reset');
        // Show a confirmation message
        if(!this.saveCalled){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Cancelled',
                    message: 'All selections have been cleared',
                    variant: 'info'
                })
            );
        }
    }

    // EXISTING GETTERS (kept unchanged)
    get shouldShowProgramPlanId() {
        return this.formData.startingYear && this.formData.intake && this.formData.programAlias;
    }

    get programPlanBoxClass() {
        return this.isDuplicateFound ? 'slds-box slds-theme_warning' : 'slds-box slds-theme_shade';
    }
    
    get programPlanIdClass() {
        return this.isDuplicateFound ? 'slds-text-color_error' : 'slds-text-color_success';
    }
    
    get combinedProgramPlanClass() {
        return `${this.isDuplicateFound ? 'slds-text-color_error' : 'slds-text-color_success'} slds-text-heading_medium`;
    }
    
    dismissDuplicateError() {
        this.isDuplicateFound = false;
        this.updateSaveButtonState();
    }

    // UPDATED GETTERS for template use
    get isStrictMode() {
        return this.masterRequirementMode; // Use master configuration
    }
    
    get isFlexibleMode() {
        return !this.masterRequirementMode;
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
            return this.masterRequirementMode ? 'Strict Mode (Auto-configured)' : 'Flexible Mode (Auto-configured)';
        }
        return this.localRequirementMode ? 'Strict Mode (Manual)' : 'Flexible Mode (Manual)';
    }
    
}