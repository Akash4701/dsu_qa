import { LightningElement, track, wire,api } from 'lwc';
import getAcademicTerms from '@salesforce/apex/AcademicFilterController.getAcademicTerms';
import getProgramsAndPlans from '@salesforce/apex/AcademicFilterController.getProgramsAndPlans';
import getTermsWithAcademicTerm from '@salesforce/apex/AcademicCalenderScreenController.getTermsWithAcademicTerm';
import getCourseConnections from '@salesforce/apex/AcademicCalenderScreenController.getCourseConnections';
import createProgramPathway from '@salesforce/apex/AcademicFilterController.createProgramPathway';
import getLookupOptions from '@salesforce/apex/AcademicFilterController.getLookupOptions';
import getPicklistValues from '@salesforce/apex/AcademicFilterController.getPicklistValues';
import createCluster from '@salesforce/apex/AcademicFilterController.createCluster';
import getAcademicPrograms from '@salesforce/apex/AcademicCalenderScreenController.getAcademicPrograms';
import getProgramPlans from '@salesforce/apex/AcademicCalenderScreenController.getProgramPlans';
import getTerms from '@salesforce/apex/AcademicCalenderScreenController.getTerms';
import getTermsWithMultipleAcademicTerms from '@salesforce/apex/AcademicCalenderScreenController.getTermsWithMultipleAcademicTerms';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CbcsAcademicPlanner extends LightningElement {
    @track termOptions = [];
    @track programOptions = [];
    @track planOptions = [];
    @track terms = [];
    @track selectedTerms = [];
    selectedTerm = '';
    selectedProgram = '';
    selectedPlan = '';

    @track showModal = false;
    @track showSpinner = false;

    @track selectedPathwayMaster = '';
    @track selectedCourse = '';
    @track specializationType = '';
    @track maximumCredits = '';
    @track startingSemester = '';
    @track endingSemester = '';
    @track cgpaRule = '';

    @track specializationTypeOptions = [];
    @track cgpaRuleOptions = [];
    @track startingSemesterOptions = [];
    @track endingSemesterOptions = [];

    @track pathwayMasterOptions = [];
    @track courseOptions = [];

   @track showClusterModal = false;
@track clusterName = '';
@track minCourses = 0;
@track maxCourses = 1;



    selectedTermIdForPopup = '';
    selectedSectionIdForPopup = '';
    
    
    get options() {
        return [
            { label: 'Major', value: 'Major' },
            { label: 'Minor', value: 'Minor' },
            { label: 'Specialization', value: 'Specialization' },
            { label: 'Concentration', value: 'Concentration' },
        ];
    }

     handleChange(event) {
        this.value = event.detail.value;
    }

    connectedCallback() {
        this.loadInitialData();
    }

    loadInitialData() {
        // Load academic terms
        getAcademicPrograms().then(result => {
            this.programOptions = result.map(program => ({
                label: program.Name,
                value: program.Id
            }));
        }).catch(error => {
            this.showToast('Error', 'Failed to load academic program: ' + error.body.message, 'error');
        });
        getAcademicTerms().then(result => {
            this.termOptions = result.map(term => ({
                label: term.Name,
                value: term.Id
            }));
        }).catch(error => {
            this.showToast('Error', 'Failed to load academic terms: ' + error.body.message, 'error');
        });

        // Load lookup options
        getLookupOptions()
            .then(result => {
                this.pathwayMasterOptions = result.pathwayMasters.map(p => ({ label: p.Name, value: p.Id }));
                this.courseOptions = result.courses.map(c => ({ label: c.Name, value: c.Id }));
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load lookup values: ' + error.body.message, 'error');
            });

        // Load picklist values
        getPicklistValues()
            .then(result => {
                this.specializationTypeOptions = result.specializationTypes;
                this.cgpaRuleOptions = result.cgpaRules;
                this.startingSemesterOptions = result.startingSemesters;
                this.endingSemesterOptions = result.endingSemesters;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load picklist values: ' + error.body.message, 'error');
            });
    }
    
handleTermChange(event) {
    this.selectedTerms = event.detail.value;

    // No filter selected → call default logic
    if (!this.selectedTerms || this.selectedTerms.length === 0) {
        getTerms({ programPlanId: this.selectedPlan })
        .then(result => {
            const rawTerms = result?.terms || [];

            getCourseConnections().then(connectionResult => {
                const courseConnections = connectionResult?.courseConnections || [];

                this.terms = rawTerms.map(term => ({
                    ...term,
                    isExpanded: false,
                    courseOfferings: [],
                    isLoadingCourses: false,
                    iconName: 'utility:chevronright',
                    innerSections: courseConnections.map(conn => {
                        const isActive = conn.Active__c === true;
                        return {
                            id: `cc-${conn.Id}`,
                            title: conn.Name,
                            titleIsNotCore: conn.Name !== 'Core',
                            isActive: isActive,
                            isExpanded: false,
                            iconName: 'utility:chevronright',
                            labelClass: 'slds-text-title_bold slds-m-left_small' + (isActive ? '' : ' text-grey')
                        };
                    })
                }));
            });

        })
        .catch(error => {
            this.showToast('Error', error?.body?.message || error?.message, 'error');
        });
        return;
    }

    // One or more academic terms selected → call filtered logic
    getTermsWithMultipleAcademicTerms({
        academicTermIds: this.selectedTerms,
        programPlanId: this.selectedPlan
    })
    .then(result => {
        const rawTerms = result?.terms || [];

        getCourseConnections().then(connectionResult => {
            const courseConnections = connectionResult?.courseConnections || [];

            this.terms = rawTerms.map(term => ({
                ...term,
                isExpanded: false,
                courseOfferings: [],
                isLoadingCourses: false,
                iconName: 'utility:chevronright',
                innerSections: courseConnections.map(conn => {
                    const isActive = conn.Active__c === true;
                    return {
                        id: `cc-${conn.Id}`,
                        title: conn.Name,
                        titleIsNotCore: conn.Name !== 'Core',
                        isActive: isActive,
                        isExpanded: false,
                        iconName: 'utility:chevronright',
                        labelClass: 'slds-text-title_bold slds-m-left_small' + (isActive ? '' : ' text-grey')
                    };
                })
            }));
        });

    })
    .catch(error => {
        this.showToast('Error', error?.body?.message || error?.message, 'error');
    });
}




    handleProgramChange(event) {
        this.selectedProgram = event.detail.value;
        this.PlanOptions = [];
        this.terms = [];
        setTimeout(() => {
        this.selectedAcademicProgramId = event.detail.value;
        if (this.selectedAcademicProgramId) {
            this.loadProgramPlans();
            //this.loadSubjects();
        }
    }, 100);
    }

    handlePlanChange(event) {
        this.selectedPlan = event.detail.value;
        setTimeout(() => {
            this.loadTermsAndDetails();
        }, 100);
    }
    loadTermsAndDetailsFromTerms(termList) {
    getCourseConnections()
        .then(connectionResult => {
            const courseConnections = connectionResult?.courseConnections || [];

            this.terms = termList.map(term => ({
                ...term,
                isExpanded: false,
                courseOfferings: [],
                isLoadingCourses: false,
                iconName: 'utility:chevronright',
                innerSections: courseConnections.map(conn => {
                    const isActive = conn.Active__c === true;
                    return {
                        id: `cc-${conn.Id}`,
                        title: conn.Name,
                        titleIsNotCore: conn.Name !== 'Core',
                        isActive: isActive,
                        isExpanded: false,
                        iconName: 'utility:chevronright',
                        labelClass: 'slds-text-title_bold slds-m-left_small' + (isActive ? '' : ' text-grey')
                    };
                })
            }));
        })
        .catch(error => {
            const msg = error?.body?.message || error?.message || 'Failed to load course connections';
            this.showToast('Error', msg, 'error');
        });
}

    loadProgramPlans() {
        getProgramPlans({ academicProgramId: this.selectedProgram })
            .then(result => {
                this.planOptions = result.map(plan => ({
                    label: plan.Name,
                    value: plan.Id
                }));
            })
            .catch(error => {
                this.showToast('Error', 'Error loading program plans: ' + error.body.message, 'error');
            });
    }
loadTermsAndDetails() {
    Promise.all([
        getTerms({ programPlanId: this.selectedPlan }),
        getCourseConnections()
    ])
    .then(([termResult, connectionResult]) => {
        const courseConnections = connectionResult?.courseConnections || [];

        if (termResult?.terms) {
            this.terms = termResult.terms.map(term => ({
                ...term,
                isExpanded: false,
                courseOfferings: [],
                isLoadingCourses: false,
                iconName: 'utility:chevronright',
                innerSections: courseConnections.map(conn => {
                    const isActive = conn.Active__c === true;
                    return {
                        id: `cc-${conn.Id}`,
                        title: conn.Name,
                        titleIsNotCore: conn.Name !== 'Core',
                        isActive: isActive,
                        isExpanded: false,
                        iconName: 'utility:chevronright',
                        labelClass: 'slds-text-title_bold slds-m-left_small' + (isActive ? '' : ' text-grey')
                    };
                })
            }));
        }
    })
    .catch(error => {
        this.showToast('Error', 'Error loading terms: ' + error.body.message, 'error');
    });
}



    handleToggleExpand(event) {
        const termId = event.currentTarget.dataset.termId;
        const termIndex = this.terms.findIndex(term => term.Id === termId);
        if (termIndex !== -1) {
            const updatedTerms = [...this.terms];
            const term = updatedTerms[termIndex];
            term.isExpanded = !term.isExpanded;
            term.iconName = term.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
            if (term.isExpanded && (!term.courseOfferings || term.courseOfferings.length === 0)) {
                this.loadTermCourseOfferings(termId, termIndex);
            }
            this.terms = updatedTerms;
        }
    }

    loadTermCourseOfferings(termId, termIndex) {
        const updatedTerms = [...this.terms];
        updatedTerms[termIndex].isLoadingCourses = true;
        this.terms = updatedTerms;
        
    }

    handleToggleInnerSection(event) {
        const termId = event.currentTarget.dataset.termId;
        const sectionId = event.currentTarget.dataset.sectionId;

        const updatedTerms = [...this.terms];
        const termIndex = updatedTerms.findIndex(t => t.Id === termId);
        if (termIndex !== -1) {
            const sectionIndex = updatedTerms[termIndex].innerSections.findIndex(s => s.id === sectionId);
            if (sectionIndex !== -1) {
                const section = updatedTerms[termIndex].innerSections[sectionIndex];
                section.isExpanded = !section.isExpanded;
                section.iconName = section.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
                this.terms = updatedTerms;
            }
        }
    }

    handleAddCourses(event) {
        const termId = event.currentTarget.dataset.termId;
        const sectionId = event.currentTarget.dataset.sectionId;
        this.selectedTermIdForPopup = termId;
        this.selectedSectionIdForPopup = sectionId;

        this.selectedPathwayMaster = '';
        this.selectedCourse = '';
        this.specializationType = '';
        this.maximumCredits = '';
        this.startingSemester = '';
        this.endingSemester = '';
        this.cgpaRule = '';

        this.showModal = true;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.detail ? event.detail.value : event.target.value;
        this[fieldMap(field)] = value;
    }

    handleSaveProgramPathway() {
        this.showSpinner = true;
        createProgramPathway({
            pathwayMasterId: this.selectedPathwayMaster,
            programPlanId: this.selectedPlan,
            courseId: this.selectedCourse,
            specializationType: this.specializationType,
            maximumCredits: this.maximumCredits,
            startingSemester: this.startingSemester,
            endingSemester: this.endingSemester,
            cgpaRule: this.cgpaRule
        }).then(() => {
            this.showToast('Success', 'Program Pathway created successfully', 'success');
            this.showModal = false;
        }).catch(error => {
            this.showToast('Error', error.body.message, 'error');
        }).finally(() => {
            this.showSpinner = false;
        });
    }

    handleModalClose() {
        this.showModal = false;
         this.showClusterModal = false;
    }

    handleAddClusters(event) {
    this.selectedTermIdForPopup = event.currentTarget.dataset.termId;
    this.selectedSectionIdForPopup = event.currentTarget.dataset.sectionId;

    this.clusterName = '';
    this.minCourses = 0;
    this.maxCourses = 1;

    this.showClusterModal = true;
}


handleClusterModalClose() {
    this.showClusterModal = false;
}

handleClusterInputChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    if (field === 'clusterName') {
        this.clusterName = value;
    } else if (field === 'minCourses') {
        this.minCourses = parseInt(value, 10);
    } else if (field === 'maxCourses') {
        this.maxCourses = parseInt(value, 10);
    }
}

handleSaveCluster() {
    createCluster({
        name: this.clusterName,
        min: this.minCourses,
        max: this.maxCourses,
        termId: this.selectedTerm, // ← this must be from Academic_Term__c
        programId: this.selectedProgram
    }).then(() => {
        this.showToast('Success', 'Cluster created successfully', 'success');
        this.showClusterModal = false;
    }).catch(error => {
        this.showToast('Error', error.body.message, 'error');
    });
}


    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}

function fieldMap(apiName) {
    return {
        'Pathway_Master__c': 'selectedPathwayMaster',
        'Program_Plan__c': 'selectedPlan',
        'Course__c': 'selectedCourse',
        'Specialization_Type__c': 'specializationType',
        'Maximum_Credits__c': 'maximumCredits',
        'Starting_Semester__c': 'startingSemester',
        'Ending_Semester__c': 'endingSemester',
        'CGPA_Rule__c': 'cgpaRule'
    }[apiName];
}