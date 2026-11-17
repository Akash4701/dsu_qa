import { LightningElement, api } from 'lwc';

const RADIUS = 48;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

export default class FeedbackDonut extends LightningElement {
    @api value = 0; // 0-100
    @api tone = 'info';
    @api label;
    @api sublabel;
    @api size = 160;

    get percent() {
        return Math.max(0, Math.min(100, Math.round(Number(this.value) || 0)));
    }

    get radius() {
        return RADIUS;
    }

    get dashArray() {
        return CIRCUMFERENCE;
    }

    get dashOffset() {
        return CIRCUMFERENCE * (1 - this.percent / 100);
    }

    get wrapperStyle() {
        return `width:${this.size}px;height:${this.size}px`;
    }

    get ringClass() {
        return `ring ring_${this.tone}`;
    }

    get ariaLabel() {
        return `${this.label || 'Progress'}: ${this.percent}%`;
    }
}