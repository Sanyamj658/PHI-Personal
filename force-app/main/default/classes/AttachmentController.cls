/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * This class is the controller class of AttachmentDataTable lightning web component.
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 * @author      : concret.io
 * @createdOn   : 29-April-2025    
 * ──────────────────────────────────────────────────────────────────────────────────────────────────
 */
public class AttachmentController { 
	@AuraEnabled
	public static List<AttachmentWrapper> getAttachments(String recordId) {
		List<AttachmentWrapper> attachmentList = new List<AttachmentWrapper>();
		try {
			for (Attachment att : [SELECT Id, Name, CreatedBy.Name, CreatedDate, Owner.Name, LastModifiedBy.Name, LastModifiedDate, BodyLength, Description, IsPrivate, Parent.Name 
				FROM Attachment 
				WHERE 
				ParentId = :recordId 
				ORDER BY LastModifiedDate DESC 
				LIMIT 50000]
			) {
				AttachmentWrapper wrapper = new AttachmentWrapper();
				wrapper.id = att.Id;
				wrapper.name = att.Name;
				wrapper.type = 'Attachment';
				wrapper.isPrivate = att.IsPrivate;
				wrapper.ownerName = att.Owner.Name;
				wrapper.parentName = att.Parent.Name;
				wrapper.description = att.Description;
				wrapper.createdDate = att.CreatedDate.format();
				wrapper.createdByName = att.CreatedBy.Name;
				wrapper.lastModifiedDate = att.LastModifiedDate.format();
				wrapper.lastModifiedByName = att.LastModifiedBy.Name;
				wrapper.fileSize = Math.ceil(att.BodyLength / 1024) + ' KB'; 
				
				attachmentList.add(wrapper);                
			}
			return attachmentList;
		} catch (Exception e) {
			throw new AuraHandledException('Error occurred while fetching attachment details: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void deleteAttachment(String attachmentId) {
		try {
			Attachment attachmentToDelete = [SELECT Id FROM Attachment WHERE Id = :attachmentId LIMIT 1];
			if (attachmentToDelete != null) {
				delete attachmentToDelete;
			}
		} catch (Exception e) {
			throw new AuraHandledException('Error occurred while deleting attachment: ' + e.getMessage());
		}
	}

	@AuraEnabled
	public static void updateAttachment(String attachmentId, String name, Boolean isPrivate, String description) {
		try {
			Attachment attachmentToUpdate = [SELECT Id, Name, IsPrivate, Description FROM Attachment WHERE Id = :attachmentId LIMIT 1];
			if (attachmentToUpdate != null) {
				attachmentToUpdate.Name = name;
				attachmentToUpdate.IsPrivate = isPrivate;
				attachmentToUpdate.Description = description;
				update attachmentToUpdate;
			}
		} catch (Exception e) {
			throw new AuraHandledException('Error occurred while updating attachment details: ' + e.getMessage());
		}
	}

	public class AttachmentWrapper {
		@AuraEnabled public String id;
		@AuraEnabled public String name;
		@AuraEnabled public String type;
		@AuraEnabled public String fileSize;      
		@AuraEnabled public String ownerName;      
		@AuraEnabled public String parentName;      
		@AuraEnabled public Boolean isPrivate;    
		@AuraEnabled public String description;   
		@AuraEnabled public String createdByName;
		@AuraEnabled public String createdDate; 
		@AuraEnabled public String lastModifiedByName; 
		@AuraEnabled public String lastModifiedDate; 
	}
}