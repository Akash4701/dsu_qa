import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAcademicProgramOptions from '@salesforce/apex/ExamReportCenterController.getAcademicProgramOptions';
import getProgramPlanOptions from '@salesforce/apex/ExamReportCenterController.getProgramPlanOptions';
import getSemesterOptions from '@salesforce/apex/ExamReportCenterController.getSemesterOptions';
import getStudentResultReport from '@salesforce/apex/ExamReportCenterController.getStudentResultReport';
import getDashboardSummary from '@salesforce/apex/ExamReportCenterController.getDashboardSummary';

const DONUT_COLORS = ['#2e844a', '#ea001e', '#ffb75d', '#706e6b'];
const BAR_COLORS = ['#0176d3', '#2e844a', '#ffb75d', '#9050e9', '#ea001e', '#706e6b'];

/**
 * examReportCenter
 * ─────────────────
 * Single LWC, two views (Dashboard / Reports) toggled internally — see
 * ExamReportCenterController.cls for the data-model notes. The Reports view
 * renders the one report format the client shared (a per-student, per-course
 * pivot: USN, Student Name, then CIA/SEE/Total Marks/Results/Grade Letter/Grade
 * Point repeated for every course code in the selected Program Plan + Semester)
 * and exports exactly what is on screen — filtered/searched/sorted — to Excel.
 *
 * Filters cascade Program → Program Plan → Semester (each level clears/reloads
 * everything downstream of it), and data is only fetched once all three are
 * picked and Apply/Refresh is clicked — never automatically on every change.
 */
export default class ExamReportCenter extends LightningElement {
    @api cardTitle = 'Exam Report Center';

    activeTab = 'dashboard';

    @track programOptions = [];
    @track programPlanOptions = [];
    @track termOptions = [];
    selectedProgramId = '';
    selectedProgramPlanId = '';
    selectedTermId = '';

    loadingPrograms = true;
    loadingProgramPlans = false;
    loadingTerms = false;
    loadingReport = false;
    loadingDashboard = false;
    error;

    @track reportData;
    @track dashboardData;

    searchTerm = '';
    sortColIndex = -1;
    sortDir = 'asc';

    async connectedCallback() {
        try {
            const programs = await getAcademicProgramOptions();
            this.programOptions = programs || [];
            this.loadingPrograms = false;
            // Load an unscoped dashboard summary as a default overview — the Reports
            // tab itself stays empty until Program, Program Plan and Semester are all
            // picked and Apply/Refresh is clicked.
            this.loadDashboard();
        } catch (e) {
            this.loadingPrograms = false;
            this.error = this.reduceError(e);
        }
    }

    // ── Tabs ─────────────────────────────────────────────────────────────────
    get isDashboardTab() { return this.activeTab === 'dashboard'; }
    get isReportsTab() { return this.activeTab === 'reports'; }
    get dashboardTabClass() { return this.isDashboardTab ? 'erc-tab erc-tab--active' : 'erc-tab'; }
    get reportsTabClass() { return this.isReportsTab ? 'erc-tab erc-tab--active' : 'erc-tab'; }
    handleTabClick(event) {
        const tab = event.currentTarget.dataset.tab;
        if (tab && tab !== this.activeTab) { this.activeTab = tab; }
    }

    // ── Filters — Program → Program Plan → Semester ─────────────────────────
    get selectedProgramLabel() {
        const p = this.programOptions.find((o) => o.value === this.selectedProgramId);
        return p ? p.label : '';
    }
    get selectedProgramPlanLabel() {
        const p = this.programPlanOptions.find((o) => o.value === this.selectedProgramPlanId);
        return p ? p.label : '';
    }
    get selectedTermLabel() {
        const t = this.termOptions.find((o) => o.value === this.selectedTermId);
        return t ? t.label : '';
    }
    get disableProgramPlan() { return !this.selectedProgramId; }
    get disableTerm() { return !this.selectedProgramPlanId; }
    get disableApply() { return !(this.selectedProgramId && this.selectedProgramPlanId && this.selectedTermId); }
    get hasAnyFilterSelected() {
        return !!(this.selectedProgramId || this.selectedProgramPlanId || this.selectedTermId);
    }
    // Reports empty-state gate: nothing loads until all three filters are picked
    // and Apply/Refresh is clicked (reportData stays undefined until then).
    get filtersIncomplete() { return this.disableApply; }

