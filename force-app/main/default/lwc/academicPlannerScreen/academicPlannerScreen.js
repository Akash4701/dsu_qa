// academicPlannerScreen.js
import { LightningElement, track, wire,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from "lightning/confirm";
import getAcademicPrograms from '@salesforce/apex/AcademicCalenderScreenController.getAcademicPrograms';
import getProgramPlans from '@salesforce/apex/AcademicCalenderScreenController.getProgramPlans';
import getTerms from '@salesforce/apex/AcademicCalenderScreenController.getTerms';
import updateTermDates from '@salesforce/apex/AcademicCalenderScreenController.updateTermDates';
//import getTermActivities from '@salesforce/apex/AcademicCalenderScreenController.getTermActivities';
import getTermCourseOfferings from '@salesforce/apex/HolidayController.getTermCourseOfferings';
import deleteCourseOffering from '@salesforce/apex/HolidayController.deleteCourseOffering';
import getAllHolidays from '@salesforce/apex/HolidayController.getAllHolidays';
//import getAvailableSubjects from '@salesforce/apex/HolidayController.getAvailableSubjects';
import getAvailableSubjectsFromMasterUnits from '@salesforce/apex/HolidayController.getAvailableSubjectsFromMasterUnits';
//import addCourseOffering from '@salesforce/apex/HolidayController.addCourseOffering';
import addSubjectAsPlanRequirement from '@salesforce/apex/HolidayController.addSubjectAsPlanRequirement';
import getPlanRequirementsMasterUnits from '@salesforce/apex/HolidayController.getPlanRequirementsMasterUnits';
import importCurriculum from '@salesforce/apex/HolidayController.importCurriculum';
import deleteAllCourseOfferings from '@salesforce/apex/HolidayController.deleteAllCourseOfferings';
//import updateCourseOffering from '@salesforce/apex/HolidayController.updateCourseOffering';
import updateCourseOfferings from '@salesforce/apex/HolidayController.updateCourseOfferings';
// Add this to your imports at the top of academicPlannerScreen.js
import deleteCompleteCourseOffering from '@salesforce/apex/HolidayController.deleteCompleteCourseOffering';
import getCoursesByAcademicProgram from '@salesforce/apex/AcademicCalenderScreenController.getCoursesByAcademicProgram';
import getCourseIdBySubject from '@salesforce/apex/AcademicCalenderScreenController.getCourseIdBySubject';

export default class AcademicPlannerScreen extends LightningElement {
    currentTab = 'planner';
    @track academicProgramOptions = [];
    @track programPlanOptions = [];
    @track selectedAcademicProgramId;
    @track selectedProgramPlanId;
    @track workingDays = '';
    @track terms = [];
    @track showHolidayModal = false;
    @track holidays = [];
    @track isLoadingHolidays = false;
    @track currentTermId;
    @track currentTermName;
    @track draftValues = [];
    // Updated column definitions with inline editing enabled
    // Modified column definitions to correctly handle date format without time
@track courseColumns = [
    { 
        label: 'Week no.', 
        fieldName: 'weekNo', 
        type: 'text', 
        initialWidth: 200,
        sortable: true
    },
    { 
        label: 'Course', 
        fieldName: 'courseName', 
        type: 'text', 
        initialWidth: 460,
        sortable: true 
    },
    { 
        label: 'Course code', 
        fieldName: 'courseId', 
        type: 'text', 
        sortable: true, 
        initialWidth: 220,
        iconName: 'utility:down',
        cellAttributes: { 
            alignment: 'left' 
        }
    },
    { 
        label: 'Section', 
        fieldName: 'sectionId', 
        type: 'text',
        editable: false,
        sortable: true,
        initialWidth: 200,
        cellAttributes: { 
            alignment: 'left' 
        }
    },
    { 
        label: 'Section Strenght', 
        fieldName: 'credits', 
        type: 'text',
        editable: true,
        sortable: true, 
        initialWidth: 200,
        cellAttributes: { 
            alignment: 'left' 
        }
    },
    { 
        label: 'Start date', 
        fieldName: 'startDate', 
        type: 'date', 
        typeAttributes: {
            day: 'numeric',
            month: 'short',
            year: 'numeric',
            timeZone: 'Asia/Kolkata'
        },
        editable: true,
        sortable: true,
        iconName: 'utility:down',
        initialWidth: 200
    },
    { 
        label: 'End date', 
        fieldName: 'endDate', 
        type: 'date',
        typeAttributes: {
            day: 'numeric',
            month: 'short',
            year: 'numeric',
            timeZone:  'Asia/Kolkata'
              },
        editable: true,
        sortable: true,
        iconName: 'utility:down',
        initialWidth: 200
    },
    {
        label: '',
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Delete', name: 'delete', iconName: 'utility:delete' }
            ]
        },
        
    }
    
];
    
    @track defaultSortDirection = 'asc';
    @track sortDirection = 'asc';
    @track sortedBy;
    //for subjects
    @track showAddSubjectsModal = false;
    @track availableSubjects = [];
    @track selectedSubject;
    @track selectedSubjectId;
    @track sectionId = '';
    @track subjectStartDate;
    @track subjectEndDate;
    @track isLoadingSubjects = false;
    @track courseId = '';
    @track capacity = '';
    @track dateError = '';
    @track showDateError = false;
    @track courseToShow = [];

    //import curricumum buttom
    @track showImportCurriculumModal = false;
    @track planRequirements = [];
    @track isLoadingPlanRequirements = false;
    @track selectedPlanRequirements = [];
    @track allSelected = false;
    @track displayedPlanRequirements = [];
    @track searchTerm = '';
    @track masterGroups = []; // To store unique master groups
    @track selectedMasterGroup = 'All'; // For filtering by master group
    
    // Columns for the imported curriculum datatable
    @track planRequirementColumns = [
        {
            label: '',
            fieldName: 'checked',
            type: 'boolean',
            editable: true,
            initialWidth: 50
        },
        {
            label: 'Subject code',
            fieldName: 'subjectCode',
            type: 'text',
            sortable: true,
            initialWidth: 120
        },
        {
            label: 'Subject',
            fieldName: 'subject',
            type: 'text',
            sortable: true
        },
        {
            label: 'Specialisation',
            fieldName: 'specialisation',
            type: 'text',
            sortable: true
        },
        {
            label: 'Credits',
            fieldName: 'credits',
            type: 'text',
            sortable: true,
            initialWidth: 100
        },
        {
            label: 'Credit hours',
            fieldName: 'creditHours',
            type: 'text',
            sortable: true,
            initialWidth: 120
        },
        {
            label: 'Category',
            fieldName: 'category',
            type: 'text',
            sortable: true,
            initialWidth: 120
        }
    ];

   

    // Wired academic programs
    @wire(getAcademicPrograms)
    wiredAcademicPrograms({ error, data }) {
        if (data) {
            this.academicProgramOptions = data.map(program => ({
                label: program.Name,
                value: program.Id
            }));
        } else if (error) {
            this.showToast('Error', 'Error loading academic programs: ' + error.body.message, 'error');
        }
    }
