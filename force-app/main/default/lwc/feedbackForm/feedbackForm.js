import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import saveQuestionnaireWithQuestions from '@salesforce/apex/QuestionnaireControllerClass.saveQuestionnaireWithQuestions';

export default class QuestionnaireForm extends NavigationMixin(LightningElement) {
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

    handleInputChange(event) {
        const field = event.target.dataset.id;
        this.questionnaire[field] = event.target.value;
    }

    handleSelection(event) {
        this.selectedValues = event.detail;
        
        this.questionnaire.targetAudience = this.selectedValues;
        console.log('Selected values:', this.selectedValues);
    }

    handleQuestionChange(event) {
        const index = event.target.dataset.index;
        const fieldName = event.target.dataset.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.questions[index][fieldName] = value;
        this.questions = [...this.questions]; // Trigger reactivity

        if (fieldName === 'type' && (value === 'Multiple Choice' || value === 'Dropdown')) {
            this.questions[index].isMCQ = true;
        } else if (fieldName === 'type' && value !== 'Multiple Choice' && value !== 'Dropdown') {
            this.questions[index].isMCQ = false;
            this.questions[index].options = '';
        }
    }

    addQuestion() {
        const newQuestion = {
            id: this.questions.length + 1,
            label: '',
            type: '',
            isRequired: false,
            options: '',
            isMCQ: false
        };
        this.questions = [...this.questions, newQuestion];
    }

    removeQuestion(event) {
        const index = event.target.dataset.index;
        this.questions.splice(index, 1);
        this.questions = [...this.questions]; // Trigger reactivity
    }

    validateForm() {
        if (!this.questionnaire.title || !this.questionnaire.description || !this.questionnaire.targetAudience) {
            this.showToast('Error', 'All questionnaire fields must be filled.', 'error');
            return false;
        }

        if (this.questions.length === 0) {
            this.showToast('Error', 'You must add at least one question.', 'error');
            return false;
        }

        for (let i = 0; i < this.questions.length; i++) {
            const question = this.questions[i];
            if (!question.label || !question.type) {
                this.showToast('Error', 'All question fields must be filled.', 'error');
                return false;
            }
            if (question.isMCQ && !question.options) {
                this.showToast('Error', 'MCQ or Dropdown questions must have options.', 'error');
                return false;
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
        this.questions = [];
    }

    saveQuestionnaire() {
        if (!this.validateForm()) {
            return;
        }

        const questionnaireRecord = {
            Section_Name__c: this.questionnaire.title,
            Descripation__c: this.questionnaire.description,
            Target_Audience__c: this.questionnaire.targetAudience
        };

        const questionsRecords = this.questions.map(q => ({
            Question_Label__c: q.label,
            Question_Type__c: q.type,
            Is_Required__c: q.isRequired,
            MCQ_Options__c: q.options
        }));

        saveQuestionnaireWithQuestions({ questionnaire: questionnaireRecord, questions: questionsRecords })
            .then(result => {
                this.showToast('Success', 'Questionnaire saved successfully.', 'success');

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result,
                        objectApiName: 'Questionnaire__c',
                        actionName: 'view'
                    }
                });

                this.resetForm();
                console.log('Questionnaire saved successfully: ', result);
            })
            .catch(error => {
                this.showToast('Error', error.body.message, 'error');
                console.error('Error saving questionnaire: ', error);
            });
    }
}