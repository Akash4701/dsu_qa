import { LightningElement, track, wire } from 'lwc';
import getAllSessions from '@salesforce/apex/SessionReportController.getAllSessions';

const COLUMNS = [
    { label: 'Date',          fieldName: 'sessionDate',       type: 'text', sortable: true },
    { label: 'Login Time',    fieldName: 'loginTime',         type: 'text', sortable: true },
    { label: 'Logout Time',   fieldName: 'logoutTime',        type: 'text' },
    { label: 'Duration',      fieldName: 'duration',          type: 'text' },
    { label: 'Status',        fieldName: 'Session_Status__c', type: 'text', sortable: true }
];

export default class SessionReportDashboard extends LightningElement {

    columns = COLUMNS;

    @track allSessions      = [];
    @track filteredSessions = [];
    @track sessionHistory   = [];
    @track searchTerm       = '';
    @track selectedId       = null;
    @track selectedContactId = null;
    @track isLoading        = true;
    @track isDownloading    = false;
    @track sortedBy         = 'sessionDate';
    @track sortedDirection  = 'desc';
    @track currentHistoryPage = 1;
    @track historyPageSize = 10;

    // ─── Wire ────────────────────────────────────────────────────────────────

    @wire(getAllSessions)
    wiredSessions({ error, data }) {
        if (data) {
            this.allSessions      = this._processSessions(data);
            this.filteredSessions = [...this.allSessions];
            if (this.allSessions.length > 0) {
                this._selectSession(this.allSessions[0]);
            }
            this.isLoading = false;
        } else if (error) {
            console.error('SessionReportDashboard error:', error);
            this.isLoading = false;
        }
    }