// **********************************************************************************************************************************
    @track selectedAcademicProgramId;
    @track selectedProgramPlanId;
    @track workingDays;

    // Private backing vars
    _selectedAcademicProgram;
    _selectedProgramPlan;
    _workingDays;


    @api
    get selectedAcademicProgram() {
        return this._selectedAcademicProgram;
    }
    set selectedAcademicProgram(value) {
        this._selectedAcademicProgram = value;
        this.selectedAcademicProgramId = value || null; // Assuming value is an object
        if (this.selectedAcademicProgramId) {
            this.loadProgramPlans(); // Or any other logic to refresh UI
        }
    }

    @api
    get selectedProgramPlan() {
        return this._selectedProgramPlan;
    }
    set selectedProgramPlan(value) {
        this._selectedProgramPlan = value;
        this.selectedProgramPlanId = value || null;
        // You can trigger other logic if needed here
        this.loadTermsAndDetailsForNAVIGATE();
    }

    @api
    get workingDays() {
        console.log('get working days called');
        return this._workingDays;
    }
    /**
     * @param {string} value
     */
    set workingDays(value) {
        this._workingDays = value;
        this.workingDays = value; // Assign to tracked var if needed in template or logic
        console.log('Working days set to:', this.workingDays);
        // Trigger any logic here if needed
    }

loadTermsAndDetailsForNAVIGATE() {
        getTerms({ programPlanId: this.selectedProgramPlanId })
            .then(result => {
                if (result) {
                    // Set working days
                    if (result.programPlanDetail && result.programPlanDetail.Working_Days__c) {
                        this.workingDays = result.programPlanDetail.Working_Days__c;
                    }
                    
                    // Set terms with expanded property
                    if (result.terms) {
                        this.terms = JSON.parse(JSON.stringify(result.terms)).map(term => {
                            return {
                                ...term,
                                isExpanded: false,
                                courseOfferings: [],
                                isLoadingCourses: false,
                                iconName: 'utility:chevronright'
                            };
                        });
                    }
                }
            })
            .catch(error => {
                // this.showToast('Error', 'Error loading terms: ' + error.body.message, 'error');
            });
    }
// **********************************************************************************************************************************
    // Update handleAcademicProgramChange to force UI refresh
handleAcademicProgramChange(event) {
    this.selectedAcademicProgramId = null; // Force complete refresh
    this.selectedProgramPlanId = null;
    
    // Reset all data
    this.terms = [];
    this.workingDays = '';
    this.planRequirements = [];
    this.displayedPlanRequirements = [];
    this.programPlanOptions = [];
    
    // Set the new academic program ID with a slight delay to ensure UI refreshes
    setTimeout(() => {
        this.selectedAcademicProgramId = event.detail.value;
        if (this.selectedAcademicProgramId) {
            this.loadProgramPlans();
            //this.loadSubjects();
        }
    }, 100);
}

//--------------------->>>>>>>>>>

@track subjectOptions =[];
loadSubjects() {
    
    getCoursesByAcademicProgram({ academicProgramId: this.selectedAcademicProgramId })
        .then(result => {
            this.subjectOptions = result.map(sub => ({ 
                label: sub.Name,
                value: sub.Id,
                courseId: sub.hed__Course__c // Assuming courseId is needed later
            }));
        })
        .catch(error => {
            this.showToast('Error', 'Error loading subjects: ' + (error.body ? error.body.message : error.message), 'error');
        });
}

    
    // Load program plans for selected academic program
    loadProgramPlans() {
        getProgramPlans({ academicProgramId: this.selectedAcademicProgramId })
            .then(result => {
                this.programPlanOptions = result.map(plan => ({
                    label: plan.Name,
                    value: plan.Id
                }));
            })
            .catch(error => {
                this.showToast('Error', 'Error loading program plans: ' + error.body.message, 'error');
            });
    }

    // Add this to force clear the wire cache when program plan changes
    @api
    refreshCache() {
        if (this._wiredProgramPlansResult) {
            return refreshApex(this._wiredProgramPlansResult);
        }
        return Promise.resolve();
    }
    
    // Handle program plan change
    handleProgramPlanChange(event) {
        // Store new value
        const newProgramPlanId = event.detail.value;
        
        // Reset everything
        this.selectedProgramPlanId = null;
        this.terms = [];
        this.workingDays = '';
        this.planRequirements = [];
        this.displayedPlanRequirements = [];
        
        // Use setTimeout to ensure the UI resets before setting the new value
        setTimeout(() => {
            console.log('Setting new Program Plan ID:', newProgramPlanId);
            this.selectedProgramPlanId = newProgramPlanId;
            
            // If a program plan is selected, get terms and details
            if (this.selectedProgramPlanId) {
                this.loadTermsAndDetails();
            }
        }, 100);
    }
    
    
    // Load terms and program plan details
    loadTermsAndDetails() {
        getTerms({ programPlanId: this.selectedProgramPlanId })
            .then(result => {
                if (result) {
                    // Set working days
                    if (result.programPlanDetail && result.programPlanDetail.Working_Days__c) {
                        this.workingDays = result.programPlanDetail.Working_Days__c;
                    }
                    
                    // Set terms with expanded property
                    if (result.terms) {
                        this.terms = JSON.parse(JSON.stringify(result.terms)).map(term => {
                            return {
                                ...term,
                                isExpanded: false,
                                courseOfferings: [],
                                isLoadingCourses: false,
                                iconName: 'utility:chevronright'
                            };
                        });
                    }
                }
            })
            .catch(error => {
                this.showToast('Error', 'Error loading terms: ' + error.body.message, 'error');
            });
    }
    
    // Toggle term expansion
    handleToggleExpand(event) {
        const termId = event.currentTarget.dataset.termId;
        const termIndex = this.terms.findIndex(term => term.Id === termId);
        
        if (termIndex !== -1) {
            const updatedTerms = [...this.terms];
            updatedTerms[termIndex].isExpanded = !updatedTerms[termIndex].isExpanded;
            
            // Update icon based on expanded status
            updatedTerms[termIndex].iconName = updatedTerms[termIndex].isExpanded 
                ? 'utility:chevrondown' 
                : 'utility:chevronright';
            
            // If expanding and no course offerings loaded yet, fetch them
            if (updatedTerms[termIndex].isExpanded && 
                (!updatedTerms[termIndex].courseOfferings || 
                 updatedTerms[termIndex].courseOfferings.length === 0)) {
                this.loadTermCourseOfferings(termId, termIndex);
            }
            
            this.terms = updatedTerms;
        }
    }
    
   // Modified loadTermCourseOfferings method to better handle date formats
     // Updated loadTermCourseOfferings to properly handle dates
// loadTermCourseOfferings(termId, termIndex) {
//     console.log('Loading course offerings for term:', termId, 'index:', termIndex);
    
//     // Set loading state
//     const updatedTerms = [...this.terms];
//     updatedTerms[termIndex].isLoadingCourses = true;
//     this.terms = updatedTerms;
    
//     getTermCourseOfferings({ termId: termId })
//         .then(result => {
//             console.log('Received course offerings:', result ? result.length : 0);
            
//             const updatedTerms = [...this.terms];
//             updatedTerms[termIndex].isLoadingCourses = false;
            
//             if (result && result.length > 0) {
//                 // Format course offerings for display
//                 const courseOfferings = JSON.parse(JSON.stringify(result)).map(offering => {
//                     // Format date objects to ensure no time component
//                     let startDate = null;
//                     let endDate = null;
                    
//                     if (offering.hed__Start_Date__c) {
//                         startDate = this.normalizeDate(offering.hed__Start_Date__c);
//                     }
                    
//                     if (offering.hed__End_Date__c) {
//                         endDate = this.normalizeDate(offering.hed__End_Date__c);
//                     }
                    
