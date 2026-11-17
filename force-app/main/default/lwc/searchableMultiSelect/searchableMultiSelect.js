import { LightningElement, api, track } from 'lwc';

export default class SearchableMultiSelect extends LightningElement {
    @api label = 'Select Values';
    @api placeholder = 'Search options';
    @api options = []; // Expected: [{label, value}]
    @track selectedValues = [];

    searchTerm = '';
    showOptions = false;

    get selectedPills() {
        return this.options
            .filter(opt => this.selectedValues.includes(opt.value))
            .map(opt => ({ label: opt.label, name: opt.value }));
    }

    get filteredOptions() {
        return this.options
            .filter(opt =>
                opt.label.toLowerCase().includes(this.searchTerm.toLowerCase()) &&
                !this.selectedValues.includes(opt.value)
            );
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.showOptions = true;
    }

    handleSelect(event) {
        const val = event.currentTarget.dataset.value;
        this.selectedValues = [...this.selectedValues, val];
        this.searchTerm = '';
        this.showOptions = false;
        this.dispatchChange();
    }

    handleRemove(event) {
        const name = event.detail.item.name;
        this.selectedValues = this.selectedValues.filter(v => v !== name);
        this.dispatchChange();
    }

    showDropdown() {
        this.showOptions = true;
    }

    handleBlur() {
        setTimeout(() => {
            this.showOptions = false;
        }, 200); // Allow click to complete
    }

    dispatchChange() {
        this.dispatchEvent(new CustomEvent('change', {
            detail: { value: this.selectedValues }
        }));
    }
}