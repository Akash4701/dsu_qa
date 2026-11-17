import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAcademicYearOptions from '@salesforce/apex/AdmissionReportsController.getAcademicYearOptions';
import getProgramOptions from '@salesforce/apex/AdmissionReportsController.getProgramOptions';
import getProgramPlanOptions from '@salesforce/apex/AdmissionReportsController.getProgramPlanOptions';
import getSemesterOptions from '@salesforce/apex/AdmissionReportsController.getSemesterOptions';
import getStateWiseReport from '@salesforce/apex/AdmissionReportsController.getStateWiseReport';
import getCategoryWiseReport from '@salesforce/apex/AdmissionReportsController.getCategoryWiseReport';
import getResultAnalysisReport from '@salesforce/apex/AdmissionReportsController.getResultAnalysisReport';
import getAdmissionDashboard from '@salesforce/apex/AdmissionReportsController.getAdmissionDashboard';

const VIEW_DASHBOARD = 'dashboard';
const VIEW_REPORTS = 'reports';

const VIEWS = [
    { key: VIEW_DASHBOARD, label: 'Dashboard' },
    { key: VIEW_REPORTS, label: 'Reports' }
];

const TAB_STATE = 'state';
const TAB_CATEGORY = 'category';
const TAB_RESULT = 'result';

const TABS = [
    {
        key: TAB_STATE,
        label: 'State Wise',
        title: 'Admission Details - State Wise – Karnataka / Non-Karnataka & Gender Wise'
    },
    {
        key: TAB_CATEGORY,
        label: 'Category Wise',
        title: 'Admission details - Category and Gender Wise (with Approved Intake)'
    },
    {
        key: TAB_RESULT,
        label: 'Result Analysis',
        title: 'Result Analysis - Students performance during the academic year'
    }
];

const STATUS_SCOPES = [
    { label: 'Admitted & beyond', value: 'ADMITTED' },
    { label: 'Enrolled only', value: 'ENROLLED' },
    { label: 'All applications', value: 'ALL' },
    { label: 'Admitted', value: 'Admitted' },
    { label: 'Approved for USN', value: 'Approved for USN' },
    { label: 'Generate Letter of Admission', value: 'Generate Letter of Admission' },
    { label: 'Application on hold', value: 'Application on hold' }
];

const FIELD_LABELS = {
    gender: 'Gender',
    state: 'State',
    category: 'Category'
};

/**
 * Chart colour, assigned by the job each chart's colour is doing.
 *
 * SERIES is the categorical order, used only where the slices ARE the subject (the
 * state / gender / category splits). It is taken in fixed order and never cycled.
 * MAGNITUDE is a single hue for the bar and column charts: there the length is the
 * encoding, so shading each bar by its own value would just restate it.
 * NO_DATA is deliberately the one grey — "Not Specified" is the absence of a value,
 * not another category, and it should never compete with a real one for attention.
 *
 * Validated with the dataviz palette validator against a #ffffff surface:
 * `#2a78d6,#eb6834,#1baf7a,#eda100,#4a3aa7,#8c8c88` passes the lightness band,
 * CVD separation (worst adjacent ΔE 9.1) and normal-vision floor (22.9). Two slots
 * sit under 3:1 contrast, which obliges visible labels — every legend row here
 * carries its label and value, so identity is never colour-alone.
 */
const SERIES_COLORS = ['#2a78d6', '#eb6834', '#1baf7a', '#eda100', '#4a3aa7'];
const MAGNITUDE_COLOR = '#2a78d6';
const NO_DATA_COLOR = '#8c8c88';
const NOT_SPECIFIED = 'Not Specified';

const DONUT = { size: 120, cx: 60, cy: 60, rOuter: 52, rInner: 32, gapDegrees: 1.5 };

/**
 * Colour follows the entity, never its position in the list. These pin each label to a
 * fixed categorical slot, so a category that happens to be empty under one filter — and
 * is therefore dropped from the chart — does not hand its colour to the next one along
 * and repaint everything the reader had already learned.
 */
const SLOTS = {
    state: { Karnataka: 0, 'Non-Karnataka': 1 },
    gender: { Male: 0, Female: 1 },
    category: { GM: 0, OBC: 1, SC: 2, ST: 3, Other: 4 }
};

