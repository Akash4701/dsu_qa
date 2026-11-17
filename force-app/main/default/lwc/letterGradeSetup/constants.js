const COLUMNS = [
    {
        label: 'Letter Grade',
        fieldName: 'letterGrade',
        editable: true,
        hideDefaultActions: 'true',
        type: 'text',
        typeAttributes: {
            required: true,
            placeholder: 'Enter a letter grade',
            pattern: '[A-Za-z ]*',
            title: 'Please enter a single alphabet (A-Z or a-z).'
        },
          sortable: true
    },
    {
        label: 'Grade Point',
        fieldName: 'gradePoint',
        editable: true,
        hideDefaultActions: 'true', 
        type: 'number',
        sortable: true,
        cellAttributes: { alignment: 'left' }
    },
    {
        label: 'Definition',
        fieldName: 'definition',
        type: 'picklistColumn',
        editable: true,
        wrapText: true,
        hideDefaultActions: 'true',
        typeAttributes: {
        placeholder: 'Select definition',
        options: { fieldName: 'definitionTypeOptions' },
        value: { fieldName: 'definition' },
        context: { fieldName: 'id' }
        }
    },
    {
        label: 'Range Start',
        fieldName: 'rangeStart',
        editable: true,
        hideDefaultActions: 'true',
        type: 'number',
        sortable: true,
        cellAttributes: { alignment: 'left' }
    },
    { label: 'Range End',
    fieldName: 'rangeEnd',
    editable: true,
    hideDefaultActions: 'true',
    type: 'number',
    sortable: true,
    cellAttributes: { alignment: 'left' }
},
];

const DELETE_COLUMN = {
    fieldName: 'delete',
    type: 'button-icon',
    initialWidth: 100,
    hideDefaultActions: 'true',
    typeAttributes: {
        iconName: 'utility:delete',
        name: 'delete',
        iconClass: 'slds-icon-text-error',
    },
};

const MECHANISM_OPTIONS = [
    { label: 'Absolute', value: 'Absolute' },
    { label: 'Relative', value: 'Relative' },
];

const TYPE_OPTIONS = [
    { label: 'Master', value: 'Master' },
    { label: 'Custom', value: 'Custom' },
];

export { COLUMNS, DELETE_COLUMN, MECHANISM_OPTIONS, TYPE_OPTIONS };