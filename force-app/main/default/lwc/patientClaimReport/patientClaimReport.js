import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCollectorsAndMedicalProviders from '@salesforce/apex/PatientClaimReportCtrl_Lightning.getCollectorsAndMedicalProviders';

export default class PatientClaimReport extends LightningElement {
        activeTabs = ['Activity_Due_Date', 'Advanced_Search_Filter'];
        isLoading = true;
        fromDate;
        toDate;
        @track collectorOptions = [];
        @track medicalProviderOptions = [];
        selectedCollectors = '';
        selectedMedicalProviders = '';

        connectedCallback() {
                this.fetchCollectorsNdMedicalProvidersData();
        }

        onExportReport(event) {
                if (!this.isContainValidValue(this.fromDate) && !this.isContainValidValue(this.toDate) 
                        && !this.isContainValidValue(this.selectedCollectors) && !this.isContainValidValue(this.selectedMedicalProviders)
                ) {
                        this.showErrorMessage('Please select at least one filter to export Patient Claim Report!');
                        return;
                }
                if (this.isContainValidValue(this.fromDate) && !this.isContainValidValue(this.toDate)) {
                        this.showErrorMessage('Please select a valid "To Date"!');
                        return
                }
                if (!this.isContainValidValue(this.fromDate) && this.isContainValidValue(this.toDate)) {
                        this.showErrorMessage('Please select a valid "From Date"!');
                        return;
                }
                if (this.isContainValidValue(this.fromDate) && this.isContainValidValue(this.toDate) && this.fromDate > this.toDate) {
                        this.showErrorMessage('"To Date" should be greater or equal to "From Date", Please change!');
                        return;
                }
                if (!this.isContainValidValue(this.fromDate)) {
                        this.fromDate = '';
                }
                if (!this.isContainValidValue(this.toDate)) {
                        this.toDate = '';
                }
                let exportURL = '/apex/PatientClaimReport?fromDate=' + this.fromDate + '&todate=' + this.toDate 
                        + '&collector=' + this.selectedCollectors + '&provider=' + this.selectedMedicalProviders;
                window.open(exportURL);
        }

        fetchCollectorsNdMedicalProvidersData() {
                this.isLoading = true;
                getCollectorsAndMedicalProviders()
                        .then(response => {
                                if (response) {
                                        this.collectorOptions = response['Collector'];
                                        this.medicalProviderOptions = response['Medical_Provider'];
                                }
                                this.isLoading = false;
                        })
                        .catch(error => {
                                this.isLoading = false;
                                this.showErrorMessage('Error occurred: ' + JSON.stringify(error));
                                console.log('Error occurred: ' + JSON.stringify(error));
                        });
        }

        onCollectorDualListBoxChange(event) {
                let selectedValues = event.detail.value;
                if (selectedValues != null && selectedValues.length > 0) {
                        this.selectedCollectors = selectedValues.join(', ');
                } else {
                        this.selectedCollectors = '';
                }
        }

        onMedicalProviderDualListBoxChange(event) {
                let selectedValues = event.detail.value;
                if (selectedValues != null && selectedValues.length > 0) {
                        this.selectedMedicalProviders = selectedValues.join(', ');
                } else {
                        this.selectedMedicalProviders = '';
                }
        }

        isContainValidValue(val) {
                return ((val == undefined || val == null || val == '') ? false : true);
        }

        handleDateChange(event) {
                let fieldChanged = event.target.name;
                if (fieldChanged == 'fromDate') {
                        this.fromDate = event.target.value;
                } else if (fieldChanged == 'toDate') {
                        this.toDate = event.target.value;
                }
        }

        showErrorMessage(msg) {
                this.dispatchEvent(
                        new ShowToastEvent({
                                title: 'Error',
                                message: msg,
                                variant: 'error'
                        }),
                );
        }
}