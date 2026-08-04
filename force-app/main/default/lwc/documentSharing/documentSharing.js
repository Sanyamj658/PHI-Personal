/**
 * @description  DocumentSharing LWC – displays and shares files linked to the
 *               Contact on an App_User__c record page.
 *
 * Features
 * ─────────
 *  • Fetches ContentDocuments via @wire (cacheable Apex) – auto-refreshes.
 *  • Shows already-shared files as checked + disabled with a "Shared" badge.
 *  • Search / filter by file name (client-side, no extra server round-trip).
 *  • "Select All" checkbox with indeterminate state support.
 *  • Bulk "Share to Mobile App" action with loading spinner and toast feedback.
 *  • Calls refreshApex after a successful share to invalidate the wire cache.
 */

import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent }                      from 'lightning/platformShowToastEvent';
import { refreshApex }                         from '@salesforce/apex';

import getContactFiles  from '@salesforce/apex/DocumentSharingController.getContactFiles';
import shareDocuments   from '@salesforce/apex/DocumentSharingController.shareDocuments';

// ─── File-type → SLDS doctype icon mapping ───────────────────────────────────
const FILE_ICON_MAP = {
    PDF:  'doctype:pdf',
    DOC:  'doctype:word',
    DOCX: 'doctype:word',
    XLS:  'doctype:excel',
    XLSX: 'doctype:excel',
    PPT:  'doctype:ppt',
    PPTX: 'doctype:ppt',
    PNG:  'doctype:image',
    JPG:  'doctype:image',
    JPEG: 'doctype:image',
    GIF:  'doctype:image',
    SVG:  'doctype:image',
    TXT:  'doctype:txt',
    CSV:  'doctype:csv',
    ZIP:  'doctype:zip',
    MP4:  'doctype:mp4',
    MOV:  'doctype:video',
};

// ─── File-type → pill colour CSS class ───────────────────────────────────────
const FILE_TYPE_PILL_CLASS = {
    PDF:  'type-pill type-pill_pdf',
    DOC:  'type-pill type-pill_word',
    DOCX: 'type-pill type-pill_word',
    XLS:  'type-pill type-pill_excel',
    XLSX: 'type-pill type-pill_excel',
    PNG:  'type-pill type-pill_image',
    JPG:  'type-pill type-pill_image',
    JPEG: 'type-pill type-pill_image',
};

// ─────────────────────────────────────────────────────────────────────────────

export default class DocumentSharing extends LightningElement {

    // ── Public API ────────────────────────────────────────────────────────────
    /** Auto-populated by the record page with the current App_User__c Id. */
    @api recordId;

    // ── Tracked state ─────────────────────────────────────────────────────────
    @track allFiles      = [];   // Full list returned by Apex (with computed props)
    @track searchKey     = '';
    @track selectedIds   = new Set();
    @track selectAll     = false;
    @track isLoading     = true;
    @track errorMessage  = null;

    /** Stored so refreshApex can invalidate the wire cache after a share. */
    _wiredResult;

    // ─── Wire ─────────────────────────────────────────────────────────────────

    @wire(getContactFiles, { appUserId: '$recordId' })
    wiredFiles(result) {
        this._wiredResult = result;          // keep reference for refreshApex
        this.isLoading    = false;

        if (result.data) {
            this.errorMessage = null;
            this._buildFileList(result.data);
        } else if (result.error) {
            this.errorMessage = this._extractErrorMessage(result.error);
            this.allFiles     = [];
        }
    }

    // ─── Computed Getters ─────────────────────────────────────────────────────

    get hasError()          { return !!this.errorMessage; }
    get hasFiles()          { return !this.hasError && this.allFiles.length > 0; }
    get hasNoFiles()        { return !this.hasError && this.allFiles.length === 0 && !this.isLoading; }

    get filteredFiles() {
        if (!this.searchKey) { return this.allFiles; }
        const lower = this.searchKey.toLowerCase();
        return this.allFiles.filter(f => f.title.toLowerCase().includes(lower));
    }

    get hasNoSearchResults() {
        return this.hasFiles && this.searchKey && this.filteredFiles.length === 0;
    }

    // ── Stats labels ──────────────────────────────────────────────────────────

    get totalFilesLabel() {
        const n = this.allFiles.length;
        return `${n} file${n !== 1 ? 's' : ''}`;
    }

    get sharedCount() {
        return this.allFiles.filter(f => f.isShared).length;
    }

    get hasSharedFiles() { return this.sharedCount > 0; }

    get sharedFilesLabel() {
        return `${this.sharedCount} shared`;
    }

    get newSelectionCount() {
        return [...this.selectedIds].filter(id => {
            const f = this.allFiles.find(file => file.contentDocumentId === id);
            return f && !f.isShared;
        }).length;
    }

    get hasNewSelection() { return this.newSelectionCount > 0; }

    get newSelectionLabel() {
        return `${this.newSelectionCount} selected`;
    }