/**
 * admissionReports
 * ────────────────
 * Two views behind one tab — see AdmissionReportsController.cls for the data model and
 * the counting rules.
 *
 *   Dashboard → the admissions in scope summarised: headline figures and bar charts.
 *   Reports   → the three tables the client shared, chosen from a second-level switcher
 *               (State Wise / Category Wise / Result Analysis).
 *
 * Both are driven by the same filter bar, and the dashboard is derived from the very same
 * aggregate the reports are, so its figures always agree with the column totals below.
 *
 * Every report comes back from Apex as the same shape (a two-row header plus rows of
 * string cells), so one table renders all three exactly as the client drew them, and
 * one exporter writes whatever is on screen — searched rows included — to CSV.
 *
 * Nothing loads on a filter change; Apply / Refresh is the only trigger, so an
 * accidental combobox click never fires an aggregate query across every application.
 */
export default class AdmissionReports extends LightningElement {
    @api cardTitle = 'Admission Reports';

    activeView = VIEW_DASHBOARD;
    activeTab = TAB_STATE;

    @track academicYearOptions = [];
    @track programOptions = [];
    @track programPlanOptions = [];
    @track termOptions = [];

    selectedAcademicYear = '';
    selectedProgramId = '';
    selectedProgramPlanId = '';
    selectedTermId = '';
    selectedStatusScope = 'ADMITTED';

    loadingYears = true;
    loadingPrograms = true;
    loadingProgramPlans = false;
    loadingTerms = false;
    loading = false;
    error;

    @track grid;
    @track dashboard;
    loadingDashboard = false;
    searchTerm = '';

    // Report output is keyed by tab so switching back to a report already run shows it
    // again instead of blanking out and forcing another round trip.
    gridsByTab = {};

    async connectedCallback() {
        try {
            const [years, programs] = await Promise.all([getAcademicYearOptions(), getProgramOptions()]);
            this.academicYearOptions = [{ label: 'All Academic Years', value: '' }].concat(years || []);
            this.programOptions = [{ label: 'All Programs', value: '' }].concat(programs || []);
        } catch (e) {
            this.error = this.reduceError(e);
        } finally {
            this.loadingYears = false;
            this.loadingPrograms = false;
        }
        this.loadDashboard();
    }

    // ── Views (Dashboard / Reports) ──────────────────────────────────────────
    get viewTabs() {
        return VIEWS.map((v) => ({
            ...v,
            cssClass: v.key === this.activeView ? 'adr-tab adr-tab--active' : 'adr-tab'
        }));
    }
    get isDashboardView() { return this.activeView === VIEW_DASHBOARD; }
    get isReportsView() { return this.activeView === VIEW_REPORTS; }

    handleViewClick(event) {
        const view = event.currentTarget.dataset.view;
        if (!view || view === this.activeView) return;
        this.activeView = view;
        this.error = undefined;
        if (this.isDashboardView) {
            if (!this.dashboard) { this.loadDashboard(); }
            return;
        }
        // Entering Reports: show whatever that report last returned, or fetch it.
        this.grid = this.gridsByTab[this.activeTab];
        if (this.isResultTab && !this.programPlanOptions.length) { this.loadProgramPlans(); }
        if (!this.grid && !this.needsBatch) { this.loadReport(); }
    }

    // ── Report sub-tabs ──────────────────────────────────────────────────────
    get reportTabs() {
        return TABS.map((t) => ({
            ...t,
            cssClass: t.key === this.activeTab ? 'adr-subtab adr-subtab--active' : 'adr-subtab'
        }));
    }
    get isResultTab() { return this.activeTab === TAB_RESULT; }

    handleTabClick(event) {
        const tab = event.currentTarget.dataset.tab;
        if (!tab || tab === this.activeTab) return;
        this.activeTab = tab;
        this.searchTerm = '';
        this.error = undefined;
        this.grid = this.gridsByTab[tab];
        // The Batch picker only appears on Result Analysis, so it is filled the first
        // time that report is opened rather than on every Program/Year change.
        if (this.isResultTab && !this.programPlanOptions.length) { this.loadProgramPlans(); }
        // Result Analysis needs a Batch; the other two run unscoped, so show something
        // immediately rather than an empty panel the user has to click to fill.
        if (!this.grid && !this.needsBatch) { this.loadReport(); }
    }

