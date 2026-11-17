/* eslint-disable no-confusing-arrow */
// letterGradeManagement.js
import { api, LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';

import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import LETTER_GRADING_OBJECT from '@salesforce/schema/Letter_Grading__c';
import DEFINITION_FIELD from '@salesforce/schema/Letter_Grading__c.Definition__c';

import { COLUMNS, DELETE_COLUMN, MECHANISM_OPTIONS, TYPE_OPTIONS } from './constants';

import getLetterGradeSettings from '@salesforce/apex/LetterGradeSetupController.getLetterGradeSettings';
import saveLetterGradeSettings from '@salesforce/apex/LetterGradeSetupController.saveLetterGradeSettings';
import noActiveLetterGradeSetting from '@salesforce/apex/LetterGradeSetupController.checkActiveLetterGrade';

export default class LetterGradeSetup extends LightningElement {
    @api recordId = '';
    recordTypeIds;
    
    @track sortedBy;
    @track sortedDirection = 'asc';

    @track definitionPicklistOption = [];
    @track letterGradeOriginal = {};
    @track letterGradeSetting = {
        gradeRanges: [],
    };
    

    isLoading = false;
    @track editClicked = false;
    isDataFetched;
    isActiveChanged = false;
    @track validationError = {};

    regex = /\d/;
    numberRegex = /^\d+$/;

    @wire(getObjectInfo, { objectApiName: LETTER_GRADING_OBJECT })
    getObjectInfoCallback({ data, error }) {
        if (data) {
            const recordTypeInfos = data.recordTypeInfos;
            this.recordTypeIds = Object.values(recordTypeInfos).filter((rti) => rti.name == 'Master')[0]?.recordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$recordTypeIds', fieldApiName: DEFINITION_FIELD })
    getDefinitionPicklistValues({ data, error }) {
        if (data) {
            this.definitionPicklistOption = data.values.map((item) => ({
                label: item.label || '',
                value: item.value || '',
            }));
        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
        }
    }

    @wire(getLetterGradeSettings, { gradeSettingId: '$recordId' ,picklistValue : '$definitionPicklistOption'})
    wiredLetterGrades({ error, data }) {
        if (data) {
            this.letterGradeOriginal = data;
            this.letterGradeSetting = JSON.parse(JSON.stringify(this.letterGradeOriginal));
            this.letterGradeSetting.gradeRanges = this.letterGradeSetting.gradeRanges.map((l) => {
                return { ...l, definitionTypeOptions: this.definitionPicklistOption };
            });
            if (!this.recordId) this.editClicked = true;

            this.isDataFetched = true;
            this.isLoading = false;
        } else if (error) {
            this.showToast('Error', error.body.message, 'error');
            this.isDataFetched = true;
            this.isLoading = false;
        }
    }

    get columns() {
        if (!this.editClicked && COLUMNS.filter((c) => c.fieldName == 'delete').length) {
            COLUMNS.pop();
        }

        return COLUMNS.map((col) => {
            return { ...col, editable: !this.showEditButton };
        });
    }

    get mechanismOptions() {
        return MECHANISM_OPTIONS;
    }

    get gradingTypeOptions() {
        return TYPE_OPTIONS;
    }

    get showEditButton() {
        return !this.editClicked;
    }

    handleAddRow() {
        const counter = this.letterGradeSetting.gradeRanges.length + 1;
        const newRow = {
            Id: counter,
            rangeStart: '',
            rangeEnd: '',
            letterGrade: '',
            gradePoint: '',
            definitionTypeOptions: this.definitionPicklistOption,
        };

        this.letterGradeSetting.gradeRanges = [...this.letterGradeSetting.gradeRanges, newRow];
    }

    handleCellChange({ detail }) {
        const editedRecordId = detail.draftValues[0].Id;
        this.validationError = { };

        if (this.validateInputValues(detail.draftValues[0])) return;

        this.letterGradeSetting.gradeRanges = this.letterGradeSetting.gradeRanges.map((item) =>
            item.Id == editedRecordId ? { ...item, ...detail.draftValues[0] } : item
        );
    }

    handleDelete(row) {
        const rowIndex = this.letterGradeSetting.gradeRanges.findIndex((item) => item.Id === row.Id);

        if (rowIndex === -1) return;

        const updatedGradeRanges = [...this.letterGradeSetting.gradeRanges];
        updatedGradeRanges.splice(rowIndex, 1);

        this.letterGradeSetting = {
            ...this.letterGradeSetting,
            gradeRanges: updatedGradeRanges,
        };
    }

    handleEditButton() {
        this.editClicked = true;
        COLUMNS.push(DELETE_COLUMN);
    }

    handleMechanismChange({ detail }) {
        this.letterGradeSetting.mechanism = detail.value;
    }

    handleTypeChange({ detail }) {
        this.letterGradeSetting.recordType = detail.value;
    }

    handleActiveChange({ detail }) {
        this.letterGradeSetting.isActive = detail.checked;
        this.isActiveChanged = !this.isActiveChanged;
    }

    handleRowAction({ detail }) {
        const actionName = detail.action.name;
        const row = detail.row;

        if (actionName === 'delete') {
            this.handleDelete(row);
        }
    }

    handleSettingNameChange({ detail }) {
        this.letterGradeSetting.name = detail.value;
    }

    async handleSaveData() {
        let result = true;

        if (!this.isValid()) return;

        if (
            this.letterGradeSetting.recordType === 'Master' &&
            ((!this.letterGradeSetting?.Id && this.letterGradeSetting.isActive) ||
                (this.isActiveChanged && this.letterGradeSetting.isActive))
        ) {
            result = await LightningConfirm.open({
                message:
                    'Do you want to activate this Letter Grade Setting? This action will deactivate other Letter Grade Settings with the same Mechanism.',
                variant: 'header',
                theme: 'warning',
                label: 'Activate Letter Grade Setting',
            });
        }

        if(!result) return;

        this.isLoading = true;

        this.letterGradeSetting.gradeRanges.forEach((g) => {
            if (g.Id.length < 15) delete g.Id;
        });

        try {
            if (
                this.letterGradeSetting.recordType === 'Master' &&
                this.isActiveChanged &&
                !this.letterGradeSetting.isActive &&
                this.letterGradeSetting?.Id
            ) {
                let noActiveRecord = await noActiveLetterGradeSetting({
                    settingId: this.letterGradeSetting.Id,
                    mechanism: this.letterGradeSetting.mechanism,
                });
                if (noActiveRecord ) {
                    this.showToast('Error', 'There should be atleast one Master letter grade setting active', 'error');
                    return;
                }
            }
            await saveLetterGradeSettings({
                letterGradeSetting: JSON.stringify(this.letterGradeSetting),
            });

            this.showToast('Success', 'Letter Grade Setting saved successfully!!', 'success');
            refreshApex(this.letterGradeOriginal);

            this.editClicked = false;
        } catch ({ body }) {
            this.showToast('Error', body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.editClicked = false;
        this.isActiveChanged = false;
        this.validationError = {};
    
        this.letterGradeSetting = JSON.parse(JSON.stringify(this.letterGradeOriginal));
        
        refreshApex(this.letterGradeOriginal);
    }

    validateInputValues(recordDetail) {
        if (recordDetail?.letterGrade && this.regex.test(recordDetail.letterGrade)) {
            this.addRowError(recordDetail, 'letterGrade', 'Letter grade cannot have number value');
            return false;
        }else if(recordDetail?.gradePoint && !this.numberRegex.test(recordDetail.gradePoint)) {
            this.addRowError(recordDetail, 'gradePoint', 'Grade point can only be number');
            return false;
        }else if(recordDetail?.rangeStart && !this.numberRegex.test(recordDetail.rangeStart)) {
            this.addRowError(recordDetail, 'rangeStart','Range Start can only be number');
            return false;
        }else if(recordDetail?.rangeEnd && !this.numberRegex.test(recordDetail.rangeEnd) ) {
            this.addRowError(recordDetail, 'rangeEnd','Range End can only be number');
            return false;
        }
    }

    addRowError(recordDetail, fieldName, message) {
        let rowErrorMessages = [];
        let rowErrorFieldNames = [];
        let rowsError = {};
        rowErrorMessages.push(message);
        rowErrorFieldNames.push(fieldName);

        rowsError[recordDetail.Id] = {
            messages: rowErrorMessages,
            fieldNames: rowErrorFieldNames,
            title: 'We found 1 error.',
        };

        this.validationError = {...this.validationError,
            rows: rowsError
        };

    }

    checkIsNullValue(value) {
        if (value === undefined || value === null || value === '') {
            return true;
        }
        return false;
    }

    isValid() {
        const isValid = [...this.template.querySelectorAll('lightning-input, lightning-combobox')].reduce(
            (validSoFar, inputField) => {
                inputField.reportValidity();
                return validSoFar && inputField.checkValidity();
            },
            true
        );

        let validate = this.validateScores();
        if (validate.invalid) {
            this.showToast('Error!', validate.message, 'error');
        }else if(
            Object.keys(this.validationError).length != 0
        ){
            this.showToast('Error!', 'Please enter Valid Values', 'error');
            return false;
        }

        return isValid && !validate.invalid;
    }

    validateScores() {
        let errorDetails = {
            message: '',
            invalid: false,
        };
        for (let i = 0; i < this.letterGradeSetting.gradeRanges.length; i++) {
            this.letterGradeSetting.gradeRanges[i].errorCls = '';
            let givenRange = this.letterGradeSetting.gradeRanges[i];
            if (this.letterGradeSetting.gradeRanges) {
                if (
                    this.checkIsNullValue(givenRange.gradePoint) ||
                    this.checkIsNullValue(givenRange.letterGrade) ||
                    this.checkIsNullValue(givenRange.rangeStart) ||
                    this.checkIsNullValue(givenRange.rangeEnd) ||
                    this.checkIsNullValue(givenRange.definition)
                ) {
                    errorDetails.message =
                        'Start Range, End Range, Letter Grade, Grade Point and Definition is required';
                    errorDetails.invalid = true;
                } else if (parseInt(givenRange.rangeStart) > 100 || parseInt(givenRange.rangeEnd) > 100) {
                    errorDetails.message = 'Start or End Range cannot be greater than 100';
                    errorDetails.invalid = true;
                } else if (parseInt(givenRange.rangeStart) > parseInt(givenRange.rangeEnd)) {
                    errorDetails.message = 'Start Range cannot be greater than End Range';
                    errorDetails.invalid = true;
                }

                if (errorDetails.invalid) return errorDetails;

                for (let j = 0; j < this.letterGradeSetting.gradeRanges.length; j++) {
                    if (i != j) {
                        let inputRange = this.letterGradeSetting.gradeRanges[j];
                        if (
                            (parseFloat(inputRange.rangeStart) <= parseFloat(givenRange.rangeStart) &&
                                parseFloat(givenRange.rangeStart) <= parseFloat(inputRange.rangeEnd)) ||
                            (parseFloat(inputRange.rangeStart) <= parseFloat(givenRange.rangeEnd) &&
                                parseFloat(givenRange.rangeEnd) <= parseFloat(inputRange.rangeEnd))
                        ) {
                            errorDetails.invalid = true;
                            this.letterGradeSetting.gradeRanges[i].errorCls = 'errorCls';
                            errorDetails.message = 'Duplicate range found';
                        } else if (inputRange.letterGrade == givenRange.letterGrade) {
                            errorDetails.invalid = true;
                            this.letterGradeSetting.gradeRanges[i].errorCls = 'errorCls';
                            errorDetails.message = 'Duplicate letter grade found';
                        } else if (inputRange.gradePoint == givenRange.gradePoint) {
                            errorDetails.invalid = true;
                            this.letterGradeSetting.gradeRanges[i].errorCls = 'errorCls';
                            errorDetails.message = 'Duplicate grade point found';
                        }
                    }
                }
            }
        }
        return errorDetails;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
            })
        );
    }
    handleSort(event) {
    const { fieldName: sortedBy, sortDirection } = event.detail;

    this.sortedBy = sortedBy;
    this.sortedDirection = sortDirection;

    const data = [...(this.letterGradeSetting.gradeRanges || [])];
    data.sort(this.sortBy(sortedBy, sortDirection));

    // reassign to trigger re-render
    this.letterGradeSetting = {
        ...this.letterGradeSetting,
        gradeRanges: data
    };
    }

    sortBy(field, direction) {
    const isAsc = direction === 'asc';

    return (a, b) => {
        const aVal = a?.[field];
        const bVal = b?.[field];

        // Numeric sort for gradePoint/rangeStart/rangeEnd (and safe fallback)
        const numFields = new Set(['gradePoint', 'rangeStart', 'rangeEnd']);
        if (numFields.has(field)) {
        const aNum = aVal === '' || aVal === null || aVal === undefined ? Number.NEGATIVE_INFINITY : Number(aVal);
        const bNum = bVal === '' || bVal === null || bVal === undefined ? Number.NEGATIVE_INFINITY : Number(bVal);

        return isAsc ? aNum - bNum : bNum - aNum;
        }

        // String sort fallback
        const aStr = (aVal ?? '').toString().toLowerCase();
        const bStr = (bVal ?? '').toString().toLowerCase();

        if (aStr === bStr) return 0;
        return isAsc ? (aStr > bStr ? 1 : -1) : (aStr < bStr ? 1 : -1);
    };
    }

}