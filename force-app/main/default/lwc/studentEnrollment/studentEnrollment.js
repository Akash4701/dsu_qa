import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getFilterOptions from '@salesforce/apex/EnrollmentController.getFilterOptions';
import searchApplications from '@salesforce/apex/EnrollmentController.searchApplications';
import createProgramEnrollments from '@salesforce/apex/EnrollmentController.createProgramEnrollments';
import getProgramPathwaysByPlan from '@salesforce/apex/EnrollmentController.getProgramPathwaysByPlan';
import { COLUMNS, COURSE_OFFERING_COLUMNS } from './constants';

// Students are enrolled in batches, one Apex call (and so one set of governor limits) per batch.
// Enrolling everyone in a single call hits the SOQL limit above ~50 students.
const ENROLL_BATCH_SIZE = 20;

export default class StudentEnrollment extends LightningElement {
    enrollProgress = '';

    @track state = {
        institute: '',
        department: '',
        program: '', 
        programPlan: '',
        term: '',
        programSpecialization: '', 
        section: '',
        isLoading: false,
        searchTerm: '',
        studentType: '',
        pathwayType: '',
        programPathway: ''
    };

    get pathwayTypeOptions() {
    return [
        { label: 'Major', value: 'major' },
        { label: 'Minor', value: 'minor' },
        { label: 'Specialization', value: 'specialization' },
        { label: 'Concentration', value: 'concentration' }
    ];
}

    get studentTypeOptions() {
        return [
            { label: 'New', value: 'new' },
            { label: 'Existing', value: 'existing' },
        ];
    }

    @track selectedRows = [];
    @track majorCourseOfferings = [];
    @track minorCourseOfferings = [];
    @track specializationCourseOfferings = [];
    @track concentrationCourseOfferings = [];
    @track selectedMajorCO = [];
    @track selectedMinorCO = [];
    @track selectedSpecializationCO = [];
    @track selectedConcentrationCO = [];
    @track pathwayOptions = [];

    instituteOptions = [];
    departmentsByInstitute = {};
    programsByDepartment = {};
    programPlanByProgram = {};
    termsByProgramPlan = {};
    programSpecializationsByProgram = {};
    sectionsByTerms = {};
    studentDetails = [];

    // **NEW: Conditional display getters for course offering tables**
    get hasMajorCourses() {
        return this.majorCourseOfferings && this.majorCourseOfferings.length > 0 && 
           this.state.pathwayType === 'major';
    }

    get hasMinorCourses() {
        return this.minorCourseOfferings && this.minorCourseOfferings.length > 0 && 
           this.state.pathwayType === 'minor';
    }

    get hasSpecializationCourses() {
        return this.specializationCourseOfferings && this.specializationCourseOfferings.length > 0  && 
           this.state.pathwayType === 'specialization';
    }

    get hasConcentrationCourses() {
        return this.concentrationCourseOfferings && this.concentrationCourseOfferings.length > 0 && 
           this.state.pathwayType === 'concentration';
    }

    // **NEW: Check if any course offerings exist**
    get hasAnyCourseOfferings() {
        return this.hasMajorCourses || this.hasMinorCourses || this.hasSpecializationCourses || this.hasConcentrationCourses;
    }

    get departmentOptions() {
        const options = this.departmentsByInstitute[this.state.institute];
        const convertedOptions = options ? this.convertToOptions(options) : [];
        return this.sortByName(convertedOptions);
    }

    get programOptions() {
        const options = this.programsByDepartment[this.state.department];
        const convertedOptions = options ? this.convertToOptions(options) : [];
        return this.sortByName(convertedOptions);
    }

    get intakeOptions() {
        const options = this.programPlanByProgram[this.state.program];
        const convertedOptions = options ? this.convertToOptions(options) : [];
        return this.sortByName(convertedOptions);
    }

    get specializationOptions() {
        const options = this.programSpecializationsByProgram[this.state.program];
        const convertedOptions = options ? this.convertToOptions(options) : [];
        return this.sortByName(convertedOptions);
    }

    get termOptions() {
        const options = this.termsByProgramPlan[this.state.programPlan];
        const convertedOptions = options ? this.convertToOptions(options) : [];
        return this.sortByName(convertedOptions);
    }