    // ── Filters ──────────────────────────────────────────────────────────────
    // Result Analysis is the only view scoped by Batch rather than by admission status.
    get isResultReport() { return this.isReportsView && this.isResultTab; }
    get showStatusFilter() { return !this.isResultReport; }
    get showBatchFilter() { return this.isResultReport; }
    get statusScopeOptions() { return STATUS_SCOPES; }
    get disableTerm() { return !this.selectedProgramPlanId; }
    get disableApply() { return this.needsBatch; }
    get needsBatch() { return this.isResultReport && !this.selectedProgramPlanId; }
    get hasAnyFilterSelected() {
        return !!(
            this.selectedAcademicYear ||
            this.selectedProgramId ||
            this.selectedProgramPlanId ||
            this.selectedTermId ||
            this.selectedStatusScope !== 'ADMITTED'
        );
    }

    async handleAcademicYearChange(event) {
        this.selectedAcademicYear = event.detail.value;
        this.resetBatchSelection();
        if (this.isResultReport) { await this.loadProgramPlans(); }
    }

    async handleProgramChange(event) {
        this.selectedProgramId = event.detail.value;
        this.resetBatchSelection();
        if (this.isResultReport) { await this.loadProgramPlans(); }
    }

    handleStatusScopeChange(event) {
        this.selectedStatusScope = event.detail.value;
    }

    async handleProgramPlanChange(event) {
        this.selectedProgramPlanId = event.detail.value;
        this.selectedTermId = '';
        this.termOptions = [];
        await this.loadSemesters();
    }

    handleTermChange(event) {
        this.selectedTermId = event.detail.value;
    }

    resetBatchSelection() {
        this.selectedProgramPlanId = '';
        this.selectedTermId = '';
        this.programPlanOptions = [];
        this.termOptions = [];
    }

    async loadProgramPlans() {
        this.loadingProgramPlans = true;
        try {
            const plans = await getProgramPlanOptions({
                programId: this.selectedProgramId || null,
                academicYear: this.selectedAcademicYear || null
            });
            this.programPlanOptions = plans || [];
        } catch (e) {
            this.programPlanOptions = [];
            this.toast('Could not load Batches', this.reduceError(e), 'error');
        } finally {
            this.loadingProgramPlans = false;
        }
    }

    async loadSemesters() {
        if (!this.selectedProgramPlanId) { this.termOptions = []; return; }
        this.loadingTerms = true;
        try {
            const terms = await getSemesterOptions({ programPlanId: this.selectedProgramPlanId });
            this.termOptions = [{ label: 'All Semesters', value: '' }].concat(terms || []);
        } catch (e) {
            this.termOptions = [];
            this.toast('Could not load Semesters', this.reduceError(e), 'error');
        } finally {
            this.loadingTerms = false;
        }
    }

    // Apply / Refresh re-fetches only the view in front of the user; the other view is
    // dropped so it reloads under the new filters next time it is opened, rather than
    // showing figures from the previous scope.
    handleApply() {
        if (this.disableApply) return;
        if (this.isDashboardView) {
            this.gridsByTab = {};
            this.grid = undefined;
            this.loadDashboard();
        } else {
            this.dashboard = undefined;
            this.loadReport();
        }
    }

    handleClearAllFilters() {
        this.selectedAcademicYear = '';
        this.selectedProgramId = '';
        this.selectedStatusScope = 'ADMITTED';
        this.resetBatchSelection();
        this.searchTerm = '';
        this.gridsByTab = {};
        this.grid = undefined;
        this.dashboard = undefined;
        if (this.isDashboardView) { this.loadDashboard(); }
        else if (!this.needsBatch) { this.loadReport(); }
    }

    // ── Dashboard ────────────────────────────────────────────────────────────
    loadDashboard() {
        this.loadingDashboard = true;
        this.error = undefined;
        getAdmissionDashboard({
            academicYear: this.selectedAcademicYear || null,
            programId: this.selectedProgramId || null,
            statusScope: this.selectedStatusScope
        })
            .then((data) => { this.dashboard = data; })
            .catch((e) => {
                this.error = this.reduceError(e);
                this.dashboard = undefined;
            })
            .finally(() => { this.loadingDashboard = false; });
    }

    get hasDashboard() { return !!(this.dashboard && this.dashboard.totalAdmissions > 0); }

