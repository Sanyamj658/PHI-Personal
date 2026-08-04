public class ManageAttachmentsController {
    public Contact contact { get; set; }
    public List<AttachmentWrapper> attachments { get; set; }

    public class AttachmentWrapper {
        public Attachment attachment { get; set; }
        public Boolean selected { get; set; }

        public AttachmentWrapper(Attachment attachment) {
            this.attachment = attachment;
            this.selected = false;
        }
    }

    public ManageAttachmentsController(ApexPages.StandardController controller) {
        this.contact = (Contact)controller.getRecord();
        fetchAttachmentDetails();
    }

    public void fetchAttachmentDetails() {
        try {
            this.attachments = new List<AttachmentWrapper>();
            for(Attachment attachment : [SELECT Id, Name, IsPrivate, CreatedDate, CreatedBy.Name 
                FROM Attachment 
                WHERE ParentId = :contact.Id
                ORDER BY CreatedDate DESC
            ]) {
                attachments.add(new AttachmentWrapper(attachment));
            }
        }  catch(Exception excp) {
            addErrorMessage('Error occurred, Please try again, if this issue persists please contact the administrator.');
        }
    }

    public void makeAttachmentsPublic() {
        List<Attachment> attachmentsToUpdate = new List<Attachment>();
        try {
            for(AttachmentWrapper wrapper : attachments) {
                System.debug('name:'+wrapper.attachment.Name + ' || selected:' +wrapper.selected);
                if(wrapper.selected && wrapper.attachment.IsPrivate) {
                    wrapper.attachment.IsPrivate = false;
                    attachmentsToUpdate.add(wrapper.attachment);
                }
            }
    
            if(!attachmentsToUpdate.isEmpty()) {
                update attachmentsToUpdate;
                addConfirmMessage('Attachment(s) updated successfully to Public.');
                fetchAttachmentDetails();
            } else {
                addErrorMessage('No private attachment(s) are selected.');
            }
        } catch(Exception excp) {
            addErrorMessage('Error occurred, Please try again, if this issue persists please contact the administrator.');
        }
    }

    public void makeAttachmentsPrivate() {
        List<Attachment> attachmentsToUpdate = new List<Attachment>();
        try {
            for(AttachmentWrapper wrapper : attachments) {
                System.debug('name:'+wrapper.attachment.Name + ' || selected:' +wrapper.selected);
                if(wrapper.selected && !wrapper.attachment.IsPrivate) {
                    wrapper.attachment.IsPrivate = true;
                    attachmentsToUpdate.add(wrapper.attachment);
                }
            }
    
            if(!attachmentsToUpdate.isEmpty()) {
                update attachmentsToUpdate;
                addConfirmMessage('Attachment(s) updated successfully to Private.');
                fetchAttachmentDetails();
            } else {
                addErrorMessage('No public attachment(s) are selected.');
            }
        } catch(Exception excp) {
            addErrorMessage('Error occurred, Please try again, if this issue persists please contact the administrator.');
        }
    }

    public void addConfirmMessage(String msg) {
		ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.CONFIRM, msg));
	}
	public void addErrorMessage(String msg) {
		ApexPages.addMessage(new ApexPages.message(ApexPages.Severity.ERROR, msg));
	}
}