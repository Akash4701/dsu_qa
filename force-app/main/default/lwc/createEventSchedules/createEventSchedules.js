import { LightningElement, api, track, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningPrompt from 'lightning/prompt';
//Apex imports
import getEvent from '@salesforce/apex/EventFormController.getEvent';
import getEventSchedule from "@salesforce/apex/EventFormController.getEventSchedule";
import createEventSchedule from "@salesforce/apex/EventFormController.createEventSchedule";
import searchContacts from '@salesforce/apex/EventFormController.searchContacts';
import getContactDetails from '@salesforce/apex/EventFormController.getContactDetails';
import createContact from '@salesforce/apex/EventFormController.createContact';
import getFileUploadSettings from '@salesforce/apex/EventFormController.getFileUploadSettings';

const SESSION_STORAGE_KEY = 'eventScheduleState_';

export default class CreateEventSchedules extends NavigationMixin(LightningElement) {
  // Public properties
  @api eventRecordId;

  // Private tracked properties
  @track datePath = [];
  @track eventScheduleRecords = [];
  @track allEventSchedules = [];
  @track savedEventSchedules = [];
  @track contactOptions = [];
  showSpinner = true;
  openFeeSelection = false;
  isSessionPricing = false;
  isEventPricing = false;
  selectedDate = '';
  startDate = "";
  endDate = "";
  error;


  // File upload settings
  allowedBrochureFileTypes;
  maxBrochureSize;

  // Location type constants
  LOCATION_TYPES = {
    ONSITE: 'On-site',
    ONLINE: 'Online event',
    HYBRID: 'Hybrid'
  };

  get showRemoveSessionButton() {
    return this.eventScheduleRecords && this.eventScheduleRecords.length > 1;
  }

  @wire(getFileUploadSettings, {
    allowedFileTypes: 'Session_Brochure_File_Types__c',
    maxFileSize: 'Session_Brochure_File_Size_MB__c'
  })
  FileSettings({ error, data }) {
    if (data) {
      this.allowedBrochureFileTypes = data.allowedFileTypes?.toLowerCase().split(',') || [];
      this.maxBrochureSize = parseInt(data.maxFileSize) * 1024 * 1024 || 2 * 1024 * 1024; // Default 5MB
    } else if (error) {
      console.error('Error loading file settings:', JSON.stringify(error));
      //default values as fallback
      this.allowedBrochureFileTypes = ['pdf', 'png', 'jpg', 'jpeg'];
      this.maxBrochureSize = 2 * 1024 * 1024; // 5MB default
    }
  }

  @wire(searchContacts)
  wiredContacts({ error, data }) {
    if (data) {
      this.contactOptions = data.map(contact => ({
        label: contact.Name,
        value: contact.Id
      }));
    } else if (error) {
      console.error('Error fetching contacts:', JSON.stringify(error));
      this.showToast('Error', 'An error occurred while fetching contacts', 'error');
    }
  }

  connectedCallback() {
    if (this.eventRecordId) {
      //load saved state
      const stateLoaded = this.loadStateFromSessionStorage();

      if (!stateLoaded) {
        this.loadEventData();
      } else {
        this.showSpinner = false;
      }
    }
  }

  get isSaveButtonDisabled() {
    if (!this.datePath || !this.savedEventSchedules) {
      return true;
    }

    // Get all unique dates from the date path
    const allDates = this.datePath.map(dateObj => dateObj.date);

    // Get all dates that have at least one schedule
    const datesWithSchedules = new Set();
    this.savedEventSchedules.forEach(schedule => {
      if (schedule.startDate) {
        const scheduleDate = new Date(schedule.startDate).toISOString().split('T')[0];
        datesWithSchedules.add(scheduleDate);
      }
    });

    // Check if every date has at least one schedule
    return !allDates.every(date => datesWithSchedules.has(date));
  }

  async loadEventData() {
    try {
      this.showSpinner = true;
      const eventData = await getEvent({ recordId: this.eventRecordId });

      if (eventData) {
        this.startDate = eventData.startdate;
        this.endDate = eventData.enddate;
        this.selectedDate = eventData.startdate;

        this.generateDatePath();
        await this.loadScheduleData();
      }
    } catch (error) {
      this.handleError('Error loading event data', error);
    } finally {

      this.showSpinner = false;
    }
  }

  // Generate the date path with class data
  generateDatePath() {
    if (!this.startDate || !this.endDate) return;

    const start = new Date(this.startDate);
    const end = new Date(this.endDate);
    this.datePath = [];

    let currentDate = new Date(start);
    while (currentDate <= end) {
      const dateString = currentDate.toISOString().split('T')[0];
      this.datePath.push({
        date: dateString,
        variant: dateString === this.selectedDate ? 'brand' : 'neutral',
        label: this.formatDateForDisplay(currentDate)
      });
      currentDate.setDate(currentDate.getDate() + 1);
    }
  }

  //Format date for display on date buttons
  formatDateForDisplay(date) {
    const day = date.getDate();
    const month = date.toLocaleString(undefined, { month: 'long' });
    const year = date.getFullYear();
    return `${day} ${month}, ${year}`;
  }

  async loadScheduleData() {
    try {
      this.showSpinner = true;

      if (!this.eventRecordId) return;

      const scheduleData = await getEventSchedule({ recordId: this.eventRecordId });
      this.allEventSchedules = this.processScheduleData(scheduleData || []);
      this.savedEventSchedules = JSON.parse(JSON.stringify(this.allEventSchedules)); // Deep copy of allEventSchedules

      this.filterSessionsBySelectedDate();

      // If no sessions for selected date, create an empty one
      if (this.eventScheduleRecords.length === 0) {
        this.addEmptySession();
      }
    } catch (error) {
      this.handleError('Error loading schedule data', error);
    } finally {
      this.showSpinner = false;
    }
  }

  //Process session data
  processScheduleData(scheduleData) {
    return scheduleData.map((record, index) => {
      // Create a session identifier
      const sessionIdentifier = record.Id || `temp-session-${index}-${Date.now()}`;
      return {
        index,
        ...record,
        uniqueKey: sessionIdentifier,
        startTime: this.formatTime(record.startTime),
        endTime: this.formatTime(record.endTime),
        eventId: this.eventRecordId,
        isOnSite: record.locationType === this.LOCATION_TYPES.ONSITE,
        isHybrid: record.locationType === this.LOCATION_TYPES.HYBRID,
        isOnlineEvent: record.locationType === this.LOCATION_TYPES.ONLINE,
        isBrochureImageType: record.brochureFileType && record.brochureFileType.startsWith('image/'),
        brochureIcon: record.brochureFileType && record.brochureFileType.startsWith('image/')
          ? 'utility:image'
          : 'utility:attachment',
        isCard: true,
        // Use the sessionIdentifier when processing speakers
        speakers: this.processSpeakersData(record.speakers || [], sessionIdentifier)
      };
    });
  }

  //Process speakers data for each session
  processSpeakersData(speakers, sessionId) {
    return speakers?.map((speaker, speakerIndex) => ({
      speakerIndex,
      uniqueKey: `${sessionId || 'new'}-speaker-${speakerIndex}-${Date.now()}`,
      ...speaker
    })) || [this.createEmptySpeaker(0)];
  }

  //Create an empty speaker object
  createEmptySpeaker(index, sessionId) {
    return {
      speakerIndex: index,
      uniqueKey: `${sessionId || 'new'}-speaker-${index}-${Date.now()}`,
      name: '',
      contactId: '',
      description: '',
      speakerImage: ''
    };
  }

  //Create an empty session object
  createEmptySession() {
    const sessionId = `temp-session-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`;
    return {
      index: this.eventScheduleRecords.length,
      eventId: this.eventRecordId,
      id: '',
      uniqueKey: sessionId,
      agenda: '',
      startTime: null,
      endTime: null,
      endDate: null,
      startDate: this.selectedDate,
      name: '',
      sessionBroucher: '',
      locationType: '',
      locationAddress: '',
      sessionLink: '',
      isOnSite: false,
      isHybrid: false,
      isOnlineEvent: false,
      isCard: false,
      displayTitle: `Session ${this.eventScheduleRecords.length + 1}`,
      speakers: [this.createEmptySpeaker(0)]
    };
  }

  //Filter sessions by the selected date
  filterSessionsBySelectedDate() {
    if (this.allEventSchedules && this.allEventSchedules.length > 0) {
      this.eventScheduleRecords = this.allEventSchedules
        .filter(record => record.startDate === this.selectedDate)
        .map((record, index) => ({ ...record, index, displayTitle: `Session ${index + 1}` }));
    } else {
      this.eventScheduleRecords = [];
    }
  }

  //Format time string from ISO to display format
  formatTime(isoString) {
    if (!isoString) return null;
    try {
      const date = new Date(isoString);
      return date.toLocaleTimeString([], {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false,
        timeZone: 'UTC'
      });
    } catch (error) {
      console.error('Error formatting time', error);
      return null;
    }
  }

  //Add an empty session to the current date
  addEmptySession() {
    const emptySession = this.createEmptySession();
    this.eventScheduleRecords = [...this.eventScheduleRecords, emptySession];
  }

  //Add a new speaker to a session
  handleAddSpeaker(event) {
    const sessionIndex = parseInt(event.currentTarget.dataset.id, 10);
    if (isNaN(sessionIndex) || sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length) {
      return;
    }

    const updatedRecords = [...this.eventScheduleRecords];
    const speakerCount = updatedRecords[sessionIndex].speakers.length;

    updatedRecords[sessionIndex].speakers.push(this.createEmptySpeaker(speakerCount));

    this.eventScheduleRecords = updatedRecords;
  }

  //Remove a speaker from a session
  async handleRemoveSpeaker(event) {
    const sessionIndex = parseInt(event.currentTarget.dataset.id, 10);
    const speakerIndex = parseInt(event.currentTarget.dataset.speakerIndex, 10);

    if (isNaN(sessionIndex) || isNaN(speakerIndex) ||
      sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length ||
      speakerIndex < 0 || speakerIndex >= this.eventScheduleRecords[sessionIndex].speakers.length) {
      return;
    }

    const updatedRecords = [...this.eventScheduleRecords];

    // Ensure there's always at least one speaker
    if (updatedRecords[sessionIndex].speakers.length > 1) {
      updatedRecords[sessionIndex].speakers.splice(speakerIndex, 1);

      // Reindex speakers
      updatedRecords[sessionIndex].speakers = updatedRecords[sessionIndex].speakers.map(
        (speaker, idx) => ({ ...speaker, speakerIndex: idx })
      );

      this.eventScheduleRecords = updatedRecords;
    } else {
      this.showToast('Info', 'At least one speaker is required', 'info');
    }
  }

  //Delete a session
  async handleDeleteSession(event) {
    try {
      const sessionIndex = parseInt(event.currentTarget.dataset.id, 10);
      if (isNaN(sessionIndex) || sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length) {
        return;
      }

      if (this.eventScheduleRecords[sessionIndex].isCard) {
        const uniqueKey = this.eventScheduleRecords[sessionIndex].uniqueKey;

        const updatedSavedRecords = this.savedEventSchedules.filter(record => record.uniqueKey !== uniqueKey);
        this.savedEventSchedules = updatedSavedRecords.map((record, idx) => ({ ...record, index: idx }));
      }

      // Remove from UI
      const updatedRecords = [...this.eventScheduleRecords];
      updatedRecords.splice(sessionIndex, 1);

      // Reindex sessions
      this.eventScheduleRecords = updatedRecords.map((record, idx) => ({ ...record, index: idx }));

      // If no sessions left, add an empty one
      if (this.eventScheduleRecords.length === 0) {
        this.addEmptySession();
      }
    } catch (error) {
      this.handleError('Error deleting session', error);
    }
  }

  //Handle date button click
  handleDateClick(event) {
    const clickedDate = event.target.dataset.date;
    if (clickedDate === this.selectedDate) return;

    // Save current sessions to allEventSchedules before changing dates
    this.saveCurrentSessionsToAllEvents();

    this.selectedDate = clickedDate;

    // Update selected styling
    this.datePath = this.datePath.map(item => ({
      ...item,
      variant: item.date === this.selectedDate ? 'brand' : 'neutral'
    }));

    this.eventScheduleRecords = [];
    this.filterSessionsBySelectedDate();

    // If no sessions for the selected date, create an empty one
    if (this.eventScheduleRecords.length === 0) {
      this.addEmptySession();
    }
  }

  // Save the current view's sessions to allEventSchedules before changing dates
  saveCurrentSessionsToAllEvents() {
    if (!this.selectedDate || this.eventScheduleRecords.length === 0) return;

    // First, remove all existing sessions for this date
    this.allEventSchedules = this.allEventSchedules.filter(
      session => session.startDate !== this.selectedDate
    );

    // Then add the current sessions for this date
    this.allEventSchedules = [
      ...this.allEventSchedules,
      ...this.eventScheduleRecords.map((record, idx) => ({
        ...record,
        index: idx // Ensure index is updated
      }))
    ];
  }

  //Handle location type selection
  handleLocationTypeSelection(event) {
    const sessionIndex = parseInt(event.target.dataset.id, 10);
    const locationType = event.target.value;

    if (isNaN(sessionIndex) || sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length) {
      return;
    }

    const updatedRecords = [...this.eventScheduleRecords];
    updatedRecords[sessionIndex].locationType = locationType;
    updatedRecords[sessionIndex].isOnSite = locationType === this.LOCATION_TYPES.ONSITE;
    updatedRecords[sessionIndex].isHybrid = locationType === this.LOCATION_TYPES.HYBRID;
    updatedRecords[sessionIndex].isOnlineEvent = locationType === this.LOCATION_TYPES.ONLINE;

    this.eventScheduleRecords = updatedRecords;
  }

  //Handle location text field changes
  handleLocationTextFields(event) {
    const sessionIndex = parseInt(event.target.dataset.id, 10);
    const field = event.target.name;
    const value = event.target.value;

    if (isNaN(sessionIndex) || sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length) {
      return;
    }

    const updatedRecords = [...this.eventScheduleRecords];
    updatedRecords[sessionIndex][field] = value;

    this.eventScheduleRecords = updatedRecords;

    // Validate location fields
    this.validateLocationFields(sessionIndex);
  }

  //Handle general input change for session fields
  handleInputChange(event) {
    const sessionIndex = parseInt(event.currentTarget.dataset.id, 10);
    const field = event.target.name;
    const value = event.target.value;
    const label = event.target.label;

    if (isNaN(sessionIndex) || sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length) {
      return;
    }

    const updatedRecords = [...this.eventScheduleRecords];
    updatedRecords[sessionIndex][field] = value;

    this.eventScheduleRecords = updatedRecords;

    // Validate time fields
    if (field === 'startTime' || field === 'endTime') {
      this.setFieldValidity(event.target, '');
      this.validateTimeRange(sessionIndex);
    }

    // Validate session title
    if (field === 'name') {
      this.validateSessionTitle(sessionIndex);
    }
  }

  //Handle speaker input changes
  async handleSpeakerInputChange(event) {
    const sessionIndex = parseInt(event.currentTarget.dataset.id, 10);
    const speakerIndex = parseInt(event.currentTarget.dataset.speakerIndex, 10);
    const fieldName = event.target.name;

    if (isNaN(sessionIndex) || isNaN(speakerIndex) ||
      sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length ||
      speakerIndex < 0 || speakerIndex >= this.eventScheduleRecords[sessionIndex].speakers.length) {
      return;
    }

    const updatedRecords = [...this.eventScheduleRecords];

    // For normal fields
    if (fieldName !== 'contactId') {
      updatedRecords[sessionIndex].speakers[speakerIndex][fieldName] = event.target.value;
      this.eventScheduleRecords = updatedRecords;
      return;
    }

    // For contact selection
    const contactId = event.detail.recordId;
    updatedRecords[sessionIndex].speakers[speakerIndex].contactId = contactId;

    // If a contact was selected, fetch its details
    if (contactId) {
      this.setFieldValidity(event.target, '');

      // Fetch the contact record
      try {
        const contactDetails = await getContactDetails({ contactId: contactId });

        if (contactDetails) {
          updatedRecords[sessionIndex].speakers[speakerIndex].name = contactDetails.Name;
        }
      } catch (error) {
        console.error('Error fetching contact details:', error);
      }
    } else {
      this.setFieldValidity(event.target, 'Speaker is required');
    }

    this.eventScheduleRecords = updatedRecords;
  }

  // Create a new contact
  async handleCreateNewContact(event) {
    const sessionIndex = parseInt(event.currentTarget.dataset.id, 10);
    const speakerIndex = parseInt(event.currentTarget.dataset.speakerIndex, 10);

    try {
      // Show prompt for new contact name
      const nameInput = await this.promptUserForInput('Enter Speaker Name');
      if (!nameInput) return;

      const newContact = await createContact({ name: nameInput });

      // Update the speaker with the new contact
      const updatedRecords = [...this.eventScheduleRecords];
      updatedRecords[sessionIndex].speakers[speakerIndex].contactId = newContact.Id;

      this.eventScheduleRecords = updatedRecords;
      this.showToast('Success', 'New contact created', 'success');
    } catch (error) {
      this.handleError('Error creating contact', error);
    }
  }

  // Prompt user for input
  promptUserForInput(message) {
    return new Promise((resolve) => {
      // Use lightning-prompt component if available
      if (typeof LightningPrompt !== 'undefined') {
        LightningPrompt.open({
          message,
          label: 'Please Respond',
          defaultValue: '',
        }).then((result) => {
          resolve(result === null ? '' : result);
        });
      } else {
        // Fallback to browser prompt
        const result = prompt(message);
        resolve(result);
      }
    });
  }

  //Handle file change(for session brochure or speaker image)
  handleFileChange(event) {
    const sessionIndex = parseInt(event.target.dataset.id, 10);
    const isSessionUpload = event.target.dataset.type === 'session';
    const speakerIndex = isSessionUpload ? null : parseInt(event.target.dataset.speakerIndex, 10);
    const file = event.target.files[0];

    if (!file) return;

    const fileExtension = file.name.split('.').pop().toLowerCase();

    // Validate file for session brochure
    if (isSessionUpload) {
      // Check file size
      if (this.maxBrochureSize && file.size > this.maxBrochureSize) {
        this.showToast(
          'Error',
          `File size exceeds the maximum limit of ${Math.round(this.maxBrochureSize / (1024 * 1024))}MB`,
          'error'
        );
        event.target.value = '';
        return;
      }

      // Check file type
      if (this.allowedBrochureFileTypes &&
        this.allowedBrochureFileTypes.length > 0 &&
        !this.allowedBrochureFileTypes.includes(fileExtension)) {
        this.showToast(
          'Error',
          `Invalid file type. Allowed types: ${this.allowedBrochureFileTypes.join(', ')}`,
          'error'
        );
        event.target.value = '';
        return;
      }
    }

    this.readFile(file, sessionIndex, isSessionUpload, speakerIndex);
  }

  //Read and process uploaded file
  readFile(file, sessionIndex, isSessionUpload, speakerIndex) {
    const reader = new FileReader();

    reader.onloadend = () => {
      const updatedRecords = [...this.eventScheduleRecords];

      if (isSessionUpload) {
        updatedRecords[sessionIndex].sessionBroucher = reader.result;
        updatedRecords[sessionIndex].brochureFileType = file.type;
        updatedRecords[sessionIndex].brochureFileName = file.name;
        updatedRecords[sessionIndex].isBrochureImageType = file.type.startsWith('image/') ? true : false;
      } else {
        updatedRecords[sessionIndex].speakers[speakerIndex].speakerImage = reader.result;
      }

      this.eventScheduleRecords = updatedRecords;
    };

    reader.onerror = (error) => {
      console.error('Error reading file:', error);
      this.showToast('Error', 'Failed to read file', 'error');
    };

    reader.readAsDataURL(file);
  }

  //Remove uploaded image
  handleRemoveImage(event) {
    const sessionIndex = parseInt(event.target.dataset.id, 10);
    const isSessionImage = event.target.dataset.type === 'session';

    if (isNaN(sessionIndex) || sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length) {
      return;
    }

    const updatedRecords = [...this.eventScheduleRecords];

    if (isSessionImage) {
      updatedRecords[sessionIndex].sessionBroucher = '';
      updatedRecords[sessionIndex].brochureFileType = '';
      updatedRecords[sessionIndex].brochureFileName = '';
      updatedRecords[sessionIndex].isBrochureImageType = false;
    } else {
      const speakerIndex = parseInt(event.target.dataset.speakerIndex, 10);
      if (isNaN(speakerIndex) || speakerIndex < 0 ||
        speakerIndex >= updatedRecords[sessionIndex].speakers.length) {
        return;
      }

      updatedRecords[sessionIndex].speakers[speakerIndex].speakerImage = '';
    }

    this.eventScheduleRecords = updatedRecords;
  }

  //Open file upload dialog
  handleOpenFileDialog(event) {
    const fileInput = this.template.querySelector(`input[type="file"][data-id="${event.target.dataset.id}"][data-type="${event.target.dataset.type}"]${event.target.dataset.speakerIndex ? '[data-speaker-index="' + event.target.dataset.speakerIndex + '"]' : ''}`);
    if (fileInput) {
      fileInput.click();
    }
  }

  handleEditSession(event) {
    const sessionIndex = parseInt(event.currentTarget.dataset.id, 10);
    if (isNaN(sessionIndex) || sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length) {
      return;
    }
    const updatedRecords = [...this.eventScheduleRecords];
    updatedRecords[sessionIndex].isCard = !updatedRecords[sessionIndex].isCard;
    this.eventScheduleRecords = updatedRecords;
  }

  //Validate session title
  validateSessionTitle(sessionIndex) {
    let isValid = true;
    const sessionTitleField = this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="sessionTitle"]`);

    if (sessionTitleField) {
      const value = sessionTitleField.value || '';

      let errorMessage = '';
      if (!value) {
        errorMessage = 'Session title is required';
        isValid = false;
      } else if (value.length < 5) {
        errorMessage = 'Session title should be at least 5 characters long';
        isValid = false;
      } else if (value.length > 100) {
        errorMessage = 'Session title should be less than 100 characters';
        isValid = false;
      }

      this.setFieldValidity(sessionTitleField, errorMessage);
    }

    return isValid;
  }

  //Validate time range for a session
  validateTimeRange(sessionIndex) {
    const session = this.eventScheduleRecords[sessionIndex];
    if (!session.startTime || !session.endTime) return true;

    const startTimeField = this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="startTime"]`);
    const endTimeField = this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="endTime"]`);

    if (!startTimeField || !endTimeField) return true;

    const isValid = session.startTime < session.endTime;

    if (!isValid) {
      this.setFieldValidity(endTimeField, 'End Time should be later than Start Time');
      this.setFieldValidity(startTimeField, 'Start Time should be earlier than End Time');
    } else {
      this.setFieldValidity(endTimeField, '');
      this.setFieldValidity(startTimeField, '');
    }

    return isValid;
  }

  //validate location fields
  validateLocationFields(sessionIndex) {
    const session = this.eventScheduleRecords[sessionIndex];

    let isValid = true;

    if (session.locationType) {
      if ((session.isOnlineEvent || session.isHybrid) && !session.sessionLink) {
        this.setFieldValidity(this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="sessionLink"]`), 'Meeting link is required');
        isValid = false;
      } else {
        this.setFieldValidity(this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="sessionLink"]`), '');
      }
      if ((session.isOnSite || session.isHybrid) && !session.locationAddress) {
        this.setFieldValidity(this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="locationAddress"]`), 'Location is required');
        isValid = false;
      } else {
        this.setFieldValidity(this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="locationAddress"]`), '');
      }
    }

    return isValid;
  }

  validateSessionFields(sessionIndex) {
    const session = this.eventScheduleRecords[sessionIndex];

    let isValid = true;

    // Validate session title
    if (!this.validateSessionTitle(sessionIndex)) {
      isValid = false;
    }

    //Validate start and end time
    if (!session.startTime) {
      this.setFieldValidity(this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="startTime"]`), 'Start Time is required');
      isValid = false;
    }

    if (!session.endTime) {
      this.setFieldValidity(this.template.querySelector(`lightning-input[data-id="${sessionIndex}"][data-field="endTime"]`), 'End Time is required');
      isValid = false;
    }

    // Validate time range
    if (!this.validateTimeRange(sessionIndex)) {
      isValid = false;
    }

    // Validate location type
    if (!this.validateLocationFields(sessionIndex)) {
      isValid = false;
    }

    // Validate speakers
    session.speakers.forEach((speaker, index) => {
      if (!speaker.contactId) {
        this.setFieldValidity(this.template.querySelector(`lightning-record-picker[data-id="${sessionIndex}"][data-speaker-index="${index}"][data-field="selectSpeaker"]`), 'Speaker is required');
        isValid = false;
      } else {
        this.setFieldValidity(this.template.querySelector(`lightning-record-picker[data-id="${sessionIndex}"][data-speaker-index="${index}"][data-field="selectSpeaker"]`), '');
      }
    });

    return isValid;
  }

  //Handle Session save
  handleSaveSession(event) {
    const sessionIndex = parseInt(event.currentTarget.dataset.id, 10);
    if (isNaN(sessionIndex) || sessionIndex < 0 || sessionIndex >= this.eventScheduleRecords.length) {
      return;
    }

    // Validate session fields
    if (!this.validateSessionFields(sessionIndex)) {
      this.showToast('Error', 'Please fix the errors before saving the session details', 'error');
      return;
    }

    const updatedRecords = [...this.eventScheduleRecords];
    updatedRecords[sessionIndex].isCard = true;
    this.eventScheduleRecords = updatedRecords;
    const currentRecord = this.eventScheduleRecords[sessionIndex];
    const uniqueKey = currentRecord.uniqueKey;

    // Check if record exists in savedEventSchedules
    const existingRecordIndex = this.savedEventSchedules.findIndex(record => record.uniqueKey === uniqueKey);
    if (existingRecordIndex !== -1) {
      // Update existing record
      this.savedEventSchedules = this.savedEventSchedules.map(record => {
        if (record.uniqueKey === uniqueKey) {
          return {
            ...record,
            ...currentRecord
          };
        }
        return record;
      });
    } else {
      // Add new record
      this.savedEventSchedules = [...this.savedEventSchedules, { ...currentRecord }];
    }
  }

  //Save event schedules
  async handleSave() {
    try {
      this.showSpinner = true;

      // Prepare data for saving
      const preparedRecords = this.savedEventSchedules
        .filter(record => record.startDate) // Ensure records have startDate
        .map((record, index) => ({
          ...record,
          eventId: this.eventRecordId,
          index
        }));

      await createEventSchedule({ records: JSON.stringify(preparedRecords) });

      // Clear the saved state since it's now saved to object.
      this.clearStateFromSessionStorage();

      this.showToast('Success', 'Sessions saved successfully', 'success');

      await this.loadScheduleData();

      // Show fee selection modal
      this.openFeeSelection = true;

    } catch (error) {
      this.handleError('Error saving sessions', error);
    } finally {
      this.showSpinner = false;
    }
  }

  //Handle previous button click
  handlePrevious() {
    // Save current state before navigating
    this.saveStateToSessionStorage();

    this.dispatchEvent(new CustomEvent('previous', {
      detail: 'targetAudience'
    }));
  }

  //Handle cancel button click
  handleCancel() {
    // Clear saved state when cancelling
    this.clearStateFromSessionStorage();

    if (this.eventRecordId) {
      this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
          recordId: this.eventRecordId,
          actionName: 'view'
        }
      });
    } else {
      this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
          objectApiName: 'Event_Master__c',
          actionName: 'list'
        },
        state: {
          filterName: 'Recent'
        }
      });
    }
  }

  //Handle session pricing selection
  handleSessionFee() {
    this.isSessionPricing = true;
    this.closeFeeModal();

    this.dispatchEvent(new CustomEvent('eventschedule', {
      detail: {
        eventId: this.eventRecordId,
        value: true,
        type: 'Session'
      }
    }));
  }

  //Handle event pricing selection
  handleEventFee() {
    this.isEventPricing = true;
    this.closeFeeModal();

    this.dispatchEvent(new CustomEvent('eventschedule', {
      detail: {
        eventId: this.eventRecordId,
        value: true,
        type: 'Event'
      }
    }));
  }

  // Save state to session storage
  saveStateToSessionStorage() {
    if (!this.eventRecordId) return;

    const stateToSave = {
      datePath: this.datePath,
      eventScheduleRecords: this.eventScheduleRecords,
      allEventSchedules: this.allEventSchedules,
      savedEventSchedules: this.savedEventSchedules,
      selectedDate: this.selectedDate,
      startDate: this.startDate,
      endDate: this.endDate
    };

    try {
      sessionStorage.setItem(
        SESSION_STORAGE_KEY + this.eventRecordId,
        JSON.stringify(stateToSave)
      );
    } catch (error) {
      console.error('Error saving state to session storage:', error);
    }
  }

  // Load state from session storage
  loadStateFromSessionStorage() {
    if (!this.eventRecordId) return false;

    try {
      const savedState = sessionStorage.getItem(SESSION_STORAGE_KEY + this.eventRecordId);
      if (savedState) {
        const parsedState = JSON.parse(savedState);

        this.datePath = parsedState.datePath;
        this.eventScheduleRecords = parsedState.eventScheduleRecords;
        this.allEventSchedules = parsedState.allEventSchedules;
        this.savedEventSchedules = parsedState.savedEventSchedules;
        this.selectedDate = parsedState.selectedDate;
        this.startDate = parsedState.startDate;
        this.endDate = parsedState.endDate;

        return true;
      }
    } catch (error) {
      console.error('Error loading state from session storage:', error);
    }

    return false;
  }

  // Clear state from session storage
  clearStateFromSessionStorage() {
    if (!this.eventRecordId) return;

    try {
      sessionStorage.removeItem(SESSION_STORAGE_KEY + this.eventRecordId);
    } catch (error) {
      console.error('Error clearing state from session storage:', error);
    }
  }

  //Close fee selection modal
  closeFeeModal() {
    this.openFeeSelection = false;
  }

  //download file
  downloadFile(event) {
    if (event.target.dataset.type == 'session') {
      const link = document.createElement('a');
      link.href = this.eventScheduleRecords[event.target.dataset.id].sessionBroucher;
      link.download = this.eventScheduleRecords[event.target.dataset.id].brochureFileName;

      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    }
  }

  //Set field validity
  setFieldValidity(field, errorMessage) {
    if (field) {
      field.setCustomValidity(errorMessage);
      field.reportValidity();
    }
  }

  //Show toast message
  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({
      title,
      message,
      variant
    }));
  }

  //Handle errors
  handleError(message, error) {
    console.error(message, error);
    const errorMsg = error.message || error.body?.message || JSON.stringify(error);
    this.showToast('Error', `${message}: ${errorMsg}`, 'error');
  }

}