import { LightningElement, api } from 'lwc';

export default class FeedbackMessage extends LightningElement {
    @api title;
    @api message;
    @api variant = 'empty'; // empty | error
    @api iconName;
    @api actionLabel;

    get isError() {
        return this.variant === 'error';
    }

    get resolvedIcon() {
        return this.iconName || (this.isError ? 'utility:warning' : 'utility:info');
    }

    get resolvedTitle() {
        return this.title || (this.isError ? 'Something went wrong' : 'Nothing here yet');
    }

    get role() {
        return this.isError ? 'alert' : 'status';
    }

    get hasAction() {
        return !!this.actionLabel;
    }

    get iconWrapClass() {
        return this.isError ? 'badge badge_error' : 'badge';
    }

    handleAction() {
        this.dispatchEvent(new CustomEvent('action'));
    }
}