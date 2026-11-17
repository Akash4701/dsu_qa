import { LightningElement, api } from 'lwc';

export default class FeedbackStatCard extends LightningElement {
    @api label;
    @api value;
    @api sub;
    @api tone = 'info';
    @api iconName = 'utility:chart';

    get cardClass() {
        return `fh-card fh-card_hover card card_${this.tone} fh-fade-in`;
    }

    get iconClass() {
        return `icon icon_${this.tone}`;
    }
}