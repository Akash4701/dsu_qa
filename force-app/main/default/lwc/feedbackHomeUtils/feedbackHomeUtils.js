// Shared, framework-free helpers for the Feedback Management home components.

export const DEFAULT_TARGET_RATE = 75;

const STATUS_TONE = {
    Live: 'success',
    Scheduled: 'info',
    Closed: 'neutral',
    Submitted: 'success',
    Pending: 'warning',
    Active: 'success',
    Inactive: 'neutral'
};

export function statusTone(status) {
    return STATUS_TONE[status] || 'neutral';
}

export function rateTone(rate, target = DEFAULT_TARGET_RATE) {
    if (rate >= target) {
        return 'success';
    }
    return rate >= target - 15 ? 'warning' : 'error';
}

export function recordPage(recordId) {
    return { type: 'standard__recordPage', attributes: { recordId, actionName: 'view' } };
}

export function newRecordPage(objectApiName) {
    return { type: 'standard__objectPage', attributes: { objectApiName, actionName: 'new' } };
}

export function plural(count, singular, pluralForm = `${singular}s`) {
    return `${count} ${count === 1 ? singular : pluralForm}`;
}

export function greeting(date = new Date()) {
    const hour = date.getHours();
    if (hour < 12) {
        return 'Good morning';
    }
    return hour < 17 ? 'Good afternoon' : 'Good evening';
}

// Apex Dates arrive as 'YYYY-MM-DD'. Parse the parts so the time zone cannot shift the day.
export function parseDate(value) {
    if (!value) {
        return null;
    }
    const [y, m, d] = String(value).split('-').map(Number);
    return new Date(y, m - 1, d);
}

export function formatShort(value) {
    const date = parseDate(value);
    return date ? date.toLocaleDateString(undefined, { day: 'numeric', month: 'short' }) : '—';
}

export function formatWindow(start, end) {
    if (!start && !end) {
        return 'No dates set';
    }
    return `${formatShort(start)} – ${formatShort(end)}`;
}

function startOfDay(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function dayDiff(from, to) {
    return Math.round((startOfDay(to) - startOfDay(from)) / 86400000);
}

/**
 * Where a schedule sits in its window: percent elapsed plus a human caption.
 * @returns {{ percent: number, caption: string, urgent: boolean }}
 */
export function scheduleTiming(row, today = new Date()) {
    const start = parseDate(row.startDate);
    const end = parseDate(row.endDate);
    if (row.status === 'Scheduled') {
        const days = start ? dayDiff(today, start) : null;
        return { percent: 0, caption: days === null ? 'Dates not set' : `Starts in ${plural(days, 'day')}`, urgent: false };
    }
    if (row.status === 'Closed') {
        const days = end ? dayDiff(end, today) : null;
        return { percent: 100, caption: days === null ? 'Closed' : `Ended ${plural(days, 'day')} ago`, urgent: false };
    }
    if (!start || !end) {
        return { percent: 50, caption: 'Open now', urgent: false };
    }
    const total = Math.max(1, dayDiff(start, end));
    const elapsed = Math.min(total, Math.max(0, dayDiff(start, today)));
    const left = dayDiff(today, end);
    return {
        percent: Math.round((elapsed / total) * 100),
        caption: left === 0 ? 'Closes today' : `${plural(left, 'day')} left`,
        urgent: left <= 3
    };
}

export function initials(name) {
    if (!name) {
        return '?';
    }
    return name
        .split(/\s+/)
        .filter(Boolean)
        .slice(0, 2)
        .map((part) => part[0].toUpperCase())
        .join('');
}

export function matchesSearch(search, ...values) {
    const needle = (search || '').trim().toLowerCase();
    if (!needle) {
        return true;
    }
    return values.some((value) => value && String(value).toLowerCase().includes(needle));
}

function csvCell(value) {
    const text = value === null || value === undefined ? '' : String(value);
    return /[",\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

export function toCsv(columns, rows) {
    const header = columns.map((c) => csvCell(c.label)).join(',');
    const lines = rows.map((row) => columns.map((c) => csvCell(row[c.field])).join(','));
    return [header, ...lines].join('\n');
}

export function downloadCsv(filename, columns, rows) {
    const blob = new Blob([toCsv(columns, rows)], { type: '' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}