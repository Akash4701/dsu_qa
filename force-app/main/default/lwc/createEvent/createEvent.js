import { LightningElement, track, wire, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFileUploadSettings from '@salesforce/apex/EventFormController.getFileUploadSettings';
import updateEvent from '@salesforce/apex/EventFormController.updateEvent';
import getEvent from '@salesforce/apex/EventFormController.getEvent';
import getPicklistValuesByFields from '@salesforce/apex/EventFormController.getPicklistValues';

export default class CreateEvent extends NavigationMixin(LightningElement) {
  @api eventRecordId;
  @api isEventSetup;
  @track wiredProgram;
  @track suitableForOptions = [];
  @track isEventGroup = false;
  @track selectedCategories = [];
  @track selectedLanguages = [];
  @track eventDetails;
  @track imageUrl;
  @track imageFile;
  @track isFileInputVisible = true;
  @track existingEventType;
  @track eventfields = {
    Id: '',
    contentDocumentId: null,
    isEventGroup: false,
    eventTitle: '',
    eventGroupId: null,
    eventGroupTitle: '',
    maximumNumberOfParticipants: null,
    eventTypes: '',
    eventLanguages: '',
    description: '',
    agenda: '',
    eventExpectations: '',
    startdate: null,
    enddate: null,
    image: null,
    imageFileName: ''
  };
  showSpinner = true;
  suitableFor;
  acceptedBannerFormats = [];
  maxBannerSize;
  @track eventCategories = [];
  @track eventLanguages = [];
  hasRendered = false;
  wiredEventResult;
  eventRecordTypeId;

  @wire(getEvent, { recordId: '$eventRecordId' })
  wiredEvent(result) {
    this.wiredEventResult = result;
    const { data, error } = result;
    if (data) {
      try {
        this.eventDetails = data;
        this.assignFields(data);
        this.selectedCategories = data.eventTypes != null ? data.eventTypes : [];
        this.selectedLanguages = data.eventLanguages != null ? data.eventLanguages : [];
        this.imageUrl = data.image;
        this.isFileInputVisible = this.imageUrl != null && this.imageUrl != undefined ? false : true;

        this.getPicklistOptions();
      } catch (error) {
        this.showToast('Error', 'Failed to load Event Data, Please try again.', 'error');
      }
    } else if (error) {
      this.showToast('Error', 'Failed to load Event Data, Please try again.', 'error');
    }
    this.showSpinner = false;
  }

  @wire(getFileUploadSettings, { allowedFileTypes: 'Event_Banner_File_Types__c', maxFileSize: 'Event_Banner_File_Size_MB__c' })
  fileUploadSettings({ error, data }) {
    if (data) {
      this.acceptedBannerFormats = data?.allowedFileTypes?.toLowerCase().split(',');
      this.maxBannerSize = parseInt(data?.maxFileSize) * 1024 * 1024;
    } else if (error) {
      this.showToast('Error', 'Error fetching file upload settings', 'error');
    }
  }

  renderedCallback() {
    if (!this.hasRendered) {
      this.hasRendered = true;
      console.log('renderedCallback');
      this.initializeChildComponents('eventTypeSelect');
      this.initializeChildComponents('languageSelect');
    }
  }


  handleInputChange(event) {
    const field = event.target.dataset.id;
    const value = event.target.value;
    this.eventfields[field] = value;

    this.validateField(field, event.target);

    if (field === 'startdate' || field === 'enddate') {
      this.validateDateRange();
    }
  }

  handleCategorySelection(event) {
    this.selectedCategories = event.detail;
    this.eventfields.eventTypes = this.selectedCategories;
    const eventTypesSelected = this.template.querySelector('[data-id="eventTypeSelect"]');
    if (eventTypesSelected)
      eventTypesSelected.validate();
  }

  handleLanguageSelection(event) {
    this.selectedLanguages = event.detail;
    this.eventfields.eventLanguages = this.selectedLanguages;
    const languagesSelected = this.template.querySelector('[data-id="languageSelect"]');
    if (languagesSelected)
      languagesSelected.validate();
  }

  handleCheckboxChange(event) {
    this.isEventGroup = event.target.checked;
  }

  //Image file upload logic
  handleFileChange(event) {
    const file = event.target.files[0];

    if (!file) {
      return;
    }

    const fileExtension = file.name.split('.').pop();
    if (this.acceptedBannerFormats && !this.acceptedBannerFormats.includes(fileExtension)) {
      this.showToast('Error', `Invalid file type. Allowed File Types: ${this.acceptedBannerFormats.join(', ')}`, 'error');
      event.target.value = '';
      return;
    }

    if (this.maxBannerSize && file.size > this.maxBannerSize) {
      this.showToast('Error', `File size exceeds the maximum limit. Please upload a file with size less than ${this.maxBannerSize / (1024 * 1024)}MB.`, 'error');
      event.target.value = '';
      return;
    }

    this.createImagePreview(file);
    this.imageFile = file;
    this.convertToBase64(file)
      .then(base64Image => {
        this.eventfields.image = base64Image; // Store the Base64 image in the eventfields object
        this.eventfields.imageFileName = file.name;
      })
      .catch(error => {
        console.error('Error converting image to Base64:', error);
      });
    this.isFileInputVisible = false; // Hide file input when image is selected
  }

  async handleSaveAsDraft() {

    if (!this.validateEventFields() || !this.validateDateRange()) {
      this.showToast(
        'Error',
        'Please fix all the errors in the form before saving.',
        'error'
      );
      return;
    }

    this.showSpinner = true;
    try {
      await updateEvent({ eventData: JSON.stringify(this.eventfields) })

      this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
          recordId: this.eventRecordId,
          objectApiName: 'Event_Master__c',
          actionName: 'view'
        }
      });
    } catch (error) {
      this.showToast('Error', 'Error saving record', 'error');
    } finally {
      this.showSpinner = false;
    }
  }

  async handleSave() {
    if (!this.validateEventFields() || !this.validateDateRange()) {
      this.showToast(
        'Error',
        'Please fix all the errors in the form before saving.',
        'error'
      );
      return;
    }

    this.showSpinner = true;

    try {
      await updateEvent({ eventData: JSON.stringify(this.eventfields) })

      this.showToast('Success', 'Event Data saved successfully', 'success');

      await refreshApex(this.wiredEventResult);

      this.dispatchEvent(
        new CustomEvent("event", {
          detail: { eventId: this.eventRecordId }
        })
      );
    } catch (error) {
      this.showToast('Error', 'Error saving record', 'error');
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

  handlePrevious() {
    this.dispatchEvent(new CustomEvent("previous", { detail: "eventSetup" }));
  }

  async getPicklistOptions() {
    const picklistData = await getPicklistValuesByFields({ objectName: 'Event_Master__c', fieldNames: ['Event_Type__c', 'Language__c'] });
    if (!picklistData) {
      this.showToast('Error', 'Error fetching picklist values', 'error');
      return;
    }

    this.eventLanguages = this.formatPicklistValues(picklistData.Language__c, this.selectedLanguages);
    this.eventCategories = this.formatPicklistValues(picklistData.Event_Type__c, this.selectedCategories);
  }

  formatPicklistValues(picklistOptions, selectedValues) {
    if (!Array.isArray(picklistOptions)) {
      return [];
    }
    console.log('picklistOptions', picklistOptions);
    return picklistOptions?.map(option => ({
      label: option.label,
      value: option.value,
      show: true,
      checked: selectedValues.includes(option.value)
    }));
  }

  initializeChildComponents(dataid) {
    setTimeout(() => {
      const childComponent = this.template.querySelector(`[data-id="${dataid}"]`);
      console.log('childComponent', childComponent);
      if (childComponent) {
        childComponent.postSelect();
        console.log('test child');
      } else {
        console.error(`Child component "${dataid}" not found!`);
      }
    }, 2000);
  }

  createImagePreview(file) {
    const reader = new FileReader();
    reader.onloadend = () => {
      this.imageUrl = reader.result;
    };
    reader.readAsDataURL(file);
  }

  removeImage() {
    this.imageUrl = null;
    this.imageFile = null;
    this.eventfields.image = null;
    this.isFileInputVisible = true; // Show file input again
  }

  convertToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result.split(',')[1]); // Remove the data URL prefix
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });
  }

  assignFields(data) {
    this.eventfields = {
      ...this.eventfields,
      Id: data.Id,
      eventTitle: data.eventTitle,
      description: data.description,
      startdate: data.startdate,
      enddate: data.enddate,
      agenda: data.agenda,
      maximumNumberOfParticipants: data.maximumNumberOfParticipants,
      eventTypes: data.eventTypes,
      eventLanguages: data.eventLanguages,
      eventExpectations: data.eventExpectations
    };
  }

  validateField(field, inputElement) {
    const value = this.eventfields[field];
    const isEmpty = value === '' || value === null || value === undefined;

    if (isEmpty) {
      this.setCustomValidity(inputElement, false, 'This field is required.');
      return false;
    }

    // Max participants > 0
    if (field === 'maximumNumberOfParticipants' && Number(value) <= 0) {
      this.setCustomValidity(inputElement, false, 'Must be greater than 0.');
      return false;
    }

    // Textarea length checks
    if ((field === 'description' || field === 'agenda') && (value.length < 10 || value.length > 1000)) {
      this.setCustomValidity(inputElement, false, `${field.charAt(0).toUpperCase() + field.slice(1)} must be between 10 and 1000 characters.`);
      return false;
    }

    this.setCustomValidity(inputElement, true, '');
    return true;
  }

  validateEventFields() {
    let fieldsToValidate = [
      'eventTitle',
      'maximumNumberOfParticipants',
      'description',
      'enddate',
      'startdate',
      'agenda',
      'eventExpectations'
    ];

    let isValid = true;

    fieldsToValidate.forEach(field => {
      const inputField = this.template.querySelector(`[data-id="${field}"]`);
      if (!this.validateField(field, inputField)) {
        isValid = false;
      }
    });

    const eventTypes = this.template.querySelector('[data-id="eventTypeSelect"]');
    if (eventTypes && !eventTypes.validate()) {
      isValid = false;
    }

    const languages = this.template.querySelector('[data-id="languageSelect"]');
    if (languages && !languages.validate()) {
      isValid = false;
    }

    return isValid;
  }

  validateDateRange() {
    const start = this.eventfields.startdate;
    const end = this.eventfields.enddate;

    const today = new Date();
    today.setHours(0, 0, 0, 0); // Reset time to compare just the date

    let isValid = true;

    const startInput = this.template.querySelector('[data-id="startdate"]');
    const endInput = this.template.querySelector('[data-id="enddate"]');

    if (start) {
      const startDate = new Date(start);
      if (startDate < today) {
        this.setCustomValidity(startInput, false, 'Start Date cannot be in the past.');
        isValid = false;
      } else {
        this.setCustomValidity(startInput, true, '');
      }
    }

    if (end) {
      const endDate = new Date(end);
      if (endDate < today) {
        this.setCustomValidity(endInput, false, 'End Date cannot be in the past.');
        isValid = false;
      } else {
        this.setCustomValidity(endInput, true, '');
      }
    }

    if (start && end && new Date(start) > new Date(end)) {
      this.setCustomValidity(startInput, false, 'Start Date must be earlier than End Date.');
      this.setCustomValidity(endInput, false, 'End Date must be later than Start Date.');
      isValid = false;
    }

    return isValid;
  }

  get todayDate() {
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, '0');
    const dd = String(today.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }


  setCustomValidity(inputField, isValid, message) {
    if (inputField) {
      inputField.setCustomValidity(isValid ? '' : message);
      inputField.reportValidity();
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