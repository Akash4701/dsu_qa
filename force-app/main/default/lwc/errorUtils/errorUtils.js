/**
 * errorUtils - ONE place that turns anything a Lightning Web Component can catch into readable text.
 *
 * Why this exists: every component used to unpack errors itself (error.body.message, error.body?.message ||
 * error.message, ...). Those copies disagree, miss field-level errors, and show raw system text. Import this
 * module instead:
 *
 *   import { reduceErrors, getErrorMessage, handleError, showErrorToast } from 'c/errorUtils';
 *
 *   // imperative Apex call
 *   try { await save({ ... }); } catch (error) { handleError(this, error, { title: 'Could not save' }); }
 *
 *   // @wire result
 *   get errors() { return this.wired.error ? reduceErrors(this.wired.error) : []; }
 *
 * It is a plain module (no template), so adopting it changes nothing until a component imports it.
 *
 * Shapes understood (all produced by the platform, none by us):
 *   - Apex @AuraEnabled failure           { body: { message } }
 *   - UI API / LDS read error             { body: [{ message }] }  or  { body: { message } }
 *   - UI API / LDS save error             { body: { output: { errors, fieldErrors }, message } }
 *   - lightning-record-edit-form onerror  { detail: { message, detail, output: { ... } } }
 *   - validation errors                   { body: { pageErrors, fieldErrors } }
 *   - JavaScript Error / TypeError        { message }
 *   - a bare string, an array of any of the above, or something unrecognisable
 */
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export const DEFAULT_ERROR_MESSAGE =
    'Something went wrong. Please try again, or contact your administrator if it keeps happening.';
export const NETWORK_ERROR_MESSAGE = 'Could not reach Salesforce. Check your connection and try again.';

// An @AuraEnabled method that throws AuraHandledException without setMessage() reaches the browser with
// this useless text. Treat it as "no message" so the user gets the friendly default instead.
const USELESS_MESSAGES = new Set(['Script-thrown exception', '[object Object]', 'undefined', 'null']);

// "Update failed. First exception on row 0 with id 001...; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, <message>: [Field]"
const DML_FIRST_ERROR = /first error:\s*[A-Z][A-Z0-9_]+,\s*([\s\S]*?)(?::\s*\[[^\]]*\])?\s*$/;
// Any remaining trailing ": []" / ": [Field__c]" noise left by Apex DML messages.
const TRAILING_FIELD_LIST = /:\s*\[[^\]]*\]\s*$/;

/**
 * Cleans one message: trims it, pulls the human part out of Apex DML wrappers, drops system noise.
 * Returns '' when nothing useful is left.
 */
export function cleanMessage(message) {
    if (typeof message !== 'string') {
        return '';
    }
    let text = message.trim();
    const dml = text.match(DML_FIRST_ERROR);
    if (dml && dml[1]) {
        text = dml[1].trim();
    }
    text = text.replace(TRAILING_FIELD_LIST, '').trim();
    return USELESS_MESSAGES.has(text) ? '' : text;
}

function addMessage(result, message) {
    const text = cleanMessage(message);
    if (text && !result.messages.includes(text)) {
        result.messages.push(text);
    }
}

function addFieldErrors(result, fieldErrors) {
    if (!fieldErrors || typeof fieldErrors !== 'object') {
        return;
    }
    Object.keys(fieldErrors).forEach((field) => {
        const entries = Array.isArray(fieldErrors[field]) ? fieldErrors[field] : [fieldErrors[field]];
        entries.forEach((entry) => {
            const text = cleanMessage(entry && typeof entry === 'object' ? entry.message : entry);
            if (!text) {
                return;
            }
            result.fieldErrors[field] = result.fieldErrors[field] || [];
            if (!result.fieldErrors[field].includes(text)) {
                result.fieldErrors[field].push(text);
            }
            addMessage(result, text);
        });
    });
}