    async handleProgramChange(event) {
        this.selectedProgramId = event.detail.value;
        this.selectedProgramPlanId = '';
        this.selectedTermId = '';
        this.programPlanOptions = [];
        this.termOptions = [];
        this.reportData = undefined;
        this.resetTableState();
        await this.loadProgramPlans();
    }

    async handleProgramPlanChange(event) {
        this.selectedProgramPlanId = event.detail.value;
        this.selectedTermId = '';
        this.termOptions = [];
        this.reportData = undefined;
        this.resetTableState();
        await this.loadSemesters();
    }

    handleTermChange(event) {
        this.selectedTermId = event.detail.value;
        this.reportData = undefined;
        this.resetTableState();
    }

    resetTableState() {
        this.searchTerm = '';
        this.sortColIndex = -1;
        this.sortDir = 'asc';
    }

    async loadProgramPlans() {
        if (!this.selectedProgramId) { this.programPlanOptions = []; return; }
        this.loadingProgramPlans = true;
        try {
            this.programPlanOptions = (await getProgramPlanOptions({ programId: this.selectedProgramId })) || [];
        } catch (e) {
            this.programPlanOptions = [];
            this.toast('Could not load Program Plans', this.reduceError(e), 'error');
        } finally {
            this.loadingProgramPlans = false;
        }
    }

    async loadSemesters() {
        if (!this.selectedProgramPlanId) { this.termOptions = []; return; }
        this.loadingTerms = true;
        try {
            this.termOptions = (await getSemesterOptions({ programPlanId: this.selectedProgramPlanId })) || [];
        } catch (e) {
            this.termOptions = [];
            this.toast('Could not load Semesters', this.reduceError(e), 'error');
        } finally {
            this.loadingTerms = false;
        }
    }

    // Apply/Refresh — the only action that loads (or re-loads) data, once all
    // three filters are selected.
    handleApply() {
        if (this.disableApply) return;
        this.loadReport();
        this.loadDashboard();
    }

    // Clear Filters — resets Program, Program Plan and Semester, and clears the report.
    handleClearAllFilters() {
        this.selectedProgramId = '';
        this.selectedProgramPlanId = '';
        this.selectedTermId = '';
        this.programPlanOptions = [];
        this.termOptions = [];
        this.reportData = undefined;
        this.resetTableState();
        this.loadDashboard();
    }

    // ── Report data ──────────────────────────────────────────────────────────
    loadReport() {
        if (this.disableApply) { this.reportData = undefined; return; }
        this.loadingReport = true;
        this.error = undefined;
        getStudentResultReport({ programPlanId: this.selectedProgramPlanId, termId: this.selectedTermId })
            .then((data) => {
                this.reportData = data;
                this.loadingReport = false;
            })
            .catch((e) => {
                this.error = this.reduceError(e);
                this.reportData = undefined;
                this.loadingReport = false;
            });
    }

    get hasReportData() { return !!(this.reportData && this.reportData.rows && this.reportData.rows.length); }
    get reportLoadedNoRows() { return this.reportData && (!this.reportData.rows || this.reportData.rows.length === 0); }

    // Flat leaf columns: USN, Student Name, then <course> <subcolumn> repeated.
    get subColumns() { return this.reportData ? this.reportData.subColumns : []; }
    get courseCodes() { return this.reportData ? this.reportData.courseCodes : []; }

    get courseGroups() {
        if (!this.hasReportData) return [];
        const span = this.subColumns.length;
        return this.courseCodes.map((code, i) => ({
            key: `grp-${i}`,
            code,
            title: this.reportData.courseTitles && this.reportData.courseTitles[i] ? this.reportData.courseTitles[i] : code,
            span
        }));
    }

    get subHeaderCells() {
        if (!this.hasReportData) return [];
        const cells = [];
        this.courseCodes.forEach((code, ci) => {
            this.subColumns.forEach((s, si) => {
                cells.push({ key: `sh-${ci}-${si}`, label: s });
            });
        });
        return cells;
    }

