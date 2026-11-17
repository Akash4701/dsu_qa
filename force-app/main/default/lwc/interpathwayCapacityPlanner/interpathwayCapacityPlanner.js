import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import getInitialData from '@salesforce/apex/InterpathwayPlannerController.getInitialData';
import createInterpathwayCapacityPlanner from '@salesforce/apex/InterpathwayPlannerController.createInterpathwayCapacityPlanner';
import INTERPATHWAY_OBJECT from '@salesforce/schema/Interpathway_Capacity_Planner__c';
import CAPACITY_TYPE_FIELD from '@salesforce/schema/Interpathway_Capacity_Planner__c.Capacity_Type__c';

const COLUMNS = [
    { label: 'Course Code', fieldName: 'CourseCode', type: 'text', sortable: true },
    { label: 'Course Name', fieldName: 'CourseName', type: 'text', sortable: true },
    { label: 'Offering Name', fieldName: 'Name', type: 'text', sortable: true }
];

export default class InterpathwayCapacityPlanner extends NavigationMixin(LightningElement) {
    @api recordId;
    @track selectedCemName = '';
    @track selectedTermName = '';
    @track selectedCemId = '';
    @track selectedTermId = '';
    @track courseVersions = [];
    @track isLoading = true;
    @track errorMessage = '';
    @track selectedRowIds = [];
    @track capacityTypeOptions = [];
    @track selectedCapacityType = '';
    @track showModal = false;
    @track capacity = 0;

    @track searchTerm = '';
    @track filteredCourseVersions = [];
    @track isTableVisible = false;
    @track isSearchLocked = false;

    @track showDropdown = false;
    @track filteredCourseSuggestions = [];

    // New property to control component visibility
    @track shouldShowComponent = true;

    columns = COLUMNS;

    @wire(getObjectInfo, { objectApiName: INTERPATHWAY_OBJECT })
    objectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$objectInfo.data.defaultRecordTypeId',
        fieldApiName: CAPACITY_TYPE_FIELD
    })
    getPicklistValues({ data, error }) {
        if (data) {
            this.capacityTypeOptions = data.values.map(option => ({
                label: option.label,
                value: option.value
            }));
        } else if (error) {
            console.error('Error fetching picklist values:', error);
        }
    }

    get hasCourseVersions() {
        return this.courseVersions && this.courseVersions.length > 0;
    }

    get selectedCount() {
        return this.selectedRowIds ? this.selectedRowIds.length : 0;
    }

    get capacityType() {
        const selectedCount = this.selectedCount;
        if (selectedCount === 0) return 'None Selected';
        if (selectedCount === 1) return 'Individual Capacity';
        return 'Combined Capacity';
    }

    get disableCreateButton() {
        return this.selectedCount === 0;
    }

    get disableConfirmButton() {
        return !this.capacity || this.capacity <= 0;
    }

    get maxRowSelection() {
        if (this.selectedCapacityType === 'Individual Capacity') {
            return 1;
        }
        return 100;
    }

    // New getters for capacity type validation
    get isCapacityTypeSelected() {
        return this.selectedCapacityType && this.selectedCapacityType.trim() !== '';
    }

    get isSearchDisabled() {
        return !this.isCapacityTypeSelected || this.isSearchLocked;
    }

    get searchPlaceholder() {
        if (!this.isCapacityTypeSelected) {
            return 'Select Capacity Type first...';
        }
        return 'Search courses...';
    }

    // New getter for capacity type disabled state
    get isCapacityTypeDisabled() {
        return this.isSearchLocked;
    }

    connectedCallback() {
        this.selectedRowIds = [];
        this.filteredCourseVersions = [];
        this.isTableVisible = false;
        this.isSearchLocked = false;
        setTimeout(() => {
            this.checkAndLoadData();
        }, 100);
    }

    checkAndLoadData() {
        if (!this.recordId) {
            this.errorMessage = 'No record ID provided. This component must be used as a Quick Action.';
            this.isLoading = false;
            this.shouldShowComponent = false;
            this.showToast('Error', 'No record ID provided. This component must be used as a Quick Action.', 'error');
            this.closeQuickAction();
            return;
        }
        this.loadInitialData();
    }

