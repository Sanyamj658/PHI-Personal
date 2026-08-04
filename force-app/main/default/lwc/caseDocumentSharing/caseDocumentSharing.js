/**
 * @description  caseDocumentSharing LWC – displays all files attached to a Case
 *               and allows bulk sharing to the patient's mobile app.
 *
 * Features
 * ─────────
 *  • Placed on the Case record page; receives the Case Id via @api recordId.
 *  • Resolves Case → Contact → App_User__c to determine sharing eligibility.
 *  • Shows an inline warning banner when no mobile account is linked.
 *  • Fetches ContentDocuments via @wire (cacheable Apex) – auto-refreshes.
 *  • Already-shared files shown as checked + disabled with a "Shared" badge.
 *  • Client-side search / filter (no extra server round-trip).
 *  • "Select All" checkbox with indeterminate-state support.
 *  • Bulk "Share to Mobile App" action with spinner and toast feedback.
 *  • Calls refreshApex after a successful share to invalidate the wire cache.
 */

import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent }                      from 'lightning/platformShowToastEvent';
import { refreshApex }                         from '@salesforce/apex';

import getCaseFilesData  from '@salesforce/apex/CaseDocumentSharingController.getCaseFilesData';
import shareDocuments    from '@salesforce/apex/CaseDocumentSharingController.shareDocuments';

// ─── File-type → SLDS doctype icon map ───────────────────────────────────────
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

// ─── File-type → colour pill CSS class ───────────────────────────────────────
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

export default class CaseDocumentSharing extends LightningElement {

    // ── Public API ────────────────────────────────────────────────────────────
    /** Auto-populated by the Case record page. */
    @api recordId;

    // ── Tracked state ─────────────────────────────────────────────────────────
    @track allFiles      = [];
    @track searchKey     = '';
    @track selectedIds   = new Set();
    @track selectAll     = false;
    @track isLoading     = true;
    @track errorMessage  = null;
    @track canShare      = false;
    @track noShareReason = null;

    /** Kept for refreshApex after a successful share. */
    _wiredResult;

    // ─── Wire ─────────────────────────────────────────────────────────────────

    @wire(getCaseFilesData, { caseId: '$recordId' })
    wiredData(result) {
        this._wiredResult = result;
        this.isLoading    = false;

        if (result.data) {
            this.errorMessage  = null;
            this.canShare      = result.data.canShare;
            this.noShareReason = result.data.noShareReason;
            this._buildFileList(result.data.files || []);
        } else if (result.error) {
            this.errorMessage = this._extractErrorMessage(result.error);
            this.allFiles     = [];
        }
    }

    // ─── Computed Getters ─────────────────────────────────────────────────────

    get hasError()         { return !!this.errorMessage; }
    get hasFiles()         { return !this.hasError && this.allFiles.length > 0; }
    get hasNoFiles()       { return !this.hasError && this.allFiles.length === 0 && !this.isLoading; }
    /** Show warning banner when sharing is not possible but there was no hard error. */
    get showShareWarning() { return !this.hasError && !this.canShare && !!this.noShareReason; }

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

    get hasSharedFiles()  { return this.sharedCount > 0; }

    get sharedFilesLabel() {
        return `${this.sharedCount} shared`;
    }

    get newSelectionCount() {
        return [...this.selectedIds].filter(id => {
            const f = this.allFiles.find(file => file.contentDocumentId === id);
            return f && !f.isShared;
        }).length;
    }

    get hasNewSelection()  { return this.newSelectionCount > 0; }

    get newSelectionLabel() {
        return `${this.newSelectionCount} selected`;
    }

    /** Disabled when no mobile account is linked, nothing selected, or loading. */
    get isShareDisabled() {
        return !this.canShare || this.newSelectionCount === 0 || this.isLoading;
    }

    /** True when SOME (not all) unshared files are selected → indeterminate. */
    get selectAllIndeterminate() {
        const unshared = this.allFiles.filter(f => !f.isShared);
        if (unshared.length === 0) { return false; }
        const selected = unshared.filter(f => this.selectedIds.has(f.contentDocumentId));
        return selected.length > 0 && selected.length < unshared.length;
    }

    // ─── Event Handlers ───────────────────────────────────────────────────────

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this._syncSelectAllState();
    }

    handleSelectAll(event) {
        const checked = event.target.checked;
        this.selectAll = checked;

        // Apply to every unshared file currently visible in the filtered list
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
        // Only pass IDs of newly-selected (not yet shared) files
        const toShare = [...this.selectedIds].filter(id => {
            const f = this.allFiles.find(file => file.contentDocumentId === id);
            return f && !f.isShared;
        });

        if (toShare.length === 0) {
            this._toast(
                'No New Files Selected',
                'Please select at least one file that has not been shared yet.',
                'warning'
            );
            return;
        }

        this.isLoading = true;
        try {
            const count = await shareDocuments({
                caseId             : this.recordId,
                contentDocumentIds : toShare
            });

            this._toast(
                'Shared Successfully',
                `${count} file${count !== 1 ? 's' : ''} shared to the mobile app.`,
                'success'
            );

            // Reset selections before refreshing
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
                fileIcon         : FILE_ICON_MAP[type]       || 'doctype:unknown',
                fileTypePillClass: FILE_TYPE_PILL_CLASS[type] || 'type-pill type-pill_default',
                formattedDate    : this._formatDate(f.createdDate),
                isChecked        : isShared || isSelected,
                isDisabled       : isShared,
                checkboxTitle    : isShared
                                     ? 'Already shared to mobile app'
                                     : 'Select to share',
                rowClass         : isShared
                                     ? 'slds-hint-parent row-shared'
                                     : 'slds-hint-parent',
            };
        });
    }

    /**
     * Re-stamps isChecked after each row selection change
     * without mutating objects in-place (returns a new mapped array).
     */
    _rebuildCheckedState() {
        this.allFiles = this.allFiles.map(f => ({
            ...f,
            isChecked: f.isShared || this.selectedIds.has(f.contentDocumentId),
        }));
    }

    /**
     * Keeps the Select-All checkbox in sync after row changes or search filter.
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
     * Converts an Apex Datetime string to a locale-friendly display string.
     */
    _formatDate(dateStr) {
        if (!dateStr) { return '—'; }
        try {
            return new Intl.DateTimeFormat(undefined, {
                day  : 'numeric',
                month: 'short',
                year : 'numeric',
            }).format(new Date(dateStr));
        } catch {
            return dateStr;
        }
    }

    /** Fires a ShowToastEvent. */
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /** Extracts a readable message from an Apex or JS error object. */
    _extractErrorMessage(error) {
        if (!error)                  { return 'An unexpected error occurred.'; }
        if (typeof error === 'string') { return error; }
        if (error.body?.message)     { return error.body.message; }
        if (error.message)           { return error.message; }
        return JSON.stringify(error);
    }
}