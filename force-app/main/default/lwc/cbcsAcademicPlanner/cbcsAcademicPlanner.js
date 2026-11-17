import { LightningElement, track } from 'lwc';
import getAcademicTerms from '@salesforce/apex/AcademicFilterController.getAcademicTerms';
import getCourseConnections from '@salesforce/apex/AcademicCalenderScreenController.getCourseConnections';
import createProgramPathway from '@salesforce/apex/AcademicFilterController.createProgramPathway';
import getLookupOptions from '@salesforce/apex/AcademicFilterController.getLookupOptions';
import getPicklistValues from '@salesforce/apex/AcademicFilterController.getPicklistValues';
import createClusterForSpecificPathway from '@salesforce/apex/AcademicFilterController.createClusterForSpecificPathway';
import getProgramPathwaysByType from '@salesforce/apex/AcademicFilterController.getProgramPathwaysByType';
import getAcademicPrograms from '@salesforce/apex/AcademicCalenderScreenController.getAcademicPrograms';
import getProgramPlans from '@salesforce/apex/AcademicCalenderScreenController.getProgramPlans';
import getTerms from '@salesforce/apex/AcademicCalenderScreenController.getTerms';
import getTermsWithMultipleAcademicTerms from '@salesforce/apex/AcademicCalenderScreenController.getTermsWithMultipleAcademicTerms';
import getPathwayUnitsByPathwayEnrollmentAndTerm from '@salesforce/apex/AcademicFilterController.getPathwayUnitsByPathwayEnrollmentAndTerm';