    get sectionOptions() {
        const options = this.sectionsByTerms[this.state.term];
        const convertedOptions = options ? this.convertToOptions(options) : [];
        const sortedOptions = this.sortByName(convertedOptions);
        const noneOption = { label: 'None', value: null };
        return [noneOption, ...sortedOptions];
    }

    get applicationColumns() {
        return COLUMNS;
    }

    get courseOfferingColumns() {
        return COURSE_OFFERING_COLUMNS;
    }

    get selectedRowKeys() {
        return (this.selectedRows || []).map(row => row.applicationRecordId);
    }

    get selectedStudentCount() {
        return this.selectedRows ? this.selectedRows.length : 0;
    }

    get studentSelectionLabel() {
        const total = this.filteredStudentDetails.length;
        return `Selected ${this.selectedStudentCount} of ${total} student${total === 1 ? '' : 's'}`;
    }

    get filteredStudentDetails() {
        try {
            const { searchTerm } = this.state;
            return searchTerm && searchTerm.trim() !== ''
                ? this.studentDetails.filter(detail =>
                    detail.studentName.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    detail.studentEmail.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    (detail.studentPhone && detail.studentPhone.includes(searchTerm))||
                    (detail.studentCode && detail.studentCode.toLowerCase().includes(searchTerm.toLowerCase()))
                )
                : this.studentDetails;
        } catch (error) {
            console.error('Exception occurred while filtering students:', error);
            return this.studentDetails || [];
        }
    }

    connectedCallback() {
        this.fetchFilters();
    }

    handleTermChange({ detail }) {
        this.state.term = detail.value;
        this.state.section = '';
    }

    handleSectionChange({ detail }) {
        this.state.section = detail.value;
    }
    
    handleStudentTypeChange(event) {
        this.state.studentType = event.detail.value;
    }

    handleInstituteChange({ detail }) {
        this.state.institute = detail.value;
        this.state.department = '';
        this.state.program = '';
        this.state.programSpecialization = '';
        this.state.pathwayType = '';
this.state.programPathway = '';
        
        // Safe template query
        const specializationEl = this.template.querySelector('[data-name="specialization"]');
        if (specializationEl) specializationEl.value = '';
        
        this.state.programPlan = '';
        const intakeEl = this.template.querySelector('[data-name="intake"]');
        if (intakeEl) intakeEl.value = '';
        
        this.state.term = '';
        const termEl = this.template.querySelector('[data-name="term"]');
        if (termEl) termEl.value = '';

        const pathwayTypeEl = this.template.querySelector('[data-name="pathwayType"]');
if (pathwayTypeEl) pathwayTypeEl.value = '';
        
        this.state.section = '';
        this.state.studentType = '';
        
        // **NEW: Clear course offerings when institute changes**
        this.clearCourseOfferings();
    }

    handleDepartmentChange({ detail }) {
        this.state.department = detail.value;
        this.state.program = '';
        this.state.programSpecialization = '';
        this.state.pathwayType = '';
        this.state.programPathway = '';
        
        const specializationEl = this.template.querySelector('[data-name="specialization"]');
        if (specializationEl) specializationEl.value = '';
        
        this.state.programPlan = '';
        const intakeEl = this.template.querySelector('[data-name="intake"]');
        if (intakeEl) intakeEl.value = '';
        
        this.state.term = '';
        const termEl = this.template.querySelector('[data-name="term"]');
        if (termEl) termEl.value = '';

        const pathwayTypeEl = this.template.querySelector('[data-name="pathwayType"]');
if (pathwayTypeEl) pathwayTypeEl.value = '';
        
        this.state.section = '';
        this.state.studentType = '';
        
        // **NEW: Clear course offerings when department changes**
        this.clearCourseOfferings();
    }

    handlePathwayTypeChange({ detail }) {
    this.state.pathwayType = detail.value;
    this.state.programPathway = ''; // clear program pathway when type changes
    
    const pathwayEl = this.template.querySelector('[data-name="pathway"]');
    if (pathwayEl) pathwayEl.value = '';
    
    // Refresh pathway options based on selected type
    if (this.state.programPlan && this.state.pathwayType) {
        this.fetchFilteredPathways();
    }
}