//                     return {
//                         ...offering,
//                         Id: offering.Id,
//                         weekNo: offering.Course_Version__r ? offering.Course_Version__r.WeekNo__c : '',
//                         courseName: offering.hed__Course__r ? offering.hed__Course__r.Name : '',
//                         courseId: offering.hed__Course__r ? offering.hed__Course__r.hed__Course_ID__c : '',
//                         sectionId: offering.hed__Section_ID__c || '',
//                         credits: offering.hed__Capacity__c || '',
//                         // Use the normalized dates
//                         startDate: startDate,
//                         endDate: endDate
//                     };
//                 });
                
//                 updatedTerms[termIndex].courseOfferings = courseOfferings;
//             } else {
//                 updatedTerms[termIndex].courseOfferings = [];
//             }
            
//             // Clear draft values to ensure edit mode is reset
//             this.draftValues = [];
            
//             this.terms = updatedTerms;
//         })
//         .catch(error => {
//             console.error('Error loading course offerings:', error);
            
//             const updatedTerms = [...this.terms];
//             updatedTerms[termIndex].isLoadingCourses = false;
//             this.terms = updatedTerms;
            
//             let errorMessage = 'Error loading course offerings';
//             if (error) {
//                 if (error.body && error.body.message) {
//                     errorMessage += ': ' + error.body.message;
//                 } else if (error.message) {
//                     errorMessage += ': ' + error.message;
//                 }
//             }
            
//             this.showToast('Error', errorMessage, 'error');
//         });
// }

loadTermCourseOfferings(termId, termIndex) {
    console.log('Loading course offerings for term:', termId, 'index:', termIndex);
    
    const updatedTerms = [...this.terms];
    updatedTerms[termIndex].isLoadingCourses = true;
    this.terms = updatedTerms;
    
    getTermCourseOfferings({ termId: termId })
        .then(result => {
            console.log('Received course offerings:', result ? result.length : 0);
            
            const updatedTerms = [...this.terms];
            updatedTerms[termIndex].isLoadingCourses = false;

            // Existing offerings to preserve data like manually added weekNo
            const existingOfferingsMap = new Map();
            if (updatedTerms[termIndex].courseOfferings) {
                updatedTerms[termIndex].courseOfferings.forEach(offering => {
                    existingOfferingsMap.set(offering.Id, offering);
                });
            }

            const courseOfferings = (result || []).map(offering => {
                let startDate = offering.hed__Start_Date__c ? this.normalizeDate(offering.hed__Start_Date__c) : null;
                let endDate = offering.hed__End_Date__c ? this.normalizeDate(offering.hed__End_Date__c) : null;

                const base = {
                    ...offering,
                    Id: offering.Id,
                    weekNo: offering.Course_Version__r?.WeekNo__c || '',
                    courseName: offering.hed__Course__r?.Name || '',
                    courseId: offering.hed__Course__r?.hed__Course_ID__c || '',
                    sectionId: offering.hed__Section_ID__c || '',
                    credits: offering.hed__Capacity__c || '',
                    startDate,
                    endDate
                };

                // If previously edited, preserve certain values (like weekNo)
                const previous = existingOfferingsMap.get(offering.Id);
                return previous ? { ...base, weekNo: previous.weekNo || base.weekNo } : base;
            });

            updatedTerms[termIndex].courseOfferings = courseOfferings;
            this.draftValues = [];
            this.terms = updatedTerms;
        })
        .catch(error => {
            console.error('Error loading course offerings:', error);
            const updatedTerms = [...this.terms];
            updatedTerms[termIndex].isLoadingCourses = false;
            this.terms = updatedTerms;

            let errorMessage = 'Error loading course offerings';
            if (error?.body?.message) {
                errorMessage += ': ' + error.body.message;
            } else if (error?.message) {
                errorMessage += ': ' + error.message;
            }
            this.showToast('Error', errorMessage, 'error');
        });
}


// Helper method to normalize dates without time component
normalizeDate(dateString) {
    if (!dateString) return null;
    
    const date = new Date(dateString);
    date.setHours(0, 0, 0, 0);
    return date;
}
    

    // Format date for display
    formatDate(dateString) {
        if (!dateString) return '';
        
        const date = new Date(dateString);
        return new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }).format(date);
    }


    
    // Handle sorting in the datatable
    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const termId = event.currentTarget.closest('[data-term-id]')?.dataset.termId;
        const termIndex = this.terms.findIndex(term => term.Id === termId);
        
        if (termIndex !== -1) {
            const cloneData = [...this.terms[termIndex].courseOfferings];
            
            cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
            
            const updatedTerms = [...this.terms];
            updatedTerms[termIndex].courseOfferings = cloneData;
            this.terms = updatedTerms;
            
            this.sortDirection = sortDirection;
            this.sortedBy = sortedBy;
        }
    }
    
    // Sort function
    sortBy(field, reverse, primer) {
        const key = primer
            ? function(x) {
                  return primer(x[field]);
              }
            : function(x) {
                  return x[field];
              };
        
        return function(a, b) {
            a = key(a);
            b = key(b);
            
            // Handle numeric values
            if (!isNaN(a) && !isNaN(b)) {
                return reverse * ((parseFloat(a) > parseFloat(b)) - (parseFloat(b) > parseFloat(a)));
            }
            
            // For dates stored as strings
            if (field === 'formattedStartDate' || field === 'formattedEndDate') {
                const dateA = new Date(a);
                const dateB = new Date(b);
                if (dateA.toString() !== 'Invalid Date' && dateB.toString() !== 'Invalid Date') {
                    return reverse * (dateA > dateB ? 1 : -1);
                }
            }
            
            // For strings
            return reverse * ((a > b) - (b > a));
        };
    }
    
    // Handler for row action for datatable
    // Update the handleRowAction method in academicPlannerScreen.js
    async handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        const termId = event.currentTarget.dataset.termId; 

        console.log('termId',termId);
    
        if (action.name === 'delete') {
            const result = await LightningConfirm.open({
                message: 'Are you sure you want to delete this course offering? This will also delete related plan requirements and course versions.',
                variant: 'header',
                label: 'Confirm Deletion'
            });
    
            if (!result) {
                return;
            }
    
            const termIndex = this.terms.findIndex(term => term.Id === termId);
            if (termIndex !== -1) {
                const updatedTerms = [...this.terms];
                updatedTerms[termIndex].isLoadingCourses = true;
                this.terms = updatedTerms;
            }
    
            deleteCompleteCourseOffering({ courseOfferingId: row.Id, termId: termId })
                .then(result => {
                    if (result) {
                        this.showToast('Success', 'Course offering and related records deleted successfully', 'success');
    
                        const termIndex = this.terms.findIndex(term => term.Id === termId);
                        if (termIndex !== -1) {
                            const updatedTerms = [...this.terms];
                            updatedTerms[termIndex].isLoadingCourses = false;
                            updatedTerms[termIndex].courseOfferings = updatedTerms[termIndex].courseOfferings.filter(
                                offering => offering.Id !== row.Id
                            );
                            this.terms = updatedTerms;
                        }
                    }
                })
                .catch(error => {
                    const termIndex = this.terms.findIndex(term => term.Id === termId);
                    if (termIndex !== -1) {
                        const updatedTerms = [...this.terms];
                        updatedTerms[termIndex].isLoadingCourses = false;
                        this.terms = updatedTerms;
                    }
    
                    this.showToast('Error', 'Error deleting records: ' + (error.body ? error.body.message : error.message), 'error');
                });
        }
    }
    
    // Delete course offering
    async deleteCourseOffering(courseOfferingId, termId) {
        const result = await LightningConfirm.open({
            message: 'Are you sure you want to delete this course offering?',
            variant: 'header',
            label: 'Confirm Deletion'
        });
    
        if (!result) {
            return;
        }
    
        deleteCourseOffering({ courseOfferingId })
            .then(result => {
                if (result) {
                    
                    (courseOfferings => {
                        const termIndex = this.terms.findIndex(term => term.Id === termId);
                        if (termIndex !== -1) {
                            const updatedTerms = [...this.terms];
                            updatedTerms[termIndex].courseOfferings = courseOfferings;
                            this.terms = updatedTerms;
                            this.showToast('Success', 'Course offering deleted successfully 1', 'success');
                            console.log('AfterDelete',updatedTerms[termIndex]);
                            console.log('After DElete',JSON.stringify(this.terms));
                            
                        }
                        
                    })
                }
            })
            // .then(courseOfferings => {
            //     const termIndex = this.terms.findIndex(term => term.Id === termId);
            //     if (termIndex !== -1) {
            //         const updatedTerms = [...this.terms];
            //         updatedTerms[termIndex].courseOfferings = courseOfferings;
            //         this.terms = updatedTerms;
            //     }
            // })
            .catch(error => {
                this.showToast('Error', 'Error deleting course offering: ' + (error.body ? error.body.message : error.message), 'error');
            });
    }
    
    // Handler for "Delete all" button
    // Handler for "Delete all" button

    async handleDeleteAllCourseOfferings(event) {
        const termId = event.currentTarget.dataset.termId;
        const termIndex = this.terms.findIndex(term => term.Id === termId);
    
        if (termIndex === -1 || !this.terms[termIndex].courseOfferings || this.terms[termIndex].courseOfferings.length === 0) {
            this.showToast('Info', 'No course offerings to delete', 'info');
            return;
        }
    
        const result = await LightningConfirm.open({
            message: 'Are you sure you want to delete all course offerings for this term? This will also delete related plan requirements and course versions.',
            variant: 'header',
            label: 'Confirm Deletion'
        });
    
        if (!result) {
            return;
        }
    
        const updatedTerms = [...this.terms];
        updatedTerms[termIndex].isLoadingCourses = true;
        this.terms = updatedTerms;
    
        deleteAllCourseOfferings({ termId: termId })
            .then(result => {
                const updatedTerms = [...this.terms];
                updatedTerms[termIndex].isLoadingCourses = false;
                updatedTerms[termIndex].courseOfferings = [];
                this.terms = updatedTerms;
                console.log('AfterDeleteALL',updatedTerms);
                console.log('After DElete all',console.log('After DElete',JSON.stringify(this.terms)));
                this.showToast('Success', `${result} course offerings deleted successfully`, 'success');
            })
            .catch(error => {
                const updatedTerms = [...this.terms];
                updatedTerms[termIndex].isLoadingCourses = false;
                this.terms = updatedTerms;
    
                this.showToast('Error', 'Error deleting course offerings: ' + error.body.message, 'error');
            });
    }

    // Handler for "Download" button
    handleDownloadCourseOfferings(event) {
        const termId = event.currentTarget.dataset.termId;
        
        // Implementation would depend on your download requirements
        this.showToast('Info', 'Download functionality would be implemented here', 'info');
    }
    
     // This method can be called to refresh the plan requirements when needed
