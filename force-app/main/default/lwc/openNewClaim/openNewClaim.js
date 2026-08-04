import { LightningElement, api, wire } from 'lwc';
import getCollectorForContact from '@salesforce/apex/CollectorCtrl.getCollectorForPatient';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import { getRecord } from "lightning/uiRecordApi";
const FIELDS = ["Contact.AccountId"];

export default class OpenNewClaim extends NavigationMixin(LightningElement) {
        @api recordId;

	@wire(getRecord, { recordId: "$recordId", fields: FIELDS })
	contact;

	@api
	async invoke() {
		this.init();
	}
	init() {
		getCollectorForContact({ 'patientId' : this.recordId })
			.then(response => {                                
                                let defaultValues = null;
                                if (this.isContainValidValue(response)) {
                                        defaultValues = encodeDefaultFieldValues({
                                                Collector__c: response,
                                                Patient__c: this.recordId,
                                                Medical_Provider__c: this.contact.data.fields.AccountId.value
                                        });
                                } else {
                                        defaultValues = encodeDefaultFieldValues({
                                                Patient__c: this.recordId,
                                                Medical_Provider__c: this.contact.data.fields.AccountId.value
                                        });
                                }
				let pageReference = {
					type: 'standard__objectPage',
					attributes: {
						objectApiName: 'Claim__c',
						actionName: 'new'
					},
					state: {
						defaultFieldValues: defaultValues
					}
				};
				// Navigate to the Claim edit page
				this[NavigationMixin.Navigate](pageReference);
			})
			.catch(error => {
				console.error('Error occurred: ' + JSON.stringify(error));
			});
	}

        isContainValidValue(val) {
                return ((val == undefined || val == null || val == '') ? false : true);
        }
}