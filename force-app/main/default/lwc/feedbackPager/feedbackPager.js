import { LightningElement, api } from 'lwc';

const PAGE_SIZES = [10, 25, 50, 100];

/**
 * Presentational pager for server-side paged lists. Owns no data: it shows the facts it is given and
 * reports intent through `pagechange` ({ page }) and `sizechange` ({ size }).
 */
export default class FeedbackPager extends LightningElement {
    @api pageNumber = 1;
    @api pageSize = 25;
    @api total = 0;
    @api totalPages = 1;
    @api truncated = false;
    @api noun = 'record';

    get hasRows() {
        return this.total > 0;
    }

    get rangeLabel() {
        if (!this.hasRows) {
            return `No ${this.noun}s`;
        }
        const from = (this.pageNumber - 1) * this.pageSize + 1;
        const to = Math.min(this.pageNumber * this.pageSize, this.total);
        return `${from}–${to} of ${this.total.toLocaleString()}`;
    }

    get pageLabel() {
        return `Page ${this.pageNumber} of ${this.totalPages}`;
    }

    get atFirst() {
        return this.pageNumber <= 1;
    }

    get atLast() {
        return this.pageNumber >= this.totalPages;
    }

    get showTruncated() {
        return this.truncated && this.atLast;
    }

    get sizeOptions() {
        return PAGE_SIZES.map((value) => ({ value, label: `${value} per page`, selected: value === this.pageSize }));
    }

    handleFirst() {
        this.go(1);
    }
    handlePrev() {
        this.go(this.pageNumber - 1);
    }
    handleNext() {
        this.go(this.pageNumber + 1);
    }
    handleLast() {
        this.go(this.totalPages);
    }

    handleSize(event) {
        this.dispatchEvent(new CustomEvent('sizechange', { detail: { size: Number(event.target.value) } }));
    }

    go(page) {
        const target = Math.min(Math.max(page, 1), this.totalPages);
        if (target !== this.pageNumber) {
            this.dispatchEvent(new CustomEvent('pagechange', { detail: { page: target } }));
        }
    }
}