import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { COLUMNS } from './constants';
import saveGradeSetting from '@salesforce/apex/GradeDistrubutionController.saveGradeSetting';

export default class GradeSetting extends LightningElement {
    @track _childProperty;
    sortedBy = null;
    sortedDirection = null;
    @api
    get childProperty() {
        console.log('1...');
        return this._childProperty;
    }
    set childProperty(value) {
        console.log('2...', value);
        if (!value) return;
        console.log('12', value);
        this._childProperty = value;
        this.result = value;
        console.log('3...',this.result);
        this.setTableData(value);
    }

    isLoading = true;
    isEdited = false;
    numberRegex = /^-?\d+(\.\d+)?$/;
    @track tableData = []; 
    result;
    table1Columns = COLUMNS;
    validationError = {};
    modifiedData = [];

    
    showPreviewModal = false;
    @track previewChartData = null; 



    async handleCellChange(event) {
        this.isEdited = true;
        const { draftValues } = event.detail;
        this.validationError = {};

        if (draftValues.length > 0 && this.validateInputValues(draftValues[0])) {
            
            return;
        }

        if (draftValues.length > 0) {
            const rowId = draftValues[0].Id;
            const editedRow = this.tableData.find(row => row.Id === rowId);
            const oldRangeStart = editedRow ? editedRow.rangeStart : null;
            const newRangeStart = draftValues[0].rangeStart;
            const percentile=draftValues[0].percentile;

            
            if (newRangeStart !== undefined && newRangeStart !== oldRangeStart && this.numberRegex.test(newRangeStart)) {
                const numericStart = parseFloat(newRangeStart);

                const sortedRows = [...this.tableData].sort((a, b) => {
                    const aStart = parseFloat(a.rangeStart) || 0; 
                    const bStart = parseFloat(b.rangeStart) || 0;
                    return bStart - aStart; 
                });

                const currentIndex = sortedRows.findIndex(r => r.Id === rowId);
                const prevRow = sortedRows[currentIndex + 1]; 

                if (prevRow && prevRow.letterGrade !== 'F') {
                    const prevRowIndex = this.tableData.findIndex(r => r.Id === prevRow.Id);
                    if (prevRowIndex !== -1) {
                        this.tableData = this.tableData.map((row, index) => {
                            if (index === prevRowIndex && row.letterGrade !== 'F') {
                                return { ...row, rangeEnd: (numericStart - 0.01).toFixed(2) };
                            }
                            return row;
                        });
                    }
                }

            }

            
            this.tableData = this.tableData.map((row) => {
                if (row.Id === rowId) {
                    return { ...row, ...draftValues[0] };
                } else {
                    return row;
                }
            });
        }
    }

    async setTableData(value) {
    this.isLoading = true;

    try {
        this.tableData = [];

        if (value && Array.isArray(value.gradeRanges)) {
            this.tableData = value.gradeRanges.map(item => ({
                Id: item?.Id,
                letterGrade: item?.grade ?? '',
                percentile: item?.percentile ?? '',
                rangeStart:
                    item?.rangeStart !== undefined && item?.rangeStart !== null
                        ? String(item.rangeStart)
                        : '',
                rangeEnd:
                    item?.rangeEnd !== undefined && item?.rangeEnd !== null
                        ? String(item.rangeEnd)
                        : '',
                letterGradeSettingName: item?.letterGradeSettingName ?? '',
                letterGradeSettingMechanism: item?.letterGradeSettingMechanism ?? '',
                recordType: item?.recordType ?? ''
            }));
        }

        console.log("Processed tableData:", this.tableData);

        let mechanism = value?.gradeRanges?.[0]?.letterGradeSettingMechanism;
        console.log("Mechanism:", mechanism);

        let cols = [...COLUMNS];

        if (mechanism === "Absolute") {
            cols = cols.filter(col => col.fieldName !== "percentile");
        }

        this.table1Columns = [...cols];
        console.log("Updated table1Columns:", this.table1Columns);

    } catch (error) {
        console.error("Error setting table:", error);
        this.tableData = [];
        this.table1Columns = [...COLUMNS];
    } finally {
        this.isLoading = false;
    }
}