refreshPlanRequirements() {
    if (!this.selectedProgramPlanId) {
        this.showToast('Error', 'Program plan must be selected to import curriculum', 'error');
        return Promise.reject(new Error('Program plan must be selected'));
    }
    
    // Show loading state
    this.isLoadingPlanRequirements = true;
    
    // Always fetch fresh data directly from the server
    return getPlanRequirementsMasterUnits({ programPlanId: this.selectedProgramPlanId })
        .then(result => {
            this.isLoadingPlanRequirements = false;
            console.log('Plan requirements received:', result);
            
            if (result && result.length > 0) {
                this.planRequirements = JSON.parse(JSON.stringify(result));
                this.displayedPlanRequirements = [...this.planRequirements];
                
                // Extract unique master groups
                const groups = new Set();
                this.planRequirements.forEach(item => {
                    if (item.masterGroup) {
                        groups.add(item.masterGroup);
                    }
                });
                
                this.masterGroups = Array.from(groups).map(group => ({
                    label: group,
                    value: group
                }));
                
                // Add "All" option at the beginning
                this.masterGroups.unshift({
                    label: 'All',
                    value: 'All'
                });
                
                return result;
            } else {
                this.showToast('Info', 'No master unit plan requirements found for this program plan', 'info');
                return [];
            }
        })
        .catch(error => {
            this.isLoadingPlanRequirements = false;
            
            // Safer error message extraction
            let errorMsg = 'Error loading plan requirements';
            
            if (error) {
                if (typeof error === 'string') {
                    errorMsg = error;
                } else if (error.body) {
                    if (typeof error.body.message === 'string') {
                        errorMsg = error.body.message;
                    } else if (typeof error.body === 'string') {
                        errorMsg = error.body;
                    }
                } else if (error.message) {
                    errorMsg = error.message;
                }
            }
            
            console.error('Error in getPlanRequirementsMasterUnits:', error);
            this.showToast('Error', errorMsg, 'error');
            return Promise.reject(error);
        });
}

    // Handler for "Import curriculum" button
    handleImportCurriculum(event) {
        // Get term ID directly from the clicked button
        const termId = event.currentTarget.dataset.termId;
        this.currentTermId = termId;
        console.log('This is the term id',termId);
        console.log('CurentTermID',this.currentTermId);
        console.log('This is the selectedProgramPlanId ',this.selectedProgramPlanId);
        // Get term details
        const term = this.terms.find(t => t.Id === termId);
        if (term) {
            this.currentTermName = term.Name;
            console.log('Import curriculum for term: ' + term.Name + ' with ID: ' + termId);
        } else {
            console.error('Term not found with ID:', termId);
            this.showToast('Error', 'Term not found', 'error');
            return;
        }
        
        if (!this.selectedProgramPlanId) {
            this.showToast('Error', 'Program plan must be selected to import curriculum', 'error');
            return;
        }
        
        // Reset modal data
        this.isLoadingPlanRequirements = true;
        this.planRequirements = [];
        this.displayedPlanRequirements = [];
        this.searchTerm = '';
        this.selectedPlanRequirements = [];
        this.allSelected = false;
        this.showImportCurriculumModal = true;
    
        
        // Show the modal first so user sees something is happening
        this.showImportCurriculumModal = true;
        
        // Make direct call to Apex instead of using refreshPlanRequirements
        // This ensures we're using the current termId directly
          // Call Apex to get plan requirements, passing both programPlanId and termId
    getPlanRequirementsMasterUnits({ 
        programPlanId: this.selectedProgramPlanId,
        termId: this.currentTermId
    })
    .then(result => {
        this.isLoadingPlanRequirements = false;
        
        if (result && result.length > 0) {
            console.log('Received ' + result.length + ' plan requirements for term: ' + this.currentTermName);
            
            // Process the results
            this.planRequirements = JSON.parse(JSON.stringify(result));
            this.displayedPlanRequirements = [...this.planRequirements];
            
            // We no longer need to extract master groups for filtering
            // as the filtering is now automatic by term number
        } else {
            this.showToast('Info', 'No subjects found for ' + this.currentTermName, 'info');
        }
    })
    
    .catch(error => {
        this.isLoadingPlanRequirements = false;
        
        // Error handling
        let errorMsg = 'Error loading plan requirements';
        if (error) {
            if (typeof error === 'string') {
                errorMsg = error;
            } else if (error.body) {
                if (typeof error.body.message === 'string') {
                    errorMsg = error.body.message;
                } else if (typeof error.body === 'string') {
                    errorMsg = error.body;
                }
            } else if (error.message) {
                errorMsg = error.message;
            }
        }
        
        console.error('Error in getPlanRequirementsMasterUnits:', error);
        this.showToast('Error', errorMsg, 'error');
    });
}

    // Add this method to handle master group selection