function collect(result, error, depth) {
    // Depth guard: a self-referencing or absurdly nested object must never hang or throw.
    if (error === null || error === undefined || depth > 6) {
        return;
    }
    if (typeof error === 'string') {
        addMessage(result, error);
        return;
    }
    if (Array.isArray(error)) {
        error.forEach((item) => collect(result, item, depth + 1));
        return;
    }
    if (typeof error !== 'object') {
        return;
    }

    if (typeof error.status === 'number') {
        result.statusCode = error.status;
    }
    if (typeof error.statusCode === 'number') {
        result.statusCode = error.statusCode;
    }

    // Wrapped responses: { body } (Apex / UI API) and { detail } (lightning-record-edit-form onerror).
    if (error.body !== undefined && error.body !== null) {
        collect(result, error.body, depth + 1);
    }
    if (error.detail !== undefined && error.detail !== null && typeof error.detail === 'object') {
        collect(result, error.detail, depth + 1);
    } else if (typeof error.detail === 'string') {
        addMessage(result, error.detail);
    }

    // UI API save errors and validation errors.
    if (error.output) {
        collect(result, error.output.errors, depth + 1);
        addFieldErrors(result, error.output.fieldErrors);
    }
    collect(result, error.pageErrors, depth + 1);
    addFieldErrors(result, error.fieldErrors);

    // Apex and JavaScript errors carry a plain message.
    addMessage(result, error.message);
}

/**
 * The single normaliser everything else is built on.
 *
 * @returns {{ messages: string[], fieldErrors: Object<string, string[]>, statusCode: (number|undefined), isNetworkError: boolean }}
 *   messages: de-duplicated, readable, never contains technical noise. Empty only when `error` is null/undefined.
 */
export function normalizeError(error) {
    const result = { messages: [], fieldErrors: {}, statusCode: undefined, isNetworkError: false };
    if (error === null || error === undefined) {
        return result;
    }

    try {
        collect(result, error, 0);
    } catch (e) {
        // A malformed error object must never make error handling itself throw.
        result.messages = [];
    }

    // fetch() failing before any response (offline, blocked, dropped connection).
    result.isNetworkError =
        result.statusCode === 0 || (error instanceof TypeError && /failed to fetch|network/i.test(error.message || ''));
    if (result.isNetworkError) {
        result.messages = [NETWORK_ERROR_MESSAGE];
    }

    if (result.messages.length === 0) {
        result.messages.push(DEFAULT_ERROR_MESSAGE);
    }
    return result;
}

/** All messages for an error, as an array (what the Trailhead module calls reduceErrors). [] for no error. */
export function reduceErrors(error) {
    return normalizeError(error).messages.filter(() => error !== null && error !== undefined);
}

/** The messages joined into one string ('' for no error). Handy for a toast, a label or an inline message. */
export function getErrorMessage(error, separator = ' ') {
    return reduceErrors(error).join(separator);
}

/** Field-level errors, keyed by field API name: { Email: ['Invalid email'] }. {} when there are none. */
export function getFieldErrors(error) {
    return normalizeError(error).fieldErrors;
}

/** Shows a standard toast from any component: showToast(this, { title, message, variant }). */
export function showToast(source, { title = '', message = '', variant = 'info', mode = 'dismissible' } = {}) {
    source.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
}

/** Shows an error toast built from any caught error. */
export function showErrorToast(source, error, title = 'Error', mode = 'dismissible') {
    showToast(source, { title, message: getErrorMessage(error), variant: 'error', mode });
}

/**
 * The one-liner for a catch block: logs the full error for developers (browser console), shows the clean
 * message to the user, and returns the messages in case the component also wants to render them inline.
 *
 * @param {LightningElement} source  the component (pass `this`)
 * @param {*} error                  whatever was caught
 * @param {{ title?: string, context?: string, toast?: boolean }} [options]
 *        title:   toast title (default "Error")
 *        context: label for the console log, e.g. 'contactList.loadContacts'
 *        toast:   false to log and return the messages without showing a toast
 */
export function handleError(source, error, { title = 'Error', context = '', toast = true } = {}) {
    // eslint-disable-next-line no-console
    console.error(context ? `[${context}]` : '[errorUtils]', error);
    const messages = reduceErrors(error);
    if (toast && messages.length > 0) {
        showErrorToast(source, error, title);
    }
    return messages;
}