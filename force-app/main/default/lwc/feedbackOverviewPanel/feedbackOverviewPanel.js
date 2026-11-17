import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { rateTone, statusTone, scheduleTiming, formatWindow, recordPage, plural, DEFAULT_TARGET_RATE } from 'c/feedbackHomeUtils';

const STAT_ICONS = ['utility:layers', 'utility:checklist', 'utility:event', 'utility:trending'];
const TYPE_TONES = ['info', 'success', 'warning', 'neutral'];

/** Presentational: renders the overview the container loaded. Emits events, never fetches. */
export default class FeedbackOverviewPanel extends NavigationMixin(LightningElement) {
    @api overview;
    @api loading = false;
    @api error;

    get hasData() {
        return !!this.overview;
    }

    get showSkeleton() {
        return this.loading && !this.overview;
    }

    get target() {
        return this.overview ? this.overview.targetResponseRate : DEFAULT_TARGET_RATE;
    }

    get stats() {
        return (this.overview ? this.overview.stats : []).map((stat, index) => ({
            ...stat,
            iconName: STAT_ICONS[index] || 'utility:chart'
        }));
    }

    get counts() {
        const byStatus = {};
        (this.overview ? this.overview.itemStatusCounts : []).forEach((c) => {
            byStatus[c.status] = c.count;
        });
        const submitted = byStatus.Submitted || 0;
        const pending = byStatus.Pending || 0;
        return { submitted, pending, total: submitted + pending };
    }

    get responseRate() {
        const { submitted, total } = this.counts;
        return total > 0 ? Math.round((submitted * 100) / total) : 0;
    }

    get hasResponses() {
        return this.counts.total > 0;
    }

    get responseTone() {
        return this.hasResponses ? rateTone(this.responseRate, this.target) : 'info';
    }

    get donutSub() {
        return `of ${plural(this.counts.total, 'item')}`;
    }

    get targetLabel() {
        return `Target ${this.target}%`;
    }

    get gapLabel() {
        const gap = this.target - this.responseRate;
        if (!this.hasResponses) {
            return 'No responses expected yet';
        }
        return gap > 0 ? `${gap} points below target` : 'Target met';
    }

    get health() {
        return (this.overview ? this.overview.recentSchedules : []).map((s) => {
            const timing = scheduleTiming(s);
            return {
                ...s,
                statusTone: statusTone(s.status),
                rateTone: rateTone(s.rate, this.target),
                caption: timing.caption,
                window: formatWindow(s.startDate, s.endDate),
                responseLabel: `${s.submitted} of ${s.total}`
            };
        });
    }

    get hasHealth() {
        return this.health.length > 0;
    }

    get alerts() {
        return (this.overview ? this.overview.alerts : []).map((a, i) => ({
            ...a,
            key: `${i}-${a.recordId}`,
            iconName: a.tone === 'error' ? 'utility:error' : 'utility:warning',
            rowClass: `alert alert_${a.tone}`
        }));
    }

    get hasAlerts() {
        return this.alerts.length > 0;
    }

    get typeBars() {
        const rows = this.overview ? this.overview.sectionTypeCounts : [];
        const total = rows.reduce((sum, r) => sum + r.count, 0);
        return rows.map((r, i) => {
            const percent = total > 0 ? Math.round((r.count * 100) / total) : 0;
            return {
                key: r.status,
                label: r.status,
                count: r.count,
                tone: TYPE_TONES[i % TYPE_TONES.length],
                percent,
                style: `width:${percent}%`
            };
        });
    }

    get hasTypeBars() {
        return this.typeBars.length > 0;
    }

    handleRetry() {
        this.dispatchEvent(new CustomEvent('retry'));
    }

    handleAlertClick(event) {
        this[NavigationMixin.Navigate](recordPage(event.currentTarget.dataset.id));
    }

    handleOpenResponses(event) {
        this.dispatchEvent(new CustomEvent('openresponses', { detail: { schedulerId: event.currentTarget.dataset.id } }));
    }

    handleOpenTab(event) {
        this.dispatchEvent(new CustomEvent('opentab', { detail: { tab: event.currentTarget.dataset.tab } }));
    }
}