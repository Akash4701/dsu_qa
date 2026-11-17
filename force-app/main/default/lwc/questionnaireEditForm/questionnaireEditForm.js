import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getRecord } from 'lightning/uiRecordApi';
import getQuestionnaireWithQuestions from '@salesforce/apex/QuestionnaireControllerClass.getQuestionnaireWithQuestions';
import saveQuestionnaireWithQuestions from '@salesforce/apex/QuestionnaireControllerClass.saveQuestionnaireWithQuestions2';
import saveQuestionnaireWithRelatedRecord from '@salesforce/apex/QuestionnaireControllerClass.saveQuestionnaireWithQuestions';
const FIELDS = ['Id'];

export default class QuestionnaireEditForm extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    questionnaireId;
    @track placeholder = '';

    @track questionnaire = {
        title: '',
        description: '',
        targetAudience: ''
    };

    @track selectedValues = '';

    @track parentOptions = [
        { label: 'Alumni', value: 'Alumni', show: true, checked: false },
        { label: 'Student', value: 'Student', show: true, checked: false },
        { label: 'All', value: 'All', show: true, checked: false }
    ];

    @track questions = [];
    @track groupedQuestions = [];

    questionTypeOptions = [
        { label: 'Short Answer', value: 'Short Answer' },
        { label: 'Rating', value: 'Rating' },
        { label: 'Multiple Choice', value: 'Multiple Choice' },
        { label: 'Dropdown', value: 'Dropdown' },
        { label: 'Comment', value: 'Comment' },
        { label: 'Yes/No', value: 'Yes/No' },
        { label: 'File Upload', value: 'File Upload' },
        { label: 'Linear Scale', value: 'Linear Scale' }
    ];

    showSpinner = false;


    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.objectApiName = data.apiName;
            console.log('this.objectApiName', this.objectApiName);
            if (this.objectApiName === 'Alm_Questionnaire__c') {
                this.fetchQuestionnaireWithQuestions();
            }
        } else if (error) {
            console.error('Error retrieving object info: ', error);
        }
    }


    fetchQuestionnaireWithQuestions() {
        this.showSpinner = true;
        getQuestionnaireWithQuestions({ questionnaireId: this.recordId })
            .then(data => {
                if (data) {
                    this.questionnaire = {
                        title: data.Section_Name__c,
                        description: data.Descripation__c,
                        targetAudience: data.Target_Audience__c
                    };

                    this.placeholder = data.Target_Audience__c;
                    let targetAudience2 = data.Target_Audience__c.split(';');
                    this.parentOptions.forEach(option => {
                        if (targetAudience2.includes(option.value)) {
                            option.checked = true;
                        } else {
                            option.checked = false;
                        }
                    });
                    if (data && data.Alm_Questionnaire_Parameters__r) {
                        this.questions = data.Alm_Questionnaire_Parameters__r.map((question, index) => ({
                            id: index + 1,
                            Id: question.Id,
                            label: question.Question_Label__c,
                            type: question.Question_Type__c,
                            isRequired: question.Is_Required__c,
                            options: question.MCQ_Options__c,
                            section: question.Section_Name__c,
                            sectionHeader: question.Section_Header__c,
                            isMCQ: question.Question_Type__c === 'Multiple Choice' || question.Question_Type__c === 'Dropdown'
                        }));

                        if (this.questions.length > 0) {
                            this.groupQuestionsBySection(this.questions);
                            this.updateSectionHeaderDisabledStatus(null);
                        }
                    }
                } else {
                    this.questions = [];
                    this.groupedQuestions = [];
                }
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
            }).finally(() => {
                this.showSpinner = false;
            });
    }


    handleInputChange(event) {
        const field = event.target.dataset.id;
        this.questionnaire[field] = event.target.value;
    }

    handleSelection(event) {
        this.selectedValues = event.detail;

        this.questionnaire.targetAudience = this.selectedValues;
        console.log('Selected values:', this.selectedValues);
    }

    handleSectionNameChange(event) {
        const sectionId = event.target.dataset.sectionid;
        const section = this.groupedQuestions.find(sec => sec.sectionId === sectionId);
        if (section) {
            section.sectionName = event.target.value;
            this.groupedQuestions = [...this.groupedQuestions];
        }
    }

    handleQuestionChange(event) {
        const sectionId = event.target.dataset.sectionid;
        const section = this.groupedQuestions.find(sec => sec.sectionId === sectionId);
        const questionId = event.target.dataset.questionid;
        const questionIndex = section.questions.findIndex(q => q.id == questionId);
        const fieldName = event.target.dataset.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        if (fieldName === 'sectionHeader') {
            section.questions[questionIndex][fieldName] = value;
            // Update disabled status for all checkboxes in this section
            this.updateSectionHeaderDisabledStatus(sectionId);
        } else {
            section.questions[questionIndex][fieldName] = value;
        }
        section.questions = [...section.questions]; // Trigger reactivity

        if (fieldName === 'type' && (value === 'Multiple Choice' || value === 'Dropdown')) {
            section.questions[questionIndex].isMCQ = true;
        } else if (fieldName === 'type' && value !== 'Multiple Choice' && value !== 'Dropdown') {
            section.questions[questionIndex].isMCQ = false;
            section.questions[questionIndex].options = '';
        }
    }

    addQuestion(event) {
        const sectionId = event.target.dataset.sectionid;
        const section = this.groupedQuestions.find(sec => sec.sectionId === sectionId);
        if (section) {

            const headerExists = section.questions.some(q => q.sectionHeader === true);

            section.questions.push({
                id: section.questions.length + 1,
                label: '',
                type: '',
                isRequired: false,
                sectionHeader: false,
                options: '',
                isMCQ: false,
                section: section.sectionName,
                isHeaderDisabled: headerExists // Disable if any other question is a header
            });
        }
        section.questions = [...section.questions]; // Trigger reactivity
    }

    addSection() {
        const sectionId = `section-${Date.now()}`;
        const newSection = {
            sectionId: sectionId,
            sectionName: '',
            questions: []
        };
        this.groupedQuestions = [...this.groupedQuestions, newSection];
    }

    removeQuestion(event) {
        const sectionId = event.target.dataset.sectionid;
        const questionId = event.target.dataset.questionid;
        const section = this.groupedQuestions.find(sec => sec.sectionId === sectionId);
        if (section) {
            section.questions = section.questions.filter(q => q.id != questionId);
            const removedQuestion = section.questions.find(q => q.id == questionId);
            const wasHeader = removedQuestion && removedQuestion.sectionHeader;

            if (wasHeader) {
                this.updateSectionHeaderDisabledStatus(sectionId);
            }

            section.questions = [...section.questions]; // Trigger reactivity
        }


    }

    removeSection() {
        const sectionId = event.target.dataset.sectionid;
        this.groupedQuestions = this.groupedQuestions.filter(sec => sec.sectionId !== sectionId);
        this.groupedQuestions = [...this.groupedQuestions]; // Trigger reactivity
    }

    validateForm() {
        if (!this.questionnaire.title || !this.questionnaire.description || !this.questionnaire.targetAudience) {
            this.showToast('Error', 'All questionnaire fields must be filled.', 'error');
            return false;
        }

        if (!this.groupedQuestions || this.groupedQuestions.length === 0) {
            this.showToast('Error', 'You must add at least one question.', 'error');
            return false;
        }

        for (let i = 0; i < this.groupedQuestions.length; i++) {
            if (!this.groupedQuestions[i].sectionName.trim()) {
                this.showToast('Error', 'Each section must have a name.', 'error');
                return false;
            }

            if (this.groupedQuestions[i].questions.length === 0) {
                this.showToast('Error', 'Each section must have at least one question.', 'error');
                return false;
            }

            for (let j = 0; j < this.groupedQuestions[i].questions.length; j++) {
                const question = this.groupedQuestions[i].questions[j];
                if (!question.label || !question.type) {
                    this.showToast('Error', 'All question fields must be filled.', 'error');
                    return false;
                }
                if (question.isMCQ && !question.options) {
                    this.showToast('Error', 'MCQ or Dropdown questions must have options.', 'error');
                    return false;
                }
            }
        }

        return true;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    resetForm() {
        this.questionnaire = {
            title: '',
            description: '',
            targetAudience: ''
        };
        this.groupedQuestions = [];
    }

    saveQuestionnaire() {
        if (!this.validateForm()) {
            return;
        }

        this.showSpinner = true;
        console.log('this.questionnaireId', this.questionnaireId);
        console.log('this.recordId', this.recordId);
        if (this.objectApiName === 'Alm_Service_Offering__c' || this.objectApiName === 'Event_Master__c' || this.objectApiName === 'Schedule_Sessions__c' || this.objectApiName === 'Alm_Survey__c') {
            this.questionnaireId = null;
        } else {
            this.questionnaireId = this.recordId;
        }

        console.log('this.objectApiName', this.objectApiName);

        const questionnaireRecord = {
            Id: this.questionnaireId,
            Section_Name__c: this.questionnaire.title,
            Descripation__c: this.questionnaire.description,
            Target_Audience__c: this.questionnaire.targetAudience
        };
        console.log(
            'questionnaireRecord',
            questionnaireRecord
        );
        const questionsRecords = this.groupedQuestions.flatMap(sec =>
            sec.questions.map(q => ({
                Id: q.Id, // Assuming questions have an Id
                Question_Label__c: q.label,
                Question_Type__c: q.type,
                Is_Required__c: q.isRequired,
                MCQ_Options__c: q.options,
                Section_Name__c: sec.sectionName,
                Section_Header__c: q.sectionHeader
            }))
        );


        console.log(
            'questionsRecords',
            questionsRecords);

        if (this.objectApiName === 'Alm_Service_Offering__c' || this.objectApiName === 'Event_Master__c' || this.objectApiName === 'Schedule_Sessions__c' || this.objectApiName === 'Alm_Survey__c') {
            console.log('relatedRecordId', this.recordId);
            console.log('relatedObjectType', this.objectApiName);
            saveQuestionnaireWithRelatedRecord({ questionnaire: questionnaireRecord, questions: questionsRecords, relatedRecordId: this.recordId, relatedObjectType: this.objectApiName })
                .then((result) => {
                    this.showToast('Success', 'Questionnaire updated successfully.', 'success');

                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: this.recordId,
                            objectApiName: this.objectApiName,
                            actionName: 'view'
                        }
                    });
                    this.resetForm();
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
                })
                .finally(() => {
                    this.showSpinner = false; // Hide spinner when done
                });

        } else {
            saveQuestionnaireWithQuestions({ questionnaire: questionnaireRecord, questions: questionsRecords })
                .then((result) => {
                    this.showToast('Success', 'Questionnaire updated successfully.', 'success');

                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: result,
                            objectApiName: 'Alm_Questionnaire__c',
                            actionName: 'view'
                        }
                    });
                    this.resetForm();
                })
                .catch(error => {
                    this.showToast('Error', error.body.message, 'error');
                })
                .finally(() => {
                    this.showSpinner = false; // Hide spinner when done
                });
        }
    }

    handleCancel() {
        if (this.recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: this.objectApiName,
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: this.objectApiName,
                    actionName: 'home'
                }
            });
        }
    }

    updateSectionHeaderDisabledStatus(sectionId) {
        const sectionsToUpdate = sectionId ?
            [this.groupedQuestions.find(sec => sec.sectionId === sectionId)] :
            this.groupedQuestions;

        sectionsToUpdate.filter(section => section).forEach(section => {
            const headerExists = section.questions.some(q => q.sectionHeader === true);
            section.questions.forEach(question => {
                question.isHeaderDisabled = headerExists && !question.sectionHeader;
            });
        });
    }


    groupQuestionsBySection(questions) {
        const grouped = questions.reduce((acc, question) => {
            if (!acc[question.section]) {
                acc[question.section] = {
                    sectionName: question.section,
                    questions: []
                };
            }
            acc[question.section].questions.push(question);
            return acc;
        }, {});

        let sectionIndex = 1;
        this.groupedQuestions = Object.values(grouped).map(section => {
            section.sectionId = `section-${sectionIndex}`;

            section.questions = section.questions.map((question, questionIndex) => {
                return {
                    ...question,
                    id: questionIndex + 1,
                };
            });

            sectionIndex++;
            return section;
        });
    }
}