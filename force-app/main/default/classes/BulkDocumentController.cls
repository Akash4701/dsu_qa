public with sharing class BulkDocumentController {

    // The migrated CRM receipts carry no fee link, so Fee Head is derived from the
    // student's fee plan (Application.Fee_Preference__c) when the real field is
    // unreachable. This only covers the three tuition heads — an exam / backlog /
    // re-evaluation receipt has no fee plan equivalent and stays unresolved.
    private static final Map<String, String> FEE_PREF_TO_HEAD = new Map<String, String>{
        'Semester-wise fee' => 'Semester Fee',
        'Year-wise fee'     => 'Year Wise Fee',
        'Total program fee' => 'Program Fee'
    };

    // A file's category comes from keywords in its title; the first category that
    // matches wins, in this order ("Admission fee receipt" is an Admission Letter).
    // Titles matching nothing are "Other". Receipt records are always "Fee Receipt".
    private static final List<String> CATEGORY_ORDER = new List<String>{
        'Admission Letter', 'Fee Receipt', 'Admit Card', 'Grade Card', 'ID Card'
    };
    private static final Map<String, List<String>> CATEGORY_KEYWORDS = new Map<String, List<String>>{
        'Admission Letter' => new List<String>{ 'admission', 'offer letter', 'joining letter', 'offer' },
        'Fee Receipt'      => new List<String>{ 'fee', 'receipt', 'invoice', 'payment', 'challan' },
        'Admit Card'       => new List<String>{ 'admit', 'hall ticket', 'exam card' },
        'Grade Card'       => new List<String>{ 'grade', 'mark', 'transcript', 'result', 'report card', 'scorecard' },
        'ID Card'          => new List<String>{ 'id card', 'e-id', 'eid', 'identity card', 'student id', 'student e-id' }
    };
    private static final String CATEGORY_ALL     = 'All';
    private static final String CATEGORY_RECEIPT = 'Fee Receipt';
    private static final String CATEGORY_OTHER   = 'Other';

    private static final Integer MAX_PAGE_SIZE = 200;
    // Fee Head can come from five places, so with a Fee Head chosen receipts are filtered
    // in Apex after the query and more rows are read per call to fill the page.
    private static final Integer FEE_HEAD_SCAN_ROWS = 2000;
    // Reads one page may chain when everything it read was filtered out.
    private static final Integer MAX_EMPTY_SCANS = 5;
    // Heap kept free while getFileContents packs files into one response.
    private static final Integer FILE_HEAP_MARGIN = 1000000;

    // Global order: newest first, files before receipts on the same instant, then Id.
    private static final Integer RANK_FILE    = 0;
    private static final Integer RANK_RECEIPT = 1;

    // ─── Response types ──────────────────────────────────────────────────────

    // One page of documents. Pass nextCursor back unchanged to get the following page;
    // hasMore = false means the end was reached.
    public class DocumentPage {
        @AuraEnabled public List<Map<String, Object>> documents = new List<Map<String, Object>>();
        @AuraEnabled public String  nextCursor;
        @AuraEnabled public Boolean hasMore = false;
    }

    public class FilterOptions {
        @AuraEnabled public List<String>              programs         = new List<String>();
        @AuraEnabled public Map<String, List<String>> batchesByProgram = new Map<String, List<String>>();
        @AuraEnabled public List<String>              feeHeads         = new List<String>();
    }

    // ─── Documents, keyset-paginated ─────────────────────────────────────────
    // Every page is read from the database; nothing is loaded in full. OFFSET stops at
    // 2,000 rows, so the page boundary is a cursor instead: the sort date + Id of the
    // last row read. cursor = null → first page.
    //
    // Files are read through ContentDocumentLink: ContentDocument queried directly only
    // returns files the running user owns (unless they have "Query All Files").
    //
    // recordId set → files on that one record (record page). Otherwise every file on an
    // Affiliation / Program Enrollment plus Receipt_and_Invoice__c receipts, narrowed by
    // category, program (account name), batch (program plan name), term (term name),
    // fee head and a search on document title or student name. Blank filters and the
    // category "All" mean no filter.
    @AuraEnabled
    public static DocumentPage getDocumentPage(Id recordId, String category, String programName,
            String programPlan, String term, String feeHead, String searchTerm,
            String cursor, Integer pageSize) {
        Integer size = (pageSize == null || pageSize < 1 || pageSize > MAX_PAGE_SIZE) ? MAX_PAGE_SIZE : pageSize;
        Filters f = new Filters(recordId, category, programName, programPlan, term, feeHead, searchTerm);
        Cursor  c = decodeCursor(cursor);

        DocumentPage page = readPage(f, c, size);
        for (Integer scan = 1; scan < MAX_EMPTY_SCANS && page.documents.isEmpty() && page.hasMore; scan++) {
            page = readPage(f, decodeCursor(page.nextCursor), size);
        }
        return page;
    }

    // How many documents one tab holds under the given filters — the same set
    // getDocumentPage pages through. The LWC asks once per tab; each call is its own
    // transaction, so one tab's count never eats into another's query-row limit.
    // A file attached to both an Affiliation and a Program Enrollment counts once for each.
    @AuraEnabled
    public static Integer getDocumentCount(Id recordId, String category, String programName,
            String programPlan, String term, String feeHead, String searchTerm) {
        Filters f = new Filters(recordId, category, programName, programPlan, term, feeHead, searchTerm);
        Integer total = 0;
        for (FileStream fs : fileStreams(f)) {
            total += aggregateTotal(fs.countSoql(f), f) - olderCopies(fs, f);
        }
        if (f.includeReceipts) {
            if (f.feeHead == null) {
                total += aggregateTotal('SELECT COUNT(Id) total FROM Receipt_and_Invoice__c' + receiptWhere(f), f);
            } else {
                // Fee Head is resolved in Apex; the Fee Head filter only opens below a
                // chosen term, so this scope is one batch-term's receipts.
                List<Receipt_and_Invoice__c> receipts = (List<Receipt_and_Invoice__c>) run(
                    'SELECT ' + RECEIPT_FIELDS + ' FROM Receipt_and_Invoice__c' + receiptWhere(f) + ' LIMIT :rowLimit',
                    f, null, 10000);
                Map<Id, String> heads = feeHeadsOf(receipts, new ReceiptContext(receipts));
                for (Receipt_and_Invoice__c ri : receipts) {
                    if (f.feeHead == heads.get(ri.Id)) total++;
                }
            }
        }
        return total;
    }

    // Older copies of regenerated documents in one stream (see markSuperseded): every
    // group of same-titled files on one record keeps only its newest.
    private static Integer olderCopies(FileStream fs, Filters f) {
        Integer older = 0;
        for (SObject ar : run(fs.duplicateGroupsSoql(f), f, null, null)) {
            older += Integer.valueOf(ar.get('copies')) - 1;
        }
        return older;
    }

    private static Integer aggregateTotal(String soql, Filters f) {
        List<AggregateResult> result = (List<AggregateResult>) run(soql, f, null, null);
        return result.isEmpty() ? 0 : Integer.valueOf(result[0].get('total'));
    }

    // Each source (files on Affiliations, files on Program Enrollments, receipts) is a
    // stream queried in the global order, all cut at the same cursor, then merged.
    private static DocumentPage readPage(Filters f, Cursor c, Integer size) {
        List<List<Row>> streams   = new List<List<Row>>();
        List<Integer>   rowLimits = new List<Integer>();
        List<Row>       fileRows  = new List<Row>();
        for (FileStream fs : fileStreams(f)) {
            List<Row> rows = new List<Row>();
            for (SObject so : run(fs.soql(f, c), f, c, size + 1)) rows.add(new Row((ContentDocumentLink) so));
            streams.add(rows);
            rowLimits.add(size + 1);
            fileRows.addAll(rows);
        }
        markSuperseded(fileRows);
        Map<Id, String> receiptFeeHeads = new Map<Id, String>();
        if (f.includeReceipts) {
            Integer rowLimit = f.feeHead != null ? FEE_HEAD_SCAN_ROWS : size + 1;
            List<Receipt_and_Invoice__c> receipts = (List<Receipt_and_Invoice__c>) run(receiptQuery(f, c), f, c, rowLimit);
            if (f.feeHead != null) receiptFeeHeads = feeHeadsOf(receipts, new ReceiptContext(receipts));
            List<Row> rows = new List<Row>();
            for (Receipt_and_Invoice__c ri : receipts) {
                Row r = new Row(ri);
                r.keep = f.feeHead == null || f.feeHead == receiptFeeHeads.get(ri.Id);
                rows.add(r);
            }
            streams.add(rows);
            rowLimits.add(rowLimit);
        }

        // A stream that came back full may hold more rows past its last one, so nothing
        // ordered after that row is safe to return yet — the earliest such row is the
        // boundary for this page.
        List<Row> merged   = new List<Row>();
        Row       boundary = null;
        Boolean   anyFull  = false;
        for (Integer i = 0; i < streams.size(); i++) {
            List<Row> rows = streams[i];
            merged.addAll(rows);
            if (rows.size() >= rowLimits[i]) {
                anyFull = true;
                Row last = rows[rows.size() - 1];
                if (boundary == null || last.compareTo(boundary) < 0) boundary = last;
            }
        }
        merged.sort();

        // A file linked to several students has one row per link; they share a sort key,
        // so they sit together and only the first is kept.
        List<Row> picked       = new List<Row>();
        Set<Id>   seen         = new Set<Id>();
        Row       lastConsumed = null;
        Boolean   leftover     = false;
        for (Row r : merged) {
            if (boundary != null && r.compareTo(boundary) > 0) { leftover = true; break; }
            Boolean emit = r.keep && !seen.contains(r.id);
            if (emit && picked.size() == size) { leftover = true; break; }
            lastConsumed = r;
            if (emit) {
                seen.add(r.id);
                picked.add(r);
            }
        }

        DocumentPage page = new DocumentPage();
        page.hasMore    = leftover || anyFull;
        page.nextCursor = lastConsumed != null ? new Cursor(lastConsumed).encode() : null;
        page.documents  = toDocuments(picked, receiptFeeHeads);
        return page;
    }

    // ─── Queries ─────────────────────────────────────────────────────────────

    // One ContentDocumentLink query. SOQL can't OR two semi-joins, so Affiliation and
    // Program Enrollment files are separate streams, and a search on student name is a
    // second stream per object next to the search on title. The student-name stream
    // skips titles the title stream already matches, so the two never overlap.
    private class FileStream {
        final String  linkFilter;
        final Boolean titleSearch;
        final Boolean studentSearch;

        FileStream(String linkFilter, Boolean titleSearch, Boolean studentSearch) {
            this.linkFilter    = linkFilter;
            this.titleSearch   = titleSearch;
            this.studentSearch = studentSearch;
        }

        String whereClause(Filters f) {
            String q = ' WHERE ' + linkFilter;
            if (f.includePatterns != null) q += ' AND ContentDocument.Title LIKE :includePatterns';
            if (f.excludePatterns != null) q += ' AND (NOT ContentDocument.Title LIKE :excludePatterns)';
            if (titleSearch)               q += ' AND ContentDocument.Title LIKE :searchPattern';
            if (studentSearch)             q += ' AND (NOT ContentDocument.Title LIKE :searchPattern)';
            return q;
        }

        String soql(Filters f, Cursor c) {
            return 'SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Id, ContentDocument.Title, '
                 + 'ContentDocument.FileType, ContentDocument.ContentSize, ContentDocument.LastModifiedDate, '
                 + 'ContentDocument.LatestPublishedVersionId '
                 + 'FROM ContentDocumentLink' + whereClause(f)
                 + cursorCondition('ContentDocument.LastModifiedDate', 'ContentDocumentId', RANK_FILE, c)
                 + ' ORDER BY ContentDocument.LastModifiedDate DESC, ContentDocumentId DESC LIMIT :rowLimit';
        }

        String countSoql(Filters f) {
            return 'SELECT COUNT_DISTINCT(ContentDocumentId) total FROM ContentDocumentLink' + whereClause(f);
        }

        // Records holding more than one file with the same title.
        String duplicateGroupsSoql(Filters f) {
            return 'SELECT COUNT(Id) copies FROM ContentDocumentLink' + whereClause(f)
                 + ' GROUP BY LinkedEntityId, ContentDocument.Title HAVING COUNT(Id) > 1 LIMIT 2000';
        }
    }

    // A document regenerated for a student is a new file with the same title on the same
    // Affiliation / Program Enrollment; only the newest copy — the first in the global
    // order — is offered, older ones are dropped. Every file filter goes by parent record
    // or title, so all copies sit in the same stream, but the newest can be on an earlier
    // page than an older one, so every copy is looked up, not just this page's rows.
    private static void markSuperseded(List<Row> rows) {
        if (rows.isEmpty()) return;
        Set<Id>     entityIds = new Set<Id>();
        Set<String> titles    = new Set<String>();
        for (Row r : rows) {
            entityIds.add(r.link.LinkedEntityId);
            titles.add(r.link.ContentDocument.Title);
        }
        Map<String, Row> newest = new Map<String, Row>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.Title, ContentDocument.LastModifiedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :entityIds AND ContentDocument.Title IN :titles
            LIMIT 10000
        ]) {
            Row    copy = new Row(cdl);
            String key  = copyKey(cdl);
            if (!newest.containsKey(key) || copy.compareTo(newest.get(key)) < 0) newest.put(key, copy);
        }
        for (Row r : rows) {
            Row latest = newest.get(copyKey(r.link));
            if (latest != null && latest.id != r.id) r.keep = false;
        }
    }

    // SOQL compares titles case-insensitively, so copies are keyed the same way.
    private static String copyKey(ContentDocumentLink cdl) {
        return cdl.LinkedEntityId + '|' + cdl.ContentDocument.Title.toLowerCase();
    }

    private static List<FileStream> fileStreams(Filters f) {
        List<FileStream> streams = new List<FileStream>();
        if (f.recordId != null) {
            streams.add(new FileStream('LinkedEntityId = :recordId', f.searchPattern != null, false));
            return streams;
        }
        // Files carry no fee head, so a Fee Head filter leaves receipts only.
        if (f.feeHead != null) return streams;

        List<String> parents = new List<String>();
        // Affiliations have no term, so a Term filter leaves Program Enrollment files only.
        if (f.term == null) {
            parents.add('SELECT Id FROM hed__Affiliation__c WHERE Id != null'
                + (f.programName != null ? ' AND hed__Account__r.Name = :programName' : '')
                + (f.programPlan != null ? ' AND Program_Plan__r.Name = :programPlan' : ''));
        }
        parents.add('SELECT Id FROM hed__Program_Enrollment__c WHERE Id != null'
            + (f.programName != null ? ' AND hed__Account__r.Name = :programName' : '')
            + (f.programPlan != null ? ' AND hed__Program_Plan__r.Name = :programPlan' : '')
            + (f.term        != null ? ' AND Term__r.Name = :term' : ''));

        for (String parent : parents) {
            if (f.searchPattern == null) {
                streams.add(new FileStream('LinkedEntityId IN (' + parent + ')', false, false));
            } else {
                streams.add(new FileStream('LinkedEntityId IN (' + parent + ')', true, false));
                streams.add(new FileStream(
                    'LinkedEntityId IN (' + parent + ' AND hed__Contact__r.Name LIKE :searchPattern)', false, true));
            }
        }
        return streams;
    }

    private static final String RECEIPT_FIELDS =
        'Id, Name, CreatedDate, Contact__c, Contact__r.Name, Receipt_Number__c, '
      + 'Document_Type__c, Receipt_URL__c, Payment_Date__c, Fee_Type__r.Fee_Head__c, '
      + 'Fee_Installment__r.Fee_Type__r.Fee_Head__c, Fee_Assignment__r.Fee_Type__r.Fee_Head__c';

    // Receipts sort on CreatedDate: Payment_Date__c (shown as the date) can be blank,
    // which a keyset cursor can't page through.
    private static String receiptQuery(Filters f, Cursor c) {
        return 'SELECT ' + RECEIPT_FIELDS + ' FROM Receipt_and_Invoice__c' + receiptWhere(f)
             + cursorCondition('CreatedDate', 'Id', RANK_RECEIPT, c)
             + ' ORDER BY CreatedDate DESC, Id DESC LIMIT :rowLimit';
    }

    private static String receiptWhere(Filters f) {
        String q = ' WHERE Receipt_URL__c != null';
        if (f.programName != null || f.programPlan != null) {
            q += ' AND Contact__c IN (SELECT hed__Contact__c FROM hed__Affiliation__c WHERE Id != null'
               + (f.programName != null ? ' AND hed__Account__r.Name = :programName' : '')
               + (f.programPlan != null ? ' AND Program_Plan__r.Name = :programPlan' : '')
               + ')';
        }
        if (f.term != null) {
            q += ' AND Contact__c IN (SELECT hed__Contact__c FROM hed__Program_Enrollment__c WHERE Term__r.Name = :term)';
        }
        if (f.searchPattern != null) {
            q += ' AND (Receipt_Number__c LIKE :searchPattern OR Name LIKE :searchPattern'
               + ' OR Document_Type__c LIKE :searchPattern OR Contact__r.Name LIKE :searchPattern)';
        }
        return q;
    }

    // Rows strictly after the cursor in (date DESC, rank ASC, Id DESC) order. Ids are
    // only compared within the cursor's own stream type.
    private static String cursorCondition(String dateField, String idField, Integer rank, Cursor c) {
        if (c == null)      return '';
        if (rank > c.rank)  return ' AND ' + dateField + ' <= :cursorDate';
        if (rank < c.rank)  return ' AND ' + dateField + ' < :cursorDate';
        return ' AND (' + dateField + ' < :cursorDate OR (' + dateField + ' = :cursorDate AND '
             + idField + ' < :cursorId))';
    }

    // Every query runs here so its bind variables are in scope by name. Filter values
    // are always bound, never concatenated into the SOQL.
    private static List<SObject> run(String soql, Filters f, Cursor c, Integer rowLimit) {
        Id           recordId        = f.recordId;
        String       programName     = f.programName;
        String       programPlan     = f.programPlan;
        String       term            = f.term;
        String       searchPattern   = f.searchPattern;
        List<String> includePatterns = f.includePatterns;
        List<String> excludePatterns = f.excludePatterns;
        Datetime     cursorDate      = c != null ? c.sortDate : null;
        Id           cursorId        = c != null ? c.recordId : null;
        return Database.query(soql);
    }

    // ─── Page → documents ────────────────────────────────────────────────────

    private static List<Map<String, Object>> toDocuments(List<Row> picked, Map<Id, String> knownFeeHeads) {
        Set<Id> entityIds = new Set<Id>();
        List<Receipt_and_Invoice__c> receipts = new List<Receipt_and_Invoice__c>();
        for (Row r : picked) {
            if (r.link != null) entityIds.add(r.link.LinkedEntityId);
            else receipts.add(r.receipt);
        }

        Map<Id, Map<String, String>> entityMeta = entityMetadata(entityIds);
        ReceiptContext ctx = new ReceiptContext(receipts);
        Map<Id, String> feeHeads = knownFeeHeads.isEmpty() ? feeHeadsOf(receipts, ctx) : knownFeeHeads;
        Map<Id, ContentVersion> receiptFiles = receiptFiles(receipts);

        List<Map<String, Object>> docs = new List<Map<String, Object>>();
        for (Row r : picked) {
            docs.add(r.link != null
                ? fileDocument(r.link, entityMeta.get(r.link.LinkedEntityId))
                : receiptDocument(r.receipt, ctx, feeHeads.get(r.receipt.Id), receiptFiles.get(r.receipt.Id)));
        }
        return docs;
    }

    // Receipt_URL__c is a Salesforce public link — either the preview page
    // (/sfc/p/<org>/a/<key>/<token>) or the direct download (…&d=%2Fa%2F<key>%2F<token>).
    // <key> is the ContentDistribution Id without its '05D' prefix, which leads to the
    // shared file, so the ZIP reads receipts through Apex like any other file. The
    // browser can't fetch these links itself: they're on another domain.
    private static final Pattern DISTRIBUTION_KEY = Pattern.compile('(?:/|%2F)a(?:/|%2F)([a-zA-Z0-9]{12})(?:/|%2F)');

    private static Map<Id, ContentVersion> receiptFiles(List<Receipt_and_Invoice__c> receipts) {
        Map<Id, Id> distributionByReceipt = new Map<Id, Id>();
        for (Receipt_and_Invoice__c ri : receipts) {
            Matcher m = DISTRIBUTION_KEY.matcher(ri.Receipt_URL__c == null ? '' : ri.Receipt_URL__c);
            if (!m.find()) continue;
            try {
                distributionByReceipt.put(ri.Id, Id.valueOf('05D' + m.group(1)));
            } catch (StringException e) {
                // Not a Salesforce link; the receipt keeps its URL only.
            }
        }

        Map<Id, ContentVersion> files = new Map<Id, ContentVersion>();
        if (distributionByReceipt.isEmpty()) return files;
        Map<Id, ContentDistribution> distributions = new Map<Id, ContentDistribution>([
            SELECT Id, ContentVersionId, ContentVersion.Id, ContentVersion.ContentSize
            FROM ContentDistribution
            WHERE Id IN :distributionByReceipt.values()
        ]);
        for (Id receiptId : distributionByReceipt.keySet()) {
            ContentDistribution cd = distributions.get(distributionByReceipt.get(receiptId));
            if (cd != null && cd.ContentVersionId != null) files.put(receiptId, cd.ContentVersion);
        }
        return files;
    }

    private static Map<String, Object> fileDocument(ContentDocumentLink cdl, Map<String, String> meta) {
        ContentDocument cd = cdl.ContentDocument;
        return new Map<String, Object>{
            'id'           => cd.Id,
            'versionId'    => cd.LatestPublishedVersionId,
            'title'        => cd.Title,
            'category'     => categoryOf(cd.Title),
            'fileType'     => cd.FileType,
            'fileSize'     => cd.ContentSize,
            'lastModified' => cd.LastModifiedDate,
            'downloadUrl'  => '/sfc/servlet.shepherd/document/download/' + cd.Id + '?operationContext=S1',
            'studentName'  => meta != null ? meta.get('studentName') : '—',
            'programPlan'  => meta != null ? meta.get('programPlan') : null,
            'programName'  => meta != null ? meta.get('programName') : null,
            'term'         => meta != null ? meta.get('term') : null
        };
    }

    private static Map<String, Object> receiptDocument(Receipt_and_Invoice__c ri, ReceiptContext ctx, String feeHead,
            ContentVersion file) {
        String docTitle = String.isNotBlank(ri.Receipt_Number__c) ? ri.Receipt_Number__c : ri.Name;
        if (String.isNotBlank(ri.Document_Type__c)) {
            docTitle += ' (' + ri.Document_Type__c + ')';
        }
        Datetime lastMod = ri.Payment_Date__c != null
            ? Datetime.newInstance(ri.Payment_Date__c, Time.newInstance(0, 0, 0, 0))
            : null;
        return new Map<String, Object>{
            'id'           => ri.Id,
            'versionId'    => file != null ? file.Id : null,
            'title'        => docTitle,
            'category'     => CATEGORY_RECEIPT,
            'fileType'     => 'PDF',
            'fileSize'     => file != null ? file.ContentSize : null,
            'lastModified' => lastMod,
            'downloadUrl'  => ri.Receipt_URL__c,
            'studentName'  => ri.Contact__r != null ? ri.Contact__r.Name : '—',
            'programPlan'  => ctx.planByContact.get(ri.Contact__c),
            'programName'  => ctx.programByContact.get(ri.Contact__c),
            'term'         => ctx.termByContact.get(ri.Contact__c),
            'feeHead'      => feeHead
        };
    }

    // Student / program / batch / term for the Affiliations and Program Enrollments
    // that this page's files hang off.
    private static Map<Id, Map<String, String>> entityMetadata(Set<Id> entityIds) {
        Map<Id, Map<String, String>> meta = new Map<Id, Map<String, String>>();
        if (entityIds.isEmpty()) return meta;
        for (hed__Affiliation__c a : [
            SELECT Id, hed__Contact__r.Name, Program_Plan__r.Name, hed__Account__r.Name
            FROM hed__Affiliation__c
            WHERE Id IN :entityIds
        ]) {
            meta.put(a.Id, new Map<String, String>{
                'studentName' => a.hed__Contact__r != null ? a.hed__Contact__r.Name : '—',
                'programPlan' => a.Program_Plan__r != null ? a.Program_Plan__r.Name : null,
                'programName' => a.hed__Account__r != null ? a.hed__Account__r.Name : null
            });
        }
        for (hed__Program_Enrollment__c pe : [
            SELECT Id, hed__Contact__r.Name, hed__Account__r.Name, hed__Program_Plan__r.Name, Term__r.Name
            FROM hed__Program_Enrollment__c
            WHERE Id IN :entityIds
        ]) {
            meta.put(pe.Id, new Map<String, String>{
                'studentName' => pe.hed__Contact__r != null ? pe.hed__Contact__r.Name : '—',
                'programName' => pe.hed__Account__r != null ? pe.hed__Account__r.Name : null,
                'programPlan' => pe.hed__Program_Plan__r != null ? pe.hed__Program_Plan__r.Name : null,
                'term'        => termLabel(pe.Term__r)
            });
        }
        return meta;
    }

    // What a receipt's student brings to it: program plan + program from their most
    // recent affiliation with a plan, term from their most recent Program Enrollment
    // (receipts carry no term of their own), and a Fee Head derived from their fee plan,
    // used only as a fallback.
    private class ReceiptContext {
        final Map<Id, String> planByContact    = new Map<Id, String>();
        final Map<Id, String> programByContact = new Map<Id, String>();
        final Map<Id, String> termByContact    = new Map<Id, String>();
        final Map<Id, String> feeHeadByContact = new Map<Id, String>();

        ReceiptContext(List<Receipt_and_Invoice__c> receipts) {
            Set<Id> contactIds = new Set<Id>();
            for (Receipt_and_Invoice__c ri : receipts) {
                if (ri.Contact__c != null) contactIds.add(ri.Contact__c);
            }
            if (contactIds.isEmpty()) return;

            for (hed__Affiliation__c a : [
                SELECT hed__Contact__c, Program_Plan__r.Name, hed__Account__r.Name,
                       Individual_Application__r.Fee_Preference__c
                FROM hed__Affiliation__c
                WHERE hed__Contact__c IN :contactIds
                  AND Program_Plan__c != null
                ORDER BY CreatedDate DESC
                LIMIT 10000
            ]) {
                if (!planByContact.containsKey(a.hed__Contact__c)) {
                    planByContact.put(a.hed__Contact__c, a.Program_Plan__r != null ? a.Program_Plan__r.Name : null);
                    programByContact.put(a.hed__Contact__c, a.hed__Account__r != null ? a.hed__Account__r.Name : null);
                }
                // Take the newest affiliation that actually states a preference, so a
                // blank on the most recent one doesn't hide an older answer.
                if (!feeHeadByContact.containsKey(a.hed__Contact__c)
                        && a.Individual_Application__r != null
                        && FEE_PREF_TO_HEAD.containsKey(a.Individual_Application__r.Fee_Preference__c)) {
                    feeHeadByContact.put(
                        a.hed__Contact__c,
                        FEE_PREF_TO_HEAD.get(a.Individual_Application__r.Fee_Preference__c)
                    );
                }
            }

            for (hed__Program_Enrollment__c pe : [
                SELECT hed__Contact__c, Term__r.Name
                FROM hed__Program_Enrollment__c
                WHERE hed__Contact__c IN :contactIds
                  AND Term__c != null
                ORDER BY CreatedDate DESC
                LIMIT 10000
            ]) {
                if (!termByContact.containsKey(pe.hed__Contact__c)) {
                    termByContact.put(pe.hed__Contact__c, termLabel(pe.Term__r));
                }
            }
        }
    }

    // Fee_Head__c lives on Fee_Type__c, which a receipt can reach three ways (directly,
    // via its installment, or via its assignment) plus its payment line items; the
    // student's fee plan is the last resort.
    private static Map<Id, String> feeHeadsOf(List<Receipt_and_Invoice__c> receipts, ReceiptContext ctx) {
        Map<Id, String> heads = new Map<Id, String>();
        if (receipts.isEmpty()) return heads;

        // A receipt raised through PaymentReceiptService carries Fee_Installment__c, but
        // some are only tied to a fee through their payment line items — check there too.
        Map<Id, String> lineItemFeeHead = new Map<Id, String>();
        for (Payment_Transaction_Line_Item__c li : [
            SELECT Receipt__c,
                   Fee_Name__c,
                   Fee_Installment__r.Fee_Type__r.Fee_Head__c,
                   Fee_Assignment__r.Fee_Type__r.Fee_Head__c
            FROM Payment_Transaction_Line_Item__c
            WHERE Receipt__c IN :receipts
            LIMIT 10000
        ]) {
            if (lineItemFeeHead.containsKey(li.Receipt__c)) continue;
            String head = null;
            if (li.Fee_Installment__r != null && li.Fee_Installment__r.Fee_Type__r != null) {
                head = li.Fee_Installment__r.Fee_Type__r.Fee_Head__c;
            }
            if (String.isBlank(head) && li.Fee_Assignment__r != null && li.Fee_Assignment__r.Fee_Type__r != null) {
                head = li.Fee_Assignment__r.Fee_Type__r.Fee_Head__c;
            }
            if (String.isBlank(head)) head = li.Fee_Name__c;
            if (String.isNotBlank(head)) lineItemFeeHead.put(li.Receipt__c, head);
        }

        for (Receipt_and_Invoice__c ri : receipts) {
            heads.put(ri.Id, feeHeadOf(ri, lineItemFeeHead, ctx.feeHeadByContact));
        }
        return heads;
    }

    private static String feeHeadOf(Receipt_and_Invoice__c ri, Map<Id, String> lineItemFeeHead,
                                    Map<Id, String> contactFeeHeadMap) {
        if (ri.Fee_Type__r != null && String.isNotBlank(ri.Fee_Type__r.Fee_Head__c)) {
            return ri.Fee_Type__r.Fee_Head__c;
        }
        if (ri.Fee_Installment__r != null && ri.Fee_Installment__r.Fee_Type__r != null
                && String.isNotBlank(ri.Fee_Installment__r.Fee_Type__r.Fee_Head__c)) {
            return ri.Fee_Installment__r.Fee_Type__r.Fee_Head__c;
        }
        if (ri.Fee_Assignment__r != null && ri.Fee_Assignment__r.Fee_Type__r != null
                && String.isNotBlank(ri.Fee_Assignment__r.Fee_Type__r.Fee_Head__c)) {
            return ri.Fee_Assignment__r.Fee_Type__r.Fee_Head__c;
        }
        if (lineItemFeeHead.containsKey(ri.Id)) return lineItemFeeHead.get(ri.Id);
        // Last resort: the student's fee plan. Approximate, never overrides a real value.
        return ri.Contact__c != null ? contactFeeHeadMap.get(ri.Contact__c) : null;
    }

    // The Term record Name (e.g. "2026-AUG-MCA-Sem 1-ONLINE") identifies the exact
    // batch term, unlike Term_Reference__c ("Semester 1") which repeats across batches.
    private static String termLabel(hed__Term__c term) {
        return term == null ? null : term.Name;
    }

    private static String categoryOf(String title) {
        String t = title == null ? '' : title.toLowerCase();
        for (String category : CATEGORY_ORDER) {
            for (String keyword : CATEGORY_KEYWORDS.get(category)) {
                if (t.contains(keyword)) return category;
            }
        }
        return CATEGORY_OTHER;
    }

    // ─── Filter options ──────────────────────────────────────────────────────
    // Read from the master records, not from documents, so they never need the full
    // document set loaded.

    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        FilterOptions opts = new FilterOptions();
        for (hed__Program_Plan__c pp : [
            SELECT Name, hed__Account__r.Name
            FROM hed__Program_Plan__c
            WHERE hed__Account__c != null
            ORDER BY Name
            LIMIT 5000
        ]) {
            String program = pp.hed__Account__r.Name;
            if (!opts.batchesByProgram.containsKey(program)) {
                opts.batchesByProgram.put(program, new List<String>());
                opts.programs.add(program);
            }
            opts.batchesByProgram.get(program).add(pp.Name);
        }
        opts.programs.sort();

        Set<String> heads = new Set<String>(FEE_PREF_TO_HEAD.values());
        for (AggregateResult ar : [
            SELECT Fee_Head__c head FROM Fee_Type__c WHERE Fee_Head__c != null GROUP BY Fee_Head__c LIMIT 500
        ]) {
            heads.add((String) ar.get('head'));
        }
        opts.feeHeads.addAll(heads);
        opts.feeHeads.sort();
        return opts;
    }

    // Terms the students of one batch are enrolled in.
    @AuraEnabled(cacheable=true)
    public static List<String> getTermOptions(String programPlan) {
        List<String> terms = new List<String>();
        if (String.isBlank(programPlan)) return terms;
        for (AggregateResult ar : [
            SELECT Term__r.Name termName
            FROM hed__Program_Enrollment__c
            WHERE hed__Program_Plan__r.Name = :programPlan
              AND Term__c != null
            GROUP BY Term__r.Name
            LIMIT 2000
        ]) {
            terms.add((String) ar.get('termName'));
        }
        terms.sort();
        return terms;
    }

    @AuraEnabled
    public static String getFileContent(Id versionId) {
        if (versionId == null) return null;
        ContentVersion cv = [
            SELECT VersionData
            FROM ContentVersion
            WHERE Id = :versionId
            LIMIT 1
        ];
        return EncodingUtil.base64Encode(cv.VersionData);
    }

    // Several files in one round trip, base64 by ContentVersion Id, so a ZIP of many
    // small files isn't one server call per file. Files are read one at a time and the
    // call stops before the heap runs out; the caller re-requests any Id not returned.
    @AuraEnabled
    public static Map<Id, String> getFileContents(List<Id> versionIds) {
        Map<Id, String> contents = new Map<Id, String>();
        if (versionIds == null || versionIds.isEmpty()) return contents;
        for (ContentVersion meta : [SELECT Id, ContentSize FROM ContentVersion WHERE Id IN :versionIds]) {
            // The blob plus its base64 copy (~1.34×) must both fit, with room to spare.
            Integer needed = (Integer) Math.ceil(meta.ContentSize * 2.5);
            if (!contents.isEmpty() && Limits.getHeapSize() + needed > Limits.getLimitHeapSize() - FILE_HEAP_MARGIN) break;
            ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :meta.Id];
            contents.put(meta.Id, EncodingUtil.base64Encode(cv.VersionData));
        }
        return contents;
    }

    // ─── Internals ───────────────────────────────────────────────────────────

    // The request's filters, normalised: blank → null, "All" → null.
    private class Filters {
        final Id           recordId;
        final String       programName;
        final String       programPlan;
        final String       term;
        final String       feeHead;
        final String       searchPattern;
        final List<String> includePatterns;
        final List<String> excludePatterns;
        final Boolean      includeReceipts;

        Filters(Id recordId, String category, String programName, String programPlan,
                String term, String feeHead, String searchTerm) {
            String cat = String.isBlank(category) ? CATEGORY_ALL : category;
            if (cat != CATEGORY_ALL && cat != CATEGORY_OTHER && !CATEGORY_KEYWORDS.containsKey(cat)) {
                throw new AuraHandledException('Unknown category: ' + category);
            }
            this.recordId    = recordId;
            this.programName = valueOrNull(programName);
            this.programPlan = valueOrNull(programPlan);
            this.term        = valueOrNull(term);
            this.feeHead     = valueOrNull(feeHead);

            String search = String.isBlank(searchTerm) ? null : searchTerm.trim();
            this.searchPattern = search == null ? null
                : '%' + search.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_') + '%';

            // Mirror categoryOf in SOQL: match this category's keywords and none of the
            // keywords of any category ahead of it.
            List<String> include = null;
            List<String> exclude = new List<String>();
            for (String c : CATEGORY_ORDER) {
                if (c == cat) {
                    include = likePatterns(CATEGORY_KEYWORDS.get(c));
                    break;
                }
                if (cat != CATEGORY_ALL) exclude.addAll(likePatterns(CATEGORY_KEYWORDS.get(c)));
            }
            this.includePatterns = include;
            this.excludePatterns = (cat == CATEGORY_ALL || exclude.isEmpty()) ? null : exclude;

            this.includeReceipts = recordId == null && (cat == CATEGORY_ALL || cat == CATEGORY_RECEIPT);
        }
    }

    private static String valueOrNull(String value) {
        return (String.isBlank(value) || value == CATEGORY_ALL) ? null : value;
    }

    private static List<String> likePatterns(List<String> keywords) {
        List<String> patterns = new List<String>();
        for (String k : keywords) patterns.add('%' + k + '%');
        return patterns;
    }

    // One row from any stream, with its position in the global order:
    // sort date DESC, rank ASC, Id DESC. Ids compare with String.compareTo
    // (case-sensitive), which agrees with SOQL's ordering of Ids.
    private class Row implements Comparable {
        ContentDocumentLink    link;
        Receipt_and_Invoice__c receipt;
        Datetime               sortDate;
        Integer                rank;
        Id                     id;
        Boolean                keep = true; // false when a post-query filter drops it

        Row(ContentDocumentLink cdl) {
            link     = cdl;
            sortDate = cdl.ContentDocument.LastModifiedDate;
            rank     = RANK_FILE;
            id       = cdl.ContentDocumentId;
        }

        Row(Receipt_and_Invoice__c ri) {
            receipt  = ri;
            sortDate = ri.CreatedDate;
            rank     = RANK_RECEIPT;
            id       = ri.Id;
        }

        public Integer compareTo(Object other) {
            Row o = (Row) other;
            if (sortDate != o.sortDate) return sortDate > o.sortDate ? -1 : 1;
            if (rank != o.rank)         return rank < o.rank ? -1 : 1;
            return -String.valueOf(id).compareTo(String.valueOf(o.id));
        }
    }

    // Opaque to the client: the last row read, as JSON {d: epoch ms, r: rank, i: Id}.
    private class Cursor {
        final Datetime sortDate;
        final Integer  rank;
        final Id       recordId;

        Cursor(Row r) {
            sortDate = r.sortDate;
            rank     = r.rank;
            recordId = r.id;
        }

        Cursor(Datetime sortDate, Integer rank, Id recordId) {
            this.sortDate = sortDate;
            this.rank     = rank;
            this.recordId = recordId;
        }

        String encode() {
            return JSON.serialize(new Map<String, Object>{ 'd' => sortDate.getTime(), 'r' => rank, 'i' => recordId });
        }
    }

    private static Cursor decodeCursor(String encoded) {
        if (String.isBlank(encoded)) return null;
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(encoded);
            return new Cursor(
                Datetime.newInstance((Long) m.get('d')),
                (Integer) m.get('r'),
                Id.valueOf((String) m.get('i'))
            );
        } catch (Exception e) {
            throw new AuraHandledException('Invalid page cursor');
        }
    }
}