    handleProgramChange({ detail }) {
        this.state.program = detail.value;
        this.state.programSpecialization = '';
        this.state.pathwayType = '';
        this.state.programPathway = '';
        
        const specializationEl = this.template.querySelector('[data-name="specialization"]');
        if (specializationEl) specializationEl.value = '';
        
        this.state.programPlan = '';
        const intakeEl = this.template.querySelector('[data-name="intake"]');
        if (intakeEl) intakeEl.value = '';
        
        this.state.term = '';
        const termEl = this.template.querySelector('[data-name="term"]');
        if (termEl) termEl.value = '';

        const pathwayTypeEl = this.template.querySelector('[data-name="pathwayType"]');
        if (pathwayTypeEl) pathwayTypeEl.value = '';
        
        this.state.section = '';
        this.state.studentType = '';
        
        // **NEW: Clear course offerings when program changes**
        this.clearCourseOfferings();
    }

    handleSpecializationChange({ detail }) {
        this.state.programSpecialization = detail.value;
    }

    handleIntakeChange({ detail }) {
        this.state.programPlan = detail.value;
        this.state.term = '';
        this.state.section = '';
        this.state.studentType = '';
        this.state.programPathway = ''; 
        this.state.pathwayType = '';
        this.pathwayOptions = [];

        const termEl = this.template.querySelector('[data-name="term"]');
        if (termEl) termEl.value = '';

        const pathwayEl = this.template.querySelector('[data-name="pathway"]');
        if (pathwayEl) pathwayEl.value = '';

         const pathwayTypeEl = this.template.querySelector('[data-name="pathwayType"]'); // ADD THIS
        if (pathwayTypeEl) pathwayTypeEl.value = '';

        // **NEW: Clear course offerings when intake changes**
        this.clearCourseOfferings();

        if (this.state.programPlan) {
            getProgramPathwaysByPlan({ programPlanId: this.state.programPlan })
                .then(result => {
                    this.pathwayOptions = result.map(item => ({
                        label: item.name,
                        value: item.id
                    }));
                })
                .catch(error => {
                    console.error('Error fetching program pathways:', error);
                    this.showToast({
                        title: 'Error',
                        message: 'Failed to load Program Pathway options',
                        variant: 'error'
                    });
                });
        }
    }
    fetchFilteredPathways() {
    if (this.state.programPlan && this.state.pathwayType) {
        getProgramPathwaysByPlan({ programPlanId: this.state.programPlan })
            .then(result => {
                // Filter pathways by selected type
                console.log('Result', result);
                const filteredPathways = result.filter(item => 
                    item.type && item.type.toLowerCase() === this.state.pathwayType.toLowerCase()
                );
                console.log('Filtered Pathways',filteredPathways);
                this.pathwayOptions = filteredPathways.map(item => ({
                    label: item.name,
                    value: item.id
                }));
            })
            .catch(error => {
                console.error('Error fetching program pathways:', error);
                this.showToast({
                    title: 'Error',
                    message: 'Failed to load Program Pathway options',
                    variant: 'error'
                });
            });
    }
}
    handlePathwayChange({ detail }) {
        this.state.programPathway = detail.value;
    }

