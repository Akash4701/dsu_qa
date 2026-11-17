import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getFilterOptions from '@salesforce/apex/EnrollmentController.getFilterOptions';
import searchApplications from '@salesforce/apex/termEnrollmentCtrl.fetchRecords';
import createProgramEnrollments from '@salesforce/apex/termEnrollmentCtrl.createProgramEnrollments';
import { COLUMNS, COURSE_OFFERING_COLUMNS } from './constants';

// Students are enrolled in batches, one Apex call (and so one set of governor limits) per batch.
// Enrolling everyone in a single call hits the SOQL limit for large selections.
const ENROLL_BATCH_SIZE = 20;

export default class termEnrollment extends LightningElement {
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
        nextTerm: '',
        currentTermLebel: '',
        pathwayType: ''
    };

    // applicationRecordIds of the selected students, across all pages
    @track selectedIds = [];

    // **UPDATED: Four separate course offering selection arrays**
    @track selectedMajorCO = [];
    @track selectedMinorCO = [];
    @track selectedSpecializationCO = [];
    @track selectedConcentrationCO = [];

    instituteOptions = [];

    departmentsByInstitute = {};
    programsByDepartment = {};
    programPlanByProgram = {};
    termsByProgramPlan = {};
    programSpecializationsByProgram = {};
    sectionsByTerms = {};

    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    sortedBy;

    // Pagination properties
    @track currentPage = 1;
    @track pageSize = 10;
    @track totalRecords = 0;

    // **NEW: Four separate course offering arrays**
    @track majorCourseOfferings = [];
    @track minorCourseOfferings = [];
    @track specializationCourseOfferings = [];
    @track concentrationCourseOfferings = [];

    studentDetails = [];

    // **NEW: Pathway type options**
    get pathwayTypeOptions() {
        return [
            { label: 'Major', value: 'major' },
            { label: 'Minor', value: 'minor' },
            { label: 'Specialization', value: 'specialization' },
            { label: 'Concentration', value: 'concentration' }
        ];
    }

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
        return this.specializationCourseOfferings && this.specializationCourseOfferings.length > 0 && 
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
        return this.sortByName(convertedOptions);
    }

    get applicationColumns() {
        return COLUMNS;
    }

    get courseOfferingColumns() {
        return COURSE_OFFERING_COLUMNS;
    }

    get filteredStudentDetails() {
        const { searchTerm } = this.state;
        return searchTerm && searchTerm !== ''
            ? this.studentDetails.filter(detail =>
                (detail.studentName && detail.studentName.toLowerCase().includes(searchTerm.toLowerCase())) ||
                (detail.studentEmail && detail.studentEmail.toLowerCase().includes(searchTerm.toLowerCase())) ||
                (detail.studentPhone && detail.studentPhone.includes(searchTerm)) ||
                (detail.registrationNumber && detail.registrationNumber.includes(searchTerm))
              )
            : this.studentDetails;
    }

    get paginatedStudentDetails() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.filteredStudentDetails.slice(start, end);
    }

    get studentSelectionLabel() {
        const total = this.studentDetails.length;
        return `Selected ${this.selectedIds.length} of ${total} student${total === 1 ? '' : 's'}`;
    }

    get isSelectAllDisabled() {
        return this.studentDetails.length === 0 || this.selectedIds.length === this.studentDetails.length;
    }

    get isClearSelectionDisabled() {
        return this.selectedIds.length === 0;
    }

    handleSelectAll() {
        this.selectedIds = this.studentDetails.map(detail => detail.applicationRecordId);
    }

    handleClearSelection() {
        this.selectedIds = [];
    }

    connectedCallback() {
        this.fetchFilters();
    }

    handleTermChange({ detail }) {
        this.state.term = detail.value;
        this.state.currentTermLebel = detail.label;
        this.state.nextTerm = '';
        this.template.querySelector('[data-name="nextterm"]').value = '';
        this.state.section = '';
    }

    handleNextTermChange({ detail }) {
        if (this.state.currentTermLebel > detail.label) {
            this.showToast({ 
                title: 'Error', 
                message: 'Invalid term sequence selected. Please choose a valid combination.', 
                variant: 'error' 
            });
        }
        this.state.nextTerm = detail.value;
        console.log('this.state.nextTerm-->' + this.state.nextTerm);
    }

    handleSectionChange({ detail }) {
        this.state.section = detail.value;
    }

    // **NEW: Pathway type change handler**
    handlePathwayTypeChange({ detail }) {
        this.state.pathwayType = detail.value;
        // Clear previous selections when pathway type changes
        this.clearCourseOfferingSelections();
    }

    handleInstituteChange({ detail }) {
        this.state.institute = detail.value;

        // reset others
        this.state.department = '';
        this.state.program = '';
        this.state.programSpecialization = '';
        this.template.querySelector('[data-name="specialization"]').value = '';
        this.state.programPlan = '';
        this.template.querySelector('[data-name="intake"]').value = '';
        this.state.term = '';
        this.template.querySelector('[data-name="term"]').value = '';
        this.state.nextTerm = '';
        this.template.querySelector('[data-name="nextterm"]').value = '';
        this.state.section = '';
        this.state.pathwayType = '';
        
        // **NEW: Clear course offerings when institute changes**
        this.clearCourseOfferings();
    }

    handleDepartmentChange({ detail }) {
        this.state.department = detail.value;

        // reset others
        this.state.program = '';
        this.state.programSpecialization = '';
        this.template.querySelector('[data-name="specialization"]').value = '';
        this.state.programPlan = '';
        this.template.querySelector('[data-name="intake"]').value = '';
        this.state.term = '';
        this.state.nextTerm = '';
        this.template.querySelector('[data-name="term"]').value = '';
        this.template.querySelector('[data-name="nextterm"]').value = '';
        this.state.section = '';
        this.state.pathwayType = '';
        
        // **NEW: Clear course offerings when department changes**
        this.clearCourseOfferings();
    }

    handleProgramChange({ detail }) {
        this.state.program = detail.value;

        // reset others
        this.state.programSpecialization = '';
        this.template.querySelector('[data-name="specialization"]').value = '';
        this.state.programPlan = '';
        this.template.querySelector('[data-name="intake"]').value = '';
        this.state.term = '';
        this.state.nextTerm = '';
        this.template.querySelector('[data-name="term"]').value = '';
        this.template.querySelector('[data-name="nextterm"]').value = '';
        this.state.section = '';
        this.state.pathwayType = '';
        
        // **NEW: Clear course offerings when program changes**
        this.clearCourseOfferings();
    }

    handleSpecializationChange({ detail }) {
        this.state.programSpecialization = detail.value;
    }

    handleIntakeChange(event) {
        console.log('event intake' + event.detail);
        this.state.programPlan = event.detail.value;
        console.log('this.state.programPlan1==>' + this.state.programPlan);

        // reset others
        this.state.term = '';
        this.template.querySelector('[data-name="term"]').value = '';
        this.state.nextTerm = '';
        this.template.querySelector('[data-name="nextterm"]').value = '';
        this.state.section = '';
        this.state.pathwayType = '';
        console.log('this.state.nextTerm==>' + this.state.nextTerm);
        
        // **NEW: Clear course offerings when intake changes**
        this.clearCourseOfferings();
    }

    handleSearch({ target }) {
        this.state.searchTerm = target.value;
    }

    handleClearClick(event) {
        this.state.institute = '';
        this.state.department = '';
        this.state.program = '';
        this.state.programPlan = '';
        this.state.term = '';
        this.state.programSpecialization = '';
        this.state.section = '';
        this.state.searchTerm = '';
        this.state.nextTerm = '';
        this.state.pathwayType = '';

        const inputs = this.template.querySelectorAll('[data-id="input"]');
        inputs.forEach(input => input.value = '');

        this.studentDetails = [];
        this.selectedIds = [];

        // **UPDATED: Clear all four course offering arrays**
        this.clearCourseOfferings();

        this.currentPage = 1;
        this.totalRecords = 0;
    }

    // The datatable only reports the selection on the current page, so keep the other pages' selections
    handleRowSelection(event) {
        const pageIds = new Set(this.paginatedStudentDetails.map(detail => detail.applicationRecordId));
        const otherPages = this.selectedIds.filter(id => !pageIds.has(id));
        this.selectedIds = [...otherPages, ...event.detail.selectedRows.map(row => row.applicationRecordId)];
    }

    // **NEW: Four separate course offering selection handlers**
    handleMajorCOSelection(event) {
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
        if (!this.validateSelectedRows(this.selectedIds)) {
            return false;
        }
        this.state.isLoading = true;

        try {
            const applicationIds = [...this.selectedIds];

            // **UPDATED: Combine all four course offering selections**
            const majorCOIds = this.selectedMajorCO;
            const minorCOIds = this.selectedMinorCO;
            const specializationCOIds = this.selectedSpecializationCO;
            const concentrationCOIds = this.selectedConcentrationCO;

            const coIds = [
                ...majorCOIds,
                ...minorCOIds,
                ...specializationCOIds,
                ...concentrationCOIds
            ];

            // Batches run one after another: in parallel they would compete for locks on the same
            // Course Offering records (enrollment counts) and fail.
            const enrolledIds = [];
            const failures = [];
            for (let start = 0; start < applicationIds.length; start += ENROLL_BATCH_SIZE) {
                const batch = applicationIds.slice(start, start + ENROLL_BATCH_SIZE);
                this.enrollProgress = `Enrolling students ${start + 1}-${start + batch.length} of ${applicationIds.length}...`;
                try {
                    await createProgramEnrollments({
                        contactIds: batch,
                        termId: this.state.nextTerm,
                        specializationId: this.state.programSpecialization,
                        courseOfferingIds: coIds,
                        prevTerm: this.state.term,
                    });
                    enrolledIds.push(...batch);
                } catch (error) {
                    console.error(`Error enrolling students ${start + 1}-${start + batch.length}:`, error);
                    failures.push({ count: batch.length, message: this.getErrorMessage(error) });
                }
            }

            // Remove the enrolled students; failed ones stay selected so they can be retried
            const enrolled = new Set(enrolledIds);
            this.studentDetails = this.studentDetails.filter(detail => !enrolled.has(detail.applicationRecordId));
            this.selectedIds = this.selectedIds.filter(id => !enrolled.has(id));
            this.totalRecords = this.studentDetails.length;
            if (this.currentPage > 1 && (this.currentPage - 1) * this.pageSize >= this.totalRecords) {
                this.currentPage = Math.max(1, Math.ceil(this.totalRecords / this.pageSize));
            }

            if (failures.length === 0) {
                this.showToast({ title: 'Success', message: `${enrolledIds.length} students enrolled successfully` });
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
            this.showToast({ title: 'Error', message: this.getErrorMessage(error), variant: 'error' });
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
        this.state.isLoading = true;
        const filters = await getFilterOptions();

        this.instituteOptions = this.sortByName(this.convertToOptions(filters.institutes));
        this.departmentsByInstitute = this.groupByParentId(filters.departments);
        this.programsByDepartment = this.groupByParentId(filters.programs);
        this.programPlanByProgram = this.groupByParentId(filters.programPlans);
        this.termsByProgramPlan = this.groupByParentId(filters.terms);
        this.programSpecializationsByProgram = this.groupByParentId(filters.programSpecializations);
        this.sectionsByTerms = this.groupByParentId(filters.sections);

        this.state.isLoading = false;
    }

    async performSearch() {
        this.state.isLoading = true;
        console.log(this.state);
        const result = await searchApplications({
            programPlan: this.state.programPlan,
            termId: this.state.term,
            sectionName: this.state.section,
            specialisationId: this.state.programSpecialization,
            nextTerm: this.state.nextTerm,
        });
        console.log('result from search app==>', result);
        
        this.studentDetails = result.studentdetails || [];
        this.selectedIds = [];

        // **UPDATED: Populate four course offering arrays**
        this.majorCourseOfferings = result.majorCourseOfferings || [];
        this.minorCourseOfferings = result.minorCourseOfferings || [];
        this.specializationCourseOfferings = result.specializationCourseOfferings || [];
        this.concentrationCourseOfferings = result.concentrationCourseOfferings || [];

        this.totalRecords = this.studentDetails.length;
        this.state.isLoading = false;
    }

    // **NEW: Helper method to clear all course offerings**
    clearCourseOfferings() {
        this.majorCourseOfferings = [];
        this.minorCourseOfferings = [];
        this.specializationCourseOfferings = [];
        this.concentrationCourseOfferings = [];
        this.clearCourseOfferingSelections();
    }

    // **NEW: Helper method to clear all course offering selections**
    clearCourseOfferingSelections() {
        this.selectedMajorCO = [];
        this.selectedMinorCO = [];
        this.selectedSpecializationCO = [];
        this.selectedConcentrationCO = [];
    }

    groupByParentId(options) {
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
        return idNamePairs.map((ob) => ({
            label: ob.name,
            value: ob.id,
        }));
    }

    validateSelectedRows(selectedRows) {
        if (selectedRows.length > 0) {
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
        return options.sort((a, b) => {
            if (a.label === undefined || b.label === undefined) {
                return -1;
            }

            return a.label.localeCompare(b.label);
        });
    }

    sortBy(field, reverse, primer) {
        const key = primer
            ? function (x) {
                return primer(x[field]);
            }
            : function (x) {
                return x[field];
            };

        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }

    onHandleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.studentDetails];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.studentDetails = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
    }

    // Pagination methods
    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNextPage() {
        if (this.currentPage < Math.ceil(this.totalRecords / this.pageSize)) {
            this.currentPage += 1;
        }
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.value;
        this.currentPage = 1;
    }
}