handleMasterGroupChange(event) {
    this.selectedMasterGroup = event.detail.value;
    this.filterPlanRequirements();
}

// Update the filter method to include master group filtering
filterPlanRequirements() {
    let filtered = [...this.planRequirements];
    
    // First apply master group filter if not "All"
    if (this.selectedMasterGroup !== 'All') {
        filtered = filtered.filter(row => 
            row.masterGroup === this.selectedMasterGroup
        );
    }
    
    // Then apply search term filter if present
    if (this.searchTerm) {
        const searchTermLower = this.searchTerm.toLowerCase();
        filtered = filtered.filter(row =>
            (row.subjectCode && row.subjectCode.toLowerCase().includes(searchTermLower)) ||
            (row.subject && row.subject.toLowerCase().includes(searchTermLower)) ||
            (row.specialisation && row.specialisation.toLowerCase().includes(searchTermLower)) ||
             (row.category && row.category.toLowerCase().includes(searchTermLower)) 
           // (row.masterGroup && row.masterGroup.toLowerCase().includes(searchTermLower))
        );
    }
    
    this.displayedPlanRequirements = filtered;
    
    // Check if all displayed items are selected
    this.allSelected = this.displayedPlanRequirements.length > 0 && 
                      this.displayedPlanRequirements.every(row => row.checked);
}
    
    // Close import curriculum modal
    closeImportCurriculumModal() {
        this.showImportCurriculumModal = false;
        // Don't clear the currentTermId here as it needs to be preserved
        console.log('Modal closed, current term ID preserved:', this.currentTermId);
    }

    // Handle checkbox changes in the datatable
    handleCheckboxChange(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const checked = event.currentTarget.checked;
        
        // Update the displayed list
        this.displayedPlanRequirements = this.displayedPlanRequirements.map(row => {
            if (row.id === rowId) {
                return {...row, checked: checked};
            }
            return row;
        });
        
        // Also update the main list
        this.planRequirements = this.planRequirements.map(row => {
            if (row.id === rowId) {
                return {...row, checked: checked};
            }
            return row;
        });
        
        // Update selected plan requirements
        if (checked) {
            this.selectedPlanRequirements.push(rowId);
        } else {
            this.selectedPlanRequirements = this.selectedPlanRequirements.filter(id => id !== rowId);
        }
        
        // Check if all are selected
        this.allSelected = this.displayedPlanRequirements.every(row => row.checked);
    }
    
    // Handle select all checkbox
    handleSelectAll(event) {
        const checked = event.target.checked;
        this.allSelected = checked;
        
        // Update all checkboxes
        this.displayedPlanRequirements = this.displayedPlanRequirements.map(row => {
            return {...row, checked: checked};
        });
        
        // Also update the main list
        this.planRequirements = this.planRequirements.map(row => {
            // Only update items that are currently displayed
            if (this.displayedPlanRequirements.some(displayedRow => displayedRow.id === row.id)) {
                return {...row, checked: checked};
            }
            return row;
        });
        
        // Update selected plan requirements
        if (checked) {
            this.selectedPlanRequirements = this.displayedPlanRequirements.map(row => row.id);
        } else {
            this.selectedPlanRequirements = [];
        }
    }
    
    // Handle search input
    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filterPlanRequirements();
    }
    
    // Import the selected curriculum
    importSelectedCurriculum() {
        if (this.selectedPlanRequirements.length === 0) {
            this.showToast('Warning', 'Please select at least one subject to import', 'warning');
            return;
        }
        
        // Validate we have the correct term ID before proceeding
        if (!this.currentTermId) {
            this.showToast('Error', 'Term ID is missing. Please try again.', 'error');
            return;
        }
        
        this.isLoadingPlanRequirements = true;

        console.log('Importing ' + this.selectedPlanRequirements.length + ' subjects to Term ID: ' + this.currentTermId);
    console.log('Term Name: ' + this.currentTermName);
        
        console.log('Importing curriculum: Term ID = ' + this.currentTermId);
        console.log('Selected IDs:', this.selectedPlanRequirements);
        
        importCurriculum({
            termId: this.currentTermId,
            planRequirementIds: this.selectedPlanRequirements
        })
        .then(result => {
            this.isLoadingPlanRequirements = false;
            this.showToast('Success', `Successfully imported ${result} subjects to ${this.currentTermName}`, 'success');
            
            // Refresh the course offerings for this term
            const termIndex = this.terms.findIndex(term => term.Id === this.currentTermId);
        if (termIndex !== -1) {
            this.loadTermCourseOfferings(this.currentTermId, termIndex);
        } else {
            console.error('Could not find term with ID: ' + this.currentTermId);
        }
            
            // Close the modal
            this.closeImportCurriculumModal();
        })
        .catch(error => {
            this.isLoadingPlanRequirements = false;
            
            // Error handling
            let errorMsg = 'Error importing curriculum';
            if (error) {
                if (typeof error === 'string') {
                    errorMsg = error;
                } else if (error.body) {
                    if (typeof error.body.message === 'string') {
                        errorMsg = error.body.message;
                    } else if (typeof error.body === 'string') {
                        errorMsg = error.body;
                    }
                } else if (error.message) {
                    errorMsg = error.message;
                }
            }
            
            console.error('Error in importCurriculum:', error);
            this.showToast('Error', errorMsg, 'error');
        });
    }
currentSUbId=[];
usedId =[];


// Update handleSubjectChange to NOT set the capacity value from credits
handleSubjectChange(event) {
    this.selectedSubjectId = event.detail.value;
    this.selectedSubject = null;
    
    console.log('selectedSubject',this.selectedSubjectId);
    this.currentSUbId=this.selectedSubjectId;
    //console.log('selectedSubjectUsed',this.usedId);

    if (this.selectedSubjectId) {
        const selectedOption = this.subjectOptions.find(option => option.value === this.selectedSubjectId);
        if (selectedOption) {
            this.selectedSubject = selectedOption;
        }

        // Now fetch the Course ID from Apex
        getCourseIdBySubject({ subjectId: this.selectedSubjectId })
            .then(courseId => {
                this.courseId = courseId || '';
                console.log('Course ID from Apex:', this.courseId);
            })
            .catch(error => {
                this.courseId = '';
                console.error('Error fetching Course ID:', error);
                this.showToast('Error', 'Unable to fetch Course ID', 'error');
            });
    } else {
        this.courseId = '';
    }
}


 // Update handleAddSubjects to initialize capacity as empty
handleAddSubjects(event) {
    const termId = event.currentTarget.dataset.termId;
    this.currentTermId = termId;
  
    
    
    // Find the current term to get its details
    const term = this.terms.find(t => t.Id === termId);
    if (term) {
        this.currentTermName = term.Name;
        
        // Set default start and end dates from the term
        this.subjectStartDate = term.hed__Start_Date__c;
        this.subjectEndDate = term.hed__End_Date__c;
    }

    // Fetch available subjects for this term (filtered by academic program)
    this.isLoadingSubjects = true;
    this.availableSubjects = [];
    this.selectedSubjectId = null;
    this.selectedSubject = null;
    this.sectionId = '';
    this.courseId = ''; // Reset the course ID
    this.capacity = ''; // Explicitly initialize capacity to empty string
     
    getAvailableSubjectsFromMasterUnits({ termId: termId,academicProgramId: this.selectedAcademicProgramId})
    .then(result => {
        if (result && result.length > 0) {
            // The result already contains objects with label and value properties
            this.availableSubjects = result;
        } else {
            // No subjects found with Master Unit record type
            this.availableSubjects = [];
        }
        this.isLoadingSubjects = false;
        this.showAddSubjectsModal = true;
    })
    .catch(error => {
        this.isLoadingSubjects = false;
        this.showToast('Error', 'Error loading subjects: ' + (error.body ? error.body.message : error.message), 'error');
    });
}





