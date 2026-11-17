import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchCourseOfferingsByCode from '@salesforce/apex/CohortCapacityPlanner.searchCourseOfferingsByCode';
import searchCombinedCourseOfferings from '@salesforce/apex/CohortCapacityPlanner.searchCombinedCourseOfferings';
import createCohortPlanner from '@salesforce/apex/CohortCapacityPlanner.createCohortPlanner';
import getSectionData from '@salesforce/apex/CohortCapacityPlanner.getSectionData';

const SECTION_COLUMNS = [
    { label: 'Course Code', fieldName: 'CourseCode', type: 'text', sortable: true },
    { 
        label: 'Course Offering Name', 
        fieldName: 'CourseOfferingName', 
        type: 'text', 
        sortable: true,
        cellAttributes: {
            iconName: { fieldName: 'lockIcon' },
            iconPosition: 'left',
            class: { fieldName: 'nameStyle' }
        }
    },
    { label: 'Student Connections', fieldName: 'studentConnections', type: 'number', sortable: true },
    { label: 'Start Date', fieldName: 'StartDate', type: 'date', sortable: true },
    { label: 'End Date', fieldName: 'EndDate', type: 'date', sortable: true },
    { label: 'Faculty', fieldName: 'Faculty', type: 'text', sortable: true },
    { 
        label: 'Cohort Created', 
        fieldName: 'cohortCreatedDisplay', 
        type: 'text', 
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'cohortCreatedStyle' }
        }
    }
];

const COMBINED_COLUMNS = [
    { label: 'Course Code', fieldName: 'CourseCode', type: 'text', sortable: true },
    { 
        label: 'Course Offering Name', 
        fieldName: 'CourseOfferingName', 
        type: 'text', 
        sortable: true,
        cellAttributes: {
            iconName: { fieldName: 'lockIcon' },
            iconPosition: 'left',
            class: { fieldName: 'nameStyle' }
        }
    },
    { label: 'Total Students', fieldName: 'totalStudents', type: 'number', sortable: true },
    { label: 'Start Date', fieldName: 'StartDate', type: 'date', sortable: true },
    { label: 'End Date', fieldName: 'EndDate', type: 'date', sortable: true },
    { label: 'Faculty', fieldName: 'Faculty', type: 'text', sortable: true },
    { label: 'Group Size', fieldName: 'offeringsCount', type: 'number', sortable: true, 
      cellAttributes: { iconName: 'utility:groups', iconPosition: 'left' } },
       { 
        label: 'Cohort Created', 
        fieldName: 'cohortCreatedDisplay', 
        type: 'text', 
        sortable: true,
        cellAttributes: {
            class: { fieldName: 'cohortCreatedStyle' }
        }
    }
];

export default class CohortPlannerQuickAction extends LightningElement {
    @track courseOfferings = [];
    @track frozenCourseOfferings = [];
    @track allCourseOfferings = []; // Combined list for display
    @track isLoading = false;
    @track errorMessage = '';
    @track selectedRowIds = [];
    @track showModal = false;
    @track cohorts = 1;
    @track capacityPerCohort = 0; // Unified field name for both Section and Combined types
    @track validationError = '';
    @track searchTerm = '';
    @track filteredCourseOfferings = [];
    @track isTableVisible = false;
    @track isSearchLocked = false;
    @track totalStudentConnections = 0;
    @track shouldShowComponent = true;
    @track selectedCohortType = '';
    @track showFrozenRecords = false;
    @track currentCourseCode = '';
    @track totalCourseOfferings = 0;
    @track dateGroups = {}; // Store date groups for combined type
    @track isSelectionValid = true;
    @track selectionErrorMessage = '';
    
    // Section-specific properties
    @track sectionData = [];
    @track totalSections = 0;
    @track isLoadingSections = false;
    
    columns = SECTION_COLUMNS;
    
    @track cohortTypeOptions = [
        { label: 'Section', value: 'Section' },
        { label: 'Combined', value: 'Combined' }
    ];

    // Getters
    get isSectionCohortType() {
        return this.selectedCohortType === 'Section';
    }

    get isCombinedCohortType() {
        return this.selectedCohortType === 'Combined';
    }

    get hasFrozenRecords() {
        return this.frozenCourseOfferings && this.frozenCourseOfferings.length > 0;
    }

    get frozenRecordCount() {
        return this.frozenCourseOfferings ? this.frozenCourseOfferings.length : 0;
    }

