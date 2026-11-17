import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { updateRecord } from 'lightning/uiRecordApi';
import TARGET_AUDIENCE from '@salesforce/schema/Event_Master__c.Target_Audience_Applicable__c';

export default class EventTargetAudience extends NavigationMixin(LightningElement) {
  @api eventRecordId;
  @track audienceOptions = ['Students', 'Alumni', 'Faculty'];
  @track selectedValues = [];
  showSpinner = false;
  isInviteAll = false;

  @wire(getRecord, { recordId: '$eventRecordId', fields: [TARGET_AUDIENCE] })
  targetAudience({ error, data }) {
    if (data) {
      const value = data.fields.Target_Audience_Applicable__c.value;
      this.selectedValues = value ? value.split(';') : [];
    } else if (error) {
      this.showToast('Error', 'Error retrieving target audience', 'error');
    }
  }

  get allVariant() {
    return this.isInviteAll ? 'brand' : 'neutral';
  }

  get studentVariant() {
    return this.selectedValues.includes('Students') ? 'brand' : 'neutral';
  }

  get alumniVariant() {
    return this.selectedValues.includes('Alumni') ? 'brand' : 'neutral';
  }

  get facultyVariant() {
    return this.selectedValues.includes('Faculty') ? 'brand' : 'neutral';
  }


  handleAudienceSelection(event) {
    const selected = event.target.dataset.value;
    this.toggleSelection(selected);
  }

  handleInviteAll(event) {
    this.isInviteAll = !this.isInviteAll;
    if (this.isInviteAll) {
      this.selectedValues = [...this.audienceOptions];
    } else {
      this.selectedValues = [];
    }
  }

  handleClick() {
    this.isInviteAll = !this.isInviteAll;
  }

  handlePrevious() {
    this.dispatchEvent(new CustomEvent("previous", { detail: "eventSetup" }));
  }

  async handleSave() {
    if (!this.eventRecordId) {
      this.showToast('Error', 'No event ID found', 'error');
      return;
    }

    this.showSpinner = true;

    try {
      await updateRecord({ fields: { 'Id': this.eventRecordId, [TARGET_AUDIENCE.fieldApiName]: this.selectedValues.join(';') } });
      this.showToast('Success', 'Target audience updated successfully', 'success');
      this.dispatchEvent(new CustomEvent("targetaudience", { detail: { eventId: this.eventRecordId } }));
    } catch (error) {
      this.showToast('Error', 'Error updating record', 'error');
    } finally {
      this.showSpinner = false;
    }
  }

  handleCancel() {
    if (this.eventRecordId) {
      this[NavigationMixin.Navigate]({
        type: "standard__recordPage",
        attributes: {
          recordId: this.eventRecordId,
          actionName: "view"
        }
      });
    } else {
      this[NavigationMixin.Navigate]({
        type: "standard__objectPage",
        attributes: {
          objectApiName: "Event_Master__c",
          actionName: "list"
        },
        state: {
          filterName: "Recent"
        }
      });
    }
  }

  toggleSelection(option) {
    const index = this.selectedValues.indexOf(option);
    if (index === -1) {
      this.selectedValues = [...this.selectedValues, option];
    } else {
      this.selectedValues = this.selectedValues.filter(val => val !== option);
    }
  }

  showToast(title, successMessage, variant) {
    const toastEvent = new ShowToastEvent({
      title: title,
      message: successMessage,
      variant: variant
    });
    this.dispatchEvent(toastEvent);
  }

}