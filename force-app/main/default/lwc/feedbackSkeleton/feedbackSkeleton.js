import { LightningElement, api } from 'lwc';

export default class FeedbackSkeleton extends LightningElement {
    @api variant = 'cards'; // cards | rows | stats
    @api count = 3;

    get items() {
        return Array.from({ length: Math.max(1, Number(this.count) || 1) }, (_, index) => ({ key: `s${index}` }));
    }

    get isCards() {
        return this.variant === 'cards';
    }

    get isStats() {
        return this.variant === 'stats';
    }

    get isRows() {
        return this.variant === 'rows';
    }
}