async loadInitialData() {
    try {
        this.isLoading = true;
        this.errorMessage = '';
        const data = await getInitialData({ cemId: this.recordId });

        this.selectedCemName = data.selectedCemName || 'Unknown';
        this.selectedTermName = data.selectedTermName || 'Unknown';
        this.selectedCemId = data.selectedCemId;
        this.selectedTermId = data.selectedTermId;

        this.courseVersions = (data.courseOfferings || []).map((offering, index) => {
            const uniqueId = offering.Id || `co_${index}_${Date.now()}_${Math.random()}`;
            return {
                Id: uniqueId,
                Name: offering.Name || '',
                CourseCode: offering.CourseCode || '',
                CourseName: offering.CourseName || '',
                AcademicTermName: offering.AcademicTermName || '',
                AcademicTerm: offering.Academic_Term__c || '',
                Course: offering.Course__c || ''
            };
        });

        //  IF no course versions
        if (this.courseVersions.length === 0) {
            this.shouldShowComponent = false;
            this.showToast(
                'Info',
                'No Course Offerings available for ICP creation in this Course Enrollment Management record.',
                'info'
            );
            setTimeout(() => {
                this.closeQuickAction();
            }, 3000);
            return;
        }

        this.selectedRowIds = [];

        // CHANGE 1: Don't show table initially - only show after capacity type is selected
        this.filteredCourseVersions = [];
        this.isTableVisible = false;
        
        this.isSearchLocked = false;
        this.updateSelectableRows();
    } catch (error) {
        this.errorMessage =
            'Error loading data: ' +
            (error.body?.message || error.message || 'Unknown error');
        this.shouldShowComponent = false;
        this.showToast('Error', this.errorMessage, 'error');
        setTimeout(() => {
            this.closeQuickAction();
        }, 3000);
    } finally {
        this.isLoading = false;
    }
}



    updateSelectableRows() {
        const availableIds = this.courseVersions.map(cv => cv.Id);
        this.selectedRowIds = this.selectedRowIds.filter(rowId =>
            availableIds.includes(rowId)
        );
    }

    getSelectedCourseVersions() {
        if (!this.selectedRowIds || this.selectedRowIds.length === 0) {
            return [];
        }
        
        return this.courseVersions.filter(cv => 
            this.selectedRowIds.includes(cv.Id)
        );
    }

    handleSearchInputChange(event) {
        // Don't allow search input if capacity type not selected
        if (!this.isCapacityTypeSelected) {
            return;
        }
        
        this.searchTerm = event.target.value;
        
        // Always show suggestions regardless of search lock status
        if (this.searchTerm && this.searchTerm.length > 0) {
            const searchLower = this.searchTerm.toLowerCase();
            this.filteredCourseSuggestions = (this.courseVersions || [])
                .filter(
                    cv =>
                        (cv.CourseCode && cv.CourseCode.toLowerCase().includes(searchLower)) ||
                        (cv.CourseName && cv.CourseName.toLowerCase().includes(searchLower))
                )
                .slice(0, 10);
            this.showDropdown = this.filteredCourseSuggestions.length > 0;
        } else {
            this.filteredCourseSuggestions = [];
            this.showDropdown = false;
        }
    }

    handleSearchKeyDown(event) {
        if (!this.isCapacityTypeSelected || this.isSearchLocked) {
            return;
        }
        
        if (event.key === 'Enter') {
            this.showDropdown = false;
            this.performSearch();
        }
    }

    handleSearchButtonClick() {
        if (!this.isCapacityTypeSelected || this.isSearchLocked) {
            return;
        }
        
        this.showDropdown = false;
        this.performSearch();
    }

    handleSuggestionClick(event) {
        if (!this.isCapacityTypeSelected) {
            return;
        }
        
        event.preventDefault();
        const code = event.currentTarget.dataset.code;
        this.searchTerm = code;
        this.showDropdown = false;
        
        if (!this.isSearchLocked) {
            this.performSearch();
        }
    }

    performSearch() {
        if (!this.isCapacityTypeSelected || this.isSearchLocked) {
            return;
        }
        
        const term = (this.searchTerm || '').trim().toLowerCase();
        
        if (!term) {
            this.filteredCourseVersions = this.getSelectedCourseVersions();
            this.isTableVisible = this.filteredCourseVersions.length > 0;
            return;
        }
        
        const searchResults = (this.courseVersions || []).filter(
            cv =>
                (cv.CourseCode && cv.CourseCode.toLowerCase().includes(term)) ||
                (cv.CourseName && cv.CourseName.toLowerCase().includes(term))
        );
        
        const selectedItems = this.getSelectedCourseVersions();
        
        const combinedResults = [...searchResults];
        selectedItems.forEach(selectedItem => {
            if (!combinedResults.some(result => result.Id === selectedItem.Id)) {
                combinedResults.push(selectedItem);
            }
        });
        
        this.filteredCourseVersions = combinedResults;
        this.isTableVisible = this.filteredCourseVersions.length > 0;
        
        // Lock the search after performing it (this will disable capacity type)
        if (this.isTableVisible) {
            this.isSearchLocked = true;
        }
    }

    handleCancelSearch() {
        // Unlock search and clear results (this will re-enable capacity type)
        this.isSearchLocked = false;
        this.searchTerm = '';
        this.filteredCourseVersions = [];
        this.isTableVisible = false;
        this.selectedRowIds = [];
        this.showDropdown = false;
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows || [];
        const newSelectedIds = selectedRows.map(row => row.Id);
        
        // Validate selection based on capacity type
        if (this.selectedCapacityType === 'Individual Capacity' && newSelectedIds.length > 1) {
            this.showToast('Warning', 'Individual Capacity allows only one course version selection.', 'warning');
            this.selectedRowIds = [newSelectedIds[0]];
            return;
        }
        
        this.selectedRowIds = newSelectedIds;
        
        if (newSelectedIds.length < this.selectedRowIds.length || newSelectedIds.length === 0) {
            this.refreshTableAfterDeselection();
        }
    }

    refreshTableAfterDeselection() {
        // Only refresh if search is not locked or if we're just updating selection within locked results
        if (!this.isSearchLocked) {
            this.performSearch();
        }
    }

    handleCapacityTypeChange(event) {
        // Only allow changes if search is not locked
        if (this.isSearchLocked) {
            this.showToast('Warning', 'Cannot change capacity type while search is locked. Cancel search first.', 'warning');
            return;
        }
        
        this.selectedCapacityType = event.detail.value;

        // CHANGE 1: Show all course offerings when capacity type is selected
        this.searchTerm = '';
        this.filteredCourseVersions = [...this.courseVersions];
        this.isTableVisible = true; // Now show the table
        this.selectedRowIds = [];

        this.showDropdown = false;

        // If changing to Individual Capacity and more than 1 item is selected, keep only the first one
        if (this.selectedCapacityType === 'Individual Capacity' && this.selectedRowIds.length > 1) {
            this.selectedRowIds = [this.selectedRowIds[0]];
            this.showToast('Info', 'Selection limited to one course offering for Individual Capacity.', 'info');
        }
    }


    handleCreateICP() {
        if (this.selectedCount === 0) {
            this.showToast('Warning', 'Please select at least one Course Version.', 'warning');
            return;
        }
        
        // Validate selection count vs capacity type
        if (this.selectedCapacityType === 'Individual Capacity' && this.selectedCount > 1) {
            this.showToast('Warning', 'Individual Capacity allows only one course version selection.', 'warning');
            return;
        }
        
        if (this.selectedCapacityType === 'Combined Capacity' && this.selectedCount === 1) {
            this.showToast('Warning', 'Combined Capacity requires more than one course version selection.Please switch to Individual Capacity', 'warning');
            return;
        }
        
        this.showModal = true;
        this.capacity = 0;
    }

    handleCapacityChange(event) {
        this.capacity = parseFloat(event.target.value) || 0;
    }

    closeModal() {
        this.showModal = false;
        this.capacity = 0;
    }

    async confirmCreate() {
        try {
            // Final validation before creating
            if (this.selectedCapacityType === 'Individual Capacity' && this.selectedCount > 1) {
                this.showToast('Error', 'Individual Capacity allows only one course version selection.', 'error');
                return;
            }
            
            if (this.selectedCapacityType === 'Combined Capacity' && this.selectedCount === 1) {
                this.showToast('Error', 'Combined Capacity requires more than one course version selection.', 'error');
                return;
            }
            
            this.isLoading = true;
            this.showModal = false;
            const result = await createInterpathwayCapacityPlanner({
                selectedCourseOfferingIds: this.selectedRowIds,
                cemId: this.selectedCemId,
                academicTermId: this.selectedTermId,
                capacity: this.capacity
            });
            
            this.showToast('Success', result, 'success');
            
            // Refresh the entire browser tab after successful creation
            setTimeout(() => {
                window.location.reload();
            }, 2000);
            
        } catch (error) {
            const errorMsg = error.body?.message || error.message || 'Unknown error occurred';
            this.showToast('Error', 'Failed to create Interpathway Capacity Planner: ' + errorMsg, 'error');
            this.isLoading = false;
        }
    }

    closeQuickAction() {
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    actionName: 'view'
                }
            });
        } catch (error) {
            const closeEvent = new CustomEvent('close', {
                bubbles: true,
                composed: true
            });
            this.dispatchEvent(closeEvent);
        }
    }

    resetSelections() {
        this.selectedRowIds = [];
        this.capacity = 0;
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