    get kpiTiles() {
        const d = this.dashboard;
        if (!d) return [];
        const tiles = [
            { key: 'total', label: 'Total Admissions', value: this.fmt(d.totalAdmissions), accent: 'a' },
            { key: 'programmes', label: 'Programmes', value: this.fmt(d.programmeCount), accent: 'b' },
            {
                key: 'intake',
                label: 'Approved Intake',
                value: this.fmt(d.approvedIntake),
                hint: d.approvedIntake > 0 ? `${this.fmt(d.fillRate)}% filled` : 'not recorded',
                accent: 'c'
            },
            {
                key: 'karnataka',
                label: 'Karnataka',
                value: this.fmt(d.karnataka),
                hint: this.share(d.karnataka, d.totalAdmissions),
                accent: 'b'
            },
            {
                key: 'nonKarnataka',
                label: 'Non-Karnataka',
                value: this.fmt(d.nonKarnataka),
                hint: this.share(d.nonKarnataka, d.totalAdmissions),
                accent: 'd'
            },
            {
                key: 'male',
                label: 'Male',
                value: this.fmt(d.male),
                hint: this.share(d.male, d.totalAdmissions),
                accent: 'a'
            },
            {
                key: 'female',
                label: 'Female',
                value: this.fmt(d.female),
                hint: this.share(d.female, d.totalAdmissions),
                accent: 'e'
            }
        ];
        // Only worth a tile when there is something in it — it is a data-quality signal,
        // not a category, so it should not sit at zero taking up space.
        const unknown = (d.stateNotSpecified || 0) + (d.genderNotSpecified || 0);
        if (unknown > 0) {
            tiles.push({
                key: 'unknown',
                label: 'Missing State / Gender',
                value: this.fmt(d.stateNotSpecified) + ' / ' + this.fmt(d.genderNotSpecified),
                hint: 'not recorded on the Contact',
                accent: 'f'
            });
        }
        return tiles.map((t) => ({ ...t, cssClass: `adr-kpi adr-kpi--${t.accent}` }));
    }

    /**
     * One chart per question, and the form follows the question rather than the
     * template: magnitude across many long-named programmes is a horizontal bar chart,
     * a two-or-three-way split of one total is a donut, a breakdown that has to add up
     * is a stacked bar, and a short magnitude comparison is a column chart.
     */
    get dashboardCharts() {
        const d = this.dashboard;
        if (!d) return [];
        return [
            this.barChart('prog', 'Admissions by Programme', d.byProgramme, 'No admissions in scope.'),
            this.donutChart('state', 'Karnataka vs Non-Karnataka', d.byState, 'No state recorded on any Contact.', SLOTS.state),
            this.stackedChart('cat', 'Admissions by Category', d.byCategory, 'No category recorded on any Contact.', SLOTS.category),
            this.donutChart('gender', 'Admissions by Gender', d.byGender, 'No gender recorded on any Contact.', SLOTS.gender),
            this.columnChart('level', 'UG vs PG', d.byLevel, 'No programme level recorded.')
        ];
    }

    chartShell(key, title, points, empty, type) {
        const pts = (points || []).filter((p) => Number(p.value) > 0);
        return {
            key,
            title,
            emptyMessage: empty,
            hasData: pts.length > 0,
            isBar: type === 'bar',
            isDonut: type === 'donut',
            isStacked: type === 'stacked',
            isColumn: type === 'column',
            points: pts,
            total: pts.reduce((s, p) => s + Number(p.value), 0)
        };
    }

    /** "Not Specified" always takes the grey; every other label keeps its pinned slot. */
    colorFor(label, slots) {
        if (label === NOT_SPECIFIED) return NO_DATA_COLOR;
        const slot = slots && slots[label];
        return SERIES_COLORS[(slot === undefined ? 0 : slot) % SERIES_COLORS.length];
    }

    // Horizontal bars — no track behind them. A track reads as "progress toward a
    // target", and there is no target here; the bar's own length is the whole message.
    barChart(key, title, points, empty) {
        const c = this.chartShell(key, title, points, empty, 'bar');
        const max = c.points.reduce((m, p) => Math.max(m, Number(p.value)), 0) || 1;
        c.bars = c.points.map((p, i) => ({
            key: `${key}-${i}`,
            label: p.label,
            value: this.fmt(p.value),
            style: `width:${Math.max(1.5, (Number(p.value) / max) * 100)}%;background:${MAGNITUDE_COLOR};`
        }));
        return c;
    }

