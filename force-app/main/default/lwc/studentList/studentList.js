import { LightningElement, api, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import COURSE_ENROLMENT from '@salesforce/schema/hed__Course_Enrollment__c';
import REASON_FIELD from '@salesforce/schema/hed__Course_Enrollment__c.Reason_for_Grade__c';
import OVERRIDE_GRADE_FIELD from '@salesforce/schema/hed__Course_Enrollment__c.Override_Grade__c';
import getEvaluationComponents from '@salesforce/apex/GradeDistrubutionUtils.getEvaluationComponents';
import getEvaluationSubComponents from '@salesforce/apex/GradeDistrubutionUtils.getEvaluationSubComponents';
import saveMinimumPassingScore from '@salesforce/apex/GradeDistrubutionController.saveMinimumPassingScore';
import { COLUMNS } from './constants';
import saveStudentGrade from '@salesforce/apex/GradeDistrubutionController.saveStudentGrade';
import getGradeSettingCounts from '@salesforce/apex/GradeDistrubutionController.getGradeSettingCounts';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

export default class StudentList extends LightningElement {
    isLoading = false;
    sortedBy = null;
    sortedDirection = null;
    minimumPassingScore = 0;  
    channelName = '/event/Letter_Grade_Change__e';
    subscription = null;
    isSubscribing = false;

    columns = COLUMNS;
    regex = /\d/;
    validationError = {};

    @track tableData = [];
    @track courseOfferingId;
    finalExamComponentName = null;

    subComponentNames = [];
    overridePicklistOptions = [];
    reasonPicklistOptions = [];

    componentsLoaded = false;
    subComponentsLoaded = false;
    evaluationComponents = [];
    evaluationSubComponents = [];

    // Maps for subcomponents
    subComponentIdToName = {};      // subcomponentId -> name
    subComponentIdsByName = {};     // name -> [subcomponentIds]
    subComponentNames = [];

    @api
    get childProperty() {
        return this.tableData;
    }
    set childProperty(value) {
        if (!value) return;
        this.setTableData(value);
    }

    @wire(getObjectInfo, { objectApiName: COURSE_ENROLMENT })
    enrolmentInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$enrolmentInfo.data.defaultRecordTypeId',
        fieldApiName: REASON_FIELD
    })
    wiredReasonPicklist({ data, error }) {
        if (data) {
            this.reasonPicklistOptions = data.values;
            this.applyPicklistOptionsToRows();
        }
        if (error) {
            console.error(error);
        }
    }

    @wire(getPicklistValues, {
        recordTypeId: '$enrolmentInfo.data.defaultRecordTypeId',
        fieldApiName: OVERRIDE_GRADE_FIELD
    })
    wiredOverridePicklist({ data, error }) {
        if (data) {
            this.overridePicklistOptions = data.values;
            this.applyPicklistOptionsToRows();
        }
        if (error) {
            console.error(error);
        }
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    registerErrorListener() {
        onError(error => {
            if (this.subscription) {
                unsubscribe(this.subscription);
                this.subscription = null;
            }
            setTimeout(() => {
                this.subscribeToLetterGradeChanges();
            }, 2000);
        });
    }

    connectedCallback() {
        this.registerErrorListener();
        this.subscribeToLetterGradeChanges();
    }

    @wire(getEvaluationComponents, { courseOfferingId: '$courseOfferingId' })
    wiredComponents({ data, error }) {
        if (data && data.length > 0) {
            this.evaluationComponents = data;
            this.componentsLoaded = true;
            this.rebuildColumns();
        } else if (error) {
            console.error('Error loading components:', error);
            this.columns = COLUMNS;
        }
    }

    @wire(getEvaluationSubComponents, { courseOfferingId: '$courseOfferingId' })
    wiredSubComponents({ data, error }) {
  console.log('wiredSubComponents data: ', JSON.stringify(data));
  console.log('wiredSubComponents error: ', JSON.stringify(error));

  if (data && data.length > 0) {
    this.evaluationSubComponents = data;
    this.subComponentIdToName = {};
    this.subComponentNames = [];

    data.forEach(sub => {
      // one column per NAME
      this.subComponentNames.push(sub.name);

      // map ALL ids for this name
      (sub.subcomponentIds || []).forEach(id => {
        this.subComponentIdToName[id] = sub.name;
      });
    });

    this.subComponentsLoaded = true;
    this.rebuildColumns();
    if (this.tableData && this.tableData.length > 0) {
      this.updateTableDataWithSubComponents();
    }
  } else if (data && data.length === 0) {
    this.subComponentsLoaded = true;
    this.rebuildColumns();
  } else if (error) {
    console.error('Error in wiredSubComponents:', error);
  }
}

    rebuildColumns() {
        let newColumns = [...COLUMNS];

        const rollNoIndex = newColumns.findIndex((col) => col.fieldName === 'rollNo');

        if (this.componentsLoaded && this.evaluationComponents.length > 0) {
            const dynamicCols = [];

            this.evaluationComponents
                .filter((comp) => comp.Name !== this.finalExamComponentName)
                .forEach((comp) => {
                    const safeFieldName = comp.Name.replace(/\s+/g, '_').replace(/[^\w]/g, '');
                    dynamicCols.push({
                        label: comp.Name,
                        fieldName: safeFieldName,
                        editable: false,
                        type: 'number',
                        cellAttributes: { alignment: 'left' }
                    });
                });

            if (this.subComponentsLoaded && this.subComponentNames.length > 0) {
                this.subComponentNames.forEach((name) => {
                    const safeName = name.replace(/\s+/g, '_').replace(/[^\w]/g, '');
                    dynamicCols.push({
                        label: name,
                        fieldName: safeName,
                        editable: false,
                        type: 'number',
                        cellAttributes: { alignment: 'left' }
                    });
                });
                console.log('Added subcomponent columns for:', this.subComponentNames);
            }

            if (rollNoIndex !== -1) {
                const part1 = newColumns.slice(0, rollNoIndex + 1);
                const part2 = newColumns.slice(rollNoIndex + 1);
                newColumns = [...part1, ...dynamicCols, ...part2];
            }
        }

        this.columns = newColumns;
    }

    updateTableDataWithSubComponents() {
        this.tableData = this.tableData.map((row) => {
            const updatedRow = { ...row };

            if (row.subComponents && Array.isArray(row.subComponents)) {
                console.log(`Student ${row.student} has ${row.subComponents.length} subcomponents:`,
                    JSON.parse(JSON.stringify(row.subComponents)));

                row.subComponents.forEach((sub) => {
                    const subComponentId = sub.componentName;              // Subcomponent Id per row
const displayName = this.subComponentIdToName[subComponentId];

if (
  this.finalExamComponentName &&
  sub.parentComponentName &&
  sub.parentComponentName.toLowerCase().trim() === this.finalExamComponentName.toLowerCase().trim() &&
  displayName
) {
  const safeName = displayName.replace(/\s+/g, '_').replace(/[^\w]/g, '');
  updatedRow[safeName] = sub.marksObtained;
}
                });
            }

            return updatedRow;
        });
    }

    applyPicklistOptionsToRows() {
        if (!this.tableData || this.tableData.length === 0) return;

        this.tableData = this.tableData.map(row => ({
            ...row,
            overridePicklistOption: this.overridePicklistOptions,
            definitionPicklistOption: this.reasonPicklistOptions
        }));

        this.forceTableUpdate();
    }

    handleCellChange(event) {
        const { draftValues } = event.detail;
        this.validationError = {};

        if (this.validateInputValues(event.detail.draftValues[0])) return;

        if (draftValues.length > 0) {
            const rowId = draftValues[0].Id;
            this.tableData = this.tableData.map((row) => {
                if (row.Id === rowId) {
                    return {
                        ...row,
                        ...draftValues[0],
                        finalGrade: draftValues[0].overrideGrade
                            ? draftValues[0].overrideGrade
                            : row.grade
                    };
                } else {
                    return row;
                }
            });
            this.applyThresholdHighlight();
        }
    }

    validateInputValues(recordDetails) {
        if (recordDetails?.overrideGrade && this.regex.test(recordDetails.overrideGrade)) {
            this.addRowError(recordDetails, 'overrideGrade', 'Grade cannot be a numeric value');
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
            title: 'We found 1 error.'
        };

        this.validationError = {
            rows: rowsError
        };
    }

    subscribeToLetterGradeChanges() {
        if (this.subscription || this.isSubscribing) {
            return;
        }

        this.isSubscribing = true;

        subscribe(this.channelName, -1, () => {
            this.refreshStudentList();
        })
            .then(response => {
                this.subscription = response;
                this.isSubscribing = false;
            })
            .catch(() => {
                this.isSubscribing = false;
            });
    }

    async refreshStudentList() {
        this.isLoading = true;

        const result = await getGradeSettingCounts({
            recordId: this.courseOfferingId
        });

        this.setTableData(result);

        this.isLoading = false;
    }

    async handleSaveButton() {
        try {
            this.isLoading = true;

            const selectedValues = this.tableData.map((item) => {
                return {
                    Id: item.Id,
                    comment: item.comment || undefined,
                    reasonForDownFall: item.reasonForDownFall || undefined,
                    overrideGrade:
                        item.overrideGrade !== null &&
                        item.overrideGrade !== undefined &&
                        item.overrideGrade !== ''
                            ? item.overrideGrade
                            : undefined
                };
            });

            const nonEmptyValues = selectedValues.filter(
                (value) => value.penalty || value.overrideGrade || value.comment
            );

            await saveStudentGrade({ value: JSON.stringify(nonEmptyValues) });
            this.dispatchEvent(new CustomEvent('refresh'));
            this.showSuccessToast('Data Saved Successfully');
        } catch (error) {
            this.showErrorToast('An error occurred while saving data');
            console.error(error);
        } finally {
            this.isLoading = false;
        }
    }

    setTableData(value) {
        this.courseOfferingId = value.courseDetail?.Id;
        this.minimumPassingScore = Number(value.courseDetail?.minimumPassingScore) || 0;
        this.finalExamComponentName = value.courseDetail?.finalExamComponentName;

        this.tableData = value.enrolments.map((item) => {
            const row = {
                Id: item?.id,
                courseConnectionName: item?.courseConnectionName,
                courseConnectionUrl: `/lightning/r/hed__Course_Enrollment__c/${item?.id}/view`,
                student: item?.Name,
                rollNo: item?.registrationNumber,
                totalMark: 100,
                markObtained: item?.componentFinalScore,
                grade: item?.grade,
                comment: item?.comments,
                reasonForDownFall: item?.reasonForgrade,
                overrideGrade: item?.overgrade,
                finalGrade: item?.overgrade ? item.overgrade : item?.grade,
                subComponents: item?.subComponents || [],
                definitionPicklistOption: this.reasonPicklistOptions,
                overridePicklistOption: this.overridePicklistOptions
            };

            if (item?.componentScores && Array.isArray(item.componentScores)) {
                item.componentScores.forEach((compScore) => {
                    if (
                        compScore.componentName &&
                        compScore.marksObtained !== null &&
                        compScore.marksObtained !== undefined
                    ) {
                        const safeFieldName = compScore.componentName
                            .replace(/\s+/g, '_')
                            .replace(/[^\w]/g, '');
                        row[safeFieldName] = compScore.marksObtained;
                    }
                });
            }

            if (item.subComponents && Array.isArray(item.subComponents)) {
                console.log(`Student "${item.Name}" subComponents from data:`,
                    JSON.parse(JSON.stringify(item.subComponents)));

                item.subComponents.forEach((sub) => {
                    const subComponentId = sub.componentName;
                    const displayName = this.subComponentIdToName[subComponentId];

                    if (
                        this.finalExamComponentName &&
                        sub.parentComponentName &&
                        sub.parentComponentName.toLowerCase().trim() === this.finalExamComponentName.toLowerCase().trim() &&
                        displayName
                    ) {
                        const safeName = displayName.replace(/\s+/g, '_').replace(/[^\w]/g, '');
                        row[safeName] = sub.marksObtained;
                    }
                });
            }

            return row;
        });

        if (this.componentsLoaded || this.subComponentsLoaded) {
            this.rebuildColumns();
        }

        this.applyThresholdHighlight();
    }

    showSuccessToast(message) {
        const evt = new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        });
        this.dispatchEvent(evt);
    }

    showErrorToast(message) {
        const evt = new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error'
        });
        this.dispatchEvent(evt);
    }

    handleSort(event) {
        const field = event.detail.fieldName;
        const direction = event.detail.sortDirection;

        this.sortedBy = field;
        this.sortedDirection = direction;

        let sortedResult = [...this.tableData];
        sortedResult.sort((a, b) => {
            let val1 = a[field] || '';
            let val2 = b[field] || '';

            if (!isNaN(val1) && !isNaN(val2)) {
                val1 = Number(val1);
                val2 = Number(val2);
            }

            if (typeof val1 === 'string' && typeof val2 === 'string') {
                return direction === 'asc' ? val1.localeCompare(val2) : val2.localeCompare(val1);
            }

            return direction === 'asc' ? val1 - val2 : val2 - val1;
        });

        this.tableData = sortedResult;
        this.applyThresholdHighlight();
    }

    handleThresholdChange(event) {
        this.minimumPassingScore = Number(event.target.value) || 0;
        this.applyThresholdHighlight();
    }

    handleThresholdSave() {
        saveMinimumPassingScore({
            courseOfferingId: this.courseOfferingId,
            score: String(this.minimumPassingScore)
        })
            .then(() => {
                this.applyThresholdHighlight();
                this.showSuccessToast('Minimum Passing Score Saved');
            })
            .catch(() => {
                this.showErrorToast('Failed to save score');
            });
    }

    applyThresholdHighlight() {
        if (!this.tableData || this.tableData.length === 0) {
            return;
        }

        const threshold = Number(this.minimumPassingScore) || 0;

        this.tableData = this.tableData.map((row) => {
            let shouldHighlight = false;

            let compositeScore = Number(row.markObtained);
            if (!isNaN(compositeScore) && compositeScore <= threshold) {
                shouldHighlight = true;
            }

            if (this.subComponentNames && this.subComponentNames.length > 0) {
                this.subComponentNames.forEach((subName) => {
                    const safeName = subName.replace(/\s+/g, '_').replace(/[^\w]/g, '');
                    const subScore = row[safeName];

                    if (subScore !== null && subScore !== undefined && !isNaN(subScore)) {
                        const scoreNum = Number(subScore);
                        if (scoreNum <= threshold) {
                            shouldHighlight = true;
                        }
                    }
                });
            }

            return {
                ...row,
                _rowClass: shouldHighlight ? 'highlight-row' : ''
            };
        });

        this.forceTableUpdate();
    }

    forceTableUpdate() {
        const datatable = this.template.querySelector('c-custom-letter-grade-datatable');
        if (datatable) {
            const tempData = [...this.tableData];
            this.tableData = [];
            Promise.resolve().then(() => {
                this.tableData = tempData;
            });
        }
    }
}