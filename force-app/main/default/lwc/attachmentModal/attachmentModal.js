import { LightningElement, api, track } from 'lwc';

export default class AttachmentModal extends LightningElement {
	@api attachment;
	@api mode = 'view';
	viewAttachmentURL = '';
	@track editedAttachment = {};

	get isViewMode() {
		return this.mode === 'view';
	}

	get isEditMode() {
		return this.mode === 'edit';
	}

	get modalTitle() {
		return this.isViewMode ? 'Attachment Details' : 'Edit Attachment';
	}

	connectedCallback() {
		this.viewAttachmentURL = `/servlet/servlet.FileDownload?file=${this.attachment.id}`;
		this.editedAttachment = { ...this.attachment }; // Local copy
	}

	handlePrivateChange(event) {
		this.editedAttachment.isPrivate = event.target.checked;
	}

	handleNameChange(event) {
		this.editedAttachment.name = event.target.value;
	}

	handleDescriptionChange(event) {
		this.editedAttachment.description = event.target.value;
	}

	switchToEdit() {
		this.mode = 'edit'; // Switch mode dynamically
	}

	//Dispatch close event to parent component
	closeModal() {
		this.dispatchEvent(new CustomEvent('close'));
	}

	//Dispatch save event to parent component
	saveChanges() {
		this.dispatchEvent(new CustomEvent('save', { detail: this.editedAttachment }));
	}

	//Dispatch delete event to parent component
	deleteHandler() {
		this.dispatchEvent(new CustomEvent('delete', { detail: this.attachment.id }));
	}
}