    get selectedCount() {
        return this.selectedRowIds ? this.selectedRowIds.length : 0;
    }

    get disableCreateButton() {
        return this.selectedCount === 0 || !this.selectedCohortType || !this.currentCourseCode || (this.selectedCohortType === 'Combined' && !this.isSelectionValid);
    }

    get maxRowSelection() {
        return 100;
    }

    get searchPlaceholder() {
        return 'Enter course code (e.g., MBAG LSC 113)...';
    }

    get isCohortTypeDisabled() {
        return this.isSearchLocked;
    }

    get isSearchDisabled() {
        return !this.selectedCohortType;
    }

    get isCancelDisabled() {
        return !this.isSearchLocked && !this.searchTerm;
    }

    get disableCreateModalButton() {
        if (this.isSectionCohortType) {
            // For section type, check if we have valid section data
            if (!this.hasSectionData) return true;
            
            return this.sectionData.some(section => 
                section.cohorts <= 0 || section.capacityPerCohort <= 0
            ) || this.validationError !== '';
        } else {
            // For combined type - check both cohorts and capacityPerCohort
            if (this.cohorts <= 0 || this.capacityPerCohort <= 0) {
                return true;
            }
            return this.validationError !== '';
        }
    }

    get showCapacityCalculation() {
        // Always show for Combined type (like Section type always shows)
        return this.selectedCohortType === 'Combined';
    }

    // New getter for total capacity calculation in Combined type
    get totalCapacityCalculated() {
        if (this.selectedCohortType === 'Combined') {
            // Always return a value, even if inputs are 0 (shows 0 instead of hiding)
            const cohorts = this.cohorts || 0;
            const capacity = this.capacityPerCohort || 0;
            return cohorts * capacity;
        }
        return 0;
    }

    get combinedTypeHelpText() {
        if (this.isCombinedCohortType && this.isTableVisible) {
            return 'Combined type: Course offerings with the same start/end dates will be grouped together for cohort creation. Group Size shows how many offerings will be combined.';
        }
        return '';
    }

    get hasSectionData() {
        return this.sectionData && this.sectionData.length > 0;
    }

    // New getters for section totals
    get totalRecordsToCreate() {
        if (!this.hasSectionData) return 0;
        return this.sectionData.reduce((total, section) => total + (section.cohorts || 0), 0);
    }

    get totalCapacityAllSections() {
        if (!this.hasSectionData) return 0;
        return this.sectionData.reduce((total, section) => total + (section.totalCapacity || 0), 0);
    }

    connectedCallback() {
        this.resetComponent();
    }

    resetComponent() {
        this.selectedRowIds = [];
        this.filteredCourseOfferings = [];
        this.courseOfferings = [];
        this.frozenCourseOfferings = [];
        this.allCourseOfferings = [];
        this.isTableVisible = false;
        this.isSearchLocked = false;
        this.totalStudentConnections = 0;
        this.selectedCohortType = '';
        this.showFrozenRecords = false;
        this.currentCourseCode = '';
        this.totalCourseOfferings = 0;
        this.searchTerm = '';
        this.columns = SECTION_COLUMNS;
        this.dateGroups = {};
        // Reset section data
        this.sectionData = [];
        this.totalSections = 0;
        this.isLoadingSections = false;
    }

    handleCohortTypeChange(event) {
        if (this.isSearchLocked) {
            this.showToast('Warning', 'Cannot change cohort type while search is active. Clear search first.', 'warning');
            const dropdown = this.template.querySelector('lightning-combobox[name="cohortType"]');
            if (dropdown) dropdown.value = this.selectedCohortType;
            return;
        }

        const newCohortType = event.detail.value;
        this.selectedCohortType = newCohortType;
        
        // Update columns based on cohort type
        this.columns = newCohortType === 'Combined' ? COMBINED_COLUMNS : SECTION_COLUMNS;
        
        // Reset search state
        this.resetSearchState();
    }

    resetSearchState() {
        this.searchTerm = '';
        this.filteredCourseOfferings = [];
        this.courseOfferings = [];
        this.frozenCourseOfferings = [];
        this.allCourseOfferings = [];
        this.isTableVisible = false;
        this.selectedRowIds = [];
        this.totalStudentConnections = 0;
        this.currentCourseCode = '';
        this.totalCourseOfferings = 0;
        this.isSearchLocked = false;
        this.dateGroups = {};
        // Reset section data
        this.sectionData = [];
        this.totalSections = 0;
    }

    handleSearchInputChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSearchKeyDown(event) {
        if (event.key === 'Enter') {
            this.performSearch();
        }
    }

    handleSearchButtonClick() {
        this.performSearch();
    }

    async performSearch() {
        if (!this.selectedCohortType) {
            this.showToast('Warning', 'Please select a Cohort Type before searching.', 'warning');
            return;
        }

        const term = (this.searchTerm || '').trim();
        if (!term) {
            this.showToast('Warning', 'Please enter a course code to search.', 'warning');
            return;
        }

        try {
            this.isLoading = true;
            this.errorMessage = '';
            
            let searchResults;
            
            if (this.selectedCohortType === 'Section') {
                searchResults = await searchCourseOfferingsByCode({ courseCode: term });
            } else {
                searchResults = await searchCombinedCourseOfferings({ courseCode: term });
            }
            console.log('SearchResults', searchResults);

            if (searchResults && searchResults.success) {
                const allOfferings = searchResults.courseOfferings || [];
                
                // Separate records for internal tracking but show all together
                const { available, frozen } = this.separateRecordsByStatus(allOfferings);
                
                this.courseOfferings = available;
                this.frozenCourseOfferings = frozen;
                
                // Show ALL offerings together in the main table
                this.allCourseOfferings = this.prepareAllOfferingsForDisplay(allOfferings);
                
                this.filteredCourseOfferings = available; // Keep for selection logic
                this.currentCourseCode = term.toUpperCase();
                this.totalCourseOfferings = allOfferings.length;
                
                // Store date groups for combined type
                if (this.selectedCohortType === 'Combined' && searchResults.dateGroups) {
                    this.dateGroups = searchResults.dateGroups;
                }
                
                this.calculateTotalStudents();
                
                this.isTableVisible = allOfferings.length > 0;
                this.isSearchLocked = this.isTableVisible;

                if (allOfferings.length === 0) {
                    this.showToast('Info', `No course offerings found for "${term}".`, 'info');
                } else {
                    let message = `Found ${allOfferings.length} course offering(s) for "${term}".`;
                    
                    if (frozen.length > 0) {
                        message += ` ${frozen.length} are locked (cohorts already created).`;
                    }
                    
                    if (this.selectedCohortType === 'Combined') {
                        const uniqueGroups = new Set();
                        available.forEach(co => {
                            if (co.dateGroupKey) uniqueGroups.add(co.dateGroupKey);
                        });
                        message += ` (${uniqueGroups.size} data groups)`;
                    }
                    this.showToast('Success', message, 'success');
                }
            } else {
                const errorMsg = searchResults?.error || 'No results found';
                this.showToast('Info', errorMsg, 'info');
                this.resetSearchResults();
            }
        } catch (error) {
            console.error('Search error:', error);
            this.showToast('Error', 'Error searching course offerings: ' + (error.body?.message || error.message), 'error');
            this.resetSearchResults();
        } finally {
            this.isLoading = false;
        }
    }

    prepareAllOfferingsForDisplay(allOfferings) {
        // Process all offerings and add visual indicators for locked ones
        const processedOfferings = allOfferings.map(offering => {
            const isLocked = offering.isFrozen || offering.CohortCreated;
            
            return {
                ...offering,
                lockIcon: isLocked ? 'utility:lock' : null,
                nameStyle: isLocked ? 'slds-text-color_weak' : null,
                isSelectable: !isLocked,
                cohortCreatedDisplay: isLocked ? 'Yes' : 'No',
                cohortCreatedStyle: isLocked ? 'slds-text-color_success' : 'slds-text-color_default'
     
            };
        });
        
        // Sort by selectable status (available first) then by name
        // return processedOfferings.sort((a, b) => {
        //     // First sort by selectable status (available first)
        //     if (a.isSelectable !== b.isSelectable) {
        //         return b.isSelectable - a.isSelectable;
        //     }
        //     // Then by course offering name
        //     return (a.CourseOfferingName || '').localeCompare(b.CourseOfferingName || '');
        // });
        // Separate into available and locked while preserving order within each group
    const available = processedOfferings.filter(offering => offering.isSelectable);
    const locked = processedOfferings.filter(offering => !offering.isSelectable);
    
    // Return available first, then locked - but order preserved within each group
    return [...available, ...locked];
    }

