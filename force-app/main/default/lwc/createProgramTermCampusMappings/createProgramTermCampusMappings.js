import { api, wire, track, LightningElement } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { CloseActionScreenEvent } from 'lightning/actions';
import getLookUpValues from '@salesforce/apex/CreateProgramTermCampusMappingController.getLookUpValues';
import getTermLookUpValues from '@salesforce/apex/CreateProgramTermCampusMappingController.getTermLookUpValues';
import saveMappings from '@salesforce/apex/CreateProgramTermCampusMappingController.saveMappings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FIELDS = ['Account.Name'];

export default class CreateProgramTermCampusMappings extends LightningElement {
    @api recordId;

    @track campusOptions;
    @track termOptions;
    @track currencyOptions;

    combinationName;
    sequenceNumber = 1;
    isLoading = true;
    program;

    @track termCampusRelationshipList = [
        {
            sequenceNumber: 1,
            campus: '',
            term: '',
            currencyValue: '',
        },
    ];

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredGetRecord({ error, data }) {
        if (data) {
            this.program = data.fields.Name.value;
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error creating record',
                    message: error.body.message,
                    variant: 'error',
                })
            );
        }
    }

    @wire(getLookUpValues)
    wiredLookupValues({ error, data }) {
        if (data) {
            this.setComboBoxOptions(data);
            this.isLoading = false;
        } else if (error) {
            console.log(error);
            this.isLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error creating record',
                    message: error.body.message,
                    variant: 'error',
                })
            );
            this.program = undefined;
        }
    }

    @wire(getTermLookUpValues, { programId: '$recordId' })
    wiredGetTermLookUpValues({ error, data }) {
        if (data) {
            let options = [];
            data.forEach((term) => {
                options.push({
                    label: term.Term_Reference__c ? term.Term_Reference__c : term.Name,
                    value: term.Id,
                });
            });
            this.termOptions = options;
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error creating record',
                    message: error.body.message,
                    variant: 'error',
                })
            );
        }
    }

    get disableSave() {
        return !this.showMapping;
    }

    get showMapping() {
        return this.program && this.combinationName && this.combinationName != '';
    }

    handleChange(event) {
        if (event.target.name === 'combinationName') {
            this.combinationName = event.detail.value;
        }

        const rowIndex = event.currentTarget.dataset.index;

        if (event.target.name === 'campus') {
            this.termCampusRelationshipList[rowIndex].campus = event.target.value;
        } else if (event.target.name === 'term') {
            this.termCampusRelationshipList[rowIndex].term = event.target.value;
        } else if (event.target.name === 'currencyValue') {
            this.termCampusRelationshipList[rowIndex].currencyValue = event.target.value;
        }
    }

    setComboBoxOptions(data) {
        if (data.currencyOptions.length > 0) {
            this.currencyOptions = data.currencyOptions;
        }

        if (data.campusList.length > 0) {
            let options2 = [];
            data.campusList.forEach((campus) => {
                options2.push({ label: campus.Name, value: campus.Id });
            });
            this.campusOptions = options2;
        }
    }

    addRow() {
        this.sequenceNumber = this.sequenceNumber + 1;
        let termCampusRelationship = {
            sequenceNumber: this.sequenceNumber,
            campus: '',
            term: '',
            currencyValue: '',
        };
        this.termCampusRelationshipList.push(JSON.parse(JSON.stringify(termCampusRelationship)));
    }

    deleteRow(event) {
        let rowIndex = event.currentTarget.dataset.index;
        if (this.termCampusRelationshipList.length > 0) {
            this.sequenceNumber = this.sequenceNumber - 1;
            this.termCampusRelationshipList.splice(rowIndex, 1);

            for (let i = rowIndex; i < this.termCampusRelationshipList.length; i++) {
                this.termCampusRelationshipList[i].sequenceNumber =
                    this.termCampusRelationshipList[i].sequenceNumber - 1;
            }
        }
    }

    handleSave(event) {
        let btnName;

        if (event !== undefined && event.target.name) {
            btnName = event.target.name;
        }

        let emptyCheck = false;

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

        if (this.termCampusRelationshipList.length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please add Combinations to Save',
                    variant: 'error',
                })
            );

            return;
        }

        for (let rowIndex in this.termCampusRelationshipList) {
            if (this.termCampusRelationshipList[rowIndex].sequenceNumber == null) {
                emptyCheck = true;
            }

            if (this.termCampusRelationshipList[rowIndex].campus == '') {
                emptyCheck = true;
            }

            if (this.termCampusRelationshipList[rowIndex].term == '') {
                emptyCheck = true;
            }

            if (this.termCampusRelationshipList[rowIndex].currencyValue == '') {
                emptyCheck = true;
            }

            if (emptyCheck === true) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Complete all the fields',
                        variant: 'error',
                    })
                );

                return;
            }
        }

        if (emptyCheck === false) {
            let recordsJSON = {
                program: this.recordId,
                combinationName: this.combinationName,
                termCampusList: this.termCampusRelationshipList,
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
                        this.handleCancel();
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
    }

    handleSaveAndNew() {
        this.handleSave();
    }

    emptyAllFieldsForNewCombination() {
        this.combinationName = null;
        this.sequenceNumber = 1;
        this.campus = null;
        this.term = null;
        this.termCampusRelationshipList = [
            {
                sequenceNumber: 1,
                campus: '',
                term: '',
            },
        ];
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}