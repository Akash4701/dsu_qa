import { LightningElement, track } from 'lwc';
import getFilterOptions         from '@salesforce/apex/SessionReportController.getFilterOptions';
import getDashboardStats        from '@salesforce/apex/SessionReportController.getDashboardStats';
import getStudentSummaryReport  from '@salesforce/apex/SessionReportController.getStudentSummaryReport';
import getStudentDetail         from '@salesforce/apex/SessionReportController.getStudentDetail';
import getStudentWeeklyActivity  from '@salesforce/apex/SessionReportController.getStudentWeeklyActivity';
import exportAllStudentsReport   from '@salesforce/apex/SessionReportController.exportAllStudentsReport';

const STATUS_OPTIONS = [
    { label: 'All',       value: '' },
    { label: 'Online',    value: 'Active' },
    { label: 'Completed', value: 'Completed' }
];

const PAGE_SIZE_OPTIONS = [
    { label: '10', value: '10' },
    { label: '25', value: '25' },
    { label: '50', value: '50' }
];

export default class StudentSessionReport extends LightningElement {

    @track filters      = { dateFrom: '', dateTo: '', programPlanId: '', studentSearch: '', statusFilter: '' };
    @track batchOptions = [{ label: 'All Batches', value: '' }];
    @track kpi          = { totalStudents: '0', studentsLoggedIn: '0', currentlyOnline: '0', totalSessions: '0', avgSession: '—' };
    @track reportData   = { rows: [], total: 0, totalPages: 1, pageNumber: 1, pageSize: 10 };

    // Detail data (shared between side panel and detail page)
    @track detail         = null;
    @track weeklyData     = [];
    @track weeklySummary  = {};
    _rawSessions          = [];

    // View state: 'list' | 'detail'
    @track currentView    = 'list';

    // Side panel (within list view)
    @track showDetail     = false;

    // Loading flags
    @track isTableLoading  = false;
    @track isDetailLoading = false;
    @track isExporting     = false;

    @track pageSize  = '10';
    @track sortField = 'lastLogout';
    @track sortDir   = 'desc';

    // Detail page pagination
    @track dpPage     = 1;
    dpPageSize        = 10;