    // Vertical columns growing from a shared baseline, value on the cap.
    columnChart(key, title, points, empty) {
        const c = this.chartShell(key, title, points, empty, 'column');
        const max = c.points.reduce((m, p) => Math.max(m, Number(p.value)), 0) || 1;
        c.columns = c.points.map((p, i) => ({
            key: `${key}-${i}`,
            label: p.label,
            value: this.fmt(p.value),
            style: `height:${Math.max(2, (Number(p.value) / max) * 100)}%;background:${
                p.label === NOT_SPECIFIED ? NO_DATA_COLOR : MAGNITUDE_COLOR
            };`
        }));
        return c;
    }

    // One bar, segments in proportion, 2px of surface between them doing the separating.
    stackedChart(key, title, points, empty, slots) {
        const c = this.chartShell(key, title, points, empty, 'stacked');
        c.segments = c.points.map((p, i) => {
            const color = this.colorFor(p.label, slots);
            const pct = (Number(p.value) / c.total) * 100;
            return {
                key: `${key}-${i}`,
                label: p.label,
                value: this.fmt(p.value),
                pct: `${pct < 1 ? pct.toFixed(1) : Math.round(pct)}%`,
                title: `${p.label}: ${this.fmt(p.value)}`,
                style: `flex:${Number(p.value)} 1 0;background:${color};`,
                swatchStyle: `background:${color};`
            };
        });
        return c;
    }

    // Donut — arcs computed here so the template stays declarative. A 1.5° gap between
    // slices is the surface doing the separating, same as the stacked bar.
    donutChart(key, title, points, empty, slots) {
        const c = this.chartShell(key, title, points, empty, 'donut');
        const { cx, cy, rOuter, rInner, gapDegrees } = DONUT;
        let angle = 0;
        c.slices = c.points.map((p, i) => {
            const color = this.colorFor(p.label, slots);
            const sweep = (Number(p.value) / c.total) * 360;
            // The separating gap is skipped on a slice too narrow to spare it — taking
            // 1.5° out of a 1° sliver puts its end before its start and the arc vanishes,
            // which is exactly how a small-but-real category would disappear from view.
            const gap = c.points.length > 1 && sweep > gapDegrees * 1.5 ? gapDegrees : 0;
            const start = angle + gap / 2;
            // A lone 360° slice has identical start and end points, which collapses the
            // arc to nothing — hold it just short of a full turn so the ring still draws.
            const end = Math.min(angle + Math.max(sweep - gap, 0.5), angle + 359.99);
            angle += sweep;
            return {
                key: `${key}-${i}`,
                label: p.label,
                value: this.fmt(p.value),
                pct: `${Math.round((Number(p.value) / c.total) * 100)}%`,
                title: `${p.label}: ${this.fmt(p.value)}`,
                d: this.arcPath(cx, cy, rOuter, rInner, start, end),
                fill: color,
                swatchStyle: `background:${color};`
            };
        });
        c.centerValue = this.fmt(c.total);
        return c;
    }

    arcPath(cx, cy, rOuter, rInner, startDeg, endDeg) {
        const polar = (r, deg) => {
            const a = ((deg - 90) * Math.PI) / 180;
            return [cx + r * Math.cos(a), cy + r * Math.sin(a)];
        };
        const largeArc = endDeg - startDeg > 180 ? 1 : 0;
        const [ox1, oy1] = polar(rOuter, startDeg);
        const [ox2, oy2] = polar(rOuter, endDeg);
        const [ix1, iy1] = polar(rInner, endDeg);
        const [ix2, iy2] = polar(rInner, startDeg);
        const n = (v) => Math.round(v * 100) / 100;
        return [
            `M ${n(ox1)} ${n(oy1)}`,
            `A ${rOuter} ${rOuter} 0 ${largeArc} 1 ${n(ox2)} ${n(oy2)}`,
            `L ${n(ix1)} ${n(iy1)}`,
            `A ${rInner} ${rInner} 0 ${largeArc} 0 ${n(ix2)} ${n(iy2)}`,
            'Z'
        ].join(' ');
    }