    // Each row flattened to [usn, name, ...perCourseValues] aligned to subHeaderCells + 2.
    get flatRows() {
        if (!this.reportData || !this.reportData.rows) return [];
        return this.reportData.rows.map((r) => {
            const values = [];
            (r.cells || []).forEach((c) => {
                values.push(c.cia || '', c.see || '', c.total || '', c.result || '', c.grade || '', c.gradePoint || '');
            });
            return { id: r.id, usn: r.usn || '', studentName: r.studentName || '', program: r.program || '', values };
        });
    }

    get filteredRows() {
        const q = (this.searchTerm || '').trim().toLowerCase();
        if (!q) return this.flatRows;
        return this.flatRows.filter((row) => {
            if (row.usn.toLowerCase().includes(q)) return true;
            if (row.studentName.toLowerCase().includes(q)) return true;
            return row.values.some((v) => String(v).toLowerCase().includes(q));
        });
    }

    get sortedRows() {
        const rows = this.filteredRows;
        if (this.sortColIndex < 0) return rows;
        const idx = this.sortColIndex;
        const dir = this.sortDir === 'desc' ? -1 : 1;
        const valueOf = (row) => (idx === 0 ? row.usn : idx === 1 ? row.studentName : row.values[idx - 2] || '');
        return [...rows].sort((a, b) => {
            const av = valueOf(a);
            const bv = valueOf(b);
            const an = this.num(av);
            const bn = this.num(bv);
            if (!Number.isNaN(an) && !Number.isNaN(bn)) return (an - bn) * dir;
            return String(av).localeCompare(String(bv), undefined, { numeric: true }) * dir;
        });
    }

    // Body rows shaped for the template (usn/name pinned, rest as an iterable list).
    get displayRows() {
        return this.sortedRows.map((row) => ({
            id: row.id,
            usn: row.usn,
            studentName: row.studentName,
            cells: row.values.map((v, i) => ({ key: `${row.id}-${i}`, value: v }))
        }));
    }

    get headerCells() {
        const base = [
            { key: 'usn', label: 'USN', idx: 0 },
            { key: 'name', label: 'Student Name', idx: 1 }
        ];
        return base;
    }

    handleSort(event) {
        const idx = Number(event.currentTarget.dataset.idx);
        if (Number.isNaN(idx)) return;
        if (this.sortColIndex === idx) {
            this.sortDir = this.sortDir === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortColIndex = idx;
            this.sortDir = 'asc';
        }
    }
    sortArrow(idx) {
        if (this.sortColIndex !== idx) return '';
        return this.sortDir === 'asc' ? ' ▲' : ' ▼';
    }
    get usnSortLabel() { return `USN${this.sortArrow(0)}`; }
    get nameSortLabel() { return `Student Name${this.sortArrow(1)}`; }

    get columnCount() { return 2 + this.subHeaderCells.length; }
    get rowCountLabel() {
        const shown = this.displayRows.length;
        const total = this.hasReportData ? this.reportData.rows.length : 0;
        return shown === total
            ? `${shown.toLocaleString()} ${shown === 1 ? 'student' : 'students'}`
            : `${shown.toLocaleString()} of ${total.toLocaleString()} students`;
    }
    get isEmptyResult() { return this.hasReportData && this.displayRows.length === 0; }
    get disableExport() { return this.displayRows.length === 0; }

    handleSearch(event) { this.searchTerm = event.target.value; }
    handleClearFilters() {
        this.searchTerm = '';
        const search = this.template.querySelector('[data-id="searchInput"]');
        if (search) { search.value = ''; }
    }
    get hasActiveFilter() { return !!this.searchTerm; }

    // ── Export — exactly the filtered/sorted rows currently on screen ─────────
    get exportTitle() {
        const plan = this.selectedProgramPlanLabel || 'Program Plan';
        const term = this.selectedTermLabel || 'Semester';
        return `Student Result Sheet - ${plan} - ${term}`;
    }
    // Shown on the report itself, per the client's ask to see the selected
    // Program Plan and Semester Name on the report (not just in the filter bar).
    get reportScopeLabel() {
        return `${this.selectedProgramPlanLabel} · ${this.selectedTermLabel}`;
    }

