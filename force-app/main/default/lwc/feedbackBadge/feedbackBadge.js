import { LightningElement, api } from 'lwc';

export default class FeedbackBadge extends LightningElement {
    @api label;
    @api tone = 'neutral';

    get cssClass() {
        return `fh-chip fh-chip_${this.tone}`;
    }
}