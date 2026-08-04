import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions'; 
import checkEligibility from '@salesforce/apex/AppUserInvitationController.checkInvitationEligibility';
import sendEmail from '@salesforce/apex/AppUserInvitationController.sendInvitationEmail';

export default class AppUserInvitation extends LightningElement {
    // 1. Intercept the Record ID securely for Quick Actions
    _recordId;
    @api set recordId(value) {
        this._recordId = value;
        if (value) {
            this.performLiveEligibilityCheck();
        }
    }
    get recordId() {
        return this._recordId;
    }
    
    @track isEligible = false;
    @track statusMessage = 'Checking eligibility...';
    @track isLoading = true;

    // 2. Imperative Apex Call - Fetches live data every time it opens
    performLiveEligibilityCheck() {
        this.isLoading = true;
        checkEligibility({ contactId: this.recordId })
            .then(data => {
                this.isEligible = data.isEligible;
                this.statusMessage = data.message;
            })
            .catch(error => {
                this.statusMessage = 'Error checking eligibility.';
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get buttonDisabled() {
        return !this.isEligible || this.isLoading;
    }

    handleSendInvitation() {
        this.isLoading = true;
        
        sendEmail({ contactId: this.recordId })
            .then(result => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Invitation email sent successfully!',
                        variant: 'success'
                    })
                );
                this.dispatchEvent(new CloseActionScreenEvent()); 
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error sending email',
                        message: error.body ? error.body.message : error.message,
                        variant: 'error'
                    })
                );
                this.isLoading = false;
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}