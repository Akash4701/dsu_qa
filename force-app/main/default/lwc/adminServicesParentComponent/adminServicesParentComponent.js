import { LightningElement, track, api } from 'lwc';

export default class AdminServiceParentComponent extends LightningElement {
    @track activeTab = 'intake';
    
    // EXISTING PROPERTIES (kept for backward compatibility)
    @track isCheckboxChecked = false;
    @api requirementMode;
    
    // NEW PROPERTIES FOR CUSTOM METADATA
    @track masterRequirementMode = false;
    @track localRequirementMode = false;
    @track institutionType = 'College';
    @track isConfigurationLoaded = false;
    @track configurationLabel = '';
    
    // Data sharing between components
    selectedAcademicProgram;
    selectedProgramPlan;
    workingDays;

    @api switchTab(tabName) {
        console.log('Parent: Switching to tab:', tabName);
        this.activeTab = tabName;
    }

    // Called when user clicks a different tab
    handleActiveTab(event) {
        this.activeTab = event.target.activeTabValue;
        console.log('Active tab changed to:', this.activeTab);

        // UPDATED: Call child method with enhanced configuration data
        setTimeout(() => {
            if (this.activeTab === 'academic') {
                const academicCmp = this.template.querySelector('c-academic-calender-screen');
                if (academicCmp?.handleCheckboxChange) {
                    academicCmp.handleCheckboxChange(this.isCheckboxChecked);
                    console.log('Checkbox checked state sent to academic:', this.isCheckboxChecked);
                }
                // NEW: Pass configuration information if available
                if (academicCmp?.handleInstitutionTypeChange && this.isConfigurationLoaded) {
                    academicCmp.handleInstitutionTypeChange(this.institutionType);
                    console.log('Institution type sent to academic:', this.institutionType);
                }
            } else if (this.activeTab === 'planner') {
                const plannerCmp = this.template.querySelector('c-academic-planner-screen');
                if (plannerCmp?.handleCheckboxChange) {
                    plannerCmp.handleCheckboxChange(this.isCheckboxChecked);
                }
                // NEW: Pass configuration information if available
                if (plannerCmp?.handleConfigurationChange && this.isConfigurationLoaded) {
                    plannerCmp.handleConfigurationChange({
                        masterRequirementMode: this.masterRequirementMode,
                        institutionType: this.institutionType,
                        isConfigurationLoaded: this.isConfigurationLoaded
                    });
                }
            }
        }, 100); // Reduced timeout for better responsiveness
    }

    // UPDATED: Handle navigation or configuration changes from child
    handleChildNavigation(event) {
        const { 
            direction, 
            currentTab, 
            selectedAcademicProgram, 
            selectedProgramPlan, 
            workingDays, 
            // EXISTING: Checkbox state
            isChecked,
            // NEW: Master configuration properties
            masterRequirementMode,
            localRequirementMode,
            institutionType,
            isConfigurationLoaded,
            configurationLabel
        } = event.detail;

        console.log('Parent received navigation event:', {
            direction,
            currentTab,
            isChecked,
            masterRequirementMode,
            localRequirementMode,
            institutionType,
            isConfigurationLoaded
        });

        // EXISTING: Handle checkbox state
        if (typeof isChecked === 'boolean') {
            this.isCheckboxChecked = isChecked;
            console.log('Checkbox checked state received:', this.isCheckboxChecked);
        }

        // NEW: Handle master configuration updates
        if (typeof masterRequirementMode === 'boolean') {
            this.masterRequirementMode = masterRequirementMode;
            console.log('Master requirement mode received:', this.masterRequirementMode);
        }

        if (typeof localRequirementMode === 'boolean') {
            this.localRequirementMode = localRequirementMode;
            console.log('Local requirement mode received:', this.localRequirementMode);
        }

        if (institutionType) {
            this.institutionType = institutionType;
            console.log('Institution type received:', this.institutionType);
        }

        if (typeof isConfigurationLoaded === 'boolean') {
            this.isConfigurationLoaded = isConfigurationLoaded;
            console.log('Configuration loaded state received:', this.isConfigurationLoaded);
        }

        if (configurationLabel) {
            this.configurationLabel = configurationLabel;
            console.log('Configuration label received:', this.configurationLabel);
        }

        // EXISTING: Handle data sharing between components
        if (selectedAcademicProgram) this.selectedAcademicProgram = selectedAcademicProgram;
        if (selectedProgramPlan) this.selectedProgramPlan = selectedProgramPlan;
        if (workingDays) this.workingDays = workingDays;

        // EXISTING: Handle navigation
        if (direction && currentTab) {
            const tabOrder = ['intake', 'academic', 'planner', 'timetable'];
            const currentIndex = tabOrder.indexOf(currentTab);

            if (direction === 'next') {
                this.activeTab = tabOrder[currentIndex + 1] || this.activeTab;
            } else if (direction === 'previous') {
                this.activeTab = tabOrder[currentIndex - 1] || this.activeTab;
                this.updateTabset(); // optional
            }

            console.log(`Navigation event received: ${direction}, now at ${this.activeTab}`);
            
            // NEW: Pass configuration to next tab after navigation
            this.passConfigurationToActiveTab();
        }
    }