handleSectionIdChange(event) {
    this.sectionId = event.detail.value;    
}


    // Handle term start date change
    handleStartDateChange(event) {
        // For term date changes
        if (event.target.dataset.termId) {
            const termId = event.target.dataset.termId;
            const startDate = event.target.value;
            
            // Find the term
            const term = this.terms.find(t => t.Id === termId);
            if (term) {
                // Update end date if start date is after end date
                if (term.hed__End_Date__c && startDate > term.hed__End_Date__c) {
                    this.showToast('Warning', 'Start date cannot be after end date', 'warning');
                    return;
                }
                
                // Update the term dates
                this.updateTermDates(termId, startDate, term.hed__End_Date__c);
            }
        } 
        // For subject modal date changes
        else {
            this.subjectStartDate = event.target.value;
        }
    }
    
    // Handle term end date change
    handleEndDateChange(event) {
        // For term date changes
        if (event.target.dataset.termId) {
            const termId = event.target.dataset.termId;
            const endDate = event.target.value;
            
            // Find the term
            const term = this.terms.find(t => t.Id === termId);
            if (term) {
                // Update end date if start date is after end date
                if (term.hed__Start_Date__c && endDate < term.hed__Start_Date__c) {
                    this.showToast('Warning', 'End date cannot be before start date', 'warning');
                    return;
                }
                
                // Update the term dates
                this.updateTermDates(termId, term.hed__Start_Date__c, endDate);
            }
        } 
        // For subject modal date changes
        else {
            this.subjectEndDate = event.target.value;
        }
    }

    // Add this method to handle capacity changes
// Add a new method to handle capacity changes
handleCapacityChange(event) {
    this.capacity = event.target.value;
    console.log('Capacity changed to:', this.capacity);
}
    
    closeAddSubjectsModal() {
        this.showAddSubjectsModal = false;
        this.resetSubjectForm();
    }
    
   // Make sure to reset capacity in resetSubjectForm
resetSubjectForm() {
    this.selectedSubjectId = null;
    this.selectedSubject = null;
    this.sectionId = '';
    this.subjectStartDate = null;
    this.subjectEndDate = null;
    this.courseId = '';
    this.capacity = ''; // Reset capacity field
}

   // Method to handle date changes in the Add Subjects form
    // Method to handle date changes in the Add Subjects form
handleSubjectDateChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    
    // Store the date value
    if (field === 'startDate') {
        this.subjectStartDate = value;
    } else if (field === 'endDate') {
        this.subjectEndDate = value;
    }
    
    // Validate dates if both are present
    if (this.subjectStartDate && this.subjectEndDate) {
        this.validateSubjectDates();
    } else {
        // Clear error if one of the dates is cleared
        this.showDateError = false;
        this.dateError = '';
    }
    console.log("Selected Date:", value);

}

// Method to validate dates
validateSubjectDates() {
    const startDate = new Date(this.subjectStartDate);
    const endDate = new Date(this.subjectEndDate);
    
    // Normalize dates by removing time component
    startDate.setHours(0, 0, 0, 0);
    endDate.setHours(0, 0, 0, 0);
    
    if (endDate < startDate) {
        this.dateError = 'End date must be after the start date.';
        this.showDateError = true;
        return false;
    } else {
        this.dateError = '';
        this.showDateError = false;
        return true;
    }
    
}
    
@track savedId = [];

    //console.log('savedIds:', this.savedId);

 // Updated saveSubject method with proper refreshing
saveSubject() {
    console.log('Final SubcodeID-->',this.selectedSubjectId);
    if (!this.sectionId) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Section ID cannot be null. Please select a value.',
                variant: 'error',
            })
        );
        return;
    }
    
    this.savedId = this.selectedSubjectId;
    //this.savedId.add(this.selectedSubjectId);
    //console.log('savedId>>>',this.savedId);
   
    // First validate the form
    if (!this.validateSubjectForm()) {
        return; // Don't proceed if validation fails
    }
    try {
        // Validate inputs
        let hasErrors = false;
        
        // Required field validation
        if (!this.selectedSubjectId) {
            this.showToast('Error', 'Please select a subject', 'error');
            hasErrors = true;
        }
        
        if (!this.subjectStartDate) {
            this.showToast('Error', 'Please select a start date', 'error');
            hasErrors = true;
        }
        
        if (!this.subjectEndDate) {
            this.showToast('Error', 'Please select an end date', 'error');
            hasErrors = true;
        }
        
        if (!this.capacity) {
            this.showToast('Error', 'Please enter a capacity value', 'error');
            hasErrors = true;
        }
        
        if (hasErrors) {
            return;
        }
        
        // Get term dates for validation
        const term = this.terms.find(t => t.Id === this.currentTermId);
        const termStartDate = term ? new Date(term.hed__Start_Date__c) : null;
        const termEndDate = term ? new Date(term.hed__End_Date__c) : null;
        const subjectStartDate = new Date(this.subjectStartDate);
        const subjectEndDate = new Date(this.subjectEndDate);
        
        // Date validation
        if (subjectStartDate > subjectEndDate) {
            this.showToast('Error', 'Start date cannot be later than end date', 'error');
            return;
        }
        
        // Validate subject dates are within term dates
        if (termStartDate && termEndDate) {
            if (subjectStartDate < termStartDate) {
                this.showToast('Warning', 'Subject start date is before the term start date', 'warning');
            }
            
            if (subjectEndDate > termEndDate) {
                this.showToast('Warning', 'Subject end date is after the term end date', 'warning');
            }
        }
        
        // Show spinner during save
        this.isLoadingSubjects = true;
        
        // Call Apex to add the plan requirement and course version
        addSubjectAsPlanRequirement({ 
            termId: this.currentTermId,
            courseId: this.selectedSubjectId,
            sectionId: this.sectionId || '',
            startDate: this.subjectStartDate,
            endDate: this.subjectEndDate,
            capacity: this.capacity
        })
        .then(result => {
            console.log('section :',this.sectionId)
            console.log('Success response from Apex:', result);
            this.isLoadingSubjects = false;
            this.showToast('Success', 'Subject added successfully with Plan Requirement, Course Version, and Course Offering', 'success');
            
            // Find the term index
            const termIndex = this.terms.findIndex(term => term.Id === this.currentTermId);
            
            // IMPORTANT: Set isLoadingCourses to true to show the spinner
            // This gives visual feedback that data is being refreshed
            if (termIndex !== -1) {
                const updatedTerms = [...this.terms];
                updatedTerms[termIndex].isLoadingCourses = true;
                this.terms = updatedTerms;
                
                // Force refresh the course offerings data with a slight delay
                // to ensure the server has time to process the new data
                setTimeout(() => {
                    this.loadTermCourseOfferings(this.currentTermId, termIndex);
                }, 250);
            }
            
            // Close the modal
            this.closeAddSubjectsModal();
            
           
        })
        .catch(error => {
            console.error('Error from Apex:', error);
            this.isLoadingSubjects = false;
            
            let errorMessage = 'Error adding subject';
            if (error) {
                if (error.body && error.body.message) {
                    errorMessage += ': ' + error.body.message;
                } else if (error.message) {
                    errorMessage += ': ' + error.message;
                }
            }
            
            this.showToast('Error', errorMessage, 'error');
        });
    } catch (e) {
        console.error('JavaScript error in saveSubject:', e);
        this.isLoadingSubjects = false;
        this.showToast('Error', 'Unexpected error: ' + e.message, 'error');
    }
}