    resetSearchResults() {
        this.courseOfferings = [];
        this.frozenCourseOfferings = [];
        this.allCourseOfferings = [];
        this.filteredCourseOfferings = [];
        this.isTableVisible = false;
        this.totalCourseOfferings = 0;
        this.totalStudentConnections = 0;
        this.dateGroups = {};
        this.sectionData = [];
        this.totalSections = 0;
    }

    separateRecordsByStatus(courseOfferings) {
        const available = [];
        const frozen = [];
        
        courseOfferings.forEach(co => {
            if (co.isFrozen || co.CohortCreated) {
                frozen.push(co);
            } else {
                available.push(co);
            }
        });
        
        return { available, frozen };
    }
    

    calculateTotalStudents() {
    if (this.selectedCohortType === 'Combined') {
        // For combined cohort type, sum up all individual student counts
        this.totalStudentConnections = this.courseOfferings.reduce((total, co) => {
            return total + (co.totalStudents || 0);
        }, 0);
    } else {
        // For section cohort type, use studentConnections field
        this.totalStudentConnections = this.courseOfferings.reduce((total, co) => {
            return total + (co.studentConnections || 0);
        }, 0);
    }
}


    handleCancelSearch() {
        this.resetSearchState();
    }

    toggleFrozenRecordsView() {
        this.showFrozenRecords = !this.showFrozenRecords;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        const validSelectedRows = selectedRows.filter(row => {
            // Check if the row is selectable (not frozen)
            if (!row.isSelectable) {
                this.showToast('Warning', 
                    `Cannot select "${row.CourseCode}" - Cohort already created`, 
                    'warning');
                return false;
            }
            
            const courseOffering = this.courseOfferings.find(co => co.Id === row.Id);
            if (courseOffering && (courseOffering.isFrozen || courseOffering.CohortCreated)) {
                this.showToast('Warning', 
                    `Cannot select "${courseOffering.CourseCode}" - Cohort already created`, 
                    'warning');
                return false;
            }
            return true;
        });

        // Reset validation
        this.isSelectionValid = true;
        this.selectionErrorMessage = '';

        // If no valid rows selected, reset and exit
        if (validSelectedRows.length === 0) {
            this.selectedRowIds = [];
            this.totalStudentConnections = 0;
            this.sectionData = [];
            this.totalSections = 0;
            return;
        }

        // Save selected IDs early so we can use them
        this.selectedRowIds = validSelectedRows.map(row => row.Id);
       console.log('Selected row IDs:', [...this.selectedRowIds]); // Spread operator
console.log('Selected row IDs as JSON:', JSON.stringify(this.selectedRowIds));


        // Combined Type: Validate all selected offerings are in the same group
        if (this.selectedCohortType === 'Combined') {
            const firstRow = validSelectedRows[0];
            const firstOffering = this.courseOfferings.find(co => co.Id === firstRow.Id);
            const expectedGroupKey = firstOffering?.dateGroupKey;

            for (let row of validSelectedRows) {
                const courseOffering = this.courseOfferings.find(co => co.Id === row.Id);
                if (courseOffering && courseOffering.dateGroupKey !== expectedGroupKey) {
                    // Invalid: Cross-group selection
                    this.isSelectionValid = false;
                    this.selectionErrorMessage = 'Cannot combine offerings from different groups (different schedule or faculty).';
                    
                    // Show error toast
                    this.showToast(
                        'Selection Not Allowed',
                        'In Combined mode, all selected offerings must belong to the same group (same start/end dates and faculty).',
                        'error'
                    );

                    // Revert selection to only previously valid ones (optional)
                    const datatable = this.template.querySelector('lightning-datatable');
                    if (datatable) {
                        datatable.selectedRows = this.selectedRowIds; // Keeps UI in sync
                    }
                    return; // Stop here — don't calculate totals
                }
            }
        }

        // All validations passed
        this.isSelectionValid = true;
        this.selectionErrorMessage = '';

        // Recalculate total students based on cohort type
        if (this.selectedCohortType === 'Combined') {
    this.totalStudentConnections = validSelectedRows.reduce(
        (total, row) => total + (row.totalStudents || 0),
        0
    );
} else {
    this.totalStudentConnections = validSelectedRows.reduce(
        (total, row) => total + (row.studentConnections || 0),
        0
    );
}


        // Load section data if Section cohort type is selected
        if (this.selectedCohortType === 'Section' && this.selectedRowIds.length > 0) {
            this.loadSectionData();
        } else if (this.selectedCohortType === 'Section' && this.selectedRowIds.length === 0) {
            // Clear section data if no rows selected
            this.sectionData = [];
            this.totalSections = 0;
        }
    }