    /**
     * NEW: Pass configuration information to the currently active tab
     */
    passConfigurationToActiveTab() {
        setTimeout(() => {
            if (this.isConfigurationLoaded) {
                const configData = {
                    masterRequirementMode: this.masterRequirementMode,
                    localRequirementMode: this.localRequirementMode,
                    institutionType: this.institutionType,
                    isConfigurationLoaded: this.isConfigurationLoaded,
                    configurationLabel: this.configurationLabel
                };

                if (this.activeTab === 'intake') {
                    const intakeCmp = this.template.querySelector('c-intake-screen');
                    if (intakeCmp?.handleConfigurationUpdate) {
                        intakeCmp.handleConfigurationUpdate(configData);
                    }
                } else if (this.activeTab === 'academic') {
                    const academicCmp = this.template.querySelector('c-academic-calender-screen');
                    if (academicCmp?.handleConfigurationUpdate) {
                        academicCmp.handleConfigurationUpdate(configData);
                    }
                } else if (this.activeTab === 'planner') {
                    const plannerCmp = this.template.querySelector('c-academic-planner-screen');
                    if (plannerCmp?.handleConfigurationUpdate) {
                        plannerCmp.handleConfigurationUpdate(configData);
                    }
                }
            }
        }, 50);
    }

    // EXISTING: Update tabset method (unchanged)
    updateTabset() {
        setTimeout(() => {
            const tabset = this.template.querySelector('lightning-tabset');
            if (tabset) {
                const current = this.activeTab;
                this.activeTab = '';
                setTimeout(() => {
                    this.activeTab = current;
                }, 0);
            }
        }, 0);
    }

    // NEW: Getters for template use
    get effectiveRequirementMode() {
        // Return the local mode if available, otherwise use master mode
        return this.localRequirementMode !== undefined ? this.localRequirementMode : this.masterRequirementMode;
    }

    get configurationStatus() {
        if (this.isConfigurationLoaded) {
            return `${this.configurationLabel} - ${this.masterRequirementMode ? 'Strict' : 'Flexible'} Mode`;
        }
        return 'Manual Configuration';
    }

    get showConfigurationInfo() {
        return this.isConfigurationLoaded;
    }

    /**
     * NEW: Method to handle configuration changes from any child component
     */
    handleConfigurationChange(configData) {
        if (configData.masterRequirementMode !== undefined) {
            this.masterRequirementMode = configData.masterRequirementMode;
        }
        if (configData.localRequirementMode !== undefined) {
            this.localRequirementMode = configData.localRequirementMode;
        }
        if (configData.institutionType) {
            this.institutionType = configData.institutionType;
        }
        if (configData.isConfigurationLoaded !== undefined) {
            this.isConfigurationLoaded = configData.isConfigurationLoaded;
        }
        if (configData.configurationLabel) {
            this.configurationLabel = configData.configurationLabel;
        }

        console.log('Parent configuration updated:', {
            masterRequirementMode: this.masterRequirementMode,
            localRequirementMode: this.localRequirementMode,
            institutionType: this.institutionType,
            isConfigurationLoaded: this.isConfigurationLoaded
        });

        // Propagate configuration to all child components
        this.propagateConfigurationToAllTabs();
    }

    /**
     * NEW: Propagate configuration to all child components
     */
    propagateConfigurationToAllTabs() {
        const configData = {
            masterRequirementMode: this.masterRequirementMode,
            localRequirementMode: this.localRequirementMode,
            institutionType: this.institutionType,
            isConfigurationLoaded: this.isConfigurationLoaded,
            configurationLabel: this.configurationLabel
        };

        // Update all child components with new configuration
        const intakeCmp = this.template.querySelector('c-intake-screen');
        if (intakeCmp?.handleConfigurationUpdate) {
            intakeCmp.handleConfigurationUpdate(configData);
        }

        const academicCmp = this.template.querySelector('c-academic-calender-screen');
        if (academicCmp?.handleConfigurationUpdate) {
            academicCmp.handleConfigurationUpdate(configData);
        }

        const plannerCmp = this.template.querySelector('c-academic-planner-screen');
        if (plannerCmp?.handleConfigurationUpdate) {
            plannerCmp.handleConfigurationUpdate(configData);
        }
    }

    /**
     * NEW: Initialize configuration on component load
     */
    connectedCallback() {
        // Initialize with any default configuration
        console.log('Parent component initialized');
        
        // If there's a default requirement mode, apply it
        if (this.requirementMode !== undefined) {
            this.localRequirementMode = this.requirementMode;
            this.isCheckboxChecked = this.requirementMode;
        }
    }
}