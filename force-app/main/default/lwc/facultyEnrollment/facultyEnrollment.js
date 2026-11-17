import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getFilterOptions from '@salesforce/apex/EnrollmentController.getFilterOptions';
import searchSubjects from '@salesforce/apex/EnrollmentController.searchSubjects';
import createFacultyEnrollments from '@salesforce/apex/EnrollmentController.createFacultyEnrollments';

export default class FacultyEnrollment extends LightningElement {
    @track state = {
        institute: '',
        department: '',
        program: '',
        programPlan: '',
        term: '',
        programSpecialization: '',
        section: '',
        isLoading: false
    };

    @track courseOfferings = [];
    // @track selectedOptionalCO = [];
    @track
    changedOptions = {};
    @track
    allFacultyOptions = [];

    instituteOptions = [];
    selectedRows = {};

    departmentsByInstitute = {};
    programsByDepartment = {};
    programPlanByProgram = {};
    termsByProgramPlan = {};
    programSpecializationsByProgram = {};
    sectionsByTerms = {};

    connectedCallback() {
        this.fetchFilters();
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

    handlePrimarySelection(event) {
        try {
            const offeringIndex = event.target.dataset.index;
            const courseOffering = this.courseOfferings[offeringIndex];
            const courseOfferingId = courseOffering.courseOfferingId;

            if (this.changedOptions[courseOfferingId]) {
                this.changedOptions[courseOfferingId].primary = event.detail;
            } else {
                this.changedOptions[courseOfferingId] = { primary: event.detail, supporting: [] };
            }

            // this needed to refresh parent list
            this.courseOfferings = this.courseOfferings.map((offering) => {
                if (offering.courseOfferingId === courseOfferingId) {
                    // changed
                    const primaryFaculty = event.detail;

                    return {
                        ...offering,
                        selectedFaculties: {
                            ...offering.selectedFaculties,
                            primary: primaryFaculty ? [primaryFaculty] : []
                        },
                        secondaryFacultyOptions: event.detail
                            ? this.allFacultyOptions.filter(
                                (facultyOption) =>
                                    facultyOption.value != primaryFaculty
                            )
                            : this.allFacultyOptions
                    };
                }
                return offering;
            });
        } catch (err) {
            console.log(err, 'error in primary selection');
        }
    }

    handleSelection(event) {
        try {
            const newSelected = event.detail;

            const offeringIndex = event.target.dataset.index;

            const courseOffering = this.courseOfferings[offeringIndex];

            const courseOfferingId = courseOffering.courseOfferingId;
            console.log('Error newSelected', JSON.stringify(newSelected));
            console.log('Error offeringIndex', JSON.stringify(offeringIndex));
            console.log('Error courseOffering', JSON.stringify(courseOffering));
            console.log('Error courseOfferingId', JSON.stringify(courseOfferingId));


            if (this.changedOptions[courseOfferingId]) {
                this.changedOptions[courseOfferingId].supporting = [...newSelected];
            } else {
                this.changedOptions[courseOfferingId] = { supporting: [...newSelected] };
            }

            this.courseOfferings = this.courseOfferings.map((offering) => {
                if (offering.courseOfferingId === courseOfferingId) {
                    // changed
                    return {
                        ...offering,
                        selectedFaculties: {
                            ...offering.selectedFaculties,
                            supporting: newSelected
                        }
                    };
                }
                return offering;
            });
        } catch (err) {
            console.log('Error handle selection', JSON.stringify(err));
        }
    }

    handleTermChange({ detail }) {
        this.state.term = detail.value;

        // reset
        this.state.section = '';
    }

    handleSectionChange({ detail }) {
        this.state.section = detail.value;
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
        this.state.section = '';
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
        this.template.querySelector('[data-name="term"]').value = '';
        this.state.section = '';
    }

    handleProgramChange({ detail }) {
        this.state.program = detail.value;

        // reset others
        this.state.programSpecialization = '';
        this.template.querySelector('[data-name="specialization"]').value = '';
        this.state.programPlan = '';
        this.template.querySelector('[data-name="intake"]').value = '';
        this.state.term = '';
        this.template.querySelector('[data-name="term"]').value = '';
        this.state.section = '';
    }

    handleSpecializationChange({ detail }) {
        this.state.programSpecialization = detail.value;
    }

    handleIntakeChange({ detail }) {
        this.state.programPlan = detail.value;

        // reset others
        this.state.term = '';
        this.template.querySelector('[data-name="term"]').value = '';

        this.state.section = '';
    }

    async handleEnrollClick() {
        this.state.isLoading = true;
        let selectedEnrollmentRows = [];
        console.log('term--->', this.state.term);
        console.log('programPlan--->', this.state.programPlan);
        console.log('program--->', this.state.program);
        console.log('programSpecialization--->', this.state.programSpecialization);
        try {
            console.log('courseOfferings-->', JSON.stringify(this.courseOfferings));

            const originalCourseOfferingsById = {};
            this.courseOfferings.forEach(co => {
                originalCourseOfferingsById[co.courseOfferingId] = co;
            });
            console.log('originalCourseOfferingsById:', JSON.stringify(originalCourseOfferingsById));

            console.log('this.changedOptions::::', JSON.stringify(this.changedOptions));

            for (let key in this.changedOptions) {
                console.log('key is :::', JSON.stringify(key));
                if (this.changedOptions[key] !== undefined) {
                    console.log('Processing changedOptions for courseOfferingId:', key);
                    console.log('changedOptions[key]:', JSON.stringify(this.changedOptions[key]));

                    const faculties = [];

                    if (this.changedOptions[key]?.primary) {
                        console.log('Primary faculty changed for', key, '->', this.changedOptions[key].primary);

                        faculties.push({ isPrimary: true, facultyId: this.changedOptions[key].primary });
                        console.log('faculties :::', JSON.stringify(faculties));
                    } else {
                        if (originalCourseOfferingsById[key]?.selectedFaculties?.primary?.length) {
                            console.log('Retaining original primary faculty for', key, '->', originalCourseOfferingsById[key].selectedFaculties.primary[0]);

                            faculties.push({ isPrimary: true, facultyId: originalCourseOfferingsById[key].selectedFaculties.primary[0] });
                        }
                    }

                    console.log('changed key length:::', this.changedOptions[key]?.supporting?.length);
                    console.log('after::--');

                    if (this.changedOptions[key]?.supporting?.length) {
                        console.log('inside if::::');
                        console.log('Supporting faculties changed for', key, '->', this.changedOptions[key].supporting);

                        faculties.push(...this.changedOptions[key].supporting.map(faculty => { return { isPrimary: false, facultyId: faculty }; }));
                    } else {
                        console.log('inside else::::');
                        console.log('Retaining original supporting faculties for', key, '->', originalCourseOfferingsById[key]?.selectedFaculties?.supporting);

                        if(originalCourseOfferingsById[key]?.selectedFaculties){
                            console.log('new if:::');
                            faculties.push(...originalCourseOfferingsById[key]?.selectedFaculties?.supporting?.map(faculty => { return { isPrimary: false, facultyId: faculty }; }));
                        }

                        
                    }
                    console.log('Final faculties list for', key, '->', JSON.stringify(faculties));

                    selectedEnrollmentRows.push({
                        courseOfferingId: key,
                        faculties
                    });
                }
            }
            console.log('Final selectedEnrollmentRows before validation:', JSON.stringify(selectedEnrollmentRows));

            this.validateSelectedRows(selectedEnrollmentRows);
            console.log('term--->', this.state.term);
            console.log('programPlan--->', this.state.programPlan);
            console.log('program--->', this.state.program);
            console.log('programSpecialization--->', this.state.programSpecialization);


            await createFacultyEnrollments({

                facultyEnrollments: selectedEnrollmentRows,
                termId: this.state.term,
                programPlan: this.state.programPlan,
                program: this.state.program,
                specializationId: this.state.programSpecialization
            });
            console.log('createFacultyEnrollments--->', JSON.stringify(createFacultyEnrollments));


            this.showToast({
                title: 'Success',
                message: 'Faculties Enrolled successfully'
            });
            this.state.isLoading = false;

            return true;
        } catch (error) {
            this.state.isLoading = false;

            console.log('Error enroll--->', JSON.stringify(error));
            this.showToast({
                title: 'Error',
                message: error.body.message,
                variant: 'error'
            });
            return false;
        }
    }

    handleSearchClick() {
        const allValid = [
            ...this.template.querySelectorAll('[data-id="input"]')
        ].reduce((validSoFar, inputCmp) => {
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
        this.programSpecializationsByProgram = this.groupByParentId(
            filters.programSpecializations
        );
        this.sectionsByTerms = this.groupByParentId(filters.sections);

        this.state.isLoading = false;
    }

    async performSearch() {
        this.state.isLoading = true;

        const result = await searchSubjects({
            termId: this.state.term,
            sectionName: this.state.section,
            specialisationId: this.state.programSpecialization
        });

        const courseOfferings = result.courseOfferings;


        if (courseOfferings?.length) {
            courseOfferings.forEach((course) => {
                // because we don't want to show the faculty which is chosen as primary for this course offering
                const primaryFaculty = course.selectedFaculties.primary.length
                    ? course.selectedFaculties.primary[0]
                    : '';

                course.secondaryFacultyOptions = primaryFaculty
                    ? result.allFaculties.filter(
                        (facultyOption) =>
                            facultyOption.value != primaryFaculty
                    )
                    : result.allFaculties;
            });
        }

        this.courseOfferings = courseOfferings;


        this.allFacultyOptions = result.allFaculties;
        this.state.isLoading = false;
        console.log('courseOfferings--', JSON.stringify(this.courseOfferings));

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
            value: ob.id
        }));
    }

    validateSelectedRows(selectedEnrollmentRows) {
        if (selectedEnrollmentRows.length > 0) {
            return true;
        }

        this.showToast({
            variant: 'error',
            title: 'Error',
            message: 'Please select any faculty to enroll.'
        });
        return false;
    }

    showToast({ title, message, variant = 'success' }) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
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
}