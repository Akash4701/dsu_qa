import { LightningElement, track } from 'lwc';

export default class FeeServices extends LightningElement {
    @track displayOverTheFee = false;

    // Show child component
    showOverTheFee() {
        this.displayOverTheFee = true;
    }

    // Hide child component when it fires a “close” event
    hideOverTheFee() {
        this.displayOverTheFee = false;
    }
}