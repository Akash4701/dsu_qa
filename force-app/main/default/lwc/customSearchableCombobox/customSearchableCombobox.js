import { LightningElement, track, api } from 'lwc';

export default class CustomSearchableCombobox extends LightningElement {
    @api classes;
    @api label;
    @api placeholder;
    @api required = false;

    _options;
    _value='';

    @api
    get value() {
        return this._value;
    }

    set value(val) {
        this._value = val;
    }

    @api
    get options() {
        return this._options;
    }

    set options(value) {
        this._options = value;
        this.filteredOptions = [...this.options];
    }

    @api variant = 'standard';
    
    @track isFocussed = false;
    @track isOpen = false;

    @track filteredOptions = [];
    domElement;
    
    _handleOutsideClick;

    constructor() {
        super();
        this._handleOutsideClick = this.handleOutsideClick.bind(this);
    }

    connectedCallback() {
        this.filteredOptions = [...this.options];
        document.addEventListener('click', this._handleOutsideClick);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this._handleOutsideClick);
    }

    @api reportValidity() {
        this.template.querySelector('lightning-input').reportValidity();
    }

    @api checkValidity() {
        return this.template.querySelector('lightning-input').checkValidity();
    }

    filterOptions(event) {
        const filterText = event.detail.value;
        this.filteredOptions = this.options.filter(option => {
            return option.label.toLowerCase().includes(filterText.toLowerCase());
        });
        
        if(!event.detail.value && this.value.length ) {
            // it is cleared
            this.value = '';
            const custEvent = new CustomEvent(
                'selectoption', {
                    detail: {
                        value: ''
                    }
                }
            );
            this.dispatchEvent(custEvent);
        }  
    }

    handleSelectOption(event) {
        this.value = event.currentTarget.dataset.label;
        const custEvent = new CustomEvent(
            'selectoption', {
                detail: {
                    value: event.currentTarget.dataset.value,
                    label: event.currentTarget.dataset.label
                }
            }
        );
        this.dispatchEvent(custEvent);

        // Close the picklist options
        this.isFocussed = false;
        this.isOpen = false;
        this.template.querySelector('lightning-input').value = this.value;
        this.reportValidity();
    }

    get noOptions() {
        return this.filteredOptions.length === 0;
    }

    get dropdownClasses() {
        
        let dropdownClasses = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        
        // Show dropdown list on focus
        if (this.isOpen) {
            dropdownClasses += ' slds-is-open';
        }

        return dropdownClasses;
    }

    handleOutsideClick(event) {

        if ((!this.isFocussed) && (this.isOpen)) { 

            //Fetch the dropdown DOM node
            let domElement = this.template.querySelector('div[data-id="resultBox"]');

            //Is the clicked element within the dropdown 
            if (domElement && !domElement.contains(event.target)) {
                this.isOpen = false;
            }

            if(!this.value) {
                this.template.querySelector('lightning-input').value = ''; 
            }

            this.reportValidity();
        }
    }

    handleFocus() {
        this.isFocussed = true;
        this.isOpen = true;
    }

    handleBlur() {
        this.isFocussed = false;

        //this.reportValidity();
    }
}