    // A single export action — CSV opens directly in Excel and is far more reliably
    // downloadable from inside a Lightning iframe than the old HTML/.xls trick.
    //
    // The Blob's MIME type is 'application/octet-stream', not 'text/csv': Lightning
    // Web Security only allows Blobs to be created with a small allow-listed set of
    // MIME types, and 'text/csv' throws "Unsupported MIME type" under LWS. The
    // browser saves the file by the `download` filename, not the Blob's internal
    // type, so this still downloads a proper .csv that opens correctly in Excel.
    handleExportExcel() {
        if (this.disableExport) return;
        try {
            const csv = this.buildCsv();
            this.saveToFile(csv, 'application/octet-stream', 'csv');
            this.toast('Report exported', `${this.exportTitle} downloaded.`, 'success');
        } catch (e) {
            // Surface the real cause instead of failing silently.
            // eslint-disable-next-line no-console
            console.error('Export Excel failed', e);
            this.toast('Export failed', e && e.message ? e.message : 'Unexpected error while exporting.', 'error');
        }
    }

    // Row shape mirrors the client-shared CSV exactly: title row, a course-code
    // row (code once, blank for the rest of its span), then the sub-column row.
    csvRows() {
        const rows = [];
        const totalCols = 2 + this.subHeaderCells.length;
        const titleRow = new Array(totalCols).fill('');
        titleRow[0] = this.exportTitle;
        rows.push(titleRow);

        const courseRow = ['USN', 'Student Name'];
        this.courseGroups.forEach((g) => {
            courseRow.push(g.code);
            for (let i = 1; i < g.span; i++) { courseRow.push(''); }
        });
        rows.push(courseRow);

        const subRow = ['', ''].concat(this.subHeaderCells.map((c) => c.label));
        rows.push(subRow);

        this.displayRows.forEach((row) => {
            rows.push([row.usn, row.studentName].concat(row.cells.map((c) => c.value)));
        });
        return rows;
    }

    csvCell(value) {
        const v = value == null ? '' : String(value);
        return `"${v.replace(/"/g, '""')}"`;
    }
    buildCsv() {
        const lines = this.csvRows().map((cells) => cells.map((c) => this.csvCell(c)).join(','));
        return '﻿' + lines.join('\r\n'); // BOM so Excel opens UTF-8 correctly
    }

    /**
     * Trigger a browser download from a Blob. A *reused* template-hosted anchor,
     * mutated and re-clicked, is not reliably picked up as a genuine download in
     * every Lightning Experience session — so this creates a fresh <a>, appends it
     * to the body (same pattern as Salesforce's own lwc-recipes fileDownload
     * sample), clicks it once, then removes it.
     */
    saveToFile(content, mime, ext) {
        const stamp = new Date().toISOString().slice(0, 10);
        const safeName = (this.exportTitle || 'export').replace(/[^a-z0-9]+/gi, '_');
        const fileName = `${safeName}_${stamp}.${ext}`;
        const blob = new Blob([content], { type: mime });
        const url = URL.createObjectURL(blob);

        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;
        link.style.display = 'none';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        // Release the object URL once the download has had time to start.
        setTimeout(() => URL.revokeObjectURL(url), 4000);
    }

    // ── Dashboard data ───────────────────────────────────────────────────────
    // Scoped to the selected Program Plan + Semester once both are chosen;
    // otherwise shows an unscoped, all-data overview (its own default state).
    loadDashboard() {
        this.loadingDashboard = true;
        const scoped = this.selectedProgramPlanId && this.selectedTermId;
        getDashboardSummary({
            programPlanId: scoped ? this.selectedProgramPlanId : null,
            termId: scoped ? this.selectedTermId : null
        })
            .then((data) => {
                this.dashboardData = data;
                this.loadingDashboard = false;
            })
            .catch((e) => {
                this.loadingDashboard = false;
                this.toast('Dashboard failed to load', this.reduceError(e), 'error');
            });
    }

