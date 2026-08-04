import { api, LightningElement } from 'lwc';
import getFieldMetadata from '@salesforce/apex/TaskControllerLightning.getFieldMetadata';
import getTaskByRecordId from '@salesforce/apex/TaskControllerLightning.getTaskByRecordId';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import userId from '@salesforce/user/Id';
import saveTask from '@salesforce/apex/TaskControllerLightning.createTask';
import { RefreshEvent } from "lightning/refresh";
import isSystemAdmin from '@salesforce/apex/TaskControllerLightning.isSystemAdmin';

const relatedToObjectPrefixMap = {
    '001': 'Account',
    'a02': 'Insurance_Company__c'
};
const relatedToOptions = [
    { label: 'Medical Provider', value: 'Account' },
    { label: 'Insurance Company', value: 'Insurance_Company__c' }
];
const whoIdObjectPrefiMap = {
    '003': 'Contact',
    '00Q': 'Lead'
}
export default class TaskForm extends NavigationMixin(LightningElement) {
    @api parentId;
    @api recordId ;
    isAccessible = false;

    isLoading = true;
    currentUserId = userId;
    taskFieldNames = ['Category__c','Subject', 'Description' , 'Claim_Assigned_To__c', 'Status', 
        'Priority', 'IsVisibleInSelfService', 'Name__c', 'WhatId', 'Related_to_Complaints__c', 
        'Claim_Assigned_To__c' 
    ];
    whoIdObject = 'Contact';
    whatIdObject = 'Account';
    metadata = {};
    taskRecord = {};
    startDate = '';
    startTime = '';
    stopDate = '';
    stopTime = '';

    connectedCallback() {
        this.isLoading = true;
        isSystemAdmin()
            .then((result) => {
                this.isAccessible = result;
                this.isLoading = false;                
            })
            .catch(error => {
                this.showToast('Error in getting field Metadata', error?.body?.message, 'error');
                this.isLoading = false;
            })
        this.loadFieldMetadata();
        if (this.isContainValidValue(this.recordId)) {
            this.fetchExistingTaskRecordDetails();
        } 
    }

