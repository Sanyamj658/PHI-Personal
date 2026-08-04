import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getScheduleReportPicklistOptions from '@salesforce/apex/ScheduleReportCtrl_Lightning.getScheduleReportPicklistOptions';
import saveScheduleReport from '@salesforce/apex/ScheduleReportCtrl_Lightning.saveScheduleReport';

export default class ScheduleReport extends LightningElement {
	isLoading = true;
	selectReport = '';
	selectReportOptions = [];
	selectContacts = '';
	selectContactOptions = [];
	selectReportFormat = '';
	selectReportFormatOptions = [];
	reportSubject = '';

	connectedCallback() {
		this.fetchComboboxOptions();
	}

	fetchComboboxOptions() {
		this.isLoading = true;
                getScheduleReportPicklistOptions()
                        .then(response => {
                                if (response) {
                                        this.selectReportOptions = response['Select_Reports'];
                                        this.selectContactOptions = response['Select_Contacts'];
					this.selectReportFormatOptions = response['Select_Report_Formats'];
                                }
                                this.isLoading = false;
                        })
                        .catch(error => {
                                this.isLoading = false;
                                this.showErrorMessage('Error occurred: ' + JSON.stringify(error));
                                console.log('Error occurred: ' + JSON.stringify(error));
                        });
	}

	handleDataChange(event) {
		let fieldChanged = event.target.name;
		if (fieldChanged == 'selectReport') {
			this.selectReport = event.target.value;
		} else if (fieldChanged == 'selectContacts') {
			this.selectContacts = event.target.value;
		} else if (fieldChanged == 'selectReportFormat') {
			this.selectReportFormat = event.target.value;			
		} else if (fieldChanged == 'reportSubject') {
			this.reportSubject = event.target.value;
		} 
	}

	onSaveReport(event) {
		this.isLoading = true;
		if (!this.isContainValidValue(this.selectReport)) {
			this.showErrorMessage('Please select the Desired Report!');
			return;
		}
		if (!this.isContainValidValue(this.selectContacts)) {
			this.showErrorMessage('Please select the report Receipents/Contacts!');
			return;
		}
		if (!this.isContainValidValue(this.selectReportFormat)) {
			this.showErrorMessage('Please select the report format!');
			return;
		}
		if (!this.isContainValidValue(this.reportSubject)) {
			this.showErrorMessage('Please select the report subject!');
			return;
		}
		
		saveScheduleReport({'selectReport' : this.selectReport, 'accountId' : this.selectContacts, 
			'reportFormat' : this.selectReportFormat, 'reportSubject' : this.reportSubject
		})
			.then(response => {
				if (response) {
					this.showSuccessMessage('Schedule Report saved successfully, and has been scheduled for weekly delivery!');
					this.selectReport = '';
					this.selectContacts = '';
					this.selectReportFormat = '';
					this.reportSubject = '';
				} else {
					this.showErrorMessage('Error occurred, please try again after sometime!')
				}
				this.isLoading = false;
			})
			.catch(error => {
				this.showErrorMessage('Error occurred: ' + JSON.stringify(error));
				console.log('Error occurred: ' + JSON.stringify(error));
			});
	}

	isContainValidValue(val) {
                return ((val == undefined || val == null || val == '') ? false : true);
        }

	showErrorMessage(msg) {
		this.isLoading = false;
                this.dispatchEvent(
                        new ShowToastEvent({
                                title: 'Error',
                                message: msg,
                                variant: 'error'
                        }),
                );
        }

	showSuccessMessage(msg) {
		this.isLoading = false;
                this.dispatchEvent(
                        new ShowToastEvent({
                                title: 'Success',
                                message: msg,
                                variant: 'success'
                        }),
                );
        }
}