// Also update saveAndNewSubject with the same refresh logic
saveAndNewSubject() {
    // First validate the form
    if (!this.validateSubjectForm()) {
        return; // Don't proceed if validation fails
    }
    // Validate inputs
    let hasErrors = false;
    
    // Required field validation
    if (!this.selectedSubjectId) {
        this.showToast('Error', 'Please select a subject', 'error');
        hasErrors = true;
    }
    
    if (!this.subjectStartDate) {
        this.showToast('Error', 'Please select a start date', 'error');
        hasErrors = true;
    }
    
    if (!this.subjectEndDate) {
        this.showToast('Error', 'Please select an end date', 'error');
        hasErrors = true;
    }
    
    if (!this.capacity) {
        this.showToast('Error', 'Please enter a capacity value', 'error');
        hasErrors = true;
    }
    
    if (hasErrors) {
        return;
    }
    
    // Date validation
    const subjectStartDate = new Date(this.subjectStartDate);
    const subjectEndDate = new Date(this.subjectEndDate);
    
    if (subjectStartDate > subjectEndDate) {
        this.showToast('Error', 'Start date cannot be later than end date', 'error');
        return;
    }
    
    // Show spinner during save
    this.isLoadingSubjects = true;
    
    // Call Apex to add the plan requirement and course version
    addSubjectAsPlanRequirement({ 
        termId: this.currentTermId,
        courseId: this.selectedSubjectId,
        sectionId: this.sectionId || '',
        startDate: this.subjectStartDate,
        endDate: this.subjectEndDate,
        capacity: this.capacity
    })
    .then(result => {
        this.isLoadingSubjects = false;
        this.showToast('Success', 'Subject added successfully with Plan Requirement, Course Version, and Course Offering', 'success');
        
        // Find the term index
        const termIndex = this.terms.findIndex(term => term.Id === this.currentTermId);
        
        // IMPORTANT: Force refresh the datatable in the background
        if (termIndex !== -1) {
            const updatedTerms = [...this.terms];
            updatedTerms[termIndex].isLoadingCourses = true;
            this.terms = updatedTerms;
            
            // Force refresh with a slight delay to ensure server has processed changes
            setTimeout(() => {
                this.loadTermCourseOfferings(this.currentTermId, termIndex);
            }, 250);
        }
        
        // Reset the form for a new entry but keep the modal open
        this.selectedSubjectId = null;
        this.selectedSubject = null;
        this.courseId = '';
        this.sectionId = '';
        this.capacity = '';
        
        // Keep the dates the same for convenience when adding multiple subjects
    })
    .catch(error => {
        this.isLoadingSubjects = false;
        this.showToast('Error', 'Error adding subject: ' + (error.body ? error.body.message : error.message), 'error');
    });
}  
  // Method to validate the entire form
   // Method to validate the entire form
validateSubjectForm() {
    let isValid = true;
    
    // Validate required fields
    if (!this.selectedSubjectId) {
        this.showToast('Error', 'Please select a subject', 'error');
        isValid = false;
    }
    
    // Validate dates if both are present
    if (this.subjectStartDate && this.subjectEndDate) {
        if (!this.validateSubjectDates()) {
            isValid = false;
        }
    } else if (!this.subjectStartDate || !this.subjectEndDate) {
        // Check if dates are missing
        this.showToast('Error', 'Start and end dates are required', 'error');
        isValid = false;
    }
    
    // Validate capacity
    if (!this.capacity) {
        this.showToast('Error', 'Section Strength is required', 'error');
        isValid = false;
    }
    
    return isValid;
}

    // Optional: A helper method to format a date in ISO format for input fields
    formatDateForInput(dateString) {
        if (!dateString) return '';
        
        const date = new Date(dateString);
        return date.toISOString().split('T')[0];
    }


    // Update term dates in the database
    updateTermDates(termId, startDate, endDate) {
        updateTermDates({ termId, startDate, endDate })
            .then(() => {
                this.showToast('Success', 'Term dates updated successfully', 'success');
                
                // Update local term data
                const termIndex = this.terms.findIndex(term => term.Id === termId);
                if (termIndex !== -1) {
                    const updatedTerms = [...this.terms];
                    updatedTerms[termIndex].hed__Start_Date__c = startDate;
                    updatedTerms[termIndex].hed__End_Date__c = endDate;
                    this.terms = updatedTerms;
                }
            })
            .catch(error => {
                this.showToast('Error', 'Error updating term dates: ' + error.body.message, 'error');
            });
    }
    
    // Handle holiday list button
    handleHolidayList() {
        this.isLoadingHolidays = true;
        this.holidays = [];
        
        // Call Apex to get all holidays
        getAllHolidays()
        .then(result => {
            if (result) {
                // Format dates and calculate days
                this.holidays = JSON.parse(JSON.stringify(result)).map(holiday => {
                    const startDate = new Date(holiday.K42_Hol_Start_Date__c);
                    const endDate = new Date(holiday.K42_Hol_End_Date__c);
                    
                    // Calculate days difference
                    const timeDiff = endDate.getTime() - startDate.getTime();
                    const days = Math.ceil(timeDiff / (1000 * 3600 * 24)) + 1; // +1 to include both start and end dates
                    
                    return {
                        ...holiday,
                        formattedStartDate: this.formatDate(holiday.K42_Hol_Start_Date__c),
                        formattedEndDate: this.formatDate(holiday.K42_Hol_End_Date__c),
                        days: days
                    };
                });
            }
            this.isLoadingHolidays = false;
            this.showHolidayModal = true;
        })
        .catch(error => {
            this.isLoadingHolidays = false;
            this.showToast('Error', 'Error loading holidays: ' + error.body.message, 'error');
        });
    }
    
    // Close holiday modal
    closeHolidayModal() {
        this.showHolidayModal = false;
    }

   // Improved handleCellEdit method with better date handling
    // Enhanced handleCellEdit method with date validation