    _searchDebounce   = null;
    _activeContactId  = null;
    _popstateHandler  = null;

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        const today = new Date();
        const from  = new Date(today);
        from.setDate(from.getDate() - 29);
        this.filters = {
            dateFrom: from.toISOString().split('T')[0],
            dateTo:   today.toISOString().split('T')[0],
            programPlanId: '', studentSearch: '', statusFilter: ''
        };
        this._popstateHandler = this._handlePopState.bind(this);
        window.addEventListener('popstate', this._popstateHandler);
        this._loadFilterOptions();
        this._loadStats();
        this._loadTable();
    }

    disconnectedCallback() {
        if (this._popstateHandler) {
            window.removeEventListener('popstate', this._popstateHandler);
        }
    }

    // ─── View Getters ─────────────────────────────────────────────────────────

    get isListView()        { return this.currentView === 'list'; }
    get isDetailView()      { return this.currentView === 'detail'; }
    get hasDetailPageData() { return this.isDetailView && !this.isDetailLoading && this.detail !== null; }

    // ─── Filter Handlers ─────────────────────────────────────────────────────

    handleDateFrom(evt)     { this.filters = { ...this.filters, dateFrom:     evt.target.value }; }
    handleDateTo(evt)       { this.filters = { ...this.filters, dateTo:       evt.target.value }; }
    handleStatusChange(evt) { this.filters = { ...this.filters, statusFilter: evt.detail.value }; }

    handleStudentSearch(evt) {
        this.filters = { ...this.filters, studentSearch: evt.target.value };
        window.clearTimeout(this._searchDebounce);
        this._searchDebounce = window.setTimeout(() => {
            this.reportData = { ...this.reportData, pageNumber: 1 };
            this._loadTable();
        }, 400);
    }

    handleSearch() {
        this.reportData = { ...this.reportData, pageNumber: 1 };
        this._loadStats();
        this._loadTable();
    }

    handleReset() {
        const today = new Date();
        const from  = new Date(today);
        from.setDate(from.getDate() - 29);
        this.filters = {
            dateFrom: from.toISOString().split('T')[0],
            dateTo:   today.toISOString().split('T')[0],
            programPlanId: '', studentSearch: '', statusFilter: ''
        };
        this.showDetail = false;
        this.detail     = null;
        this._activeContactId = null;
        this.reportData = { ...this.reportData, pageNumber: 1 };
        this._loadStats();
        this._loadTable();
    }

    // ─── Table Handlers ───────────────────────────────────────────────────────

    handleRowClick(evt) {
        const contactId = evt.currentTarget.dataset.contactid;
        if (contactId) this._openSidePanel(contactId);
    }

    // Eye icon → full detail page navigation
    handleViewDetail(evt) {
        evt.stopPropagation();
        const contactId = evt.currentTarget.dataset.contactid;
        if (!contactId) return;
        this._navigateToDetail(contactId);
    }

    handleSortFirstLogin() {
        this.sortField = 'firstLogin';
        this.sortDir   = this.sortField === 'firstLogin' && this.sortDir === 'desc' ? 'asc' : 'desc';
        this._sortRows();
    }

    handleSortLastLogout() {
        this.sortField = 'lastLogout';
        this.sortDir   = this.sortDir === 'desc' ? 'asc' : 'desc';
        this._sortRows();
    }

    handlePrev() {
        if (this.reportData.pageNumber > 1) {
            this.reportData = { ...this.reportData, pageNumber: this.reportData.pageNumber - 1 };
            this._loadTable();
        }
    }

    handleNext() {
        if (this.reportData.pageNumber < this.reportData.totalPages) {
            this.reportData = { ...this.reportData, pageNumber: this.reportData.pageNumber + 1 };
            this._loadTable();
        }
    }

    handlePageClick(evt) {
        const page = parseInt(evt.currentTarget.dataset.page, 10);
        if (!isNaN(page) && page !== this.reportData.pageNumber) {
            this.reportData = { ...this.reportData, pageNumber: page };
            this._loadTable();
        }
    }

    handlePageSizeChange(evt) {
        this.pageSize   = evt.detail.value;
        this.reportData = { ...this.reportData, pageNumber: 1 };
        this._loadTable();
    }

    // ─── Side Panel (list view) ───────────────────────────────────────────────

    handleCloseDetail() {
        this.showDetail       = false;
        this.detail           = null;
        this._activeContactId = null;
        this._rawSessions     = [];
        this.reportData       = { ...this.reportData, rows: this._clearSelected(this.reportData.rows) };
    }

    // ─── Detail Page Navigation ───────────────────────────────────────────────

    handleBack() {
        // Try browser back first; also set view directly as fallback
        this.currentView  = 'list';
        this.showDetail   = false;
        try { window.history.back(); } catch (e) { /* ignore */ }
    }

    _navigateToDetail(contactId) {
        this._activeContactId = contactId;
        this.currentView      = 'detail';
        this.showDetail       = false;
        this.isDetailLoading  = true;
        this.detail           = null;
        this.weeklyData       = [];
        this.weeklySummary    = {};
        this._rawSessions     = [];
        this.dpPage           = 1;

        // Push browser history entry for back button support
        try {
            window.history.pushState(
                { view: 'detail', contactId },
                '',
                window.location.href
            );
        } catch (e) { /* ignore in restricted contexts */ }

        // Highlight selected row
        this.reportData = {
            ...this.reportData,
            rows: this._markSelected(this.reportData.rows, contactId)
        };

        // Load ALL sessions for this student (no date filter on the detail page)
        getStudentDetail({
            contactId,
            dateFrom: null,
            dateTo:   null
        })
        .then(data => {
            this._rawSessions = data.timeline || [];
            this.detail       = this._processDetail(data);
        })
        .catch(e => console.error('getStudentDetail:', e))
        .finally(() => { this.isDetailLoading = false; });

        getStudentWeeklyActivity({ contactId })
            .then(data => {
                this.weeklyData    = this._processWeekly(data && data.days);
                this.weeklySummary = this._buildWeeklySummary(data && data.summary);
            })
            .catch(e => console.error('getStudentWeeklyActivity:', e));
    }

    _handlePopState(evt) {
        if (evt.state && evt.state.view === 'detail') {
            this.currentView = 'detail';
        } else {
            this.currentView = 'list';
        }
    }

    // ─── Export ───────────────────────────────────────────────────────────────

    handleExport() {
        this.isExporting = true;
        exportAllStudentsReport({
            dateFrom:     this.filters.dateFrom     || null,
            dateTo:       this.filters.dateTo       || null,
            statusFilter: this.filters.statusFilter || null
        })
        .then(data => {
            const headers = [
                'Student Name', 'Email', 'USN', 'University Email',
                'Program Name', 'Batch (Program Plan)', 'Current Semester',
                'Total Sessions', 'Total Hours', 'Last Login'
            ];
            const rows = (data || []).map(r => [
                this._csv(r.studentName),
                this._csv(r.email),
                this._csv(r.usn),
                this._csv(r.universityEmail),
                this._csv(r.programName),
                this._csv(r.batch),
                this._csv(r.semester),
                r.totalSessions || 0,
                this._csv(this._fmtDuration(r.totalMinutes)),
                this._csv(this._fmtDate(r.lastLogin))
            ].join(','));
            this._downloadCSV([headers.join(','), ...rows].join('\n'), 'All_Students_Session_Report.csv');
        })
        .catch(e => console.error('Export error:', e))
        .finally(() => { this.isExporting = false; });
    }

    handleDownloadStudentDetail() {
        if (!this.detail) return;
        const name     = this.detail.contactName || 'Student';
        const roll     = this.detail.rollNumber  || '';
        const sessions = this._rawSessions || [];

        const headers = ['Student Name','Roll No.','Date','Login Time','Logout Time','Duration (mins)','Status'];
        const rows = sessions.map(s => [
            this._csv(name), this._csv(roll),
            this._csv(this._fmtDate(s.loginTime)),
            this._csv(this._fmtTime(s.loginTime)),
            this._csv(s.logoutTime ? this._fmtTime(s.logoutTime) : 'Active'),
            s.durationMins != null ? Math.round(Number(s.durationMins)) : 0,
            this._csv(s.status === 'Active' ? 'Active' : 'Completed')
        ].join(','));

        const safeName = name.replace(/[^a-zA-Z0-9_-]/g, '_');
        this._downloadCSV([headers.join(','), ...rows].join('\n'), `${safeName}_Session_History.csv`);
    }

    // ─── Computed Getters ─────────────────────────────────────────────────────

    get statusOptions()   { return STATUS_OPTIONS; }
    get pageSizeOptions() { return PAGE_SIZE_OPTIONS; }

    get mainContentClass() { return 'sr-main'; }

    get hasRows()          { return this.reportData.rows && this.reportData.rows.length > 0; }
    get isPrevDisabled()   { return this.reportData.pageNumber <= 1; }
    get isNextDisabled()   { return this.reportData.pageNumber >= this.reportData.totalPages; }
    get hasDetailData()    { return this.showDetail && !this.isDetailLoading && this.detail !== null; }
    get hasTimeline()      { return this.detail && this.detail.timeline && this.detail.timeline.length > 0; }
    get hasSessionRows()   { return this.detail && this.detail.sessionRows && this.detail.sessionRows.length > 0; }

    // Detail page session table pagination
    get paginatedSessionRows() {
        if (!this.detail || !this.detail.sessionRows) return [];
        const start = (this.dpPage - 1) * this.dpPageSize;
        return this.detail.sessionRows.slice(start, start + this.dpPageSize);
    }

    get dpTotalPages()    { return Math.ceil(((this.detail && this.detail.sessionRows) ? this.detail.sessionRows.length : 0) / this.dpPageSize) || 1; }
    get dpIsPrevDisabled(){ return this.dpPage <= 1; }
    get dpIsNextDisabled(){ return this.dpPage >= this.dpTotalPages; }
    get dpTotalRows()     { return (this.detail && this.detail.sessionRows) ? this.detail.sessionRows.length : 0; }
    get dpShowingFrom()   { return this.dpTotalRows === 0 ? 0 : (this.dpPage - 1) * this.dpPageSize + 1; }
    get dpShowingTo()     { return Math.min(this.dpPage * this.dpPageSize, this.dpTotalRows); }

    handleDpPrev() { if (this.dpPage > 1) this.dpPage -= 1; }
    handleDpNext() { if (this.dpPage < this.dpTotalPages) this.dpPage += 1; }

    get showingFrom() {
        if (!this.reportData.total) return 0;
        return (this.reportData.pageNumber - 1) * parseInt(this.pageSize, 10) + 1;
    }
    get showingTo() {
        return Math.min(this.reportData.pageNumber * parseInt(this.pageSize, 10), this.reportData.total);
    }

    get pageNumbers() {
        const total = this.reportData.totalPages, current = this.reportData.pageNumber;
        const pages = [];
        let keyIdx  = 0;
        const addPage     = v  => pages.push({ key: `p-${keyIdx++}`, label: String(v), value: v, btnClass: v === current ? 'sr-page-btn sr-page-btn-active' : 'sr-page-btn', isEllipsis: false });
        const addEllipsis = () => pages.push({ key: `e-${keyIdx++}`, label: '...', value: null, btnClass: 'sr-page-ellipsis', isEllipsis: true });
        if (total <= 7) { for (let i = 1; i <= total; i++) addPage(i); }
        else {
            addPage(1);
            if (current > 3) addEllipsis();
            for (let i = Math.max(2, current - 1); i <= Math.min(total - 1, current + 1); i++) addPage(i);
            if (current < total - 2) addEllipsis();
            addPage(total);
        }
        return pages;
    }

    get sortIconFirstLogin() { return this.sortField !== 'firstLogin' ? '↕' : this.sortDir === 'asc' ? '↑' : '↓'; }
    get sortIconLastLogout()  { return this.sortField !== 'lastLogout'  ? '↕' : this.sortDir === 'asc' ? '↑' : '↓'; }

    // ─── Private: Data Loading ────────────────────────────────────────────────

    _loadFilterOptions() {
        getFilterOptions()
            .then(data => {
                const opts = [{ label: 'All Batches', value: '' }];
                if (data && data.batches) data.batches.forEach(b => opts.push({ label: b.label, value: b.value }));
                this.batchOptions = opts;
            })
            .catch(e => console.error('getFilterOptions:', e));
    }

    _loadStats() {
        getDashboardStats({ dateFrom: this.filters.dateFrom, dateTo: this.filters.dateTo })
            .then(data => {
                this.kpi = {
                    totalStudents:    this._fmt(data.totalStudents),
                    studentsLoggedIn: this._fmt(data.studentsLoggedIn),
                    currentlyOnline:  this._fmt(data.currentlyOnline),
                    totalSessions:    this._fmt(data.totalSessions),
                    avgSession:       (data.avgSessionMinutes > 0) ? data.avgSessionMinutes + ' min' : '—'
                };
            })
            .catch(e => console.error('getDashboardStats:', e));
    }

    _loadTable() {
        this.isTableLoading = true;
        getStudentSummaryReport({
            dateFrom:      this.filters.dateFrom || null,
            dateTo:        this.filters.dateTo   || null,
            programPlanId: this.filters.programPlanId || null,
            studentSearch: this.filters.studentSearch || null,
            statusFilter:  this.filters.statusFilter  || null,
            pageNumber:    this.reportData.pageNumber,
            pageSize:      parseInt(this.pageSize, 10)
        })
        .then(data => {
            const startNum = (data.pageNumber - 1) * parseInt(this.pageSize, 10) + 1;
            this.reportData = {
                rows:      (data.rows || []).map((r, i) => this._processRow(r, startNum + i)),
                total:      data.total      || 0,
                totalPages: data.totalPages || 1,
                pageNumber: data.pageNumber || 1,
                pageSize:   parseInt(this.pageSize, 10)
            };
        })
        .catch(e => console.error('getStudentSummaryReport:', e))
        .finally(() => { this.isTableLoading = false; });
    }

    // Side panel opener (row click in list view)
    _openSidePanel(contactId) {
        if (contactId === this._activeContactId && this.showDetail) return;
        this._activeContactId = contactId;
        this.showDetail       = true;
        this.isDetailLoading  = true;
        this.detail           = null;
        this.weeklyData       = [];
        this.weeklySummary    = {};
        this._rawSessions     = [];
        this.reportData       = { ...this.reportData, rows: this._markSelected(this.reportData.rows, contactId) };

        getStudentDetail({ contactId, dateFrom: this.filters.dateFrom, dateTo: this.filters.dateTo })
            .then(data => { this._rawSessions = data.timeline || []; this.detail = this._processDetail(data); })
            .catch(e => console.error('getStudentDetail:', e))
            .finally(() => { this.isDetailLoading = false; });

        getStudentWeeklyActivity({ contactId })
            .then(data => {
                this.weeklyData    = this._processWeekly(data && data.days);
                this.weeklySummary = this._buildWeeklySummary(data && data.summary);
            })
            .catch(e => console.error('getStudentWeeklyActivity:', e));
    }

    // ─── Private: Data Processing ─────────────────────────────────────────────

    _processRow(r, rowNum) {
        return {
            contactId:      r.contactId || '',
            rowNum,
            studentName:    r.studentName    || '—',
            rollNumber:     r.rollNumber     || '—',
            firstLoginFmt:  this._fmtDateTime(r.firstLogin),
            lastLogoutFmt:  r.lastLogout ? this._fmtDateTime(r.lastLogout) : '—',
            sessionCount:   r.sessionCount   || 0,
            totalActiveFmt: this._fmtDuration(r.totalMinutes),
            avgSessionFmt:  this._fmtDuration(r.avgMinutes),
            status:         r.status         || 'Completed',
            statusClass:    this._statusClass(r.status),
            rowClass:       r.contactId === this._activeContactId ? 'sr-tr sr-tr-selected' : 'sr-tr',
            _firstLogin:    r.firstLogin,
            _lastLogout:    r.lastLogout
        };
    }

    _processDetail(data) {
        const sessions    = data.timeline || [];
        const timeline    = [];
        const sessionRows = [];
        let   totalMins   = 0;

        sessions.forEach((s, idx) => {
            const isLastSession = idx === sessions.length - 1;
            const hasLogout     = !!s.logoutTime || s.status !== 'Active';
            const isActive      = s.status === 'Active';
            const durMins       = Number(s.durationMins) || 0;
            totalMins += durMins;

            timeline.push({ key: `tl-${idx}-login`,  time: this._fmtTime(s.loginTime),  action: 'Login',  subText: null, dotClass: 'sr-tl-dot sr-tl-dot-green', isLast: isLastSession && !hasLogout });
            if (hasLogout) {
                timeline.push({ key: `tl-${idx}-logout`, time: s.logoutTime ? this._fmtTime(s.logoutTime) : '—', action: 'Logout', subText: durMins ? 'Active Time: ' + this._fmtDuration(durMins) : null, dotClass: 'sr-tl-dot sr-tl-dot-red', isLast: isLastSession });
            }

            sessionRows.push({
                key:        `sr-row-${idx}`,
                num:        idx + 1,
                loginDate:  this._fmtDate(s.loginTime),
                loginTime:  this._fmtTime(s.loginTime),
                logoutTime: s.logoutTime ? this._fmtTime(s.logoutTime) : '—',
                duration:   this._fmtDuration(durMins),
                status:     isActive ? 'Active' : 'Completed',
                statusClass: isActive ? 'sr-status sr-status-online' : 'sr-status sr-status-completed'
            });
        });

        // Compute initials and avg session
        const nameParts = (data.contactName || '').trim().split(/\s+/);
        const initials  = nameParts.length >= 2
            ? (nameParts[0][0] + nameParts[nameParts.length - 1][0]).toUpperCase()
            : (nameParts[0] ? nameParts[0][0].toUpperCase() : '?');
        const avgMins   = sessions.length > 0 ? totalMins / sessions.length : 0;

        const isOnline     = !!data.isOnline;
        const lastActivity = data.lastLogout || data.firstLogin;

        return {
            contactName:      data.contactName || '—',
            rollNumber:       data.rollNumber  || '—',
            programName:      data.programName || '',
            batchName:        data.batchName   || '',
            initials,
            statusLabel:      isOnline ? 'Active' : 'Completed',
            statusBadgeClass: isOnline ? 'sr-badge sr-badge-online' : 'sr-badge sr-badge-completed',
            lastActivityFmt:  lastActivity ? this._fmtDateTime(lastActivity) : '—',
            firstLoginDate:   data.firstLogin ? this._fmtDate(data.firstLogin) : '—',
            firstLoginTime:   data.firstLogin ? this._fmtTime(data.firstLogin) : '—',
            lastLogoutDate:   data.lastLogout ? this._fmtDate(data.lastLogout) : '—',
            lastLogoutTime:   data.lastLogout ? this._fmtTime(data.lastLogout) : '—',
            totalActiveFmt:   this._fmtDuration(data.totalMinutes),
            avgSessionFmt:    this._fmtDuration(avgMins),
            totalSessions:    sessions.length,
            timeline,
            sessionRows
        };
    }

    _processWeekly(data) {
        if (!data || !data.length) return [];
        const MAX_PX  = 120;
        const maxMins = Math.max(...data.map(d => Number(d.minutes) || 0));
        return data.map(d => {
            const mins = Number(d.minutes) || 0;
            const px   = maxMins > 0 ? Math.max(4, Math.round((mins / maxMins) * MAX_PX)) : 4;
            return { dayLabel: d.dayLabel || '', shortDay: d.shortDay || '', dateLabel: d.dateLabel || '', durationFmt: this._fmtDuration(mins), hasData: mins > 0, barStyle: `height:${px}px` };
        });
    }

    _buildWeeklySummary(summary) {
        const empty = {
            hasActivity: false, totalActive: '—', avgDaily: '—', totalLogins: 0,
            totalSessions: 0, longestSession: '—', mostRecentLogin: '—', lastSeenFmt: ''
        };
        if (!summary) return empty;

        const totalMins = Number(summary.totalMinutes) || 0;
        const sessions  = Number(summary.totalSessions) || 0;
        if (sessions === 0) {
            return {
                ...empty,
                lastSeenFmt: summary.lastSeen ? this._fmtDateTime(summary.lastSeen) : ''
            };
        }

        return {
            hasActivity:     true,
            // Averaged over the whole 7-day window, matching the card's label.
            totalActive:     this._fmtDuration(totalMins),
            avgDaily:        this._fmtDuration(totalMins / 7),
            totalLogins:     Number(summary.totalLogins) || 0,
            totalSessions:   sessions,
            longestSession:  this._fmtDuration(Number(summary.longestSessionMinutes) || 0),
            mostRecentLogin: this._fmtRecentLogin(summary.mostRecentLogin),
            lastSeenFmt:     summary.lastSeen ? this._fmtDateTime(summary.lastSeen) : ''
        };
    }

    _fmtRecentLogin(dt) {
        if (!dt) return '—';
        const d = new Date(dt);
        if (isNaN(d.getTime())) return '—';
        const time  = this._fmtTime(d);
        const now   = new Date();
        const isSameDay = (a, b) => a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
        if (isSameDay(d, now)) return `Today, ${time}`;
        const yesterday = new Date(now.getTime() - 86400000);
        if (isSameDay(d, yesterday)) return `Yesterday, ${time}`;
        return `${this._fmtDate(d)}, ${time}`;
    }

    _markSelected(rows, contactId) { return rows.map(r => ({ ...r, rowClass: r.contactId === contactId ? 'sr-tr sr-tr-selected' : 'sr-tr' })); }
    _clearSelected(rows)           { return rows.map(r => ({ ...r, rowClass: 'sr-tr' })); }

    _sortRows() {
        const field = this.sortField === 'firstLogin' ? '_firstLogin' : '_lastLogout';
        const dir   = this.sortDir === 'asc' ? 1 : -1;
        const sorted = [...this.reportData.rows].sort((a, b) => {
            const va = a[field] ? new Date(a[field]).getTime() : 0;
            const vb = b[field] ? new Date(b[field]).getTime() : 0;
            return (va - vb) * dir;
        });
        this.reportData = { ...this.reportData, rows: sorted };
    }

    // ─── Formatters ──────────────────────────────────────────────────────────

    _fmtDateTime(dt) {
        if (!dt) return '—';
        try { return new Date(dt).toLocaleString('en-US', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }); } catch (e) { return String(dt); }
    }
    _fmtDate(dt) {
        if (!dt) return '—';
        try { return new Date(dt).toLocaleDateString('en-US', { day: '2-digit', month: 'short', year: 'numeric' }); } catch (e) { return String(dt); }
    }
    _fmtTime(dt) {
        if (!dt) return '—';
        try { return new Date(dt).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }); } catch (e) { return String(dt); }
    }
    _fmtDuration(mins) {
        const m = parseFloat(mins) || 0;
        if (m <= 0) return '—';
        const h = Math.floor(m / 60), r = Math.round(m % 60);
        return h === 0 ? `${r}m` : r === 0 ? `${h}h` : `${h}h ${r}m`;
    }
    _fmt(n) { const num = Number(n); return (!num && num !== 0) ? '0' : num.toLocaleString('en-US'); }
    _statusClass(s) {
        if (s === 'Online') return 'sr-status sr-status-online';
        if (s === 'Idle')   return 'sr-status sr-status-idle';
        return 'sr-status sr-status-completed';
    }
    _csv(v) {
        if (!v) return '';
        const s = String(v);
        return (s.includes(',') || s.includes('"') || s.includes('\n')) ? `"${s.replace(/"/g, '""')}"` : s;
    }
    _downloadCSV(csv, filename) {
        try {
            const anchor = this.template.querySelector('.sr-dl-anchor');
            if (!anchor) { console.error('sr-dl-anchor not found'); return; }

            // LWS blocks: data: URIs AND text/csv MIME type in Blob.
            // Use text/plain — LWS allows it. The download attribute forces .csv extension.
            const blob    = new Blob(['﻿' + csv], { type: 'text/plain' });
            const blobUrl = URL.createObjectURL(blob);

            anchor.setAttribute('href', blobUrl);
            anchor.setAttribute('download', filename);
            anchor.click();

            // Release memory after the browser picks up the download
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => URL.revokeObjectURL(blobUrl), 1500);
        } catch (e) {
            console.error('Download failed:', e);
        }
    }
}