    async loadSectionData() {
        const courseOfferingIds = this.getSelectedCourseOfferingIds();
        console.log('Loading section data for IDs:', courseOfferingIds);
        
        if (courseOfferingIds.length === 0) {
            this.sectionData = [];
            this.totalSections = 0;
            return;
        }

        try {
            this.isLoadingSections = true;
            console.log('Calling getSectionData with IDs:', courseOfferingIds);
            
            const sectionResult = await getSectionData({ courseOfferingIds });
            console.log('Section Result from Apex:', sectionResult);
            
            if (sectionResult && sectionResult.sections) {
                this.sectionData = sectionResult.sections.map(section => {
                    const cohorts = section.cohorts || 1;
                    const capacityPerCohort = section.capacityPerCohort || section.studentCount || 0;
                    return {
                        name: section.name || 'Unknown Section',
                        studentCount: section.studentCount || 0,
                        cohorts: cohorts,
                        capacityPerCohort: capacityPerCohort,
                        totalCapacity: cohorts * capacityPerCohort
                    };
                });
                
                this.totalSections = this.sectionData.length;
                console.log('Section Data loaded (reactive):', this.sectionData);
                console.log('Total sections:', this.totalSections);
                console.log('Initial total records to create:', this.totalRecordsToCreate);
                console.log('Initial total capacity:', this.totalCapacityAllSections);
            } else {
                console.log('No section data returned from Apex');
                this.sectionData = [];
                this.totalSections = 0;
            }
            
        } catch (error) {
            console.error('Error loading section data:', error);
            console.error('Error details:', error.body?.message || error.message);
            this.showToast('Warning', 'Could not retrieve section data: ' + (error.body?.message || error.message), 'warning');
            this.sectionData = [];
            this.totalSections = 0;
        } finally {
            this.isLoadingSections = false;
        }
    }

    getSelectedCourseOfferingIds() {
        return this.selectedRowIds || [];
    }

    getSelectedCourseOfferings() {
        return this.courseOfferings.filter(co => this.selectedRowIds.includes(co.Id));
    }

    async handleCreateCohort() {
        if (this.selectedCount === 0) {
            this.showToast('Warning', 'Please select at least one Course Offering.', 'warning');
            return;
        }
        if (!this.selectedCohortType) {
            this.showToast('Warning', 'Please select a Cohort Type.', 'warning');
            return;
        }
        if (!this.currentCourseCode) {
            this.showToast('Warning', 'Please search for a course code first.', 'warning');
            return;
        }

        // Check if selected offerings have students
        const selectedOfferings = this.getSelectedCourseOfferings();
        const hasStudents = selectedOfferings.some(co => {
            if (this.selectedCohortType === 'Combined') {
                return (co.totalStudents || 0) > 0;
            } else {
                return (co.studentConnections || 0) > 0;
            }
        });

        if (!hasStudents) {
            this.showToast('Warning', 'Selected Course Offerings have no student connections. Cannot create cohort.', 'warning');
            return;
        }

        // Load section data for Section cohort type before showing modal
        if (this.selectedCohortType === 'Section') {
            await this.loadSectionData();
            
            if (!this.hasSectionData) {
                this.showToast('Warning', 'No section data available for selected course offerings.', 'warning');
                return;
            }
        }

        this.showModal = true;
        this.validationError = '';
        
        // Set default values for combined type
        if (this.selectedCohortType === 'Combined') {
            this.cohorts = 1;
            // Calculate a reasonable default capacity per cohort
            // This could be total students divided by number of cohorts, rounded up
            this.capacityPerCohort = Math.ceil(this.totalStudentConnections / this.cohorts) || 0;
        }
    }

    closeModal() {
        this.showModal = false;
        this.validationError = '';
    }

    handleCohortsChange(event) {
        const value = parseInt(event.detail.value) || 1;
        this.cohorts = Math.max(1, value);
        this.validateModalInputs();
    }

    handleCapacityPerCohortChange(event) {
        const value = parseInt(event.detail.value) || 0;
        this.capacityPerCohort = Math.max(0, value);
        this.validateModalInputs();
    }

