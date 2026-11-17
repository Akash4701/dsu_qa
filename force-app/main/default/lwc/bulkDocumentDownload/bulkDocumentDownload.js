import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentPage  from '@salesforce/apex/BulkDocumentController.getDocumentPage';
import getDocumentCount from '@salesforce/apex/BulkDocumentController.getDocumentCount';
import getFilterOptions from '@salesforce/apex/BulkDocumentController.getFilterOptions';
import getTermOptions   from '@salesforce/apex/BulkDocumentController.getTermOptions';
import getFileContent   from '@salesforce/apex/BulkDocumentController.getFileContent';
import getFileContents  from '@salesforce/apex/BulkDocumentController.getFileContents';

// ─── CRC-32 table (built once at module load) ─────────────────────────────
const CRC32_TABLE = (() => {
    const t = new Uint32Array(256);
    for (let i = 0; i < 256; i++) {
        let c = i;
        for (let j = 0; j < 8; j++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
        t[i] = c;
    }
    return t;
})();

// Categories are decided in Apex (BulkDocumentController.CATEGORY_KEYWORDS); every
// page arrives already filtered to the active tab.
const CATEGORY_ORDER = ['All', 'Admission Letter', 'Fee Receipt', 'Admit Card', 'Grade Card', 'ID Card', 'Other'];

// Term only ever resolves for documents hung off a Program Enrollment, so the Term
// filter is offered on those tabs only. Affiliation-backed documents (Admission
// Letter, ID Card, Other) have no term to filter by.
const TERM_FILTER_CATEGORIES = new Set(['All', 'Fee Receipt', 'Admit Card', 'Grade Card']);

// Fee Head (Fee_Type__c.Fee_Head__c) only exists on fee receipts.
const FEE_HEAD_FILTER_CATEGORIES = new Set(['All', 'Fee Receipt']);

const SEARCH_DEBOUNCE_MS = 350;

// "Select all matching" reads every page under the current filters in batches of the
// Apex maximum page size.
const SELECT_ALL_BATCH = 200;

// ZIP download: Salesforce files are read in batches (one Apex call per batch, kept
// well under the Apex heap and response size), and several batches / receipt fetches
// run at once instead of one file after another.
const ZIP_BATCH_BYTES = 1500000;
const ZIP_BATCH_FILES = 25;
const ZIP_CONCURRENCY = 4;

// The ZIP is built in browser memory, so a large selection is split into several ZIPs
// of at most this many files, built and downloaded one after another.
const MAX_FILES_PER_ZIP = 1000;

const CATEGORY_COLOR = {
    'Admission Letter': 'cat-badge badge-blue',
    'Fee Receipt':      'cat-badge badge-green',
    'Admit Card':       'cat-badge badge-orange',
    'Grade Card':       'cat-badge badge-purple',
    'ID Card':          'cat-badge badge-teal',
    'Other':            'cat-badge badge-grey',
};

export default class BulkDocumentDownload extends LightningElement {

    @api recordId;

    // Only the current page is held; every page is fetched from Apex.
    @track _docs            = [];
    @track searchTerm       = '';
    @track activeCategory   = 'All';
    @track activeProgram    = 'All';   // hed__Account__c name — actual program
    @track activePlan       = 'All';   // hed__Program_Plan__c name — batch
    @track activeTerm       = 'All';   // hed__Term__c Name e.g. "2026-AUG-MCA-Sem 1-ONLINE"
    @track activeFeeHead    = 'All';   // Fee_Type__c Fee_Head__c e.g. "Year Wise Fee"
    @track _isLoading       = true;
    @track isDownloading    = false;
    @track downloadProgress = 0;
    @track downloadZipPart  = 0;
    @track _pageSize        = 10;

    // Keyset paging: _pageCursors[n] is the cursor that starts page n + 1 (null = first
    // page). Going back re-requests a page with its saved cursor.
    _pageCursors = [null];
    @track _currentPage = 1;
    _nextCursor = null;
    @track _hasMore = false;

    // Selected documents by id, kept across pages and filters so one ZIP can collect
    // files from several pages. Reassigned (not mutated) so the template re-renders.
    @track _selected = {};

    // "Select all matching": the filter key it last completed for (null once any
    // document is deselected), and the run in flight — a newer run or a filter change
    // bumps _selectAllRunId so a stale run drops its results.
    @track _selectAllKey      = null;
    @track isSelectingAll     = false;
    @track selectAllProgress  = 0;
    _selectAllRunId = 0;

    @track _programs         = [];
    @track _batchesByProgram = {};
    @track _terms            = [];
    @track _feeHeads         = [];

    // Documents per tab under the current filters; a tab missing here is still counting.
    @track _counts = {};

    _requestId      = 0;
    _countRequestId = 0;
    _searchTimer;

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    connectedCallback() {
        if (!this.recordId) this._loadFilterOptions();
        this._loadPage();
        this._loadCounts();
    }

    disconnectedCallback() {
        clearTimeout(this._searchTimer);
    }

    // ─── Core Getters ─────────────────────────────────────────────────────────

    get isLoading()   { return this._isLoading; }
    get showFilters() { return !this.recordId; }
    get headerSub() {
        const total = this._counts.All;
        const what  = this.recordId ? 'on this record' : 'across all students';
        return total === undefined ? `Documents ${what}` : `${total.toLocaleString()} documents ${what}`;
    }

    get filteredDocuments() {
        return this._docs.map(d => {
            const selected = !!this._selected[d.id];
            return { ...d, selected, itemClass: 'doc-row' + (selected ? ' doc-row--selected' : '') };
        });
    }

    get programOptions() {
        return [{ label: 'All programs', value: 'All' }, ...this._programs.map(p => ({ label: p, value: p }))];
    }
    get programPlanOptions() {
        const plans = this._batchesByProgram[this.activeProgram] || [];
        return [{ label: 'All batches', value: 'All' }, ...plans.map(p => ({ label: p, value: p }))];
    }
    get termOptions() {
        return [{ label: 'All terms', value: 'All' }, ...this._terms.map(t => ({ label: t, value: t }))];
    }
    get feeHeadOptions() {
        return [{ label: 'All fee heads', value: 'All' }, ...this._feeHeads.map(h => ({ label: h, value: h }))];
    }

    get showTermFilter()    { return TERM_FILTER_CATEGORIES.has(this.activeCategory); }
    get showFeeHeadFilter() { return FEE_HEAD_FILTER_CATEGORIES.has(this.activeCategory) && this._feeHeads.length > 0; }

    get programValue() { return this.activeProgram; }
    get planValue()    { return this.isPlanDisabled    ? null : this.activePlan; }
    get termValue()    { return this.isTermDisabled    ? null : this.activeTerm; }
    get feeHeadValue() { return this.isFeeHeadDisabled ? null : this.activeFeeHead; }

    // The filters are a hierarchy — each dropdown stays locked until the one above
    // it has a specific value: Program → Batch → Term → Fee Head.
    get isPlanDisabled()    { return this.activeProgram === 'All'; }
    get isTermDisabled()    { return this.isPlanDisabled || this.activePlan === 'All'; }
    get isFeeHeadDisabled() { return this.isTermDisabled || this.activeTerm === 'All'; }

    get hasActiveFilter() {
        return this.activeProgram !== 'All' || !!this.searchTerm;
    }

    get hasDocuments()  { return this._docs.length > 0; }
    get hasSearch()     { return !!this.searchTerm; }
    get selectedCount() { return Object.keys(this._selected).length; }
    get hasSelection()  { return this.selectedCount > 0; }

    get allSelected() {
        return this._docs.length > 0 && this._docs.every(d => this._selected[d.id]);
    }

    get pageDocCount() { return this._docs.length; }
    get zipDisabled()  { return this.isDownloading || this.isSelectingAll; }

    get zipCount() { return Math.ceil(this.selectedCount / MAX_FILES_PER_ZIP); }
    get zipButtonLabel() {
        const files = this.selectedCount.toLocaleString();
        return this.zipCount > 1 ? `Download ${this.zipCount} ZIPs (${files})` : `Download ZIP (${files})`;
    }
    get downloadProgressLabel() {
        const progress = `Preparing ${this.downloadProgress.toLocaleString()} of ${this.selectedCount.toLocaleString()}`;
        return this.zipCount > 1 ? `${progress} · ZIP ${this.downloadZipPart} of ${this.zipCount}...` : `${progress}...`;
    }

    get matchingLabel() {
        const count = this._counts[this.activeCategory];
        return count === undefined ? 'the' : count.toLocaleString();
    }
    get activeTabLabel() {
        return this.activeCategory === 'All' ? '' : this.activeCategory;
    }
    get selectAllBannerClass() {
        return 'select-all-banner'
            + (!this.isSelectingAll && this.allMatchingSelected ? ' select-all-banner--success' : '');
    }
    // Progress against the tab count; while that is still counting, show what's found.
    get selectAllProgressLabel() {
        const total = this._counts[this.activeCategory];
        return total === undefined
            ? `${this.selectAllProgress.toLocaleString()} found so far`
            : `${this.selectAllProgress.toLocaleString()} of ${total.toLocaleString()} selected`;
    }
    get selectAllProgressStyle() {
        const total = this._counts[this.activeCategory] || 0;
        const pct   = total ? Math.min(100, Math.round(this.selectAllProgress / total * 100)) : 15;
        return `width: ${pct}%`;
    }
    get allMatchingSelected() {
        return this._selectAllKey !== null && this._selectAllKey === this._filterKey();
    }
    // Offered once the whole page is ticked and the filters match more than this page.
    get showSelectAllBanner() {
        const morePages = this._currentPage > 1 || this._hasMore;
        return morePages && (this.isSelectingAll || this.allMatchingSelected || this.allSelected);
    }

    // ─── Pagination ───────────────────────────────────────────────────────────

    get pageLabel() { return String(this._currentPage); }
    get pageInfo() {
        if (!this._docs.length) return '0 results';
        const start = (this._currentPage - 1) * this._pageSize + 1;
        return `${start}–${start + this._docs.length - 1}`;
    }
    get prevDisabled() { return this._currentPage <= 1 || this._isLoading; }
    get nextDisabled() { return !this._hasMore || this._isLoading; }

    get pageSizeStr()     { return String(this._pageSize); }
    get pageSizeOptions() {
        return [
            { label: '10 / page', value: '10' },
            { label: '20 / page', value: '20' },
            { label: '50 / page', value: '50' },
        ];
    }

    get categoryTabs() {
        return CATEGORY_ORDER.map(cat => {
            const count = this._counts[cat];
            return {
                value: cat, label: cat,
                countLabel: count === undefined ? '…' : count.toLocaleString(),
                tabClass: 'tab-btn' + (this.activeCategory === cat ? ' tab-btn--active' : '')
            };
        });
    }

    // ─── Handlers ────────────────────────────────────────────────────────────

    handleSearch(event) {
        this.searchTerm = event.detail.value;
        clearTimeout(this._searchTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this._searchTimer = setTimeout(() => this._reload(true), SEARCH_DEBOUNCE_MS);
    }
    handleCategoryChange(event) {
        this.activeCategory = event.currentTarget.dataset.value;
        // Term / Fee Head only exist on some tabs; drop them when they no longer apply,
        // which changes the filters and so the counts.
        const before = this.activeTerm + '|' + this.activeFeeHead;
        if (!this.showTermFilter)    this.activeTerm    = 'All';
        if (!FEE_HEAD_FILTER_CATEGORIES.has(this.activeCategory)) this.activeFeeHead = 'All';
        this._reload(before !== this.activeTerm + '|' + this.activeFeeHead);
    }
    handleProgramChange(event) {
        this.activeProgram = event.detail.value;
        this.activePlan    = 'All';
        this.activeTerm    = 'All';
        this.activeFeeHead = 'All';
        this._terms        = [];
        this._reload(true);
    }
    handlePlanChange(event) {
        this.activePlan    = event.detail.value;
        this.activeTerm    = 'All';
        this.activeFeeHead = 'All';
        this._loadTermOptions();
        this._reload(true);
    }
    handleTermChange(event) {
        this.activeTerm    = event.detail.value;
        this.activeFeeHead = 'All';
        this._reload(true);
    }
    handleFeeHeadChange(event) {
        this.activeFeeHead = event.detail.value;
        this._reload(true);
    }
    handleClearFilters() {
        this.activeProgram  = 'All';
        this.activePlan     = 'All';
        this.activeTerm     = 'All';
        this.activeFeeHead  = 'All';
        this.searchTerm     = '';
        this._terms         = [];
        this._reload(true);
    }
    handlePrevPage() {
        if (this.prevDisabled) return;
        this._currentPage--;
        this._loadPage();
    }
    handleNextPage() {
        if (this.nextDisabled) return;
        this._pageCursors = [...this._pageCursors.slice(0, this._currentPage), this._nextCursor];
        this._currentPage++;
        this._loadPage();
    }
    handlePageSize(event) { this._pageSize = parseInt(event.detail.value, 10); this._reload(); }
    stopProp(event)       { event.stopPropagation(); }

    // "Select all" covers the page on screen; selections on other pages are kept.
    handleSelectAll(event) {
        const checked  = event.target.checked;
        const selected = { ...this._selected };
        this._docs.forEach(d => { if (checked) selected[d.id] = d; else delete selected[d.id]; });
        this._selected = selected;
        if (!checked) this._selectAllKey = null;
    }

    // Pages through every document matching the current tab + filters and adds them
    // to the selection (on top of anything already selected elsewhere).
    async handleSelectAllMatching() {
        const runId  = ++this._selectAllRunId;
        const key    = this._filterKey();
        const params = { ...this._filterParams(), category: this.activeCategory };
        this.isSelectingAll    = true;
        this.selectAllProgress = 0;

        const found = {};
        let count  = 0;
        let cursor = null;
        try {
            do {
                // eslint-disable-next-line no-await-in-loop
                const page = await getDocumentPage({ ...params, cursor, pageSize: SELECT_ALL_BATCH });
                if (runId !== this._selectAllRunId) return;
                for (const d of this._processDocs(page.documents || [])) {
                    if (found[d.id]) continue;
                    found[d.id] = d;
                    count++;
                }
                this.selectAllProgress = count;
                cursor = page.hasMore ? page.nextCursor : null;
            } while (cursor);

            this._selected     = { ...this._selected, ...found };
            this._selectAllKey = key;
        } catch (e) {
            if (runId === this._selectAllRunId) {
                this._toast('Error', e.body?.message || 'Failed to select all documents', 'error');
            }
        } finally {
            if (runId === this._selectAllRunId) this.isSelectingAll = false;
        }
    }
    handleCancelSelectAll() {
        this._cancelSelectAll();
    }
    _cancelSelectAll() {
        this._selectAllRunId++;
        this.isSelectingAll = false;
    }
    handleCheckbox(event) {
        this._setSelected(event.target.dataset.id, event.target.checked);
    }
    handleRowToggle(event) {
        const id = event.currentTarget.dataset.id;
        this._setSelected(id, !this._selected[id]);
    }
    handleClearAll() {
        this._cancelSelectAll();
        this._selected     = {};
        this._selectAllKey = null;
    }
    _setSelected(id, checked) {
        const doc = this._docs.find(d => d.id === id);
        const selected = { ...this._selected };
        if (checked && doc) selected[id] = doc; else delete selected[id];
        this._selected = selected;
        if (!checked) this._selectAllKey = null;
    }

    handleSingleDownload(event) {
        const url  = event.currentTarget.dataset.url;
        const name = event.currentTarget.dataset.name;
        this._downloadFile(url, name).catch(() => window.open(url, '_blank'));
    }

    // ─── Bulk ZIP Download (Apex-based — no CORS issues) ─────────────────────

    // Splits the selection into ZIPs of at most MAX_FILES_PER_ZIP files. Each ZIP is
    // built, downloaded and released before the next starts, so memory holds one at a time.
    async handleBulkDownload() {
        const selected = Object.values(this._selected);
        if (!selected.length) return;

        const parts = [];
        for (let i = 0; i < selected.length; i += MAX_FILES_PER_ZIP) {
            parts.push(selected.slice(i, i + MAX_FILES_PER_ZIP));
        }

        this.isDownloading    = true;
        this.downloadProgress = 0;
        this.downloadZipPart  = 0;

        const date    = new Date().toISOString().slice(0, 10);
        let packaged  = 0;
        let skipped   = 0;
        let zipsSaved = 0;
        try {
            for (let p = 0; p < parts.length; p++) {
                this.downloadZipPart = p + 1;
                const fileName = parts.length > 1
                    ? `student_documents_${date}_part${p + 1}_of_${parts.length}.zip`
                    : `student_documents_${date}.zip`;
                // eslint-disable-next-line no-await-in-loop
                const result = await this._downloadZipPart(parts[p], fileName);
                packaged += result.packaged;
                skipped  += result.skipped;
                if (result.packaged) zipsSaved++;
            }
        } catch (e) {
            console.error('ZIP download failed', e);
        } finally {
            this.isDownloading = false;
        }

        if (!packaged) {
            this._toast('Error', 'No files could be packaged. Check file permissions.', 'error');
            return;
        }
        const zips = zipsSaved > 1 ? `${zipsSaved} ZIPs` : 'ZIP';
        const msg  = skipped > 0
            ? `${packaged} file(s) in ${zips}. ${skipped} could not be included.`
            : `${packaged} file(s) packaged into ${zips} successfully`;
        this._toast('Success', msg, skipped > 0 || zipsSaved < parts.length ? 'warning' : 'success');
    }

    // Fetches one part's files, builds its ZIP and hands it to the browser to save.
    async _downloadZipPart(selected, fileName) {
        const usedNames = {};
        const safeName  = (title, fileType) => {
            const ext  = fileType ? '.' + fileType.toLowerCase() : '';
            let   base = (title || 'document').replace(/[/\\?%*:|"<>]/g, '_') + ext;
            if (!usedNames[base]) { usedNames[base] = 1; return base; }
            usedNames[base]++;
            const dot = base.lastIndexOf('.');
            return dot > -1
                ? base.slice(0, dot) + ` (${usedNames[base]})` + base.slice(dot)
                : base + ` (${usedNames[base]})`;
        };

        // Content per selected doc, by position, so the ZIP keeps the selection order.
        const contents = new Array(selected.length);
        const done     = () => { this.downloadProgress++; };

        const tasks = [];
        let batch = [];
        let batchBytes = 0;
        const flush = () => {
            if (!batch.length) return;
            const items = batch;
            tasks.push(() => this._loadFileBatch(items, contents, done));
            batch = [];
            batchBytes = 0;
        };
        selected.forEach((doc, index) => {
            if (!doc.versionId) {
                tasks.push(() => this._loadUrlContent(doc, index, contents, done));
                return;
            }
            const size = doc.fileSize || 0;
            if (batch.length && (batchBytes + size > ZIP_BATCH_BYTES || batch.length >= ZIP_BATCH_FILES)) flush();
            batch.push({ doc, index });
            batchBytes += size;
        });
        flush();
        await this._runPool(tasks, ZIP_CONCURRENCY);

        const zipEntries = [];
        const skipped    = [];
        selected.forEach((doc, index) => {
            const data = contents[index];
            if (!data) { skipped.push(doc.title); return; }
            const prog      = (doc.programName && doc.programName !== '—') ? doc.programName : null;
            const batchName = (doc.programPlan && doc.programPlan !== '—') ? doc.programPlan : null;
            const folder    = prog && batchName ? `${prog}/${batchName}/`
                            : prog              ? `${prog}/`
                            :                     '';
            zipEntries.push({ name: folder + safeName(doc.title, doc.fileType), data });
        });

        if (zipEntries.length > 0) {
            const zipBlob = new Blob([this._buildZip(zipEntries)], { type: 'application/zip' });
            const zipUrl  = URL.createObjectURL(zipBlob);
            const a       = document.createElement('a');
            a.href        = zipUrl;
            a.download    = fileName;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            setTimeout(() => URL.revokeObjectURL(zipUrl), 3000);
        }
        return { packaged: zipEntries.length, skipped: skipped.length };
    }

    // Runs async tasks with at most `limit` in flight.
    async _runPool(tasks, limit) {
        let next = 0;
        const worker = async () => {
            while (next < tasks.length) {
                const task = tasks[next++];
                // eslint-disable-next-line no-await-in-loop
                await task();
            }
        };
        await Promise.all(Array.from({ length: Math.min(limit, tasks.length) }, worker));
    }

    // One Apex call for a batch of Salesforce files. Anything the batch didn't return
    // (heap budget reached, or the call failed) is retried on its own.
    async _loadFileBatch(items, contents, done) {
        let result = {};
        try {
            result = (await getFileContents({ versionIds: items.map(it => it.doc.versionId) })) || {};
        } catch (e) {
            console.error('Batch failed, retrying files one by one', e);
        }
        for (const { doc, index } of items) {
            let b64 = result[doc.versionId];
            if (!b64) {
                try {
                    // eslint-disable-next-line no-await-in-loop
                    b64 = await getFileContent({ versionId: doc.versionId });
                } catch (e) {
                    console.error('Failed:', doc.title, e);
                }
            }
            if (b64) contents[index] = this._b64ToBytes(b64);
            done();
        }
    }

    // Receipts live at an external URL, fetched by the browser.
    async _loadUrlContent(doc, index, contents, done) {
        try {
            const resp = await fetch(doc.downloadUrl, { credentials: 'include' });
            if (resp.ok) contents[index] = new Uint8Array(await resp.arrayBuffer());
        } catch (e) {
            console.warn('Fetch failed for:', doc.title);
        }
        done();
    }

    _b64ToBytes(b64) {
        const bin   = atob(b64);
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        return bytes;
    }

    // ─── ZIP Builder (stored / uncompressed method) ───────────────────────────

    _buildZip(files) {
        const localParts  = [];
        const centralDirs = [];
        let   offset      = 0;

        for (const { name, data } of files) {
            const nameBytes = new TextEncoder().encode(name);
            const crc       = this._crc32(data);

            // Local file header (30 bytes + name)
            const lh   = new Uint8Array(30 + nameBytes.length);
            const lhv  = new DataView(lh.buffer);
            lhv.setUint32(0,  0x04034b50, true); // signature
            lhv.setUint16(4,  20,         true); // version needed (2.0)
            lhv.setUint16(6,  0,          true); // flags
            lhv.setUint16(8,  0,          true); // compression: stored
            lhv.setUint16(10, 0,          true); // mod time
            lhv.setUint16(12, 0,          true); // mod date
            lhv.setUint32(14, crc,        true); // CRC-32
            lhv.setUint32(18, data.length, true); // compressed size
            lhv.setUint32(22, data.length, true); // uncompressed size
            lhv.setUint16(26, nameBytes.length, true);
            lhv.setUint16(28, 0,          true); // extra field length
            lh.set(nameBytes, 30);

            centralDirs.push({ nameBytes, crc, size: data.length, offset });
            offset += lh.length + data.length;
            localParts.push(lh, data);
        }

        // Central directory entries
        const cdParts  = [];
        const cdStart  = offset;

        for (const { nameBytes, crc, size, offset: off } of centralDirs) {
            const cd  = new Uint8Array(46 + nameBytes.length);
            const cdv = new DataView(cd.buffer);
            cdv.setUint32(0,  0x02014b50,       true); // signature
            cdv.setUint16(4,  0x0314,            true); // version made by
            cdv.setUint16(6,  20,                true); // version needed
            cdv.setUint16(8,  0,                 true); // flags
            cdv.setUint16(10, 0,                 true); // compression
            cdv.setUint16(12, 0,                 true); // mod time
            cdv.setUint16(14, 0,                 true); // mod date
            cdv.setUint32(16, crc,               true); // CRC-32
            cdv.setUint32(20, size,              true); // compressed size
            cdv.setUint32(24, size,              true); // uncompressed size
            cdv.setUint16(28, nameBytes.length,  true); // name length
            cdv.setUint16(30, 0,                 true); // extra length
            cdv.setUint16(32, 0,                 true); // comment length
            cdv.setUint16(34, 0,                 true); // disk start
            cdv.setUint16(36, 0,                 true); // internal attr
            cdv.setUint32(38, 0,                 true); // external attr
            cdv.setUint32(42, off,               true); // local header offset
            cd.set(nameBytes, 46);
            cdParts.push(cd);
            offset += cd.length;
        }

        // End of central directory
        const eocd  = new Uint8Array(22);
        const eocdv = new DataView(eocd.buffer);
        eocdv.setUint32(0,  0x06054b50,        true); // signature
        eocdv.setUint16(4,  0,                 true); // disk number
        eocdv.setUint16(6,  0,                 true); // CD start disk
        eocdv.setUint16(8,  centralDirs.length, true); // entries on disk
        eocdv.setUint16(10, centralDirs.length, true); // total entries
        eocdv.setUint32(12, offset - cdStart,  true); // CD size
        eocdv.setUint32(16, cdStart,           true); // CD offset
        eocdv.setUint16(20, 0,                 true); // comment length

        // Merge all parts into one Uint8Array
        const all   = [...localParts, ...cdParts, eocd];
        const total = all.reduce((s, p) => s + p.length, 0);
        const zip   = new Uint8Array(total);
        let   pos   = 0;
        for (const part of all) { zip.set(part, pos); pos += part.length; }
        return zip;
    }

    _crc32(data) {
        let crc = 0xFFFFFFFF;
        for (let i = 0; i < data.length; i++) {
            crc = (crc >>> 8) ^ CRC32_TABLE[(crc ^ data[i]) & 0xFF];
        }
        return (crc ^ 0xFFFFFFFF) >>> 0;
    }

    // ─── Private Loaders ─────────────────────────────────────────────────────

    // Any filter change starts again from the first page; recount when the filters
    // behind the tab counts changed (not for a tab switch or page size).
    _reload(recount = false) {
        this._cancelSelectAll();
        this._pageCursors = [null];
        this._currentPage = 1;
        this._loadPage();
        if (recount) this._loadCounts();
    }

    _filterParams() {
        return {
            recordId:    this.recordId || null,
            programName: this.activeProgram,
            programPlan: this.activePlan,
            term:        this.activeTerm,
            feeHead:     this.activeFeeHead,
            searchTerm:  this.searchTerm || null
        };
    }

    // Identifies the set of documents the current tab + filters match.
    _filterKey() {
        return JSON.stringify({ ...this._filterParams(), category: this.activeCategory });
    }

    // One request per tab so each count runs in its own transaction. Tabs partition
    // the documents, so "All" is their sum.
    async _loadCounts() {
        const requestId = ++this._countRequestId;
        this._counts = {};
        const params     = this._filterParams();
        const categories = CATEGORY_ORDER.filter(c => c !== 'All');
        const results    = await Promise.allSettled(
            categories.map(category => getDocumentCount({ ...params, category }))
        );
        if (requestId !== this._countRequestId) return; // filters changed meanwhile

        const counts = {};
        let total = 0;
        results.forEach((r, i) => {
            if (r.status === 'fulfilled') {
                counts[categories[i]] = r.value;
                total += r.value;
            }
        });
        if (results.every(r => r.status === 'fulfilled')) counts.All = total;
        this._counts = counts;
    }

    async _loadPage() {
        const requestId = ++this._requestId;
        this._isLoading = true;
        try {
            const page = await getDocumentPage({
                ...this._filterParams(),
                category:    this.activeCategory,
                cursor:      this._pageCursors[this._currentPage - 1],
                pageSize:    this._pageSize
            });
            if (requestId !== this._requestId) return; // a newer request replaced this one
            this._docs       = this._processDocs(page.documents || []);
            this._nextCursor = page.nextCursor;
            this._hasMore    = page.hasMore;
        } catch (e) {
            if (requestId !== this._requestId) return;
            this._docs    = [];
            this._hasMore = false;
            this._toast('Error', e.body?.message || 'Failed to load', 'error');
        } finally {
            if (requestId === this._requestId) this._isLoading = false;
        }
    }

    async _loadFilterOptions() {
        try {
            const opts = await getFilterOptions();
            this._programs         = opts.programs || [];
            this._batchesByProgram = opts.batchesByProgram || {};
            this._feeHeads         = opts.feeHeads || [];
        } catch (e) {
            this._toast('Error', e.body?.message || 'Failed to load filters', 'error');
        }
    }

    async _loadTermOptions() {
        const plan = this.activePlan;
        this._terms = [];
        if (plan === 'All') return;
        try {
            const terms = await getTermOptions({ programPlan: plan });
            if (plan === this.activePlan) this._terms = terms || [];
        } catch (e) {
            this._toast('Error', e.body?.message || 'Failed to load terms', 'error');
        }
    }

    async _downloadFile(url, filename) {
        const resp    = await fetch(url, { credentials: 'include' });
        if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
        const blob    = await resp.blob();
        const blobUrl = URL.createObjectURL(blob);
        const a       = document.createElement('a');
        a.href = blobUrl; a.download = filename || 'document';
        document.body.appendChild(a); a.click(); document.body.removeChild(a);
        setTimeout(() => URL.revokeObjectURL(blobUrl), 2000);
    }

    // ─── Doc Processing ───────────────────────────────────────────────────────

    _processDocs(raw) {
        return raw.map(d => {
            const category = d.category || 'Other';
            return {
                id:            d.id,
                versionId:     d.versionId   || null,
                title:         d.title       || 'Untitled',
                studentName:   d.studentName || '—',
                programName:   d.programName || '—',   // hed__Account__c
                programPlan:   d.programPlan || '—',   // hed__Program_Plan__c
                term:          d.term        || '—',   // hed__Term__c Name
                feeHead:       d.feeHead     || '—',   // Fee_Type__c Fee_Head__c
                fileType:      (d.fileType   || '').toUpperCase(),
                fileSize:      d.fileSize,
                lastModified:  d.lastModified,
                downloadUrl:   d.downloadUrl,
                category,
                categoryClass: CATEGORY_COLOR[category] || 'cat-badge badge-grey',
                fileIcon:      this._fileIcon(d.fileType),
                meta:          this._buildMeta(d.fileType, d.fileSize, d.lastModified),
            };
        });
    }

    _fileIcon(ft) {
        const t = (ft || '').toLowerCase();
        if (t === 'pdf')                                  return 'doctype:pdf';
        if (['png','jpg','jpeg','gif','svg'].includes(t)) return 'doctype:image';
        if (['doc','docx'].includes(t))                   return 'doctype:word';
        if (['xls','xlsx'].includes(t))                   return 'doctype:excel';
        if (['ppt','pptx'].includes(t))                   return 'doctype:ppt';
        if (['zip','rar','7z'].includes(t))               return 'doctype:zip';
        return 'doctype:unknown';
    }

    _buildMeta(ft, size, date) {
        const parts = [];
        if (ft)   parts.push(ft.toUpperCase());
        if (size) parts.push(this._formatSize(size));
        if (date) parts.push(this._formatDate(date));
        return parts.join('  ·  ');
    }

    _formatSize(b) {
        if (!b) return '—';
        if (b < 1024)     return b + ' B';
        if (b < 1048576)  return (b / 1024).toFixed(1) + ' KB';
        return (b / 1048576).toFixed(1) + ' MB';
    }

    _formatDate(dt) {
        if (!dt) return '—';
        return new Date(dt).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}