    // ─── Event Handlers ──────────────────────────────────────────────────────

    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        const base = this.allSessions.filter(s =>
            s.contactName.toLowerCase().includes(this.searchTerm)
        );
        this.filteredSessions = this._applySelected(base);
    }

    handleSessionClick(event) {
        const id        = event.currentTarget.dataset.id;
        const session   = this.allSessions.find(s => s.Id === id);
        if (session) this._selectSession(session);
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy        = fieldName;
        this.sortedDirection = sortDirection;
        this.sessionHistory  = [...this.sessionHistory].sort((a, b) => {
            const va = (a[fieldName] || '').toString();
            const vb = (b[fieldName] || '').toString();
            return sortDirection === 'asc' ? va.localeCompare(vb) : vb.localeCompare(va);
        });
        this.currentHistoryPage = 1;
    }

    handlePreviousPage() {
        if (this.currentHistoryPage > 1) {
            this.currentHistoryPage -= 1;
        }
    }

    handleNextPage() {
        if (this.currentHistoryPage < this.totalHistoryPages) {
            this.currentHistoryPage += 1;
        }
    }

    // ─── Computed Properties ─────────────────────────────────────────────────

    get hasFilteredSessions()  { return this.filteredSessions.length > 0; }
    get hasSelectedSession()   { return !!this.selectedContactId; }
    get hasSessionHistory()    { return this.sessionHistory.length > 0; }
    get totalCount()           { return this.filteredSessions.length; }

    get totalSessionsCount() {
        return this.sessionHistory.length;
    }

    get totalHistoryPages() {
        return Math.ceil(this.sessionHistory.length / this.historyPageSize) || 1;
    }

    get paginatedSessionHistory() {
        const start = (this.currentHistoryPage - 1) * this.historyPageSize;
        const end = start + this.historyPageSize;
        return this.sessionHistory.slice(start, end);
    }

    get isPreviousDisabled() {
        return this.currentHistoryPage <= 1;
    }

    get isNextDisabled() {
        return this.currentHistoryPage >= this.totalHistoryPages;
    }

    get selectedContact() {
        if (!this.selectedContactId) return {};
        const s = this.allSessions.find(s => s.Contact__c === this.selectedContactId);
        return s ? {
            name:            s.contactName            || '—',
            email:           s.contactEmail           || '—',
            usn:             s.contactUSN             || '—',
            universityEmail: s.contactUniversityEmail || '—',
            programName:     s.contactProgramName     || '—',
            batch:           s.contactBatch           || '—',
            semester:        s.contactSemester        || '—'
        } : {};
    }

    get latestSession() {
        if (!this.selectedContactId) return {};
        const sessions = this.allSessions.filter(s => s.Contact__c === this.selectedContactId);
        if (!sessions.length) return {};
        const latest = sessions[0];
        return {
            loginTime:   this._formatTime(latest.Login_Time__c),
            logoutTime:  latest.Logout_Time__c ? this._formatTime(latest.Logout_Time__c) : 'Active',
            duration:    this._formatDuration(latest.Session_Duration_Minutes__c),
            sessionDate: this._formatDate(latest.Login_Time__c)
        };
    }

    get summary() {
        if (!this.selectedContactId) return {};
        const sessions  = this.allSessions.filter(s => s.Contact__c === this.selectedContactId);
        const completed = sessions.filter(s => s.Session_Duration_Minutes__c > 0);

        const now        = new Date();
        const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const weekStart  = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7);
        const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

        const sum  = (arr, filter) =>
            arr.filter(filter).reduce((t, s) => t + (s.Session_Duration_Minutes__c || 0), 0);

        return {
            totalHours:    this._formatHours(sum(completed, () => true)),
            todayHours:    this._formatHours(sum(completed, s => new Date(s.Login_Time__c) >= todayStart)),
            weeklyHours:   this._formatHours(sum(completed, s => new Date(s.Login_Time__c) >= weekStart)),
            monthlyHours:  this._formatHours(sum(completed, s => new Date(s.Login_Time__c) >= monthStart)),
            totalSessions: sessions.length
        };
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    _selectSession(session) {
        this.selectedId        = session.Id;
        this.selectedContactId = session.Contact__c;
        this.filteredSessions  = this._applySelected(this.filteredSessions);

        const contactSessions = this.allSessions.filter(s => s.Contact__c === session.Contact__c);
        this.sessionHistory   = contactSessions.map(s => ({
            Id:                 s.Id,
            sessionDate:        this._formatDate(s.Login_Time__c),
            loginTime:          this._formatTime(s.Login_Time__c),
            logoutTime:         s.Logout_Time__c ? this._formatTime(s.Logout_Time__c) : '—',
            duration:           this._formatDuration(s.Session_Duration_Minutes__c),
            Session_Status__c:  s.Session_Status__c || '—'
        }));
    }

    _applySelected(sessions) {
        return sessions.map(s => ({
            ...s,
            itemClass: s.Contact__c === this.selectedContactId
                ? 'session-item session-item_selected'
                : 'session-item'
        }));
    }

    _processSessions(data) {
        return data.map(s => {
            const contactName            = s.contactName   || 'Unknown';
            const contactEmail           = s.contactEmail  || '';
            const contactUSN             = s.rollNumber    || '';
            const contactUniversityEmail = s.dsuEmail      || '';
            const contactProgramName     = s.programName   || '';
            const contactBatch           = s.programPlan   || '';
            const contactSemester        = s.currentSemester || '';                                                                                                                                                                                                                                                                                                                                                                                                                                             
            return {
                ...s,
                contactId:              s.Contact__c,
                contactName,
                contactEmail,
                contactUSN,
                contactUniversityEmail,
                contactProgramName,
                contactBatch,
                contactSemester,
                initials:           this._initials(contactName),
                formattedLoginTime: this._formatDateTime(s.Login_Time__c),
                formattedDuration:  this._formatDuration(s.Session_Duration_Minutes__c),
                itemClass:          'session-item',
                statusPillClass:    s.Session_Status__c === 'Active'
                    ? 'status-pill pill-active'
                    : 'status-pill pill-completed'
            };
        });
    }

    _initials(name) {
        if (!name) return '?';
        const p = name.trim().split(' ');
        return p.length === 1
            ? p[0][0].toUpperCase()
            : (p[0][0] + p[p.length - 1][0]).toUpperCase();
    }

    _formatDateTime(dt) {
        if (!dt) return '—';
        return new Date(dt).toLocaleString('en-US', {
            month: 'short', day: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    }

    _formatDate(dt) {
        if (!dt) return '—';
        return new Date(dt).toLocaleDateString('en-US', {
            year: 'numeric', month: 'short', day: 'numeric'
        });
    }

    _formatTime(dt) {
        if (!dt) return '—';
        return new Date(dt).toLocaleTimeString('en-US', {
            hour: '2-digit', minute: '2-digit', second: '2-digit'
        });
    }

    _formatDuration(mins) {
        if (!mins || mins <= 0) return '—';
        const h = Math.floor(mins / 60);
        const m = Math.round(mins % 60);
        if (h === 0) return `${m} Min`;
        if (m === 0) return `${h} Hr`;
        return `${h} Hr ${m} Min`;
    }

    _formatHours(mins) {
        if (!mins || mins <= 0) return '0h';
        const h = Math.floor(mins / 60);
        const m = Math.round(mins % 60);
        if (h === 0) return `${m}m`;
        if (m === 0) return `${h}h`;
        return `${h}h ${m}m`;
    }

    handleDownloadReport() {
        this.isDownloading = true;
        try {
            // Overall report: one aggregated row per student across all sessions.
            const uniqueStudents = this._getUniqueStudents();
            const csv = this._generateStudentReportCSV(uniqueStudents);
            this._downloadCSV(csv, 'All_Students_Session_Report.csv');
        } catch (error) {
            console.error('Download failed:', error);
        } finally {
            this.isDownloading = false;
        }
    }

    handleDownloadStudentHistory() {
        this.isDownloading = true;
        try {
            const contact  = this.selectedContact;
            const sessions = this.allSessions.filter(s => s.Contact__c === this.selectedContactId);
            const csv      = this._generateStudentDetailedReportCSV(contact, sessions);
            const safeName = (contact.name || 'Student').replace(/[^a-zA-Z0-9_-]/g, '_');
            this._downloadCSV(csv, `${safeName}_Session_History.csv`);
        } catch (error) {
            console.error('Student history download failed:', error);
        } finally {
            this.isDownloading = false;
        }
    }

    _getUniqueStudents() {
        const studentMap = new Map();
        for (const session of this.allSessions) {
            const key = session.contactId;
            if (!studentMap.has(key)) {
                const totalMinutes = this._getTotalMinutesForContact(session.contactId);
                // allSessions is ordered DESC by login time; first match is the latest.
                const lastLogin = session.Login_Time__c ? this._formatDate(session.Login_Time__c) : '—';
                studentMap.set(key, {
                    name:            session.contactName,
                    email:           session.contactEmail,
                    usn:             session.contactUSN,
                    universityEmail: session.contactUniversityEmail,
                    programName:     session.contactProgramName,
                    batch:           session.contactBatch,
                    semester:        session.contactSemester,
                    totalSessions:   this._getTotalSessionsForContact(session.contactId),
                    totalHours:      this._formatHours(totalMinutes),
                    lastLogin
                });
            }
        }
        return Array.from(studentMap.values());
    }

    _getTotalSessionsForContact(contactId) {
        return this.allSessions.filter(s => s.contactId === contactId).length;
    }

    _getTotalMinutesForContact(contactId) {
        return this.allSessions
            .filter(s => s.contactId === contactId)
            .reduce((sum, s) => sum + (s.Session_Duration_Minutes__c || 0), 0);
    }

    _generateStudentDetailedReportCSV(contact, sessions) {
        const totalMinutes = sessions.reduce((sum, s) => sum + (s.Session_Duration_Minutes__c || 0), 0);

        const lines = [];

        // Student Information Section
        lines.push('STUDENT INFORMATION,,');
        lines.push(`Name,${this._escapeCsvValue(contact.name)},`);
        lines.push(`Email,${this._escapeCsvValue(contact.email)},`);
        lines.push(`USN,${this._escapeCsvValue(contact.usn)},`);
        lines.push(`University Email,${this._escapeCsvValue(contact.universityEmail)},`);
        lines.push(`Program Name,${this._escapeCsvValue(contact.programName)},`);
        lines.push(`Batch (Program Plan),${this._escapeCsvValue(contact.batch)},`);
        lines.push(`Current Semester,${this._escapeCsvValue(contact.semester)},`);

        // Session Summary Section
        lines.push('');
        lines.push('SESSION SUMMARY,,');
        lines.push(`Total Sessions,${sessions.length},`);
        lines.push(`Total Hours,${this._formatHours(totalMinutes)},`);

        // Session History Section
        lines.push('');
        lines.push('SESSION HISTORY');
        lines.push('Date,Login Time,Logout Time,Duration (Minutes),Status');

        // Session rows
        const sessionRows = sessions.map(s => [
            this._formatDate(s.Login_Time__c),
            this._formatTime(s.Login_Time__c),
            s.Logout_Time__c ? this._formatTime(s.Logout_Time__c) : 'Active',
            s.Session_Duration_Minutes__c || 0,
            s.Session_Status__c || '—'
        ].map(v => this._escapeCsvValue(String(v))).join(','));

        lines.push(...sessionRows);

        return lines.join('\n');
    }

    _generateStudentReportCSV(students) {
        const headers = [
            'Student Name',
            'Email',
            'USN',
            'University Email',
            'Program Name',
            'Batch (Program Plan)',
            'Current Semester',
            'Total Sessions',
            'Total Hours',
            'Last Login'
        ];

        const rows = students.map(s => [
            this._escapeCsvValue(s.name),
            this._escapeCsvValue(s.email),
            this._escapeCsvValue(s.usn),
            this._escapeCsvValue(s.universityEmail),
            this._escapeCsvValue(s.programName),
            this._escapeCsvValue(s.batch),
            this._escapeCsvValue(s.semester),
            s.totalSessions,
            s.totalHours,
            this._escapeCsvValue(s.lastLogin)
        ]);

        const csv = [
            headers.join(','),
            ...rows.map(row => row.join(','))
        ].join('\n');

        return csv;
    }

    _escapeCsvValue(value) {
        if (!value) return '';
        const str = String(value);
        if (str.includes(',') || str.includes('"') || str.includes('\n')) {
            return `"${str.replace(/"/g, '""')}"`;
        }
        return str;
    }

    _downloadCSV(csv, filename) {
        const element = document.createElement('a');
        element.setAttribute('href', `data:text/csv;charset=utf-8,${encodeURIComponent(csv)}`);
        element.setAttribute('download', filename);
        element.style.display = 'none';
        document.body.appendChild(element);
        element.click();
        document.body.removeChild(element);
    }
}