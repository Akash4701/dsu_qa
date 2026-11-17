import { LightningElement, api, wire, track } from 'lwc';
import getQuestionnaireResponses from '@salesforce/apex/QuestionnaireController.getQuestionnaireResponses';

export default class CaseQuestionnaireResponses extends LightningElement {
    @api recordId; // Case Id
    @track selectedQuestionnaire;

    @wire(getQuestionnaireResponses, { caseId: '$recordId' })
    wiredQuestionnaire({ error, data }) {
        if (data) {
            // Assuming you want to automatically select the first questionnaire (or other logic to pick one)
            this.selectedQuestionnaire = data[0]; // Set this as per your logic (e.g., based on case)
        } else if (error) {
            // Handle error if needed
            console.error("Error loading questionnaire responses: ", error);
        }
    }
}