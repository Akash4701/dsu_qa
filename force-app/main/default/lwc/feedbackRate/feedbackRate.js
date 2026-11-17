import { LightningElement, api } from 'lwc';

export default class FeedbackRate extends LightningElement {
    @api value = 0;
    @api tone = 'info';
    @api target; // optional goal marker, 0-100
    @api compact = false;

    get percent() {
        return Math.max(0, Math.min(100, Math.round(Number(this.value) || 0)));
    }

    get barStyle() {
        return `width:${this.percent}%`;
    }

    get barClass() {
        return `bar bar_${this.tone}`;
    }

    get hasTarget() {
        return this.target !== undefined && this.target !== null && this.target !== '';
    }

    get markerStyle() {
        return `left:${Number(this.target)}%`;
    }

    get markerTitle() {
        return `Target ${this.target}%`;
    }

    get trackClass() {
        return this.compact ? 'track track_compact' : 'track';
    }
}