    handleSectionCohortsChange(event) {
        const sectionName = event.target.dataset.section;
        const value = parseInt(event.target.value) || 1;
        
        this.sectionData = this.sectionData.map(section => {
            if (section.name === sectionName) {
                const cohorts = Math.max(1, value);
                return {
                    ...section,
                    cohorts: cohorts,
                    totalCapacity: cohorts * section.capacityPerCohort
                };
            }
            return section;
        });
        
        this.validateModalInputs();
    }

    handleSectionCapacityChange(event) {
        const sectionName = event.target.dataset.section;
        const value = parseInt(event.target.value) || 0;
        
        this.sectionData = this.sectionData.map(section => {
            if (section.name === sectionName) {
                const capacity = Math.max(0, value);
                return {
                    ...section,
                    capacityPerCohort: capacity,
                    totalCapacity: section.cohorts * capacity
                };
            }
            return section;
        });
        
        this.validateModalInputs();
    }

    validateModalInputs() {
    this.validationError = '';
    
    if (this.selectedCohortType === 'Combined') {
        if (this.cohorts <= 0) {
            this.validationError = 'Number of cohorts must be greater than 0.';
            return;
        }
        if (this.capacityPerCohort <= 0) {
            this.validationError = 'Capacity per cohort must be greater than 0.';
            return;
        }
        
        // Check if total capacity can accommodate total student connections
        const totalCapacity = this.cohorts * this.capacityPerCohort;
        if (totalCapacity < this.totalStudentConnections) {
            this.validationError = `Total capacity (${totalCapacity}) is less than total student connections (${this.totalStudentConnections}). Please increase cohorts or capacity per cohort.`;
            return;
        }
         // 🔧 FIXED: Prevent empty cohorts validation
        if (this.cohorts > 1 && this.totalStudentConnections > 0) {
            // Calculate how students would be distributed
            const studentsPerCohort = Math.floor(this.totalStudentConnections / this.cohorts);
            const extraStudents = this.totalStudentConnections % this.cohorts;
            
            // If any cohort would be completely empty
            if (studentsPerCohort === 0) {
                this.validationError = `With ${this.cohorts} cohorts and ${this.totalStudentConnections} students, ${this.cohorts - this.totalStudentConnections} cohort(s) will be empty. Maximum cohorts allowed: ${this.totalStudentConnections}.`;
                return;
            }
            
            // Additional check: if capacity per cohort equals total students and we have multiple cohorts
            if (this.capacityPerCohort >= this.totalStudentConnections && this.cohorts > 1) {
                this.validationError = `Capacity per cohort (${this.capacityPerCohort}) can hold all ${this.totalStudentConnections} students in one cohort, but you're creating ${this.cohorts} cohorts. This will create ${this.cohorts - 1} empty cohort(s). Either reduce cohorts to 1 or reduce capacity per cohort.`;
                return;
            }
        }
    } else if (this.selectedCohortType === 'Section') {
        if (!this.hasSectionData) {
            this.validationError = 'No section data available.';
            return;
        }
        
        // Check each section individually
        for (let section of this.sectionData) {
            if (section.cohorts <= 0) {
                this.validationError = `Section "${section.name}" must have at least 1 cohort.`;
                return;
            }
            if (section.capacityPerCohort <= 0) {
                this.validationError = `Section "${section.name}" must have capacity per cohort greater than 0.`;
                return;
            }
            
            
            // Check if section's total capacity can accommodate its students
            const sectionTotalCapacity = section.cohorts * section.capacityPerCohort;
            if (sectionTotalCapacity < section.studentCount) {
                this.validationError = `Section "${section.name}" has insufficient capacity. Has ${section.studentCount} students but total capacity is only ${sectionTotalCapacity}. Please increase cohorts or capacity per cohort for this section.`;
                return;
            }
            // 🆕 NEW: Prevent empty cohorts in sections
            if (section.cohorts > 1 && section.studentCount > 0) {
                // If number of cohorts exceeds number of students
                if (section.cohorts > section.studentCount) {
                    this.validationError = `Section "${section.name}" cannot create ${section.cohorts} cohorts for only ${section.studentCount} student(s). This will create ${section.cohorts - section.studentCount} empty cohort(s). Maximum cohorts allowed: ${section.studentCount}.`;
                    return;
                }
                
                // If capacity per cohort can hold all students but creating multiple cohorts
                if (section.capacityPerCohort >= section.studentCount && section.cohorts > 1) {
                    this.validationError = `Section "${section.name}" capacity per cohort (${section.capacityPerCohort}) can hold all ${section.studentCount} student(s) in one cohort, but you're creating ${section.cohorts} cohorts. This will create ${section.cohorts - 1} empty cohort(s). Either reduce cohorts to 1 or reduce capacity per cohort.`;
                    return;
                }
            }
        }
         
            
        // Additional check: Ensure no section has 0 students (optional)
        const sectionsWithNoStudents = this.sectionData.filter(section => section.studentCount === 0);
        if (sectionsWithNoStudents.length > 0) {
            const sectionNames = sectionsWithNoStudents.map(s => s.name).join(', ');
            this.validationError = `The following sections have no students: ${sectionNames}. Cannot create cohorts for sections without students.`;
            return;
        }
    }
}


