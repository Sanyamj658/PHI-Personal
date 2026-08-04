import { LightningElement, api, wire } from 'lwc';
import { getRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import deleteClaim from '@salesforce/apex/ClaimCtrl.deleteClaim';
import { NavigationMixin } from 'lightning/navigation';
import userId from '@salesforce/user/Id';
const FIELDS = ["User.UserRoleId"];

export default class DeleteClaimRecord extends NavigationMixin(LightningElement) {
        @api recordId;

	@wire(getRecord, { recordId: userId, fields: FIELDS })
	user;

	@api
	async invoke() {
		this.init();
	}
	init() {
		let userRoleId = this.user.data.fields.UserRoleId.value;
		if (this.isContainValidValue(userRoleId)) {
			userRoleId = userRoleId.substring(0, 15);
			if (userRoleId == '00EG000000131JW') {
				deleteClaim({'claimId' : this.recordId})
					.then(response => {
						if (response) {
							this.showSuccessMessage('Claim has been deleted successfully!');
							this.navigateToListView();
						} else {
							this.showErrorMessage('Please refresh the page to get the updated details!')
						}
					})
					.catch(error => {
						console.error('Error occurred: ' + error);
						this.showErrorMessage('Error occurred: ' + JSON.stringify(error));
					});
			} else {
				this.showErrorMessage('Claim can\'t be deleted because you don\'t have sufficient access!');
			}
		}
	}

	isContainValidValue(val) {
                return ((val == undefined || val == null || val == '') ? false : true);
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

	showSuccessMessage(msg) {
                this.dispatchEvent(
                        new ShowToastEvent({
                                title: 'Success',
                                message: msg,
                                variant: 'success'
                        }),
                );
        }

	navigateToListView() {
		this[NavigationMixin.Navigate]({
			type: 'standard__objectPage',
			attributes: {
			    objectApiName: 'Claim__c', 
			    actionName: 'list',
			},
			state: {
			    filterName: 'All_Claims',
			},
		    });
	}
}