    validateInputValues(recordDetails) {
        if (recordDetails?.rangeStart && !this.numberRegex.test(recordDetails.rangeStart)) {
            console.log('Start Rage Error');
            this.addRowError(recordDetails, 'rangeStart', 'Range Start cannot be a String value');
            return false;
        } else if (recordDetails?.rangeEnd && !this.numberRegex.test(recordDetails.rangeEnd)) {
            this.addRowError(recordDetails, 'rangeEnd', 'Range End cannot be a String value');
            return false;
        }
    }



    
    handlePreviewChart() {
        console.log('Preview Chart button clicked');
        
        if (!this.tableData || !Array.isArray(this.tableData) || this.tableData.length === 0) {
             this.showErrorToast('No grade data available to preview.');
             return;
        }
        
        try {
           
            this.previewChartData = this.generatePreviewData(this.tableData); 
            console.log('Preview Chart Data Generated:', JSON.stringify(this.previewChartData, null, 2));
            this.showPreviewModal = true;
        } catch (error) {
            console.error('Error generating preview data:', error);
            this.showErrorToast('Failed to generate preview data.');
            this.previewChartData = null; 
        }
    }

    
    closePreviewModal() {
        this.showPreviewModal = false;
        
    }

    
    generatePreviewData(currentTableData) {
    console.log('Generating preview data using currentTableData:', JSON.stringify(currentTableData, null, 2));
    console.log('Using enrolment data from this.result:', this.result?.enrolments);

    const enrolments = this.result?.enrolments || [];
    if (enrolments.length === 0) {
        console.warn('No enrolment data found for preview.');
        return []; 
    }

    const gradeOrder = ['A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'C-', 'D', 'F'];
    const gradeCounts = gradeOrder.reduce((acc, grade) => {
        acc[grade] = 0; 
        return acc;
    }, {});

    let totalValidEnrolments = 0; 

    for (const enrolment of enrolments) {
        const scoreStr = enrolment.componentFinalScore;
       
        if (scoreStr == null || scoreStr === '') {
            console.warn(`Skipping enrolment with null/empty score:`, enrolment);
            continue; 
        }

        const score = parseFloat(scoreStr);
       
        if (isNaN(score)) {
            console.warn(`Skipping enrolment with invalid score '${scoreStr}':`, enrolment);
            continue;
        }

        let assignedGrade = 'F'; 
        let matched = false; 

        
        const sortedCurrentTableData = [...currentTableData].sort((a, b) => {
            const aStart = parseFloat(a.rangeStart);
            const bStart = parseFloat(b.rangeStart);
            
            if (isNaN(aStart)) return 1; 
            if (isNaN(bStart)) return -1;
            return bStart - aStart; 
        });

        for (const range of sortedCurrentTableData) {
           
            const rangeStartStr = String(range.rangeStart ?? '').trim();
            const rangeEndStr = String(range.rangeEnd ?? '').trim();
            const letterGrade = range.letterGrade?.trim();

            
            if (!letterGrade ||
                rangeStartStr === '' || rangeEndStr === '' ||
                !this.numberRegex.test(rangeStartStr) || !this.numberRegex.test(rangeEndStr)) {
                console.warn(`Skipping invalid or incomplete draft range row:`, range);
                continue;
            }

            const rangeStart = parseFloat(rangeStartStr);
            const rangeEnd = parseFloat(rangeEndStr);

            
            if (isNaN(rangeStart) || isNaN(rangeEnd)) {
                console.warn(`Skipping range with NaN values after parsing:`, range);
                continue;
            }

            if (score >= rangeStart && score <= rangeEnd) {
                assignedGrade = letterGrade;
                matched = true;
                console.log(`Assigned score ${score} to grade ${assignedGrade} using range: ${rangeStart} - ${rangeEnd}`);
                break; 
            }
        }
        gradeCounts[assignedGrade]++;
        totalValidEnrolments++;
    }

    if (totalValidEnrolments === 0) {
        console.warn('No valid enrolment scores found to process for preview.');
        return []; 
    }

    console.log('Final grade counts for preview (before filtering):', gradeCounts);
    console.log('Total valid enrolments processed:', totalValidEnrolments);

    const previewDataArray = gradeOrder.map(key => {
        const count = gradeCounts[key];
        const percentage = ((count / totalValidEnrolments) * 100).toFixed(2);
        return {
            key,      
            count,    
            percentage 
        };
    })
    .filter(item => item.count > 0); 

    console.log('Final preview data array (filtered):', previewDataArray);
    return previewDataArray; 
}


     async handleSaveData() {
        try {

            if (this.isEdited ===  false){
                this.showErrorToast('No Changes Found');
                return
            }

            this.isLoading = true;

            const parentValue = {
                Id: this.result?.gradeRanges[0]?.letterGradeId, // Assuming all IDs are the same for parent values
                letterGradeSettingName: this.tableData[0].letterGradeSettingName,
                letterGradeSettingMechanism: this.tableData[0].letterGradeSettingMechanism,
                recordType: this.tableData[0].recordType,
                courseOfferingId: this.result?.courseDetail?.Id,
                courseOfferingName : this.result?.courseDetail?.courseOfferingName
            };

            const letterGrades = this.tableData.map((item) => ({
                Id: item.Id,
                rangeStart: item.rangeStart || undefined,
                rangeEnd: item.rangeEnd || undefined,
                grade: item.letterGrade,
                percentile: item.percentile
            }));

            if (!this.isValid()) return;

            const nonEmptyValues = letterGrades.filter((value) => value.rangeStart || value.rangeEnd ||value.percentile);
            const finalPayload = {
                ...parentValue,
                nonEmptyValues,
            };
            console.log(finalPayload)

            await saveGradeSetting({ value: JSON.stringify(finalPayload) });

            this.dispatchEvent(new CustomEvent('refresh'));

            this.showSuccessToast('Data Saved Successfully');
            this.isLoading = false;
        } catch (error) {
            console.log(error);
            this.showErrorToast('An error occurred while saving data');
            this.isLoading = false;
        }
    }


    isValid() {
        let validate = this.validateScores();
        if (validate.invalid) {
            this.showErrorToast(validate.message);
            this.isLoading = false;
        } else if (Object.keys(this.validationError).length !== 0) {
            this.showErrorToast('Please enter Valid Values');
            this.isLoading = false;
            return false;
        }

        return !validate.invalid;
    }


     validateScores() {
        let errorDetails = {
            message: '',
            invalid: false,
        };
        for (let i = 0; i < this.tableData.length; i++) {
            this.tableData[i].errorCls = '';
            let givenRange = this.tableData[i];
            if (this.tableData) {
                console.log(givenRange);
                if (this.checkIsNullValue(givenRange.rangeStart) || this.checkIsNullValue(givenRange.rangeEnd)) {
                    errorDetails.message = 'Start Range, End Range is required';
                    errorDetails.invalid = true;
                } else if (parseInt(givenRange.rangeStart) > 100 || parseInt(givenRange.rangeEnd) > 100) {
                    errorDetails.message = 'Start or End Range cannot be greater than 100';
                    errorDetails.invalid = true;
                } else if (parseInt(givenRange.rangeStart) > parseInt(givenRange.rangeEnd)) {
                    errorDetails.message = 'Start Range cannot be greater than End Range';
                    errorDetails.invalid = true;
                }

                if (errorDetails.invalid) return errorDetails;

                for (let j = 0; j < this.tableData.length; j++) {
                    if (i !== j) {
                        let inputRange = this.tableData[j];
                        if (
                            (parseFloat(inputRange.rangeStart) <= parseFloat(givenRange.rangeStart) &&
                                parseFloat(givenRange.rangeStart) <= parseFloat(inputRange.rangeEnd)) ||
                            (parseFloat(inputRange.rangeStart) <= parseFloat(givenRange.rangeEnd) &&
                                parseFloat(givenRange.rangeEnd) <= parseFloat(inputRange.rangeEnd))
                        ) {
                            errorDetails.invalid = true;
                            this.tableData[i].errorCls = 'errorCls';
                            errorDetails.message = 'Duplicate range found';
                        } else if (inputRange.rangeStart === givenRange.rangeStart) {
                            errorDetails.invalid = true;
                            this.tableData[i].errorCls = 'errorCls';
                            errorDetails.message = 'Duplicate grade range found';
                        } else if (inputRange.rangeEnd === givenRange.rangeEnd) {
                            errorDetails.invalid = true;
                            this.tableData[i].errorCls = 'errorCls';
                            errorDetails.message = 'Duplicate grade range found';
                        }
                    }
                }
            }
        }
        return errorDetails;
    }


    checkIsNullValue(value) {
        if (value === undefined || value === null || value === '') {
            return true;
        }
        return false;
    }


    showSuccessToast(message) {
        const evt = new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success',
        });
        this.dispatchEvent(evt);
    }

    showErrorToast(message) {
        const evt = new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error',
        });
        this.dispatchEvent(evt);
    }
    handleSort(event) {
    const fieldName = event.detail.fieldName;
    const sortDirection = event.detail.sortDirection;

    this.sortedBy = fieldName;
    this.sortedDirection = sortDirection;

   
    let sortedData = [...this.tableData];

    sortedData.sort((a, b) => {
        let val1 = a[fieldName];
        let val2 = b[fieldName];

        
         if (['rangeStart', 'rangeEnd', 'percentile'].includes(fieldName)){
            val1 = Number(val1);
            val2 = Number(val2);
        }

       
        if (typeof val1 === "string" && typeof val2 === "string") {
            return sortDirection === "asc"
                ? val1.localeCompare(val2)
                : val2.localeCompare(val1);
        }

       
        return sortDirection === 'asc' ? val1 - val2 : val2 - val1;
    });

   
    this.tableData = sortedData;
}
 isPrint = false;

  connectedCallback() {
    this._beforePrint = () => (this.isPrint = true);
    this._afterPrint = () => (this.isPrint = false);

    window.addEventListener("beforeprint", this._beforePrint);
    window.addEventListener("afterprint", this._afterPrint);
  }

  disconnectedCallback() {
    window.removeEventListener("beforeprint", this._beforePrint);
    window.removeEventListener("afterprint", this._afterPrint);
  }
  // after you set table1Columns and tableData
printColumns = [];
printRows = [];

// whenever table data/columns change, call this
buildPrintData() {
    this.printColumns = this.table1Columns.map(c => ({
        label: c.label,
        fieldName: c.fieldName
    }));

    this.printRows = this.tableData.map(row => {
        return {
            id: row.Id || row.id,
            cells: this.printColumns.map(col => ({
                fieldName: col.fieldName,
                value: row[col.fieldName]   // ✅ computed access allowed in JS
            }))
        };
    });
}

}