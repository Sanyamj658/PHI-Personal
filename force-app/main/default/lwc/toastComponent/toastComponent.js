import { api, LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { FlowNavigationFinishEvent, FlowNavigationBackEvent } from 'lightning/flowSupport';

export default class ToastComponent extends LightningElement {
    @api title;
    @api message;
    @api variant;

    connectedCallback() {
        this.showToastMessage();
        this.handleClose();
    }

    showToastMessage = () => {
        const toastMessage = {
            title: this.title,
            message: this.message,
            variant: this.variant
        };
        this.fireToastMessage(toastMessage);
    }

    fireToastMessage = (toastMessage) => {
        this.dispatchEvent(new ShowToastEvent(toastMessage));
    }

    handleClose() {
        if(this.variant == 'success') {
            this.dispatchEvent(new FlowNavigationFinishEvent());
        }
        else {
            this.dispatchEvent(new FlowNavigationBackEvent());
        }
    }
}