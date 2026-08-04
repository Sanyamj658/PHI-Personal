import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAttachments from '@salesforce/apex/AttachmentController.getAttachments';
import updateAttachment from '@salesforce/apex/AttachmentController.updateAttachment';
import deleteAttachment from '@salesforce/apex/AttachmentController.deleteAttachment';

const COLUMNS = [
	{ label: 'Type', fieldName: 'type', type: 'text', wrapText:true},
	{
		label: 'Title',
		fieldName: 'downloadUrl',
        wrapText:true,
		type: 'url',
		typeAttributes: {
			label: { fieldName: 'name' },
			target: '_blank'
		}
	},
	{ label: 'Last Modified By', fieldName: 'lastModifiedBy', type: 'text', wrapText:true },
	{ label: 'Created By', fieldName: 'createdBy', type: 'text', wrapText:true },
	{
		type: 'action',
		typeAttributes: {
			rowActions: [
				{ label: 'View', name: 'view' },
				{ label: 'Edit', name: 'edit' },
				{ label: 'Delete', name: 'delete' }
			]
		}
	}
];

export default class AttachmentDataTable extends LightningElement {
	@api recordId;
	isRefreshed = false;
	@track mode = 'view';
	@track isLoading = false;
	@track columns = COLUMNS;
	@track attachmentData = [];
	@track isModalOpen = false;
	@track selectedAttachment = null;

	connectedCallback() {
		this.getAttachmentRecord(this.isRefreshed);
	}

	get attachmentTitle() {
		const count = this.attachmentData?.length || 0;
		return `Manage Attachments (${count})`;
	}

	handleRowAction(event) {
		const actionName = event.detail.action.name;
		this.selectedAttachment = event.detail.row;
		switch (actionName) {
			case 'view':
				this.mode = 'view';
				this.isModalOpen = true;
				break;
			case 'edit':
				this.mode = 'edit';
				this.isModalOpen = true;
				break;
			case 'delete':
				this.deleteAttachmentHandler(this.selectedAttachment.id);
				break;
			default:
		}
	}

	handleSave(event) {
		const updatedAttachment = event.detail;
		updateAttachment({ attachmentId: updatedAttachment.id, name: updatedAttachment.name, isPrivate: updatedAttachment.isPrivate, description: updatedAttachment.description })
			.then(() => {
				this.attachmentData = this.attachmentData.map((attachment) =>
					attachment.id === updatedAttachment.id ? { ...updatedAttachment } : attachment
				);
				this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Attachment updated successfully', variant: 'success' }));
			})
			.catch((error) => {
				console.error('Error occurred while updating attachment: ' + JSON.stringify(error));
				this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Error occurred while updating attachment', variant: 'error' }));
			})
			.finally(() => {
				this.closeModal();
			});
	}

	closeModal() {
		this.isModalOpen = false;
	}

	handleDelete(event) {
		if (event && event.detail) {
			this.deleteAttachmentHandler(event.detail);
		}
	}

	deleteAttachmentHandler(attachmentId) {
		deleteAttachment({ attachmentId })
			.then(() => {
				this.attachmentData = this.attachmentData.filter(
					attachment => attachment.id !== attachmentId
				);
				this.closeModal();
				this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Attachment deleted successfully', variant: 'success' }));
			})
			.catch(error => {
				console.error('Error deleting attachment: ' + JSON.stringify(error));
				let errorString = JSON.stringify(error?.body?.message);
				if (!errorString.includes('Unable to delete attachments.')) {
					this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Error occurred while deleting attachment: '+ JSON.stringify(error), variant: 'error' }));
				} else {
					this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: 'Error: You do not have permission to delete the attachment(s).', variant: 'error' }));
				}
			});
	}

	refreshAttachments() {
		this.isRefreshed = true;
		this.getAttachmentRecord(this.isRefreshed);
	}

	getAttachmentRecord() {
		this.isLoading = true;
		getAttachments({ recordId: this.recordId })
			.then(data => {
				this.attachmentData = data.map(att => ({
					...att,
					downloadUrl: `/servlet/servlet.FileDownload?file=${att.id}`,
					createdBy: att.createdByName + ', ' + att.createdDate,
					lastModifiedBy: att.lastModifiedByName + ', ' + att.lastModifiedDate
				}));
				if (this.isRefreshed) {
					this.dispatchEvent(new ShowToastEvent({ title: 'Refreshed', message: 'Attachment list updated', variant: 'success' }));
				}
			})
			.catch(error => {
				console.error('Error occurred while refreshing attachments: ' + JSON.stringify(error));
				this.dispatchEvent(
					new ShowToastEvent({ title: 'Error', message: this.isRefreshed ? 'Failed to refresh attachments.' : 'Failed to load attachments.', variant: 'error' })
				);
			})
			.finally(() => {
				this.isLoading = false;
				this.isRefreshed = false;
			});
	}
}