handleCellEdit(event) {
    // Event contains draftValues which is an array of records with their edited values
    const draftValues = event.detail.draftValues;
    
    if (!draftValues || draftValues.length === 0) {
        return;
    }
    
    // Get the term ID from the parent element
    const termId = event.currentTarget.closest('[data-term-id]')?.dataset.termId;
    const termIndex = this.terms.findIndex(term => term.Id === termId);
    
    if (termIndex === -1) {
        this.showToast('Error', 'Could not identify the term for this update', 'error');
        return;
    }
    
    // Get the existing course offerings to compare against edited values
    const currentOfferings = this.terms[termIndex].courseOfferings;
    
    // Validate date changes before proceeding
    let hasDateError = false;
    
    for (const draftValue of draftValues) {
        const recordId = draftValue.Id;
        const currentRecord = currentOfferings.find(record => record.Id === recordId);
        
        if (!currentRecord) continue;
        
        // Get the new start and end dates, or use existing values if not changed
        let newStartDate = draftValue.startDate ? new Date(draftValue.startDate) : null;
        let newEndDate = draftValue.endDate ? new Date(draftValue.endDate) : null;
        
        // If only one date is being edited, use the existing value for the other
        if (newStartDate && !newEndDate) {
            newEndDate = new Date(currentRecord.endDate);
        } else if (!newStartDate && newEndDate) {
            newStartDate = new Date(currentRecord.startDate);
        }
        
        // Validate dates if both are present
        if (newStartDate && newEndDate) {
            // Normalize dates by removing time component
            newStartDate.setHours(0, 0, 0, 0);
            newEndDate.setHours(0, 0, 0, 0);
            
            // Check if end date is before start date
            if (newEndDate < newStartDate) {
                hasDateError = true;
                this.showToast(
                    'Error', 
                    'End date cannot be earlier than start date for ' + currentRecord.courseName, 
                    'error'
                );
                break;
            }
        }
    }
    
    // If there's a date validation error, exit without saving
    if (hasDateError) {
        // Clear draft values to reset the datatable
        this.draftValues = [];
        return;
    }
    
    // Show loading state
    const updatedTerms = [...this.terms];
    updatedTerms[termIndex].isLoadingCourses = true;
    this.terms = updatedTerms;
    
    // Prepare updates for Apex, ensuring dates are properly formatted
    const updates = draftValues.map(draftValue => {
        // Create a clean update object
        const update = {
            Id: draftValue.Id,
            sectionId: draftValue.sectionId,
            credits: draftValue.credits
        };
        
        // Handle start date - format for server
        if (draftValue.startDate) {
            update.startDate = this.formatDateForServer(draftValue.startDate);
        }
        
        // Handle end date - format for server
        if (draftValue.endDate) {
            update.endDate = this.formatDateForServer(draftValue.endDate);
        }
        
        return update;
    });
    
    console.log('Sending updates to server:', updates);
    
    // Call Apex to update the course offerings
    updateCourseOfferings({ updates: updates })
        .then(result => {
            this.showToast('Success', 'Course offerings updated successfully', 'success');
            
            // Clear draft values
            this.draftValues = [];
            
            // Add a small delay before refreshing to ensure server processing is complete
            setTimeout(() => {
                console.log('Refreshing course offerings for term:', termId);
                this.loadTermCourseOfferings(termId, termIndex);
            }, 300);
        })
        .catch(error => {
            const updatedTerms = [...this.terms];
            updatedTerms[termIndex].isLoadingCourses = false;
            this.terms = updatedTerms;
            
            let errorMessage = 'Error updating course offerings';
            if (error) {
                if (error.body && error.body.message) {
                    errorMessage += ': ' + error.body.message;
                } else if (error.message) {
                    errorMessage += ': ' + error.message;
                }
            }
            console.error('Error updating course offerings:', error);
            this.showToast('Error', errorMessage, 'error');
            
            // Clear draft values on error to reset the UI
            this.draftValues = [];
        });
}

/**
 * Format a date value to YYYY-MM-DD format, removing any time component
 * @param {String|Date} dateValue - Date value to format
 * @return {String} Formatted date in YYYY-MM-DD format
   /**
 * Format a date value to YYYY-MM-DD format, removing any time component
 * @param {String|Date} dateValue - Date value to format
 * @return {String} Formatted date in YYYY-MM-DD format
 */
formatDateForServer(dateValue) {
    if (!dateValue) return null;
    
    try {
        let dateObj;
        if (dateValue instanceof Date) {
            dateObj = dateValue;
        } else {
            // For string dates, force removal of any time component
            // by only using the date portion
            if (typeof dateValue === 'string' && dateValue.includes('T')) {
                // If it's in ISO format, extract only the date part
                dateValue = dateValue.split('T')[0];
            }
            dateObj = new Date(dateValue);
        }
        
        // Ensure we're working with a valid date
        if (dateObj instanceof Date && !isNaN(dateObj)) {
            // Format as YYYY-MM-DD, explicitly setting hours to midnight
            dateObj.setHours(0, 0, 0, 0);
            return dateObj.getFullYear() + '-' + 
                  ('0' + (dateObj.getMonth() + 1)).slice(-2) + '-' + 
                  ('0' + dateObj.getDate()).slice(-2);
        }
    } catch (e) {
        console.error('Error formatting date:', e);
    }
    
    return dateValue; // Return original value if formatting fails
}

/**
 * Process dates in the datatable's loadEvent to remove time components
 * @param {CustomEvent} event - The loadEvent from lightning-datatable
 */
handleDateLoad(event) {
    if (event.detail && event.detail.row) {
        // Check if this is a date cell being loaded
        if (event.detail.row.startDate || event.detail.row.endDate) {
            // Remove time component for display
            if (event.detail.row.startDate) {
                const dateOnly = new Date(event.detail.row.startDate);
                dateOnly.setHours(0, 0, 0, 0);
                event.detail.row.startDate = dateOnly;
            }
            
            if (event.detail.row.endDate) {
                const dateOnly = new Date(event.detail.row.endDate);
                dateOnly.setHours(0, 0, 0, 0);
                event.detail.row.endDate = dateOnly;
            }
        }
    }
}

    
    // Handle cancel button
    handleCancel() {
        // Reset the component
        this.selectedAcademicProgramId = null;
        this.selectedProgramPlanId = null;
        this.terms = [];
        this.workingDays = '';
        
        // Navigate back or fire event for parent component
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    //    // Handle "Previous Step" button click
    //    handlePreviousStep() {
    //     console.log('Academic Planner: Previous button clicked');
    //     this.dispatchNavigationEvent('previous');
    // }

    // // Handle "Next Step" button click
    // handleNextStep() {
    //     console.log('Academic Planner: Next button clicked');
    //     this.dispatchNavigationEvent('next');
    // }

    // // Dispatch the navigation event to the parent
    // dispatchNavigationEvent(direction) {
    //     // Create a custom event with direction and current tab
    //     const navigateEvent = new CustomEvent('navigate', {
    //         detail: {
    //             direction: direction,
    //             currentTab: this.currentTab
    //         }
    //     });
        
    //     console.log('Academic Planner: Dispatching event:', JSON.stringify(navigateEvent.detail));
    //     this.dispatchEvent(navigateEvent);
    // } 

    goToPrevious() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                direction: 'previous',
                currentTab: 'planner'
            },
            bubbles: true,
            composed: true
        }));
        
        console.log('Dispatching navigate event: previous');

    }
 
    goToNext() {
        this.dispatchEvent(new CustomEvent('navigate', {
            detail: {
                direction: 'next',
                currentTab: 'planner'
            },
            bubbles: true,
            composed: true
        }));
        
        console.log('Dispatching navigate event: next');

    }
    
    
    //   // Handle "Previous Step" button click
    //   handlePreviousStep() {
    //     // Find the parent component and call its navigation method
    //     this.navigateToTab('previous');
    // }

    // // Handle "Next Step" button click
    // handleNextStep() {
    //     // Find the parent component and call its navigation method
    //     this.navigateToTab('next');
    // }

    // Helper method to find parent and navigate
    // navigateToTab(direction) {
    //     // Find the parent component
    //     const parentComponent = this.template.querySelector('c-admin-service-parent-component');
        
    //     // If not directly accessible, bubble up the event to the parent
    //     if (!parentComponent) {
    //         // Dispatch a custom event that will bubble up to the parent
    //         const navigateEvent = new CustomEvent('navigate', {
    //             bubbles: true,
    //             composed: true,
    //             detail: {
    //                 direction: direction,
    //                 currentTab: this.currentTab
    //             }
    //         });
    //         this.dispatchEvent(navigateEvent);
    //     } else {
    //         // If directly accessible, call the parent method
    //         parentComponent.handleNavigation(direction, this.currentTab);
    //     }
    // }

    // Show toast message
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}