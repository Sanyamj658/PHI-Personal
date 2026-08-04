import { LightningElement, api, wire } from 'lwc';
import getCollectorAndARdays from '@salesforce/apex/ClaimCollectorInfoController.getCollectorAndARdays';

export default class ClaimCollectorInfo extends LightningElement {
    @api recordId;
    collector;
    days;

    @wire(getCollectorAndARdays, { claimId: '$recordId' })
    wiredResult({ data, error }) {
        if (data) {            
            this.collector = data.latestCollector;
            this.days = data.daysTaken;
        } 
        else if (error) {
            console.error('Error:', error);
        }
    }

    get showInfo() {
        return this.collector && this.days !== undefined && this.days !== null;
    }
}