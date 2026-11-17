import LightningDatatable from 'lightning/datatable';
import picklistColumn from './customPicklistColumn.html';
import picklistView from './customPicklistView.html'
import { api } from 'lwc';


export default class CustomLetterGradeDatatable extends LightningDatatable {
    @api getFocusedInput() {
        return this.template.querySelector('lightning-input');
    }

    static customTypes = {
        picklistColumn: {
            template: picklistView,
            editTemplate: picklistColumn,
            standardCellLayout: true,
            typeAttributes: ['label', 'placeholder', 'options', 'value', 'context', 'variant','name']
        }
    };
}