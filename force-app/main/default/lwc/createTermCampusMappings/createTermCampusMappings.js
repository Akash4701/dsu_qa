import { wire, track, LightningElement } from 'lwc';
import getProgramValues from '@salesforce/apex/CreateTermCampusMappingController.getProgramValues';
import getProgramDependentLookupValues from '@salesforce/apex/CreateTermCampusMappingController.getProgramDependentLookupValues';
import getTermLookUpValues from '@salesforce/apex/CreateTermCampusMappingController.getTermLookUpValues';
import saveMappings from '@salesforce/apex/CreateTermCampusMappingController.saveMappings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class CreateTermCampusMappings extends NavigationMixin(LightningElement) {
    @track programOptions = [];
    @track masterCombinationOptions = [];
    @track programPlanOptions = [];
    @track termCampusRelationshipList = [];

    programId;
    programPlanId;
    masterCombinationId;
    combinationName;
    isLoading = true;
    isError = false;

    @wire(getProgramValues)
    wiredGetProgramValues({ error, data }) {
        if (data) {
            this.programOptions = this.getComboBoxOptions(data);
            this.isLoading = false;
        } else if (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error creating record',
                    message: error.body.message,
                    variant: 'error',
                })
            );
            this.programOptions = undefined;
            this.isLoading = false;
        }
    }

    get disableSave() {
        return !this.showMapping;
    }

    get showProgramDependentFields() {
        return this.programId && !this.isError;
    }

    get showMapping() {
        return (
            this.programPlanId &&
            this.masterCombinationId &&
            this.combinationName &&
            this.combinationName != '' &&
            this.programId &&
            this.termCampusRelationshipList.length !== 0
        );
    }

    async handleChange(event) {
        if (event.target.name === 'program') {
            this.isError = false;
            this.programId = event.detail.value;
            this.programPlanOptions = [];
            this.masterCombinationOptions = [];
            this.termCampusRelationshipList = [];
            this.programPlanId = null;
            this.masterCombinationId = null;

            try {
                this.isLoading = true;
                const result = await getProgramDependentLookupValues({ programId: this.programId });

                if (result.programCampusCombinations.length > 0) {
                    let options = [];
                    result.programCampusCombinations.forEach((option) => {
                        options.push({ label: option.Combination_Name__c, value: option.Id });
                    });
                    this.masterCombinationOptions = options;
                } else {
                    this.isError = true;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'Program do not have Program campus combinations.',
                            variant: 'error',
                        })
                    );

                    return;
                }

                if (result.programPlans.length > 0) {
                    this.programPlanOptions = this.getComboBoxOptions(result.programPlans);
                } else {
                    this.isError = true;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'Program do not have Program plans.',
                            variant: 'error',
                        })
                    );

                    return;
                }
            } catch (error) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            } finally {
                this.isLoading = false;
            }
        } else if (event.target.name === 'combinationName') {
            this.combinationName = event.detail.value;
        } else if (event.target.name === 'masterCombinaton') {
            this.masterCombinationId = event.detail.value;
            this.termCampusRelationshipList = [];
            this.getTermCombinations();
        } else if (event.target.name === 'programPlan') {
            this.programPlanId = event.detail.value;
            this.termCampusRelationshipList = [];
            this.getTermCombinations();
        }
    }

    getTermCombinations() {
        if(!this.programPlanId || !this.masterCombinationId) {
            return;
        }

        this.isLoading = true;
        getTermLookUpValues({ programCombinationId: this.masterCombinationId, programPlanId: this.programPlanId })
            .then((result) => {
                if (result) {
                    this.deserializeTerms(result);
                    this.isLoading = false;
                }
            })
            .catch((error) => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
                this.isLoading = false;
            });
    }

    getComboBoxOptions(data) {
        if (data.length > 0) {
            let options = [];
            data.forEach((option) => {
                options.push({ label: option.Name, value: option.Id });
            });

            return options;
        }
    }

    deserializeTerms(data) {
        if (data.length > 0) {
            let termCampusMappings = [];
            data.forEach((termCampusMapping) => {
                termCampusMappings.push({
                    termId: termCampusMapping.termId,
                    sequenceNumber: termCampusMapping.sequenceNumber,
                    campus: termCampusMapping.campus,
                    campusId: termCampusMapping.campusId,
                    term: termCampusMapping.termReference ? termCampusMapping.termReference : termCampusMapping.term,
                    currencyValue: termCampusMapping.currencyValue,
                });
            });

            this.termCampusRelationshipList = termCampusMappings;
        } else {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No Campus - Term Combinations available.',
                    variant: 'error',
                })
            );
        }
    }

    handleSave(event) {
        let btnName;
        if (event != undefined && event.target.name) {
            btnName = event.target.name;
        }

        if (!this.programId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please Select Program',
                    variant: 'error',
                })
            );
            return;
        }

        if (!this.combinationName) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please Select Combination Name',
                    variant: 'error',
                })
            );
            return;
        }

        if (!this.programPlanId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please Select Program Plan',
                    variant: 'error',
                })
            );
            return;
        }

        if (!this.masterCombinationId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please Select Master Program Campus Combination',
                    variant: 'error',
                })
            );
            return;
        }

        let recordsJSON = {
            program: this.programId,
            programPlan: this.programPlanId,
            combinationName: this.combinationName,
            masterCombination: this.masterCombinationId,
            termCampusRelationships: this.termCampusRelationshipList,
        };

        this.isLoading = true;

        saveMappings({ recordsString: JSON.stringify(recordsJSON) })
            .then((result) => {
                if (result !== undefined) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Mapping created Successfully',
                            variant: 'success',
                        })
                    );
                }
                if (btnName === 'save') {
                    this.navigateToHomePage();
                } else {
                    this.emptyAllFieldsForNewCombination();
                }

                this.isLoading = false;
            })
            .catch((error) => {
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error creating record',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    }

    handleSaveAndNew() {
        this.handleSave();
    }

    emptyAllFieldsForNewCombination() {
        this.programId = null;
        this.combinationName = null;
        this.programPlanId = null;
        this.masterCombinationId = null;
        this.masterCombinationOptions = [];
        this.programPlanOptions = [];
        this.termCampusRelationshipList = [];
    }

    handleCancel() {
        const closeQA = new CustomEvent('close');
        // Dispatches the event.
        this.dispatchEvent(closeQA);
        this.navigateToHomePage();
    }

    navigateToHomePage() {
        let url = window.location.origin + '/lightning/o/Program_Campus_Relationship__c/home';
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: url,
            },
        });
    }
}