    // async confirmCreate() {
    //     this.validateModalInputs();
        
    //     if (this.validationError) {
    //         return;
    //     }

    //     try {
    //         this.isLoading = true;
    //         console.log('Selected Row IDs:', this.selectedRowIds);
    //     console.log('Selected Row IDs length:', this.selectedRowIds.length);
    //     console.log('Selected Course Offerings:', this.getSelectedCourseOfferings());
            
    //         const plannerData = {
    //             courseOfferingIds: this.selectedRowIds,
    //             cohortType: this.selectedCohortType,
    //             courseCode: this.currentCourseCode
    //         };

    //         if (this.selectedCohortType === 'Combined') {
    //             plannerData.cohorts = this.cohorts;
    //             plannerData.capacityPerCohort = this.capacityPerCohort;
    //             plannerData.sectionData = null;
    //         } else {
    //             plannerData.sectionData = JSON.stringify(this.sectionData);
    //         }
    //       console.log('Final plannerData being sent to Apex:', JSON.stringify(plannerData, null, 2));


    //         const result = await createCohortPlanner(plannerData);
    //         console.log('Result',result)
            
    //         if (result && result.success) {
    //             this.showToast('Success', result.message || 'Cohort Planner created successfully!', 'success');
    //             this.closeModal();
    //             this.resetComponent();
    //         } else {
    //             this.showToast('Error', result?.error || 'Failed to create Cohort Planner', 'error');
    //         }
    //     } catch (error) {
    //         console.error('Error creating cohort planner:', error);
    //         this.showToast('Error', 'Error creating Cohort Planner: ' + (error.body?.message || error.message), 'error');
    //     } finally {
    //         this.isLoading = false;
    //     }
    // }
    async confirmCreate() {
    this.validateModalInputs();
    
    if (this.validationError) {
        this.showToast('Error', this.validationError, 'error');
        return;
    }

    try {
        this.isLoading = true;
        
        const courseOfferingIds = [...this.selectedRowIds];
        
        console.log('Selected Row IDs (converted):', courseOfferingIds);
        console.log('Selected Row IDs length:', courseOfferingIds.length);
        
        let result;
        
        // ✅ Match exact Apex parameter names
        const requestData = {
            selectedCourseOfferingIds: courseOfferingIds, // ✅ Matches Apex parameter
            courseCode: this.currentCourseCode,
            cohorts: this.selectedCohortType === 'Combined' ? this.cohorts : this.totalRecordsToCreate,
            studentCapacity: this.selectedCohortType === 'Combined' ? this.totalCapacityCalculated : this.totalCapacityAllSections,
            cohortType: this.selectedCohortType,
            sectionData: this.selectedCohortType === 'Section' ? JSON.stringify(this.sectionData) : null
        };
        
        console.log('Data sent to Apex (stringified):', JSON.stringify(requestData, null, 2));
        
        result = await createCohortPlanner(requestData);
        
        console.log('Result from Apex:', result);
        
        // ✅ Since Apex returns String, handle differently
        if (result && !result.startsWith('Error:')) {
            this.showToast('Success', result, 'success');
            this.closeModal();
            this.resetComponent();
        } else {
            this.showToast('Error', result || 'Failed to create Cohort Planner', 'error');
        }
        
    } catch (error) {
        console.error('Error creating cohort planner:', error);
        this.showToast('Error', 'Error creating Cohort Planner: ' + (error.body?.message || error.message), 'error');
    } finally {
        this.isLoading = false;
    }
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