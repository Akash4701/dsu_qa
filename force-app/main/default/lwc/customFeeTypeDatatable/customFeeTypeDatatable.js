import LightningDatatable from 'lightning/datatable';
import picklistColumn from './customPicklistColumn.html';
import picklistView from './customPicklistView.html'
import lookupColumn from './customLookupColumn.html';
import multiSelectView from './customMultiSelectColumn.html';
import multiSelectViewColumn from './customMultiSelectViewColumn.html';

export default class CustomFeeTypeDatatable extends LightningDatatable {
    static customTypes = {
        picklistColumn: {
            template: picklistView,
            editTemplate: picklistColumn,
            standardCellLayout: true,
            typeAttributes: ['label', 'placeholder', 'options', 'value', 'context', 'variant','name']
        },
        lookupColumn: {
            template: lookupColumn,
            standardCellLayout: true,
            typeAttributes: ['value', 'fieldName', 'object', 'context', 'name', 'fields', 'target', 'contextField']
        },
        multiSelectColumn: {
            template: multiSelectViewColumn,
            editTemplate: multiSelectView,
            standardCellLayout: true,
            typeAttributes: ['disabled', 'label', 'name', 'readOnly', 'required', 'singleSelect', 'showPills', 'placeholder', 'options', 'context', 'noOptionsText']
        }
    };
}