    get dashboardSourceNote() { return this.buildSourceNote(this.dashboard && this.dashboard.sourceFields); }
    get hasDashboardSourceNote() {
        const src = (this.dashboard && this.dashboard.sourceFields) || {};
        return Object.keys(src).length > 0;
    }

    share(part, whole) {
        if (!whole) return '';
        return `${Math.round((Number(part) / Number(whole)) * 100)}% of total`;
    }

    // ── Report ───────────────────────────────────────────────────────────────
    loadReport() {
        if (this.needsBatch) { this.grid = undefined; return; }
        const tab = this.activeTab;
        this.loading = true;
        this.error = undefined;

        let request;
        if (tab === TAB_RESULT) {
            request = getResultAnalysisReport({
                programPlanId: this.selectedProgramPlanId,
                termId: this.selectedTermId || null
            });
        } else {
            const args = {
                academicYear: this.selectedAcademicYear || null,
                programId: this.selectedProgramId || null,
                statusScope: this.selectedStatusScope
            };
            request = tab === TAB_STATE ? getStateWiseReport(args) : getCategoryWiseReport(args);
        }

        request
            .then((data) => {
                this.gridsByTab = { ...this.gridsByTab, [tab]: data };
                // Ignore a response for a report the user has already navigated away from.
                if (tab === this.activeTab) { this.grid = data; }
            })
            .catch((e) => {
                if (tab === this.activeTab) {
                    this.error = this.reduceError(e);
                    this.grid = undefined;
                }
            })
            .finally(() => {
                if (tab === this.activeTab) { this.loading = false; }
            });
    }

    get hasGrid() { return !!(this.grid && this.grid.rows && this.grid.rows.length); }
    get noDataMessage() {
        if (this.error) return 'The report could not be loaded — see the message above.';
        return this.isResultTab
            ? 'No Course Connections found for the selected Batch and Semester.'
            : 'No applications found for the selected filters.';
    }

    // ── Header cells ─────────────────────────────────────────────────────────
    get headerRow1() {
        if (!this.grid) return [];
        return (this.grid.headerRow1 || []).map((h, i) => ({
            key: `h1-${i}`,
            label: h.label,
            colspan: h.colspan,
            rowspan: this.hasHeaderRow2 ? h.rowspan : 1,
            cssClass: h.colspan > 1 ? 'adr-th adr-th-group' : 'adr-th'
        }));
    }
    get headerRow2() {
        if (!this.grid) return [];
        return (this.grid.headerRow2 || []).map((h, i) => ({ key: `h2-${i}`, label: h.label }));
    }
    get hasHeaderRow2() { return !!(this.grid && this.grid.headerRow2 && this.grid.headerRow2.length); }

    // ── Body rows ────────────────────────────────────────────────────────────
    get filteredRows() {
        const rows = (this.grid && this.grid.rows) || [];
        const q = (this.searchTerm || '').trim().toLowerCase();
        if (!q) return rows;
        return rows.filter((r) => (r.cells || []).some((c) => String(c).toLowerCase().includes(q)));
    }

    get displayRows() {
        return this.filteredRows.map((r) => ({
            id: r.id,
            cells: (r.cells || []).map((v, i) => ({
                key: `${r.id}-${i}`,
                value: v,
                cssClass: this.isNumeric(v) ? 'adr-td adr-td-num' : 'adr-td'
            }))
        }));
    }

    get hasTotalsRow() {
        // Totals describe the whole report, so they are hidden while a search is
        // narrowing the rows rather than left to contradict what is on screen.
        return !!(this.grid && this.grid.totalsRow && this.grid.totalsRow.length && !this.searchTerm);
    }
    get totalCells() {
        if (!this.grid) return [];
        return (this.grid.totalsRow || []).map((v, i) => ({
            key: `tot-${i}`,
            value: v,
            cssClass: this.isNumeric(v) ? 'adr-total-cell adr-td-num' : 'adr-total-cell'
        }));
    }

    get isEmptyResult() { return this.hasGrid && this.displayRows.length === 0; }
    get disableExport() { return this.displayRows.length === 0; }
    get rowCountLabel() {
        const shown = this.displayRows.length;
        const total = this.hasGrid ? this.grid.rows.length : 0;
        return shown === total ? `${shown} rows` : `${shown} of ${total} rows`;
    }