    handleSearch({ target }) {
        this.state.searchTerm = target.value;
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    handleMajorCOSelection(event) {
    // Extract only the courseOfferingId values, not the full objects
    this.selectedMajorCO = event.detail.selectedRows.map(row => row.courseOfferingId);
    console.log('Selected Major CO IDs:', this.selectedMajorCO);
}

handleMinorCOSelection(event) {
    this.selectedMinorCO = event.detail.selectedRows.map(row => row.courseOfferingId);
    console.log('Selected Minor CO IDs:', this.selectedMinorCO);
}

handleSpecializationCOSelection(event) {
    this.selectedSpecializationCO = event.detail.selectedRows.map(row => row.courseOfferingId);
    console.log('Selected Specialization CO IDs:', this.selectedSpecializationCO);
}

handleConcentrationCOSelection(event) {
    this.selectedConcentrationCO = event.detail.selectedRows.map(row => row.courseOfferingId);
    console.log('Selected Concentration CO IDs:', this.selectedConcentrationCO);
}


    async handleEnrollClick() {
    if (!this.validateSelectedRows(this.selectedRows)) {
        return false;
    }

    this.state.isLoading = true;

    try {
        const contactIds = this.selectedRows.map(row => row.contactId || row.applicationRecordId);
        
        if (contactIds.length === 0 || contactIds.some(id => !id)) {
            throw new Error('Invalid contact IDs found in selection');
        }
        
        // FIXED: selectedMajorCO now contains IDs directly, not objects
        const majorCOIds = this.selectedMajorCO; // Already contains courseOfferingId values
        const minorCOIds = this.selectedMinorCO; // Already contains courseOfferingId values
        const specializationCOIds = this.selectedSpecializationCO; // Already contains courseOfferingId values
        const concentrationCOIds = this.selectedConcentrationCO; // Already contains courseOfferingId values

        const courseOfferingIds = [
            ...majorCOIds,
            ...minorCOIds,
            ...specializationCOIds,
            ...concentrationCOIds
        ];

        // Batches run one after another: running them in parallel would make them compete for
        // locks on the same Course Offering records (enrollment counts) and fail.
        const enrolledIds = [];
        const failures = [];
        for (let start = 0; start < contactIds.length; start += ENROLL_BATCH_SIZE) {
            const batch = contactIds.slice(start, start + ENROLL_BATCH_SIZE);
            this.enrollProgress = `Enrolling students ${start + 1}-${start + batch.length} of ${contactIds.length}...`;
            try {
                await createProgramEnrollments({
                    contactIds: batch,
                    termId: this.state.term,
                    specializationId: this.state.programSpecialization,
                    programPathwayId: this.state.programPathway,
                    courseOfferingIds: courseOfferingIds
                });
                enrolledIds.push(...batch);
            } catch (error) {
                console.error(`Error enrolling students ${start + 1}-${start + batch.length}:`, error);
                failures.push({ count: batch.length, message: this.getErrorMessage(error) });
            }
        }

        // Remove the enrolled students from the list; failed ones stay selectable for a retry
        this.studentDetails = this.studentDetails.filter(detail =>
            !enrolledIds.includes(detail.contactId) && !enrolledIds.includes(detail.applicationRecordId));
        this.selectedRows = [];

        if (failures.length === 0) {
            this.showToast({ title: 'Success', message: `${enrolledIds.length} students enrolled successfully.` });
            return true;
        }
        const failedCount = failures.reduce((sum, f) => sum + f.count, 0);
        this.showToast({
            title: enrolledIds.length ? 'Partially enrolled' : 'Error',
            message: `${enrolledIds.length} students enrolled, ${failedCount} failed. ${failures[0].message}`,
            variant: enrolledIds.length ? 'warning' : 'error'
        });
        return false;

    } catch (error) {
        console.error('Error during enrollment:', error);
        this.showToast({ title: 'Error', message: `Failed to enroll students. ${this.getErrorMessage(error)}`, variant: 'error' });
        return false;
    } finally {
        this.enrollProgress = '';
        this.state.isLoading = false;
    }
}

    getErrorMessage(error) {
        if (error && error.body) {
            if (error.body.message) return error.body.message;
            if (error.body.pageErrors && error.body.pageErrors.length > 0) return error.body.pageErrors[0].message;
        }
        return (error && error.message) || '';
    }


    handleSearchClick() {
        // Validate required fields before proceeding
        if (!this.state.institute || !this.state.department || !this.state.program || 
            !this.state.programPlan || !this.state.term || !this.state.studentType) {
            this.showToast({ 
                variant: 'error', 
                title: 'Error', 
                message: 'Please fill all required fields before searching.' 
            });
            return;
        }

        const allValid = [...this.template.querySelectorAll('[data-id="input"]')].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        if (!allValid) {
            return;
        }
        this.performSearch();
    }

    async fetchFilters() {
        console.log('=== Starting fetchFilters ===');
        this.state.isLoading = true;
        
        try {
            const filters = await getFilterOptions();
            console.log('Filters received:', filters);

            this.instituteOptions = this.sortByName(this.convertToOptions(filters.institutes || []));
            this.departmentsByInstitute = this.groupByParentId(filters.departments || []);
            this.programsByDepartment = this.groupByParentId(filters.programs || []);
            this.programPlanByProgram = this.groupByParentId(filters.programPlans || []);
            this.termsByProgramPlan = this.groupByParentId(filters.terms || []);
            this.programSpecializationsByProgram = this.groupByParentId(filters.programSpecializations || []);
            this.sectionsByTerms = this.groupByParentId(filters.sections || []);
            
            console.log('Filters processed successfully');
            
        } catch (error) {
            console.error('Error in fetchFilters:', error);
            this.showToast({ 
                title: 'Error', 
                message: 'Failed to load filter options: ' + (error.body?.message || error.message), 
                variant: 'error' 
            });
        } finally {
            this.state.isLoading = false;
            console.log('=== Ending fetchFilters ===');
        }
    }

    async performSearch() {
        console.log('=== Starting performSearch ===');
        console.log('Search parameters:', {
            programPlan: this.state.programPlan,
            termId: this.state.term,
            sectionName: this.state.section,
            specialisationId: this.state.programSpecialization,
            studentType: this.state.studentType
        });
        
        this.state.isLoading = true;

        try {
            const result = await searchApplications({
                programPlan: this.state.programPlan,
                termId: this.state.term,
                sectionName: this.state.section,
                specialisationId: this.state.programSpecialization,
                studentType: this.state.studentType
            });
            
            console.log('Search result received:', result);

            this.studentDetails = result.studentdetails || [];
            this.selectedRows = [];
            this.majorCourseOfferings = result.majorCourseOfferings || [];
            this.minorCourseOfferings = result.minorCourseOfferings || [];
            this.specializationCourseOfferings = result.specializationCourseOfferings || [];
            this.concentrationCourseOfferings = result.concentrationCourseOfferings || [];
            
            console.log('Data processed successfully');
            
        } catch (error) {
            console.error('Error in performSearch:', error);
            this.showToast({ 
                title: 'Error', 
                message: 'Failed to search applications: ' + (error.body?.message || error.message), 
                variant: 'error' 
            });
        } finally {
            this.state.isLoading = false;
            console.log('=== Ending performSearch ===');
        }
    }

    // **NEW: Helper method to clear all course offerings**
    clearCourseOfferings() {
        this.majorCourseOfferings = [];
        this.minorCourseOfferings = [];
        this.specializationCourseOfferings = [];
        this.concentrationCourseOfferings = [];
        this.selectedMajorCO = [];
        this.selectedMinorCO = [];
        this.selectedSpecializationCO = [];
        this.selectedConcentrationCO = [];
        this.state.pathwayType = ''; 
        this.state.programPathway = ''; 
    }

    groupByParentId(options) {
        if (!options || !Array.isArray(options)) return {};
        
        const optionByParentId = {};
        for (let option of options) {
            if (!optionByParentId[option.parentId]) {
                optionByParentId[option.parentId] = [];
            }
            optionByParentId[option.parentId].push(option);
        }
        return optionByParentId;
    }

    convertToOptions(idNamePairs) {
        if (!idNamePairs || !Array.isArray(idNamePairs)) return [];
        
        return idNamePairs.map((ob) => ({
            label: ob.name,
            value: ob.id,
        }));
    }

    validateSelectedRows(selectedRows) {
        if (selectedRows && selectedRows.length > 0) {
            return true;
        }

        this.showToast({ variant: 'error', title: 'Error', message: 'Please select any student record.' });
        return false;
    }

    showToast({ title, message, variant = 'success' }) {
        const event = new ShowToastEvent({
            title,
            message,
            variant,
        });
        this.dispatchEvent(event);
    }

    sortByName(options) {
        if (!options || !Array.isArray(options)) return [];
        
        return options.sort((a, b) => {
            if (a.label === undefined || b.label === undefined) {
                return -1;
            }
            return a.label.localeCompare(b.label);
        });
    }
}