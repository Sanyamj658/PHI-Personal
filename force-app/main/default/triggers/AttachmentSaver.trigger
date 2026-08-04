trigger AttachmentSaver on Attachment (after delete) {
	// Get the current user's profile name
	Profile prof = [select Name from Profile where Id = :UserInfo.getProfileId() ];
	
	// If current user is not a System Administrator, do not allow Attachments to be deleted
	if (!'System Administrator'.equalsIgnoreCase(prof.Name)) {
		for (Attachment a : Trigger.old) {
			a.addError('Unable to delete attachments.');
		}	
	}
}