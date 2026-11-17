import { LightningElement, track } from 'lwc';
import getAcademicPrograms from '@salesforce/apex/AcademicTermController.getAcademicPrograms';
import getProgramPlans from '@salesforce/apex/AcademicTermController.getProgramPlans';
import getTermsWithAcademicTerms from '@salesforce/apex/AcademicTermController.getTermsWithAcademicTerms';
import getAcademicTerms from '@salesforce/apex/AcademicTermController.getAcademicTerms';
import getAcademicTermById from '@salesforce/apex/AcademicTermController.getAcademicTermById';
import updateAcademicTerm from '@salesforce/apex/AcademicTermController.updateAcademicTerm';
import createAcademicTerm from '@salesforce/apex/AcademicTermController.createAcademicTerm';
import mapAcademicTermToTerm from '@salesforce/apex/AcademicTermController.mapAcademicTermToTerm';
import removeAcademicTermMapping from '@salesforce/apex/AcademicTermController.removeAcademicTermMapping';
import getUnmappedAcademicTerms from '@salesforce/apex/AcademicTermController.getUnmappedAcademicTerms';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EnhancedAcademicTerm extends LightningElement {
    @track selectedAcademicProgram = '';
    @track selectedProgramPlan = '';
    @track selectedTermForCreation = '';
    @track selectedAcademicTermForEdit = '';
    @track currentTermId = '';
    @track currentTermLabel = '';
    @track refreshCounter = 0;
    
    @track academicProgramOptions = [];
    @track programPlanOptions = [];
    @track termOptions = [];
    @track academicTermOptions = [];
    @track availableAcademicTermOptions = [];
    
    @track isProgramPlanDisabled = true;
    @track isTermSectionVisible = false;
    @track showModal = false;
    @track isLoading = true;
    @track isEditMode = false;
    @track academicTermIdForEdit = '';
    @track isSaveDisabled = false;
    @track showSpinner = false;
    
    @track seasonOptions = [
        { label: '--None--', value: '' },
        { label: 'Spring', value: 'Spring' },
        { label: 'Summer', value: 'Summer' },
        { label: 'Fall', value: 'Fall' },
        { label: 'Winter', value: 'Winter' }
    ];
    
    @track newAcademicTerm = this.getEmptyAcademicTerm();

    // Getters for computed properties
    get isGlobalUpdateDisabled() {
        return !this.selectedAcademicTermForEdit;
    }

    get modalTitle() {
        if (this.isEditMode) {
            return this.currentTermLabel ? 
                `Update Academic Term for ${this.currentTermLabel}` : 
                'Update Academic Term';
        }
        return this.currentTermLabel ? 
            `Create Academic Term for ${this.currentTermLabel}` : 
            'Create Academic Term';
    }

    get saveButtonLabel() {
        return this.isEditMode ? 'Update' : 'Save';
    }

    get hasTerms() {
        return this.termOptions && this.termOptions.length > 0;
    }

    get programPlanLabel() {
        if (this.selectedProgramPlan && this.programPlanOptions.length > 0) {
            const plan = this.programPlanOptions.find(p => p.value === this.selectedProgramPlan);
            return plan ? plan.label : '';
        }
        return '';
    }

    getEmptyAcademicTerm() {
        return {
            Name: '',
            Academic_Year__c: '',
            Season__c: '',
            Start_Date__c: '',
            End_Date__c: '',
            Registration_Open_Date__c: '',
            Registration_Close_Date__c: '',
            Last_Modified_Date__c: '',
            Late_Registration_Date__c: '',
            Description__c: '',
            External_Id__c: '',
            IsActive__c: true
        };
    }

    connectedCallback() {
        this.initializeComponent();
    }

    async initializeComponent() {
        try {
            this.showSpinner = true;
            await Promise.all([
                this.fetchAcademicPrograms(),
                this.fetchAcademicTerms()
            ]);
        } catch (error) {
            console.error('Error initializing component:', error);
            this.showToast('Error', 'Failed to initialize component', 'error');
        } finally {
            this.showSpinner = false;
            this.isLoading = false;
        }
    }

    async fetchAcademicPrograms() {
        try {
            const result = await getAcademicPrograms();
            this.academicProgramOptions = result.map(record => ({
                label: record.Name,
                value: record.Id
            }));
            console.log('Academic Programs loaded:', this.academicProgramOptions.length);
        } catch (error) {
            console.error('Error fetching academic programs:', error);
            this.showToast('Error', 'Failed to load academic programs', 'error');
            throw error;
        }
    }

    async fetchAcademicTerms() {
        try {
            const result = await getAcademicTerms();
            this.academicTermOptions = result.map(record => ({
                label: `${record.Academic_Year__c || ''} - ${record.Season__c || ''} - ${record.Name || ''}`,
                value: record.Id
            }));
            console.log('Academic Terms loaded:', this.academicTermOptions.length);
        } catch (error) {
            console.error('Error fetching academic terms:', error);
            this.showToast('Error', 'Failed to load academic terms', 'error');
            throw error;
        }
    }

    async fetchAvailableAcademicTerms() {
        try {
            if (!this.selectedProgramPlan) {
                this.availableAcademicTermOptions = [...this.academicTermOptions];
                return;
            }

            const result = await getUnmappedAcademicTerms({ programPlanId: this.selectedProgramPlan });
            this.availableAcademicTermOptions = result.map(record => ({
                label: `${record.Academic_Year__c || ''} - ${record.Season__c || ''} - ${record.Name || ''}`,
                value: record.Id
            }));
            console.log('Available Academic Terms loaded:', this.availableAcademicTermOptions.length);
        } catch (error) {
            console.error('Error fetching available academic terms:', error);
            this.availableAcademicTermOptions = [...this.academicTermOptions];
        }
    }

    handleAcademicProgramChange(event) {
        const newValue = event.detail.value;
        console.log('Academic Program changed to:', newValue);
        
        this.selectedAcademicProgram = newValue;
        this.resetProgramPlanData();

        if (!this.selectedAcademicProgram) {
            this.isProgramPlanDisabled = true;
            return;
        }

        this.isProgramPlanDisabled = false;
        this.loadProgramPlans();
    }

    resetProgramPlanData() {
        this.selectedProgramPlan = '';
        this.programPlanOptions = [];
        this.termOptions = [];
        this.isTermSectionVisible = false;
        this.selectedAcademicTermForEdit = '';
    }

    async loadProgramPlans() {
        try {
            this.showSpinner = true;
            const result = await getProgramPlans({ accountId: this.selectedAcademicProgram });
            this.programPlanOptions = result.map(record => ({
                label: record.Name,
                value: record.Id
            }));
            console.log('Program Plans loaded:', this.programPlanOptions.length);
        } catch (error) {
            console.error('Error fetching program plans:', error);
            this.showToast('Error', 'Failed to load program plans', 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    handleProgramPlanChange(event) {
        const newValue = event.detail.value;
        console.log('Program Plan changed to:', newValue);
        
        this.selectedProgramPlan = newValue;
        
        if (!this.selectedProgramPlan) {
            this.isTermSectionVisible = false;
            this.termOptions = [];
            return;
        }

        this.isTermSectionVisible = true;
        this.loadTermsWithMappings();
        this.fetchAvailableAcademicTerms();
    }

    async loadTermsWithMappings() {
        try {
            this.showSpinner = true;
            const result = await getTermsWithAcademicTerms({ programPlanId: this.selectedProgramPlan });
            
            this.termOptions = result.map(record => {
                const hasAcademicTerm = record.Academic_Term__c != null;
                const academicTerm = record.Academic_Term__r;
                
                return {
                    label: record.Name,
                    value: record.Id,
                    hasAcademicTerm: hasAcademicTerm,
                    academicTermId: record.Academic_Term__c || '',
                    selectedAcademicTermId: record.Academic_Term__c || '',
                    academicTermLabel: hasAcademicTerm && academicTerm ? 
                        `${academicTerm.Academic_Year__c || ''} - ${academicTerm.Season__c || ''} - ${academicTerm.Name || ''}` : '',
                    academicTermName: academicTerm?.Name || '',
                    academicYear: academicTerm?.Academic_Year__c || '',
                    season: academicTerm?.Season__c || '',
                    startDate: this.formatDate(academicTerm?.Start_Date__c),
                    endDate: this.formatDate(academicTerm?.End_Date__c),
                    registrationOpenDate: this.formatDate(academicTerm?.Registration_Open_Date__c),
                    registrationCloseDate: this.formatDate(academicTerm?.Registration_Close_Date__c),
                    lateRegistrationDate: this.formatDate(academicTerm?.Late_Registration_Date__c),
                    isActive: academicTerm?.IsActive__c || false,
                    description: academicTerm?.Description__c || '',
                    isMapDisabled: true,
                    isUpdateDisabled: !hasAcademicTerm,
                    isRemoveDisabled: !hasAcademicTerm
                };
            });
            
            console.log('Terms with mappings loaded:', this.termOptions.length);
            this.refreshCounter++; // Force reactivity
        } catch (error) {
            console.error('Error fetching terms with academic terms:', error);
            this.showToast('Error', 'Failed to load terms with academic term mappings', 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        try {
            return new Date(dateValue).toLocaleDateString();
        } catch (error) {
            return dateValue;
        }
    }

    handleAcademicTermChange(event) {
        const termId = event.target.dataset.termId;
        const selectedValue = event.detail.value;
        
        console.log('Academic Term selection changed:', { termId, selectedValue });

        this.termOptions = this.termOptions.map(term => {
            if (term.value === termId) {
                const isMapDisabled = !selectedValue || selectedValue === term.academicTermId;
                return {
                    ...term,
                    selectedAcademicTermId: selectedValue,
                    isMapDisabled: isMapDisabled
                };
            }
            return term;
        });
    }

    async handleMapAcademicTerm(event) {
        const termId = event.target.dataset.termId;
        const term = this.termOptions.find(t => t.value === termId);
        
        if (!term || !term.selectedAcademicTermId) {
            this.showToast('Warning', 'Please select an Academic Term to map', 'warning');
            return;
        }

        try {
            this.showSpinner = true;
            await mapAcademicTermToTerm({ 
                termId: termId, 
                academicTermId: term.selectedAcademicTermId 
            });
            
            this.showToast('Success', 'Academic Term mapped successfully', 'success');
            await this.refreshData();
        } catch (error) {
            console.error('Error mapping academic term:', error);
            this.showToast('Error', 'Failed to map Academic Term', 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    async handleRemoveMapping(event) {
        const termId = event.target.dataset.termId;
        const term = this.termOptions.find(t => t.value === termId);
        
        if (!term || !term.hasAcademicTerm) {
            this.showToast('Warning', 'No Academic Term mapping to remove', 'warning');
            return;
        }

        try {
            this.showSpinner = true;
            await removeAcademicTermMapping({ termId: termId });
            
            this.showToast('Success', 'Academic Term mapping removed successfully', 'success');
            await this.refreshData();
        } catch (error) {
            console.error('Error removing mapping:', error);
            this.showToast('Error', 'Failed to remove Academic Term mapping', 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    handleCreateAcademicTermForTerm(event) {
        const termId = event.target.dataset.termId;
        const termLabel = event.target.dataset.termLabel;
        
        console.log('Creating Academic Term for term:', { termId, termLabel });
        
        this.selectedTermForCreation = termId;
        this.currentTermId = termId;
        this.currentTermLabel = termLabel;
        this.isEditMode = false;
        this.academicTermIdForEdit = '';
        this.newAcademicTerm = this.getEmptyAcademicTerm();
        this.newAcademicTerm.Description__c = `Academic Term for ${termLabel}`;
        
        // Pre-populate name if we have term info
        const currentYear = new Date().getFullYear();
        this.newAcademicTerm.Academic_Year__c = currentYear.toString();
        this.newAcademicTerm.Name = `${currentYear} Fall`;
        
        this.showModal = true;
    }

    handleUpdateAcademicTermForTerm(event) {
        const termId = event.target.dataset.termId;
        const termLabel = event.target.dataset.termLabel;
        const term = this.termOptions.find(t => t.value === termId);
        
        console.log('Updating Academic Term for term:', { termId, termLabel, term });
        
        if (!term || !term.academicTermId) {
            this.showToast('Warning', 'No Academic Term mapped to this term', 'warning');
            return;
        }

        this.selectedTermForCreation = termId;
        this.currentTermId = termId;
        this.currentTermLabel = termLabel;
        this.isEditMode = true;
        this.academicTermIdForEdit = term.academicTermId;
        
        this.loadAcademicTermForEdit(term.academicTermId);
    }

    handleCreateGlobalAcademicTerm() {
        console.log('Creating global Academic Term');
        
        this.selectedTermForCreation = null;
        this.currentTermId = '';
        this.currentTermLabel = '';
        this.isEditMode = false;
        this.academicTermIdForEdit = '';
        this.newAcademicTerm = this.getEmptyAcademicTerm();
        
        // Pre-populate with current year
        const currentYear = new Date().getFullYear();
        this.newAcademicTerm.Academic_Year__c = currentYear.toString();
        
        this.showModal = true;
    }

    handleUpdateGlobalAcademicTerm() {
        if (!this.selectedAcademicTermForEdit) {
            this.showToast('Warning', 'Please select an Academic Term to update', 'warning');
            return;
        }

        console.log('Updating global Academic Term:', this.selectedAcademicTermForEdit);

        this.selectedTermForCreation = null;
        this.currentTermId = '';
        this.currentTermLabel = '';
        this.isEditMode = true;
        this.academicTermIdForEdit = this.selectedAcademicTermForEdit;
        
        this.loadAcademicTermForEdit(this.selectedAcademicTermForEdit);
    }

    async loadAcademicTermForEdit(academicTermId) {
        try {
            this.showSpinner = true;
            const result = await getAcademicTermById({ termId: academicTermId });
            
            this.newAcademicTerm = {
                Name: result.Name || '',
                Academic_Year__c: result.Academic_Year__c || '',
                Season__c: result.Season__c || '',
                Start_Date__c: result.Start_Date__c || '',
                End_Date__c: result.End_Date__c || '',
                Registration_Open_Date__c: result.Registration_Open_Date__c || '',
                Registration_Close_Date__c: result.Registration_Close_Date__c || '',
                Last_Modified_Date__c: result.Last_Modified_Date__c || '',
                Late_Registration_Date__c: result.Late_Registration_Date__c || '',
                Description__c: result.Description__c || '',
                External_Id__c: result.External_Id__c || '',
                IsActive__c: result.IsActive__c !== undefined ? result.IsActive__c : true
            };
            
            console.log('Academic Term loaded for edit:', this.newAcademicTerm);
            this.showModal = true;
        } catch (error) {
            console.error('Error fetching academic term details:', error);
            this.showToast('Error', 'Failed to load Academic Term details', 'error');
        } finally {
            this.showSpinner = false;
        }
    }

    handleAcademicTermSelection(event) {
        this.selectedAcademicTermForEdit = event.detail.value;
        console.log('Global Academic Term selected:', this.selectedAcademicTermForEdit);
    }

    handleModalClose() {
        console.log('Closing modal');
        this.showModal = false;
        this.newAcademicTerm = this.getEmptyAcademicTerm();
        this.isEditMode = false;
        this.academicTermIdForEdit = '';
        this.selectedTermForCreation = '';
        this.currentTermId = '';
        this.currentTermLabel = '';
        this.isSaveDisabled = false;
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        
        console.log('Input changed:', { field, value });
        
        this.newAcademicTerm = {
            ...this.newAcademicTerm,
            [field]: value
        };

        // Auto-generate name if Academic Year and Season are provided
        if ((field === 'Academic_Year__c' || field === 'Season__c') && 
            this.newAcademicTerm.Academic_Year__c && this.newAcademicTerm.Season__c) {
            this.newAcademicTerm.Name = `${this.newAcademicTerm.Academic_Year__c} ${this.newAcademicTerm.Season__c}`;
        }

        // Validate form
        this.validateForm();
    }

    validateForm() {
        const requiredFields = ['Name', 'Academic_Year__c', 'Season__c', 'Start_Date__c', 'End_Date__c'];
        const missingFields = requiredFields.filter(field => !this.newAcademicTerm[field]);
        
        let hasErrors = missingFields.length > 0;

        // Validate date logic
        if (this.newAcademicTerm.Start_Date__c && this.newAcademicTerm.End_Date__c) {
            const startDate = new Date(this.newAcademicTerm.Start_Date__c);
            const endDate = new Date(this.newAcademicTerm.End_Date__c);
            
            if (startDate >= endDate) {
                hasErrors = true;
            }
        }

        // Validate registration dates
        if (this.newAcademicTerm.Registration_Open_Date__c && this.newAcademicTerm.Registration_Close_Date__c) {
            const regOpen = new Date(this.newAcademicTerm.Registration_Open_Date__c);
            const regClose = new Date(this.newAcademicTerm.Registration_Close_Date__c);
            
            if (regOpen >= regClose) {
                hasErrors = true;
            }
        }

        this.isSaveDisabled = hasErrors;
        
        console.log('Form validation:', { 
            missingFields, 
            hasErrors, 
            isSaveDisabled: this.isSaveDisabled 
        });
    }

    async handleSaveAcademicTerm() {
        console.log('Saving Academic Term:', this.newAcademicTerm);
        
        this.validateForm();
        
        if (this.isSaveDisabled) {
            this.showToast('Error', 'Please fill in all required fields correctly', 'error');
            return;
        }

        try {
            this.isSaveDisabled = true;
            this.showSpinner = true;

            if (this.isEditMode) {
                await updateAcademicTerm({
                    termData: JSON.stringify(this.newAcademicTerm),
                    academicTermId: this.academicTermIdForEdit
                });
                
                this.showToast('Success', 'Academic Term updated successfully', 'success');
            } else {
                const result = await createAcademicTerm({
                    termData: JSON.stringify(this.newAcademicTerm),
                    selectedTermId: this.selectedTermForCreation
                });
                
                console.log('Academic Term created with ID:', result);
                
                this.showToast('Success', 
                    this.selectedTermForCreation ? 
                    'Academic Term created and mapped successfully' : 
                    'Academic Term created successfully', 
                    'success');
            }
            
            this.handleModalClose();
            await this.refreshData();
            
        } catch (error) {
            console.error('Error saving academic term:', error);
            this.showToast('Error', 
                this.isEditMode ? 'An Academic Term with this Academic Year and Season already exists' : 'An Academic Term with this Academic Year and Season already exists', 
                'error');
        } finally {
            this.isSaveDisabled = false;
            this.showSpinner = false;
        }
    }

    async refreshData() {
        try {
            console.log('Refreshing data...');
            
            // Refresh academic terms list
            await this.fetchAcademicTerms();
            
            // Refresh available academic terms for mapping
            await this.fetchAvailableAcademicTerms();
            
            // Refresh terms with mappings if we have a selected program plan
            if (this.selectedProgramPlan) {
                await this.loadTermsWithMappings();
            }
            
            console.log('Data refresh completed');
        } catch (error) {
            console.error('Error refreshing data:', error);
            this.showToast('Warning', 'Some data may not be up to date', 'warning');
        }
    }

    // Utility method to handle date formatting for display
    getFormattedDateRange(startDate, endDate) {
        if (!startDate && !endDate) return '';
        if (!startDate) return `Until ${this.formatDate(endDate)}`;
        if (!endDate) return `From ${this.formatDate(startDate)}`;
        return `${this.formatDate(startDate)} - ${this.formatDate(endDate)}`;
    }

    // Utility method to get status text
    getStatusText(isActive) {
        return isActive ? 'Active' : 'Inactive';
    }

    // Method to handle keyboard events for accessibility
    handleKeyDown(event) {
        if (event.key === 'Escape' && this.showModal) {
            this.handleModalClose();
        }
    }

    // Method to focus on first input when modal opens
    renderedCallback() {
        if (this.showModal && this.template.querySelector('lightning-input[name="Name"]')) {
            setTimeout(() => {
                const firstInput = this.template.querySelector('lightning-input[name="Name"]');
                if (firstInput) {
                    firstInput.focus();
                }
            }, 100);
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        
        console.log(`Toast: ${title} - ${message} (${variant})`);
    }
}