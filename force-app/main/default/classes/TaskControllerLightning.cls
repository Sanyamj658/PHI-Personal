public class TaskControllerLightning {
	
	@AuraEnabled
    	public static Boolean isSystemAdmin() {
		try {
			User currentUser = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
			if(currentUser != null) {
				return currentUser.Profile.Name == 'System Administrator';
			}
		}  catch(Exception excp) {
			throw new AuraHandledException('Error occurred while fetching user details: ' + excp.getMessage());
		}
		return false;        
	}
	
	@AuraEnabled
	public static Map<String, Map<String, Object>> getFieldMetadata(List<String> fieldNames) {
		Map<String, Map<String, Object>> fieldMetadataMap = new Map<String, Map<String, Object>>();
		try {
			Schema.DescribeSObjectResult taskDescribe = Schema.SObjectType.Task;
			for (String fieldName : fieldNames) {
				Map<String, Object> fieldMetadata = new Map<String, Object>();
				Schema.DescribeFieldResult fieldDescribe = taskDescribe.fields.getMap().get(fieldName).getDescribe();
				if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST || fieldDescribe.getType() == Schema.DisplayType.COMBOBOX) {
					List<PicklistOption> picklistOptions = new List<PicklistOption>();	
					String defaultValue = '';		
					for (Schema.PicklistEntry picklistEntry : fieldDescribe.getPicklistValues()) {
						picklistOptions.add(new PicklistOption(picklistEntry.getLabel(), picklistEntry.getValue()));
						if (picklistEntry.isDefaultValue()) {
							defaultValue = picklistEntry.getValue();
						}
					}
					fieldMetadata.put('picklist', picklistOptions);
					fieldMetadata.put('defaultValue', defaultValue);
				}
				fieldMetadata.put('helpText', fieldDescribe.getInlineHelpText());
				fieldMetadataMap.put(fieldName, fieldMetadata);
		    	}
		}  catch(Exception excp) {
			throw new AuraHandledException('Error occurred while fetching task field details: ' + excp.getMessage());
		}
		return fieldMetadataMap;
	}
	
	@AuraEnabled
	public static Map<String, Object> getTaskByRecordId(String recordId) {
		try {
			if (String.isBlank(recordId)) {
				return null;
			}
			Task taskRecord = [SELECT Id, IsVisibleInSelfService, Name__c, Subject, Status, Priority,
				ActivityDate, Description, OwnerId, Start_Time__c, 
				Stop_Time__c, Attorney__c, Category__c, WhatId, WhoId, 
				Claim_Assigned_To__c, Related_to_Complaints__c
				FROM Task
				WHERE Id = :recordId 
				ORDER BY LastModifiedDate DESC
				LIMIT 1
			];
			DateTime startDateTime = taskRecord.Start_Time__c;
			DateTime stopDateTime = taskRecord.Stop_Time__c;
			
			return new Map<String, Object>{
				'Task' => taskRecord,
				'StartDateTime' => (startDateTime != null ? startDateTime.format() : ''),
				'StopDateTime' => (stopDateTime != null ? stopDateTime.format() : '')
			};
		} catch(Exception excp) {
			throw new AuraHandledException('Error occurred while fetching existing task details: ' + excp.getMessage());
		}		
	}

	@AuraEnabled
	public static Boolean createTask(String jsonData, String startDateTime, String stopDateTime) {
		try {
			if (String.isBlank(jsonData)) {
				return false;
			}
			Task data = (Task) JSON.deserialize(jsonData, Task.class);
			if (String.isNotBlank(startDateTime)) {
				DateTime startDateTimeValue = convertStringToDateTime(startDateTime).addHours(5);
				data.Start_Time__c = startDateTimeValue;
			}
			if (String.isNotBlank(stopDateTime)) {
				DateTime stopDateTimeValue = convertStringToDateTime(stopDateTime).addHours(5);
				data.Stop_Time__c = stopDateTimeValue;
			}
			upsert data;
			return true;
		} catch (Exception e) {
			throw new AuraHandledException('Error occurred while saving task details: ' + e.getMessage());
		}
	}

	public static DateTime convertStringToDateTime(String datetimeString) {
		try {
			datetimeString = (datetimeString == null ? '' : datetimeString.trim());
			if (String.isBlank(datetimeString)) {
				return null;
			}
			dateTimeString = dateTimeString.replaceAll('Z', '');
			// Split the datetime string into date and time parts
			List<String> parts = datetimeString.split('T');

			// Extract date and time components
			List<String> dateParts = parts[0].split('-');
			List<String> timeParts = parts[1].split(':');

			// Parse date components
			Integer year = Integer.valueOf(dateParts[0]);
			Integer month = Integer.valueOf(dateParts[1]);
			Integer day = Integer.valueOf(dateParts[2]);

			// Parse time components
			Integer hours = Integer.valueOf(timeParts[0]);
			Integer minutes = Integer.valueOf(timeParts[1]);

			// Construct DateTime object
			DateTime dateTimeObj = DateTime.newInstanceGMT(year, month, day, hours, minutes, 00);

			return dateTimeObj;
		} catch (Exception excp) {
			return System.now();
		}
	}

	public class PicklistOption {
		@AuraEnabled public String label { get; set; }
		@AuraEnabled public String value { get; set; }

		public PicklistOption(String label, String value) {
			this.label = label;
			this.value = value;
		}
	}
}