    // Names the Contact field behind each demographic column — an empty column means
    // something different when the field is missing than when it is merely unfilled.
    get sourceNote() { return this.buildSourceNote(this.grid && this.grid.sourceFields); }

    buildSourceNote(sourceFields) {
        const src = sourceFields || {};
        const parts = Object.keys(src).map((k) => {
            const label = FIELD_LABELS[k] || k;
            return src[k] ? `${label}: ${src[k]}` : `${label}: no field found on Contact`;
        });
        return `Counted from — ${parts.join(' · ')}`;
    }
    get hasSourceNotes() {
        const src = (this.grid && this.grid.sourceFields) || {};
        return Object.keys(src).length > 0;
    }

    handleSearch(event) { this.searchTerm = event.target.value; }
    handleClearSearch() {
        this.searchTerm = '';
        const input = this.template.querySelector('[data-id="searchInput"]');
        if (input) { input.value = ''; }
    }

    // ── Export ───────────────────────────────────────────────────────────────
    get exportTitle() {
        const scope = this.grid && this.grid.scopeLabel ? ` - ${this.grid.scopeLabel}` : '';
        return `${(this.grid && this.grid.title) || 'Admission Report'}${scope}`;
    }

    /**
     * CSV, not .xls: it opens straight into Excel and is far more reliably downloadable
     * from inside a Lightning iframe. The Blob is typed 'application/octet-stream'
     * because Lightning Web Security rejects 'text/csv' as an unsupported Blob MIME
     * type; the browser names the file from `download`, so it still saves as a .csv.
     */
    handleExport() {
        if (this.disableExport) return;
        try {
            this.saveToFile(this.buildCsv(), 'application/octet-stream', 'csv');
            this.toast('Report exported', `${this.exportTitle} downloaded.`, 'success');
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('Export failed', e);
            this.toast('Export failed', e && e.message ? e.message : 'Unexpected error while exporting.', 'error');
        }
    }

    csvRows() {
        const labels = (this.grid && this.grid.columnLabels) || [];
        const rows = [];
        const titleRow = new Array(labels.length).fill('');
        titleRow[0] = this.exportTitle;
        rows.push(titleRow);
        rows.push(labels);
        this.displayRows.forEach((r) => rows.push(r.cells.map((c) => c.value)));
        if (this.hasTotalsRow) { rows.push(this.grid.totalsRow); }
        return rows;
    }

    csvCell(value) {
        const v = value === null || value === undefined ? '' : String(value);
        return `"${v.replace(/"/g, '""')}"`;
    }
    buildCsv() {
        const lines = this.csvRows().map((cells) => cells.map((c) => this.csvCell(c)).join(','));
        return '﻿' + lines.join('\r\n'); // BOM so Excel reads it as UTF-8
    }

    // A fresh anchor appended to the body, clicked once and removed — a reused
    // template-hosted anchor is not reliably treated as a genuine download in every
    // Lightning Experience session (same pattern as Salesforce's lwc-recipes sample).
    saveToFile(content, mime, ext) {
        const stamp = new Date().toISOString().slice(0, 10);
        const safeName = (this.exportTitle || 'export').replace(/[^a-z0-9]+/gi, '_').slice(0, 90);
        const blob = new Blob([content], { type: mime });
        const url = URL.createObjectURL(blob);

        const link = document.createElement('a');
        link.href = url;
        link.download = `${safeName}_${stamp}.${ext}`;
        link.style.display = 'none';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        setTimeout(() => URL.revokeObjectURL(url), 4000);
    }

    // ── Utils ────────────────────────────────────────────────────────────────
    isNumeric(v) {
        if (v === null || v === undefined || v === '') return false;
        return /^-?[\d,]+(\.\d+)?%?$/.test(String(v).trim());
    }
    fmt(n) {
        const num = Number(n);
        if (Number.isNaN(num)) return n == null ? '0' : String(n);
        return Number.isInteger(num) ? num.toLocaleString() : num.toLocaleString(undefined, { maximumFractionDigits: 2 });
    }
    toast(title, message, variant) { this.dispatchEvent(new ShowToastEvent({ title, message, variant })); }
    reduceError(error) {
        if (Array.isArray(error?.body)) return error.body.map((e) => e.message).join(', ');
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'Something went wrong.';
    }
}