import { api, LightningElement, track } from 'lwc';
import LightningConfirm from 'lightning/confirm';

export default class CustomComboboxSearch extends LightningElement {
    @api disabled = false;
    @api label = '';
    @api name;
    @api readOnly = false;
    @api required = false;
    @api singleSelect = false;
    @api showPills = false;
    @api forceShowPills = false;
    @api placeholder;
    @api pillRemoveMsg;


    @api
    get selected() {
        return this._selected;
    }

    // Array of ids
    set selected(value) {
        this._selected = value;

        this.prepareOptions(this.currentOptions, value);
    }

    @api get options() {
        return this.currentOptions;
    }
    set options(value) {
        this.currentOptions = value.map((o) => {
            return { ...o };
        });

        this.prepareOptions(this.currentOptions, this.selected);
    }

    _selected = [];
    selectedOptions = [];

    @track currentOptions = [];
    searchterm = '';
   
    isInitialized = false;
    isLoaded = false;
    isVisible = false;
    isDisabled = false;

    selectedSearchLabel;
    openDropdown;
    needsToRegisterEvent = false;

    connectedCallback() {
        this.isDisabled = this.disabled || this.readOnly;
        this.hasPillsEnabled = this.forceShowPills || (this.showPills && !this.singleSelect);
    }

    renderedCallback() {
        if (!this.isInitialized) {
            let cmp = this.template.querySelector('.multi-select-combobox__input');

            if (!cmp) return;

            cmp.addEventListener('click', (event) => {
                this.handleClick(event.target);
                event.stopPropagation();
            });
            this.template.addEventListener('click', (event) => {
                event.stopPropagation();
            });
            document.addEventListener('click', () => {
                this.close();
            });

            this.isInitialized = true;
            this.needsToRegisterEvent = false;
        }
    }

    get dropDownClass() {
        return this.openDropdown
            ? 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-picklist multi-select-combobox__dropdown slds-is-open'
            : 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-picklist multi-select-combobox__dropdown';
    }

    get filterRecords() {
        return this.currentOptions
            ? this.currentOptions.filter((item) => item.label.toLowerCase().includes(this.searchterm.toLowerCase()))
            : [];
    }

    get showInput() {
        return !this.selectedSearchLabel || this.openDropdown;
    }

    handleClick() {
        if (this.openDropdown) {
            this.close();
        } else {
            this.dispatchEvent(new CustomEvent('close'));
            this.openDropdown = true;
        }
    }

    @api
    close() {
        this.openDropdown = false;
    }

    handleChange(event) {
        this.change(event);
    }

    handleInputClick() {
        this.needsToRegisterEvent = true;
        this.dispatchEvent(new CustomEvent('close'));
        this.openDropdown = true;
    }

    async handleRemove(event) {
        if (this.pillRemoveMsg && this.pillRemoveMsg !== '') {
            const result = await LightningConfirm.open({
                theme: 'warning',
                variant: 'header',
                message: this.pillRemoveMsg,
                label: 'Please Confirm', // this is the header text
            });

            if (!result) {
                return;
            }
        }

        const oldLength = this.selectedOptions.length;
        this.selectedOptions.splice(event.detail.index, 1);

        if (oldLength != 0 && this.selectedOptions.length === 0) {
            this.needsToRegisterEvent = true;
        }

        this.change(event);
    }

    change(event) {
        const isSelect = event.detail.selected;
        let selectedItems = this.selectedOptions.map(option => option.value);
        if(isSelect) {
            if(this.singleSelect) {
                selectedItems = [event.detail.item.value];
            } else {
                selectedItems.push(event.detail.item.value);
            }
        } else {
           const indexOfRemoved = selectedItems.indexOf(event.detail.item.value);
           if(indexOfRemoved >= 0 ) {
            selectedItems.splice(indexOfRemoved, 1);
           }
           
        }
        
        this.prepareOptions(this.currentOptions, selectedItems);

        this.dispatchEvent(new CustomEvent('change', { detail: this.singleSelect ? selectedItems[0] : selectedItems }));
    }

    handlesearchterm(event) {
        this.searchterm = event.target.value;
    }

    prepareOptions(options, selected) {
        const selectedItems =[];
        options.forEach(option => {
            if(selected.includes(option.value)) {
                option.selected = true;
                selectedItems.push(option);
            } else {
                option.selected = false;
            }
        });
        this.setSelection(selectedItems);
    }

    setSelection(selectedItems) {
        let selection = '';
        if (selectedItems.length < 1) {
            if (this.needsToRegisterEvent) {
                this.isInitialized = false;
            }

            selection = undefined;
            this.selectedOptions = [];
        } else if (selectedItems.length > 2) {
            selection = `${selectedItems.length} Options Selected`;
            this.selectedOptions = selectedItems
        } else {
            selection = selectedItems.map((selected) => selected.label).join(', ');
            this.selectedOptions = selectedItems
        }
        this.selectedSearchLabel = selection;
        this.isVisible = this.selectedOptions && this.selectedOptions.length > 0;
    }

    

    getSelectedItems() {
        return this.currentOptions.filter((item) => this.selected.includes(item.value));
    }
}