    get isShareDisabled() {
        return this.newSelectionCount === 0 || this.isLoading;
    }

    /** True when SOME (not all) unshared files are selected → indeterminate state. */
    get selectAllIndeterminate() {
        const unshared = this.allFiles.filter(f => !f.isShared);
        if (unshared.length === 0) { return false; }
        const selected = unshared.filter(f => this.selectedIds.has(f.contentDocumentId));
        return selected.length > 0 && selected.length < unshared.length;
    }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        // Reset select-all when search changes
        this._syncSelectAllState();
    }

    handleSelectAll(event) {
        const checked = event.target.checked;
        this.selectAll = checked;

        // Apply to every unshared file currently visible (respects search filter)
        this.filteredFiles.forEach(f => {
            if (!f.isShared) {
                if (checked) {
                    this.selectedIds.add(f.contentDocumentId);
                } else {
                    this.selectedIds.delete(f.contentDocumentId);
                }
            }
        });
        this._rebuildCheckedState();
    }

    handleRowSelect(event) {
        const docId   = event.target.dataset.id;
        const checked = event.target.checked;

        if (checked) {
            this.selectedIds.add(docId);
        } else {
            this.selectedIds.delete(docId);
        }
        this._rebuildCheckedState();
        this._syncSelectAllState();
    }

    async handleShare() {
        // Collect only newly-selected (not yet shared) document IDs
        const toShare = [...this.selectedIds].filter(id => {
            const f = this.allFiles.find(file => file.contentDocumentId === id);
            return f && !f.isShared;
        });

        if (toShare.length === 0) {
            this._toast('No New Files Selected',
                'Please select at least one file that has not been shared yet.',
                'warning');
            return;
        }

        this.isLoading = true;
        try {
            const count = await shareDocuments({
                appUserId          : this.recordId,
                contentDocumentIds : toShare
            });

            this._toast(
                'Shared Successfully',
                `${count} file${count !== 1 ? 's' : ''} shared to the mobile app.`,
                'success'
            );

            // Reset selections before refresh
            this.selectedIds = new Set();
            this.selectAll   = false;

            // Invalidate wire cache and re-fetch
            await refreshApex(this._wiredResult);

        } catch (error) {
            this._toast('Share Failed', this._extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    /**
     * Decorates raw Apex FileWrapper objects with computed properties
     * needed by the template (icon, CSS classes, formatted date, etc.).
     */
    _buildFileList(data) {
        this.allFiles = data.map(f => {
            const type       = (f.fileType || 'UNKNOWN').toUpperCase();
            const isShared   = !!f.isShared;
            const isSelected = this.selectedIds.has(f.contentDocumentId);

            return {
                ...f,
                fileIcon        : FILE_ICON_MAP[type]      || 'doctype:unknown',
                fileTypePillClass: FILE_TYPE_PILL_CLASS[type] || 'type-pill type-pill_default',
                formattedDate   : this._formatDate(f.createdDate),
                isChecked       : isShared || isSelected,
                isDisabled      : isShared,
                checkboxTitle   : isShared
                                    ? 'Already shared to mobile app'
                                    : 'Select to share',
                rowClass        : isShared
                                    ? 'slds-hint-parent row-shared'
                                    : 'slds-hint-parent',
            };
        });
    }

    /**
     * Re-stamps the `isChecked` and `rowClass` properties after selection changes
     * (avoids mutating the allFiles array directly – returns a new mapped array).
     */
    _rebuildCheckedState() {
        this.allFiles = this.allFiles.map(f => ({
            ...f,
            isChecked: f.isShared || this.selectedIds.has(f.contentDocumentId),
        }));
    }

    /**
     * Keeps the "Select All" checkbox in sync with the current row selections,
     * accounting only for unshared files visible in the filtered list.
     */
    _syncSelectAllState() {
        const unsharedVisible = this.filteredFiles.filter(f => !f.isShared);
        if (unsharedVisible.length === 0) {
            this.selectAll = false;
            return;
        }
        this.selectAll = unsharedVisible.every(
            f => this.selectedIds.has(f.contentDocumentId)
        );
    }

    /**
     * Converts an Apex Datetime string (e.g. "2024-05-15 14:30:00")
     * to a locale-friendly display string.
     */
    _formatDate(dateStr) {
        if (!dateStr) { return '—'; }
        try {
            const d = new Date(dateStr);
            return new Intl.DateTimeFormat(undefined, {
                day  : 'numeric',
                month: 'short',
                year : 'numeric',
            }).format(d);
        } catch {
            return dateStr;
        }
    }

    /** Fires a ShowToastEvent. */
    _toast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }

    /** Extracts a readable message from an Apex or JS error. */
    _extractErrorMessage(error) {
        if (!error) { return 'An unexpected error occurred.'; }
        if (typeof error === 'string') { return error; }
        if (error.body?.message) { return error.body.message; }
        if (error.message)       { return error.message; }
        return JSON.stringify(error);
    }
}