    get hasDashboardData() { return !!this.dashboardData; }

    get kpiTiles() {
        if (!this.dashboardData) return [];
        const d = this.dashboardData;
        const tiles = [
            { key: 'students', label: 'Students', value: this.fmt(d.totalStudents), accent: 'a' },
            { key: 'results', label: 'Results Recorded', value: this.fmt(d.totalResults), accent: 'b' },
            { key: 'pass', label: 'Passed', value: this.fmt(d.passCount), accent: 'c' },
            { key: 'fail', label: 'Failed', value: this.fmt(d.failCount), accent: 'd' },
            { key: 'passPct', label: 'Pass %', value: `${this.fmt(d.passPercentage)}%`, accent: 'a' },
            { key: 'avgMarks', label: 'Average Total Marks', value: this.fmt(d.averageMarks), accent: 'b' },
            { key: 'avgSgpa', label: 'Average SGPA', value: this.fmt(d.averageSgpa), accent: 'c' },
            { key: 'ciaUp', label: 'CIA Uploaded', value: `${this.fmt(d.ciaUploadPercentage)}%`, accent: 'e' },
            { key: 'seeUp', label: 'SEE Uploaded', value: `${this.fmt(d.seeUploadPercentage)}%`, accent: 'e' },
            { key: 'cycles', label: 'Exam Cycles (Active)', value: `${this.fmt(d.totalExamCycles)} (${this.fmt(d.activeExamCycles)})`, accent: 'd' }
        ];
        return tiles.map((t) => ({ ...t, cssClass: `erc-kpi erc-kpi--${t.accent}` }));
    }

    barChart(points) {
        const pts = points || [];
        const max = pts.reduce((m, p) => Math.max(m, Number(p.value) || 0), 0) || 1;
        return pts.map((p, i) => ({
            key: `${p.label}-${i}`,
            label: p.label,
            value: this.fmt(p.value),
            widthStyle: `width:${Math.max(4, Math.round(((Number(p.value) || 0) / max) * 100))}%;background:${BAR_COLORS[i % BAR_COLORS.length]};`
        }));
    }
    get gradeBars() { return this.hasDashboardData ? this.barChart(this.dashboardData.gradeDistribution) : []; }
    get cycleBars() { return this.hasDashboardData ? this.barChart(this.dashboardData.examCyclesByType) : []; }
    get hasGradeBars() { return this.gradeBars.length > 0; }
    get hasCycleBars() { return this.cycleBars.length > 0; }

    get passFailTotal() {
        if (!this.hasDashboardData) return 0;
        return (this.dashboardData.passFail || []).reduce((s, p) => s + (Number(p.value) || 0), 0);
    }
    get passFailLegend() {
        if (!this.hasDashboardData) return [];
        const total = this.passFailTotal || 1;
        return (this.dashboardData.passFail || []).map((p, i) => ({
            key: `${p.label}-${i}`,
            label: p.label,
            value: this.fmt(p.value),
            pct: `${Math.round(((Number(p.value) || 0) / total) * 100)}%`,
            swatchStyle: `background:${DONUT_COLORS[i % DONUT_COLORS.length]};`
        }));
    }
    get passFailDonutStyle() {
        if (!this.hasDashboardData || this.passFailTotal === 0) {
            return `background: conic-gradient(#e5e5e5 0deg 360deg);`;
        }
        let acc = 0;
        const total = this.passFailTotal;
        const segments = (this.dashboardData.passFail || []).map((p, i) => {
            const start = (acc / total) * 360;
            acc += Number(p.value) || 0;
            const end = (acc / total) * 360;
            return `${DONUT_COLORS[i % DONUT_COLORS.length]} ${start}deg ${end}deg`;
        });
        return `background: conic-gradient(${segments.join(', ')});`;
    }
    get hasPassFailData() { return this.passFailTotal > 0; }

    // ── Utils ────────────────────────────────────────────────────────────────
    num(v) {
        const n = parseFloat(String(v).replace(/[^0-9.\-]/g, ''));
        return Number.isNaN(n) ? NaN : n;
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