// Add these new imports for CRUD operations
import updateCluster from '@salesforce/apex/AcademicFilterController.updateCluster';
import deleteCluster from '@salesforce/apex/AcademicFilterController.deleteCluster';
import cloneCluster from '@salesforce/apex/AcademicFilterController.cloneCluster';
updateCluster

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CbcsAcademicPlanner extends LightningElement {
    @track termOptions = [];
    @track programOptions = [];
    @track planOptions = [];
    @track terms = [];
    @track selectedTerms = [];
    @track specializationTypeOptions = [];
    @track courseOptions = [];
    @track filteredCourses = [];
    @track clusterName = '';
    @track minCourses = 0;
    @track maxCourses = 1;
    @track selectedCoursesForCluster = [];
    @track showClusterCourseSelection = false;
    @track isClusterFormValid = false;
    @track searchTerm = '';
    @track showClusterModal = false;
    @track isLoadingSubjects = false;
    @track showSpinner = false;
    @track subjectStartDate;
    @track subjectEndDate;

    // New properties for edit/clone/delete functionality
    @track showEditModal = false;
    @track showDeleteModal = false;
    @track editingCluster = null;
    @track clusterToDelete = null;
    @track isEditMode = false;
    @track editClusterName = '';
    @track editMinCourses = 0;
    @track editMaxCourses = 1;
    @track editSelectedCourses = [];
    @track currentEditTermIndex = -1;
    @track pathwayStartingSemester = '';
    @track pathwayEndingSemester = '';
    selectedProgram = '';
    selectedPlan = '';
    selectedTermIdForPopup = '';
    selectedPathwayIdForCluster = '';
    
    // Fixed: Use consistent property names matching the HTML
    selectedPathwayType = '';  // Changed from pathwayType
    selectedPathwayName = '';  // Changed from pathwayName
    pathwayNameOptions = [];
    globalPathwayList = []; 

    connectedCallback() {
        this.loadInitialData();
    }

    async loadInitialData() {
        try {
            const [programs, terms, lookupOptions, picklistValues] = await Promise.all([
                getAcademicPrograms(),
                getAcademicTerms(),
                getLookupOptions(),
                getPicklistValues()
            ]);

            this.programOptions = programs.map(p => ({ label: p.Name, value: p.Id }));
            this.termOptions = terms.map(t => ({ label: t.Name, value: t.Id }));
            this.courseOptions = lookupOptions.courses.map(c => ({
                label: c.Name,
                value: c.Id,
                courseId: c.hed__Course_ID__c || 'N/A',
                credits: c.Credits__c || 'N/A',
                isSelected: false
            }));
            this.filteredCourses = [...this.courseOptions];
            this.specializationTypeOptions = picklistValues.specializationTypes;
        } catch (error) {
            this.showToast('Error', 'Failed to load data: ' + (error.body?.message || error.message), 'error');
        }
    }

    initTerm(term) {
        return {
            ...term,
            isExpanded: false,
            iconName: 'utility:chevronright',
            pathwayList: [],
            pathwayNames: [],
            pathwayType: this.selectedPathwayType, // Use global pathway type
            pathwayName: this.selectedPathwayName, // Use global pathway name
            selectedPathway: null,
            innerSections: [],
            sectionOptions: [],
            selectedSections: [],
            selectedSectionNames: [],
            pathwayUnits: [],
            uniqueClusters: [],
            isLoadingPathways: false,
            academicTermId: term.hed__Academic_Term__c || term.Academic_Term__c || null,
            isEditable: true
        };
    }

    async loadTermsAndDetails() {
    try {
        const result = await getTerms({ programPlanId: this.selectedPlan });
        this.terms = (result?.terms || []).map(term => {
            const initializedTerm = this.initTerm(term);
            initializedTerm.isEditable = this.isTermEditable(term);
            return initializedTerm;
        });
         this.terms = [...this.terms];
        // If pathway is already selected, load sections
        if (this.selectedPathwayName && this.globalPathwayList.length > 0) {
            const selectedPathway = this.globalPathwayList.find(p => p.Id === this.selectedPathwayName);
            if (selectedPathway) {
                this.loadInnerSectionsForAllTerms(selectedPathway);
            }
        }
    } catch (error) {
        this.showToast('Error', 'Error loading terms: ' + (error.body?.message || error.message), 'error');
    }
}

    async loadGlobalPathways(specializationType) {
        console.log('Specialization Type =', specializationType);
        if (!this.selectedPlan) {
            this.showToast('Warning', 'Select a Program Plan before choosing a pathway type.', 'warning');
            return;
        }

        if (!specializationType) {
            this.globalPathwayList = [];
            this.pathwayNameOptions = [];
            return;
        }

        try {
            const result = await getProgramPathwaysByType({
                programPlanId: this.selectedPlan,
                specializationType: specializationType
            });

            this.globalPathwayList = result.map(p => ({ Id: p.Id, 
                Name: p.Name, 
                Starting_Semester__c: p.Starting_Semester__c,
                Ending_Semester__c: p.Ending_Semester__c }));
            this.pathwayNameOptions = this.globalPathwayList.map(p => ({
                label: p.Name,
                value: p.Id  // Use ID as value to match the selection
            }));
            console.log('Pathway Name Options:', JSON.stringify(this.pathwayNameOptions, null, 2));
        } catch (error) {
            this.showToast('Error', 'Failed to fetch pathways: ' + (error.body?.message || error.message), 'error');
        }
    }

    async loadInnerSectionsForAllTerms(selectedPathway) {
        console.log('Loading inner sections for pathway:', selectedPathway);
        try {
            const result = await getCourseConnections();
            console.log('Course connections result:', result);

            const innerSections = (result?.courseConnections || []).map(conn => ({
                id: `cc-${conn.Id}`,
                title: conn.Name,
                isActive: conn.Active__c,
                isSelected: false,
                pathwayId: selectedPathway.Id,
                courseEnrollmentId: conn.Id
            }));

            console.log('Inner sections created:', innerSections);

            // Clone and update each term individually
            const updatedTerms = this.terms.map(originalTerm => {
                const updatedTerm = { ...originalTerm };

                updatedTerm.innerSections = [...innerSections];
                updatedTerm.selectedSections = [];
                updatedTerm.selectedSectionNames = [];
                updatedTerm.selectedPathway = selectedPathway; // Set the selected pathway
                updatedTerm.pathwayType = this.selectedPathwayType;
                updatedTerm.pathwayName = this.selectedPathwayName;
                
                // Fixed: Use correct property names
                updatedTerm.sectionOptions = innerSections.map(s => ({
                    label: s.title,  // Fixed: was s.Title
                    value: s.id,     // Fixed: was s.Id
                    uniqueId: `${originalTerm.Id}-${s.id}`
                }));

                return updatedTerm;
            });

            this.terms = [...updatedTerms]; // ensure reactivity
            console.log('Terms updated with inner sections:', this.terms);
        } catch (error) {
            console.error('Error in loadInnerSectionsForAllTerms:', error);
            this.showToast('Error', 'Failed to load sections: ' + (error.body?.message || error.message), 'error');
        }
    }

async loadPathwayUnits(termIndex) {
    const term = this.terms[termIndex];
    if (!term.selectedSections?.length || !term.selectedPathway) {
        term.pathwayUnits = [];
        term.uniqueClusters = [];
        this.terms = [...this.terms];
        return;
    }

    try {
        let allUnits = [];

        for (const sectionId of term.selectedSections) {
            const courseEnrollmentId = sectionId.replace('cc-', '');
            const section = term.innerSections.find(s => s.id === sectionId);

            try {
                const result = await getPathwayUnitsByPathwayEnrollmentAndTerm({
                    pathwayId: term.selectedPathway.Id,
                    courseEnrollmentId: courseEnrollmentId,
                    termId: term.Id
                });

                const units = result.map(unit => ({
                    Id: unit.Id,
                    CourseName: unit.Course__r?.Name || 'N/A',
                    CourseId: unit.Course__r?.Id || unit.Course__c, // Add this line - the actual course ID
                    ClusterName: unit.Cluster__r?.Name || 'N/A',
                    ClusterId: unit.Cluster__r?.Id,
                    MinCourses: unit.Cluster__r?.Minimum_Courses__c || 0,
                    MaxCourses: unit.Cluster__r?.Maximum_Courses__c || 0,
                    EnrollmentName: section?.title || 'N/A',
                    CreatedDate: unit.CreatedDate,
                    ProgramPlanAccountId: unit.Program_Plan__r?.hed__Account__c,
                    courseEnrollmentId: courseEnrollmentId // Add this for processUniqueClusters
                }));

                allUnits = [...allUnits, ...units];
            } catch (err) {
                console.error(`Error fetching units for ${sectionId}`, err);
            }
        }

        const filteredUnits = allUnits.filter(unit =>
            unit.ProgramPlanAccountId === this.selectedProgram
        );

        term.pathwayUnits = filteredUnits;
        this.processUniqueClusters(termIndex);
        this.terms = [...this.terms];
    } catch (error) {
        this.showToast('Error', 'Failed to load units: ' + (error.body?.message || error.message), 'error');
    }
}

    // In your processUniqueClusters method, you need to store both Course IDs and Pathway Unit IDs
processUniqueClusters(termIndex) {
    const term = this.terms[termIndex];
    const clusterMap = new Map();

    term.pathwayUnits.forEach(unit => {
        const key = `${unit.ClusterId}-${unit.courseEnrollmentId}`;
        if (!clusterMap.has(key)) {
            clusterMap.set(key, {
                key,
                ClusterId: unit.ClusterId,
                ClusterName: unit.ClusterName,
                MinCourses: unit.MinCourses,
                MaxCourses: unit.MaxCourses,
                EnrollmentName: unit.EnrollmentName,
                CourseNames: [],
                CourseIds: [],           // This stores actual Course IDs
                PathwayUnitIds: [],      // This stores Pathway Unit IDs
                CreatedDate: unit.CreatedDate
            });
        }
        const cluster = clusterMap.get(key);
        if (!cluster.CourseNames.includes(unit.CourseName)) {
            cluster.CourseNames.push(unit.CourseName);
            cluster.CourseIds.push(unit.CourseId);        // Use CourseId from the updated loadPathwayUnits
            cluster.PathwayUnitIds.push(unit.Id);         // Store Pathway Unit ID
        }
        if (unit.CreatedDate && (!cluster.CreatedDate || unit.CreatedDate > cluster.CreatedDate)) {
            cluster.CreatedDate = unit.CreatedDate;
        }
    });

    term.uniqueClusters = Array.from(clusterMap.values())
        .map(cluster => ({ 
            ...cluster, 
            CourseNames: cluster.CourseNames.join(', '),
            termIndex: termIndex
        }))
        .sort((a, b) => new Date(b.CreatedDate || 0) - new Date(a.CreatedDate || 0));

    this.terms = [...this.terms];
}

    // NEW: Unified Menu Action Handler
    handleMenuAction(event) {
        const action = event.currentTarget.dataset.action;
        const clusterId = event.currentTarget.dataset.clusterId; 
        const termIndex = parseInt(event.currentTarget.dataset.termIndex);
        
        switch (action) {
            case 'edit':
                this.handleEditCluster(clusterId, termIndex);
                break;
            case 'clone':
                this.handleCloneCluster(clusterId, termIndex);
                break;
            case 'delete':
                this.handleDeleteCluster(clusterId, termIndex);
                break;
        }
    }

    // NEW: Edit Cluster Handler
handleEditCluster(clusterId, termIndex) {
    const term = this.terms[termIndex];
    const cluster = term.uniqueClusters.find(c => c.ClusterId === clusterId);
    
    if (cluster) {
        console.log('Editing cluster:', cluster);
        console.log('Cluster CourseIds:', cluster.CourseIds);
        
        this.editingCluster = { ...cluster };
        this.editClusterName = cluster.ClusterName;
        this.editMinCourses = cluster.MinCourses;
        this.editMaxCourses = cluster.MaxCourses;
        this.editSelectedCourses = [...(cluster.CourseIds || [])];
        this.currentEditTermIndex = termIndex;
        this.isEditMode = true;
        
        console.log('editSelectedCourses:', this.editSelectedCourses);
        
        // Clear search term first
        this.searchTerm = '';
        
        // Reset all course selections first
        this.courseOptions = this.courseOptions.map(c => ({
            ...c,
            isSelected: false
        }));
        
        // Then mark the selected courses
        this.editSelectedCourses.forEach(courseId => {
            console.log('Looking for courseId:', courseId);
            const course = this.courseOptions.find(c => c.value === courseId);
            if (course) {
                console.log('Found course and marking as selected:', course.label);
                course.isSelected = true;
            } else {
                console.log('Course not found:', courseId);
            }
        });
        
        // Update filtered courses
        this.filteredCourses = [...this.courseOptions];
        
        // Force reactivity
        this.courseOptions = [...this.courseOptions];
        
        console.log('Final courseOptions:', this.courseOptions.filter(c => c.isSelected));
        
        this.showEditModal = true;
    }
}

    // NEW: Clone Cluster Handler
    async handleCloneCluster(clusterId, termIndex) {
        const term = this.terms[termIndex];
        const cluster = term.uniqueClusters.find(c => c.ClusterId === clusterId);
        
        if (cluster) {
            this.showSpinner = true;
            try {
                await cloneCluster({
                    clusterIdToClone: clusterId,
                    newClusterName: `${cluster.ClusterName} - Copy`,
                    termId: term.Id,
                    programPlanId: this.selectedPlan
                });
                
                this.showToast('Success', 'Cluster cloned successfully!', 'success');
                // Refresh the data
                setTimeout(() => this.loadPathwayUnits(termIndex), 1000);
            } catch (error) {
                this.showToast('Error', 'Failed to clone cluster: ' + (error.body?.message || error.message), 'error');
            } finally {
                this.showSpinner = false;
            }
        }
    }

    // NEW: Delete Cluster Handler
    handleDeleteCluster(clusterId, termIndex) {
        const term = this.terms[termIndex];
        const cluster = term.uniqueClusters.find(c => c.ClusterId === clusterId);
        
        if (cluster) {
            this.clusterToDelete = { 
                ...cluster, 
                termIndex: termIndex 
            };
            this.showDeleteModal = true;
        }
    }

    // NEW: Confirm Delete Handler
    async handleConfirmDelete() {
    if (this.clusterToDelete) {
        this.showSpinner = true;
        const termIndexToRefresh = this.clusterToDelete.termIndex; // Store before clearing
        
        try {
            await deleteCluster({
                clusterId: this.clusterToDelete.ClusterId
            });
            
            this.showToast('Success', 'Cluster deleted successfully!', 'success');
            this.showDeleteModal = false;
            this.clusterToDelete = null; // Clear before refresh
            
            // Refresh the specific term's pathway units
            setTimeout(() => this.loadPathwayUnits(termIndexToRefresh), 1000);
            
        } catch (error) {
            this.showToast('Error', 'Failed to delete cluster: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.showSpinner = false;
        }
    }
}


    // NEW: Save Edit Handler
async handleSaveEdit() {
    if (!this.editingCluster || !this.editClusterName.trim()) {
        this.showToast('Error', 'Please provide a valid cluster name.', 'error');
        return;
    }

    this.showSpinner = true;
    try {
        await updateCluster({
            clusterId: this.editingCluster.ClusterId,
            clusterName: this.editClusterName,
            minCourses: this.editMinCourses,
            maxCourses: this.editMaxCourses,
            selectedCourseIds: this.editSelectedCourses
        });
        
        this.showToast('Success', 'Cluster updated successfully!', 'success');
        this.handleCloseEditModal();
        
        // Reload pathway units for all terms that have selected sections and pathways
        setTimeout(() => {
            this.terms.forEach((term, index) => {
                if (term.selectedSections?.length > 0 && term.selectedPathway) {
                    this.loadPathwayUnits(index);
                }
            });
        }, 1000);
        
    } catch (error) {
        this.showToast('Error', 'Failed to update cluster: ' + (error.body?.message || error.message), 'error');
    } finally {
        this.showSpinner = false;
    }
}

    // NEW: Edit Input Change Handler
    handleEditInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        
        if (field === 'editClusterName') {
            this.editClusterName = value;
        } else if (field === 'editMinCourses') {
            this.editMinCourses = parseInt(value, 10) || 0;
        } else if (field === 'editMaxCourses') {
            this.editMaxCourses = parseInt(value, 10) || 1;
        }
    }

    // NEW: Edit Course Selection Handler
    handleEditCourseSelection(event) {
        const courseId = event.target.dataset.courseId;
        const isChecked = event.target.checked;
        
        [this.courseOptions, this.filteredCourses].forEach(courses => {
            const course = courses.find(c => c.value === courseId);
            if (course) course.isSelected = isChecked;
        });
        
        if (isChecked && !this.editSelectedCourses.includes(courseId)) {
            this.editSelectedCourses.push(courseId);
        } else if (!isChecked) {
            this.editSelectedCourses = this.editSelectedCourses.filter(id => id !== courseId);
        }
    }

    // NEW: Close Edit Modal
    handleCloseEditModal() {
        this.showEditModal = false;
        this.editingCluster = null;
        this.isEditMode = false;
        this.editClusterName = '';
        this.editMinCourses = 0;
        this.editMaxCourses = 1;
        this.editSelectedCourses = [];
        this.currentEditTermIndex = -1;
        
        // Reset course selections
        this.courseOptions = this.courseOptions.map(c => ({ ...c, isSelected: false }));
        this.filteredCourses = [...this.courseOptions];
    }

    // NEW: Close Delete Modal
    handleCloseDeleteModal() {
        this.showDeleteModal = false;
        this.clusterToDelete = null;
    }

    handleProgramChange(event) {
        this.selectedProgram = event.detail.value;
        this.planOptions = [];
        this.terms = [];
        // Reset pathway selections
        this.selectedPathwayType = '';
        this.selectedPathwayName = '';
        this.pathwayNameOptions = [];
        this.globalPathwayList = [];
        if (this.selectedProgram) this.loadProgramPlans();
    }

    handlePlanChange(event) {
        this.selectedPlan = event.detail.value;
        this.terms = [];
        // Reset pathway selections
        this.selectedPathwayType = '';
        this.selectedPathwayName = '';
        this.pathwayNameOptions = [];
        this.globalPathwayList = [];
        if (this.selectedPlan) setTimeout(() => this.loadTermsAndDetails(), 100);
    }

    async handleTermChange(event) {
    this.selectedTerms = event.detail.value;
    try {
        const result = !this.selectedTerms?.length
            ? await getTerms({ programPlanId: this.selectedPlan })
            : await getTermsWithMultipleAcademicTerms({ 
                academicTermIds: this.selectedTerms, 
                programPlanId: this.selectedPlan 
            });

        this.terms = (result?.terms || []).map(term => {
            const initializedTerm = this.initTerm(term);
            initializedTerm.isEditable = this.isTermEditable(term);
            return initializedTerm;
        });
        
        this.terms = [...this.terms];
        // If pathway is already selected, load sections
        if (this.selectedPathwayName && this.globalPathwayList.length > 0) {
            const selectedPathway = this.globalPathwayList.find(p => p.Id === this.selectedPathwayName);
            if (selectedPathway) {
                this.loadInnerSectionsForAllTerms(selectedPathway);
            }
        }
    } catch (error) {
        this.showToast('Error', error?.body?.message || error.message, 'error');
    }
}

    handlePathwayTypeChange(event) {
        console.log('Pathway type changed to:', event.detail.value);
        this.selectedPathwayType = event.detail.value;  // Fixed: use selectedPathwayType
        this.selectedPathwayName = '';  // Fixed: use selectedPathwayName
        this.pathwayNameOptions = [];
        this.globalPathwayList = [];

        // Clear all terms
        this.terms = this.terms.map(term => ({
            ...term,
            pathwayType: this.selectedPathwayType,
            pathwayName: '',
            selectedPathway: null,
            innerSections: [],
            selectedSections: [],
            selectedSectionNames: [],
            sectionOptions: []
        }));

        // Load pathways for selected type
        this.loadGlobalPathways(this.selectedPathwayType);
    }

    handlePathwayNameChange(event) {
    console.log('Pathway name changed to:', event.detail.value);
    this.selectedPathwayName = event.detail.value;

    const selectedPathway = this.globalPathwayList?.find(
        p => p.Id === this.selectedPathwayName
    );

    console.log('Selected pathway found:', selectedPathway);

    // Set the semester values from the selected pathway FIRST
    if (selectedPathway) {
        this.pathwayStartingSemester = selectedPathway.Starting_Semester__c || '';
        this.pathwayEndingSemester = selectedPathway.Ending_Semester__c || '';
        console.log('Pathway Semesters:', this.pathwayStartingSemester, 'to', this.pathwayEndingSemester);
    } else {
        this.pathwayStartingSemester = '';
        this.pathwayEndingSemester = '';
    }

    // THEN update terms with proper isEditable calculation
    this.terms = this.terms.map(term => {
        const updatedTerm = {
            ...term,
            pathwayName: this.selectedPathwayName,
            selectedPathway: selectedPathway || null,
            selectedSections: [],
            selectedSectionNames: [],
            innerSections: [],
            sectionOptions: []
        };
        
        // Calculate isEditable AFTER semester values are set
        updatedTerm.isEditable = this.isTermEditable(updatedTerm);
        return updatedTerm;
    });

    // Force reactivity
    this.terms = [...this.terms];

    
console.log('Updated terms with isEditable:', this.terms.map(t => ({ name: t.Name, isEditable: t.isEditable })));


    if (selectedPathway) {
        console.log('Loading inner sections for selected pathway');
        this.loadInnerSectionsForAllTerms(selectedPathway);
    } else {
        console.log('No pathway selected, clearing sections');
    }
}

isTermEditable(term) {
    console.log('=== isTermEditable called ===');
    console.log('Term:', term.Name);
    console.log('pathwayStartingSemester:', this.pathwayStartingSemester);
    console.log('pathwayEndingSemester:', this.pathwayEndingSemester);
    
    if (!this.pathwayStartingSemester || !this.pathwayEndingSemester) {
        console.log('No pathway semester restrictions - returning true');
        return true;
    }

    const termName = term.Name || '';
    console.log('Processing term name:', termName);
    
    // Try multiple patterns to extract semester number
    const patterns = [
        /Semester\s+(\d+)/i,
        /Sem\s+(\d+)/i,
        /(\d+)(?:st|nd|rd|th)?\s+Semester/i,
        /Term\s+(\d+)/i,
        /(\d+)/
    ];
    
    let termSemesterNum = null;
    for (const pattern of patterns) {
        const match = termName.match(pattern);
        if (match) {
            termSemesterNum = parseInt(match[1]);
            console.log(`Extracted term semester: ${termSemesterNum} using pattern: ${pattern}`);
            break;
        }
    }
    
    if (!termSemesterNum) {
        console.log('Could not parse term semester - returning true');
        return true;
    }
    
    // Extract pathway semester numbers
    let startSemesterNum = null;
    let endSemesterNum = null;
    
    for (const pattern of patterns) {
        if (!startSemesterNum) {
            const startMatch = this.pathwayStartingSemester.match(pattern);
            if (startMatch) {
                startSemesterNum = parseInt(startMatch[1]);
                console.log(`Extracted start semester: ${startSemesterNum}`);
            }
        }
        if (!endSemesterNum) {
            const endMatch = this.pathwayEndingSemester.match(pattern);
            if (endMatch) {
                endSemesterNum = parseInt(endMatch[1]);
                console.log(`Extracted end semester: ${endSemesterNum}`);
            }
        }
        if (startSemesterNum && endSemesterNum) break;
    }
    
    if (!startSemesterNum || !endSemesterNum) {
        console.log('Could not parse pathway semesters - returning true');
        return true;
    }
    
    const isEditable = termSemesterNum >= startSemesterNum && termSemesterNum <= endSemesterNum;
    console.log(`FINAL RESULT: Term ${termName} (${termSemesterNum}) is ${isEditable ? 'EDITABLE' : 'NOT EDITABLE'} (range: ${startSemesterNum}-${endSemesterNum})`);
    console.log('=== end isTermEditable ===');
    
    return isEditable;
}

    handleSectionChange(event) {
    const termIndex = this.terms.findIndex(t => t.Id === event.target.dataset.termId);
    if (termIndex === -1) return;

    const term = this.terms[termIndex];
    const sectionId = event.target.value;
    // Radio buttons are always "checked" when selected, no need to check isChecked

    if (!term.selectedSections) {
        term.selectedSections = [];
        term.selectedSectionNames = [];
    }

    // For radio buttons, selection always means replacing the current selection
    term.selectedSections = [sectionId];
    
    // Clear previous section names and add the new one
    const section = term.innerSections.find(s => s.id === sectionId);
    term.selectedSectionNames = section ? [section.title] : [];
    
    // Update all sections to reflect the new selection state
    term.innerSections.forEach(section => {
        section.isSelected = section.id === sectionId;
    });

    // Remove plural indicator since we'll always have 0 or 1 selection
    term.selectedSectionsPlural = '';

    this.terms = [...this.terms];

    // Load pathway units since we have a selection
    if (term.selectedPathway) {
        this.loadPathwayUnits(termIndex);
    } else {
        term.pathwayUnits = [];
        term.uniqueClusters = [];
        this.terms = [...this.terms];
    }
}

    handleToggleExpand(event) {
        const termIndex = this.terms.findIndex(t => t.Id === event.currentTarget.dataset.termId);
        if (termIndex !== -1) {
            const term = this.terms[termIndex];
            term.isExpanded = !term.isExpanded;
            term.iconName = term.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
            this.terms = [...this.terms];
        }
    }

    handleRefreshPathwayUnits(event) {
        const termIndex = this.terms.findIndex(t => t.Id === event.currentTarget.dataset.termId);
        if (termIndex !== -1) {
            this.loadPathwayUnits(termIndex);
            this.showToast('Info', 'Refreshing units...', 'info');
        }
    }

    handleAddClusters(event) {
        this.selectedTermIdForPopup = event.currentTarget.dataset.termId;
        const termIndex = this.terms.findIndex(t => t.Id === this.selectedTermIdForPopup);
        if (termIndex !== -1) {
            const term = this.terms[termIndex];
            this.selectedPathwayIdForCluster = term.selectedPathway?.Id;
            if (term.selectedPathway && term.selectedSections?.length > 0) {
                this.subjectStartDate = term.hed__Start_Date__c;
                this.subjectEndDate = term.hed__End_Date__c;
                this.resetClusterForm();
                this.showClusterModal = true;
            } else {
                this.showToast('Error', !term.selectedPathway ? 'Select a pathway first.' : 'Select at least one enrollment.', 'error');
            }
        }
    }

    resetClusterForm() {
        this.clusterName = '';
        this.minCourses = 0;
        this.maxCourses = 1;
        this.selectedCoursesForCluster = [];
        this.showClusterCourseSelection = false;
        this.isClusterFormValid = false;
        this.searchTerm = '';
        this.courseOptions = this.courseOptions.map(c => ({ ...c, isSelected: false }));
        this.filteredCourses = [...this.courseOptions];
    }

    handleClusterInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        if (field === 'clusterName') this.clusterName = value;
        else if (field === 'minCourses') this.minCourses = parseInt(value, 10) || 0;
        else if (field === 'maxCourses') this.maxCourses = parseInt(value, 10) || 1;
        this.validateClusterForm();
    }

    validateClusterForm() {
        const hasValidName = this.clusterName.trim().length > 0;
        this.showClusterCourseSelection = hasValidName;
        if (!hasValidName) this.selectedCoursesForCluster = [];
        this.isClusterFormValid = hasValidName && this.selectedCoursesForCluster.length > 0;
    }

    handleCourseSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filteredCourses = !this.searchTerm
            ? [...this.courseOptions]
            : this.courseOptions.filter(c =>
                  c.label.toLowerCase().includes(this.searchTerm) ||
                  c.courseId.toLowerCase().includes(this.searchTerm)
              );
    }

    handleCourseSelection(event) {
        const courseId = event.target.dataset.courseId;
        const isChecked = event.target.checked;
        [this.courseOptions, this.filteredCourses].forEach(courses => {
            const course = courses.find(c => c.value === courseId);
            if (course) course.isSelected = isChecked;
        });
        if (isChecked && !this.selectedCoursesForCluster.includes(courseId)) {
            this.selectedCoursesForCluster.push(courseId);
        } else if (!isChecked) {
            this.selectedCoursesForCluster = this.selectedCoursesForCluster.filter(id => id !== courseId);
        }
        this.isClusterFormValid = this.clusterName.trim().length > 0 && this.selectedCoursesForCluster.length > 0;
    }

    handleSelectAllCourses(event) {
        const isChecked = event.target.checked;
        const visibleIds = this.filteredCourses.map(c => c.value);
        this.filteredCourses.forEach(course => (course.isSelected = isChecked));
        this.courseOptions.forEach(course => {
            if (visibleIds.includes(course.value)) course.isSelected = isChecked;
        });
        if (isChecked) {
            visibleIds.forEach(id => {
                if (!this.selectedCoursesForCluster.includes(id)) this.selectedCoursesForCluster.push(id);
            });
        } else {
            this.selectedCoursesForCluster = this.selectedCoursesForCluster.filter(id => !visibleIds.includes(id));
        }
        this.isClusterFormValid = this.clusterName.trim().length > 0 && this.selectedCoursesForCluster.length > 0;
    }

    handleClearAllCourses() {
        this.courseOptions.forEach(c => (c.isSelected = false));
        this.filteredCourses.forEach(c => (c.isSelected = false));
        this.selectedCoursesForCluster = [];
        this.isClusterFormValid = false;
    }

    async handleSaveCluster() {
    if (!this.isClusterFormValid || !this.selectedPathwayIdForCluster) {
        this.showToast('Error', 'Please complete all required fields.', 'error', 'sticky');
        return;
    }

    const termRecord = this.terms.find(t => t.Id === this.selectedTermIdForPopup);
    const selectedSections = termRecord?.selectedSections || [];
    if (!selectedSections.length) {
        this.showToast('Error', 'Please select at least one course enrollment.', 'error', 'sticky');
        return;
    }

    const academicTermId = termRecord?.academicTermId;
    this.isLoadingSubjects = true;

    try {
        let totalClustersCreated = 0;
        let totalUnitsCreated = 0;
        const errors = [];

        for (let i = 0; i < selectedSections.length; i++) {
            const sectionId = selectedSections[i];
            const courseEnrollmentId = sectionId.replace('cc-', '');
            const section = termRecord.innerSections.find(s => s.id === sectionId);
            const sectionName = section?.title || `Section-${i + 1}`;

            try {
                await createClusterForSpecificPathway({
                    name: `${this.clusterName} - ${sectionName}`,
                    min: this.minCourses,
                    max: this.maxCourses,
                    termId: academicTermId,
                    programId: this.selectedProgram,
                    selectedCourseIds: [...this.selectedCoursesForCluster],
                    specificPathwayId: this.selectedPathwayIdForCluster,
                    programPlanId: this.selectedPlan,
                    courseEnrollmentId,
                    sectionId: '',
                    startDate: this.subjectStartDate,
                    endDate: this.subjectEndDate,
                    capacity: null,
                    semesterTermId: this.selectedTermIdForPopup
                });
                totalClustersCreated++;
                totalUnitsCreated += this.selectedCoursesForCluster.length;
            } catch (error) {
                errors.push(`Failed to create cluster for ${sectionName}: ${error.body?.message || error.message}`);
            }
        }

        if (totalClustersCreated > 0) {
            const message = `Successfully created ${totalClustersCreated} cluster(s) with ${totalUnitsCreated} total pathway units!`;
            this.showToast(
                errors.length > 0 ? 'Partial Success' : 'Success',
                message,
                errors.length > 0 ? 'warning' : 'success',
                errors.length > 0 ? 'sticky' : 'dismissable' // 👈 partial success = sticky, full success = auto close
            );
        } else {
            this.showToast(
                'Error',
                `Failed to create clusters. ${errors.join('; ')}`,
                'error',
                'sticky'
            );
        }

        this.showClusterModal = false;

        const termIndex = this.terms.findIndex(t => t.Id === this.selectedTermIdForPopup);
        if (termIndex !== -1) {
            setTimeout(() => this.loadPathwayUnits(termIndex), 1000);
        }
    } catch (error) {
        this.showToast('Error', 'Unexpected error: ' + (error.body?.message || error.message), 'error', 'sticky');
    } finally {
        this.isLoadingSubjects = false;
    }
}


    async loadProgramPlans() {
        try {
            const result = await getProgramPlans({ academicProgramId: this.selectedProgram });
            this.planOptions = result.map(plan => ({ label: plan.Name, value: plan.Id }));
        } catch (error) {
            this.showToast('Error', 'Error loading program plans: ' + error.body?.message, 'error');
        }
    }

    handleModalClose() {
        this.showClusterModal = false;
        this.resetClusterForm();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get isAllCoursesSelected() {
        return this.filteredCourses.length > 0 && this.filteredCourses.every(c => c.isSelected);
    }

    get selectedClustersInfo() {
        const termRecord = this.terms.find(t => t.Id === this.selectedTermIdForPopup);
        const selectedSections = termRecord?.selectedSections || [];
        const selectedCourses = this.selectedCoursesForCluster.length;
        return selectedSections.length > 0 && selectedCourses > 0
            ? {
                  clusterCount: selectedSections.length,
                  unitsPerCluster: selectedCourses,
                  totalUnits: selectedSections.length * selectedCourses
              }
            : null;
    }
    
    get isSaveClusterDisabled() {
        return !this.isClusterFormValid;
    }

    // NEW: Getters for edit modal
    get isEditSaveDisabled() {
        return !this.editClusterName.trim() || this.editSelectedCourses.length === 0;
    }

    get editSelectedClustersInfo() {
        return this.editSelectedCourses.length > 0
            ? {
                  totalUnits: this.editSelectedCourses.length
              }
            : null;
    }
}