    loadFieldMetadata() {
        this.isLoading = true;
        getFieldMetadata({ fieldNames: this.taskFieldNames })
            .then(response => {
                this.metadata = response; 
                if (!this.isContainValidValue(this.recordId)) {
                    this.taskRecord = {...this.taskRecord, Subject: this.metadata?.Subject?.defaultValue};
                    this.taskRecord = {...this.taskRecord, Status: this.metadata?.Status?.defaultValue};
                    this.taskRecord = {...this.taskRecord, Priority: this.metadata?.Priority?.defaultValue};
                    this.taskRecord = {...this.taskRecord, Category__c: this.metadata?.Category__c?.defaultValue};
                    this.taskRecord = {...this.taskRecord, Name__c: this.metadata?.Name__c?.defaultValue};
                    this.taskRecord = {...this.taskRecord, Claim_Assigned_To__c: this.metadata?.Claim_Assigned_To__c?.defaultValue};
                    this.taskRecord = {...this.taskRecord, OwnerId: this.currentUserId};
                    if (this.isContainValidValue(this.parentId)) {
                        let relatedTo = this.getRelatedToObjectApiNameFromId(this.parentId);
                        let whoId = this.getWhoIdObjectApiNameFromId(this.parentId);
                        let attorneyId = this.parentId ? this.getAttornyID(this.parentId) : this.metadata?.Attorney__c;
                        this.taskRecord = {...this.taskRecord, Attorney__c: attorneyId};
                        if (relatedTo != 'Unknown') {
                            this.taskRecord = {...this.taskRecord, WhatId: this.parentId};
                        } else if (whoId != 'Unknown') {
                            this.taskRecord = {...this.taskRecord, WhoId: this.parentId};
                        }
                        this.whatIdObject = relatedTo == 'Unknown' ? 'Account' : relatedTo;
                        this.whoIdObject = whoId == 'Unknown' ? 'Contact' : whoId;
                    }
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error in getting field Metadata', error?.body?.message, 'error');
                this.isLoading = false;
            });
    }
    
    fetchExistingTaskRecordDetails() {
        this.isLoading = true;
        getTaskByRecordId({ recordId : this.recordId})
            .then(response => {
                if (response) {                    
                    this.taskRecord = response?.Task;
                    if (this.taskRecord?.Start_Time__c || this.taskRecord?.Stop_Time__c) {
                        let startDT = response?.StartDateTime ? new Date(response.StartDateTime) : null;
                        let stopDT = response?.StopDateTime ? new Date(response.StopDateTime) : null;
                    
                        this.startDate = startDT ? startDT.toISOString().slice(0, 10) : null;
                        this.startTime = startDT ? startDT.toTimeString().slice(0, 5) : null;
                        this.stopDate = stopDT ? stopDT.toISOString().slice(0, 10) : null;
                        this.stopTime = stopDT ? stopDT.toTimeString().slice(0, 5) : null;
                    }                    
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error in existing record', error?.body?.message, 'error');
                this.isLoading = false;
            })
    }

    handleSave() {
        this.isLoading = true;
        let errorMessage = this.checkValidData();
        if (this.isContainValidValue(errorMessage)) {
            this.showToast('Missing Required Details', errorMessage, 'warning');
            this.isLoading = false;
            return;
        }
        let startDateTimeStr = this.prepareDateTimeStr(this.startDate, this.startTime);
        let stopDateTimeStr = this.prepareDateTimeStr(this.stopDate, this.stopTime);
        saveTask({ jsonData : JSON.stringify(this.taskRecord), startDateTime: startDateTimeStr, stopDateTime: stopDateTimeStr })
            .then(response => {
                if (response) {
                    this.taskRecord = {};
                    this.startDate = null;
                    this.startTime = null;
                    this.stopDate = null;
                    this.stopTime = null;
                    this.showToast('Success', 'Task '+ (this.isContainValidValue(this.recordId) ? 'updated' : 'created') +' successfully', 'success');
                    this.redirectToRecordPage();
                } else {
                    this.showToast('Error', 'Error occurred while saving task details, please try again', 'error');
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', error?.body?.message, 'error');
                this.isLoading = false;
            });
    }

    get subjectOptions() {   
        return this.metadata?.Subject?.picklist || [];
    }

    get statusOptions() {
        return this.metadata?.Status?.picklist || [];
    }

    get priorityOptions() {
        return this.metadata?.Priority?.picklist || [];
    }

    get categoryOptions() {
        return this.metadata?.Category__c?.picklist || [];
    }

    get nameOptions() {
        return this.metadata?.Name__c?.picklist || [];
    }

    get claimAssignedToOption(){
        return this.metadata?.Claim_Assigned_To__c?.picklist || [];
    }

    get subjectHelpText() {
        return this.metadata.Subject?.helpText || '';
    }

    get descriptionHelpText() {
        return this.metadata.Description?.helpText || '';
    }

    get statusHelpText() {
        return this.metadata.Status?.helpText || '';
    }

    get priorityHelpText() {
        return this.metadata.Priority?.helpText || '';
    }

    get nameHelpText() {
        return this.metadata.Name__c?.helpText || '';
    }

    get whatIdHelpText() {
        return this.metadata.WhatId?.helpText || '';
    }

    get claimAssignedToHelpText(){
        return this.metadata.Claim_Assigned_To__c?.helpText || '';
    }

    get realtedToComplaintHelpText() {
        return this.metadata.Related_to_Complaints__c?.helpText || '';
    }

    get isVisibleHelpText() {
        return this.metadata.IsVisibleInSelfService?.helpText || '';
    }

    get whoIdOptions(){
        return [
            { label: 'Patient', value: 'Contact' },
            { label: 'Complaints', value: 'Lead' }
        ];
    }

    get whatIdOptions() {
        return relatedToOptions;
    }

    handlePublicCheckboxChange(event) {
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.detail?.value || event.target.value;
        this.taskRecord[field] = value;
    }

    handleAssignedToRecordChange({detail: {recordId}}){
        this.taskRecord = {...this.taskRecord, OwnerId: recordId}
    }

    handleSubjectChange({detail: { value }}){
        this.taskRecord = {...this.taskRecord, Subject: value};
    }

    handleStatusChange({detail: { value }}){
        this.taskRecord = {...this.taskRecord, Status: value};
    }

    handleCommentInputChange({detail: { value }}){
        this.taskRecord = {...this.taskRecord, Description: value};
    }

    handleAttorneyRecordChange({detail: {recordId}}){
        this.taskRecord = {...this.taskRecord, Attorney__c: recordId}
    }

    onDueDateChange({target: {value}}){
        this.taskRecord = {...this.taskRecord, ActivityDate: value}
    }

    handlePriorityChange({detail: { value }}){
        this.taskRecord = {...this.taskRecord, Priority: value};
    }

    handleNameChange({detail: { value }}){
        this.taskRecord = {...this.taskRecord, Name__c: value};
    }

    handleCategoryChange({detail: { value }}){
        this.taskRecord = {...this.taskRecord, Category__c: value};
    }

    handleWhoIdObjectChange({detail: {value}}) {
        this.whoIdObject = value;
    }

    handleWhatIdObjectChange({detail: {value}}) {
        this.whatIdObject = value;
    }

    handleWhoIdRecordChange({detail: {recordId}}){
        this.whoIdObject = recordId ? this.getWhoIdObjectApiNameFromId(recordId) : 'Contact';
        this.taskRecord = {...this.taskRecord, WhoId: recordId};
    }

    handleWhatIdRecordChange({detail: {recordId}}){
        this.whatIdObject = recordId ? this.getRelatedToObjectApiNameFromId(recordId) : 'Account';
        this.taskRecord = {...this.taskRecord, WhatId: recordId};
    }

    handleComplaintIdRecordChange({detail: {recordId}}){
        this.taskRecord = {...this.taskRecord, Related_to_Complaints__c: recordId}
    }

    handleClaimAssignToChange({target: {value}}){
        this.taskRecord = {...this.taskRecord, Claim_Assigned_To__c: value}
    }

    onStartDateChange({target: {value}}){
        this.startDate = value;
        if (!this.isContainValidValue(this.startTime)) {
            this.startTime = new Date().toTimeString().slice(0, 5);
        }
    }

    onStartTimeChange({target: {value}}){
        this.startTime = value;
    }

    onStopDateChange({target: {value}}){
        this.stopDate = value;
        if (!this.isContainValidValue(this.stopTime)) {
            this.stopTime = new Date().toTimeString().slice(0, 5);
        }
    }

    onStopTimeChange({target: {value}}){
        this.stopTime = value;
    }

    handleCancel(){
        this.redirectToRecordPage();
    }

    redirectToRecordPage() {
        // this[NavigationMixin.Navigate]({
        //     type: 'standard__recordPage',
        //     attributes: {
        //         recordId: this.parentId ? this.parentId : this.recordId ,
        //         actionName: 'view'
        //     }
        // });
        // this.dispatchEvent(new RefreshEvent());
        window.location.href = '/lightning/r/'+ (this.parentId ? this.parentId : this.recordId) +'/view';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getRelatedToObjectApiNameFromId(recordId) {
        if (!recordId || recordId.length < 3) {
            return null;
        }
        const prefix = recordId.substring(0, 3);
        return relatedToObjectPrefixMap[prefix] || 'Unknown';
    }

    getWhoIdObjectApiNameFromId(recordId) {
        if (!recordId || recordId.length < 3) return null;
        const prefix = recordId.substring(0, 3);
        return whoIdObjectPrefiMap[prefix] || 'Unknown';
    }

    getAttornyID(recordId){
        if (!recordId || recordId.length < 3) return null;
        const prefix = recordId.substring(0, 3);
        return prefix === 'a0C' ? recordId :null;
    }

    isContainValidValue(val) {
        return ((val == undefined || val == null || val == '') ? false : true);
    }

    checkValidData() {
        if (!this.isContainValidValue(this.taskRecord.Subject)) {
            return 'Please select the Task "Subject"';
        }
        if (!this.isContainValidValue(this.taskRecord.ActivityDate)) {
            return 'Please select the Task "Due Date"';
        } 
        if (!this.isContainValidValue(this.taskRecord.Priority)) {
            return 'Please select the Task "Priority"';
        }
        if (!this.isContainValidValue(this.taskRecord.Name__c)) {
            return 'Please select the "Name"';
        } 
        if (!this.isContainValidValue(this.taskRecord.Claim_Assigned_To__c)) {
            return 'Please select the Task "Claim Assigned To"'
        }
        if (!this.isContainValidValue(this.taskRecord.Category__c)) {
            return 'Please select the Task "Category"';
        }
        if (!this.isContainValidValue(this.taskRecord.Status)) {
            return 'Please select the Task "Status"';
        }
        if (!this.isContainValidValue(this.taskRecord.OwnerId)) {
            return 'Please select the Task "Assigned To"';
        }
        if (!this.isContainValidValue(this.taskRecord.WhoId) && !this.isContainValidValue(this.taskRecord.WhatId)) {
            return 'Please link the task activity with Patient or Medical Provider or any other';
        }
        return '';
    }

    prepareDateTimeStr(dateValue, timeValue) {
        if (this.isContainValidValue(dateValue) && this.isContainValidValue(timeValue)) {
            return `${dateValue}T${timeValue}Z`
        }
        return '';
    }
}