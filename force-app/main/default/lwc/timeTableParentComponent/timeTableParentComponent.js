import { LightningElement, track, api, wire } from 'lwc';
import getAcademicPrograms from '@salesforce/apex/TimetableController.getAcademicPrograms';
import getProgramPlans from '@salesforce/apex/TimetableController.getProgramPlans';
import getTerms from '@salesforce/apex/TimetableController.getTerms';
import getSections from '@salesforce/apex/TimetableController.getSections';
import getSubjects from '@salesforce/apex/TimetableController.getSubjects';
import { refreshApex } from '@salesforce/apex';
import getSessions from '@salesforce/apex/TimetableController.getSessions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class TimetableParentComponent extends LightningElement {
    // API properties that can be set from parent
    @api defaultView = 'month';
   
    // Current date and view state
    @track currentDate = new Date();
    @track currentView;
    @track calendarWeeks = [];
   
    // Form field values and options
    @track selectedProgramId;
    @track selectedPlanId;
    @track selectedTermId;
    @track selectedSectionId;
   
    @track programOptions = [];
    @track planOptions = [];
    @track termOptions = [];
    @track sectionOptions = [];
   
    @track allSubjectsSelected = false;
    @track showFaculty = true;
    @track showFacility = false;
   
    // Data collections
    @track events = [];
    @track facultyList = [];
    @track subjects = [];
    @track selectedDate = '2025-04-22';

    // Loading states
    @track isLoadingPrograms = true;
    @track isLoadingPlans = false;
    @track isLoadingTerms = false;
    @track isLoadingSections = false;
    @track isLoadingSubjects = false;
    @track isLoading = false;
   
    // Error states
    @track error;


    // View properties
    showBasicMonthView = false;
    showAdvancedMonthView = true;


    // Toast notification properties
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';
   
    // Weekday names for the calendar
    weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
   
    // Lifecycle hooks
    connectedCallback() {
        // Set the initial view based on the default view property
        this.currentView = this.defaultView || 'month';
       
        // Generate calendar data for month view
        this.generateCalendarData();
       
        // Setting a timeout allows the DOM to render before accessing elements
        setTimeout(() => {
            this.initializeComponents();
        }, 100);
    }

    handleDateChange(event) {
        this.selectedDate = event.detail.value;
    }
   
    // Initialize any additional components if needed
    initializeComponents() {
        console.log('Components initialized');
        console.log('Current view:', this.currentView);
       
        // Load sessions from server
        this.loadSessionsFromServer();
       
        // Initialize the appropriate view component based on current view
        if (this.currentView === 'month') {
            this.initializeMonthView();
        } else if (this.currentView === 'day') {
            this.initializeDayView();
        } else if (this.currentView === 'week') {
            this.initializeWeekView();
        }
    }
   
    // Initialize the month view component if needed
    initializeMonthView() {
        const monthViewComponent = this.template.querySelector('c-month-view-component');
        if (monthViewComponent) {
            monthViewComponent.currentDate = this.currentDate;
            monthViewComponent.events = this.events;


            // Pass the context data to MonthViewComponent
            monthViewComponent.updateContextData(
                this.selectedProgramId,
                this.selectedTermId,
                this.selectedSectionId
            );


            monthViewComponent.refreshCalendar();
        }
    }

    // Initialize the day view component if needed
    initializeDayView() {
        const dayViewComponent = this.template.querySelector('c-day-view-component');
        if (dayViewComponent) {
            console.log('Initializing day view component');
            
            // Set basic properties
            dayViewComponent.currentDate = this.currentDate;
            
            // Process events for day view format
            const processedEvents = this.processDayViewEvents();
            dayViewComponent.events = processedEvents;
            
            // Process faculty data
            dayViewComponent.facultyListRaw = this.processFacultyForDayView();
            
            // Process facility data - this is crucial for facility view
            dayViewComponent.facilityListRaw = this.processFacilityForDayView();
            
            // Set the faculty/facility toggle flags
            // IMPORTANT: Pass the current state to the component
            dayViewComponent.showFaculty = !this.showFacility;
            dayViewComponent.showFacility = this.showFacility;
            
            console.log('Day view initialized with showFacility =', this.showFacility);
            
            // Force a refresh
            if (typeof dayViewComponent.refreshData === 'function') {
                dayViewComponent.refreshData();
            }
        }
    }
    get facilityList() {
        return this.processFacilityForDayView();
    }
    

    // Initialize the week view component
    initializeWeekView() {
        const weekViewComponent = this.template.querySelector('c-week-view-component');
        if (weekViewComponent) {
            weekViewComponent.currentDate = this.currentDate;
            weekViewComponent.events = this.events;
            weekViewComponent.facultyListRaw = this.processFacultyForWeekView();
        }
    }

    // Process faculty for week view format - extracts unique faculty from events
    processFacultyForWeekView() {
        // Extract unique faculty values from events
        const uniqueFaculty = new Map();
        
        this.events.forEach(event => {
            if (event.facultyId && !uniqueFaculty.has(event.facultyId)) {
                uniqueFaculty.set(event.facultyId, {
                    id: event.facultyId,
                    name: event.facultyName || event.facultyId,
                    shortName: event.facultyName ? event.facultyName.split(' ')[0] : event.facultyId
                });
            }
        });
        
        return Array.from(uniqueFaculty.values());
    }

    // Process events for day view format
    processDayViewEvents() {
        const currentDateStr = this.formatDate(this.currentDate);
        
        console.log('Processing day view events for date:', currentDateStr);
        
        // Filter events for the current date
        const filteredEvents = this.events.filter(event => event.date === currentDateStr);
        
        return filteredEvents.map(event => {
            // Extract time from Start_Date_Time__c first if available
            let startHour = null;
            let startMinute = null;
            let startTime = null;
            
            // 1. Try to get time from Start_Date_Time__c
            if (event.sessionData && event.sessionData.Start_Date_Time__c) {
                const startDateTime = new Date(event.sessionData.Start_Date_Time__c);
                startHour = startDateTime.getHours();
                startMinute = startDateTime.getMinutes();
                startTime = `${startHour.toString().padStart(2, '0')}:${startMinute.toString().padStart(2, '0')}`;
                console.log(`Time from Start_Date_Time__c: ${startTime}`);
            }
            
            // 2. Try Start_Time_Format__c
            if (!startTime && event.sessionData && event.sessionData.Start_Time_Format__c) {
                startTime = event.sessionData.Start_Time_Format__c;
                console.log(`Time from Start_Time_Format__c: ${startTime}`);
            }
            
            // 3. Try event.Start_Time_Format__c
            if (!startTime && event.Start_Time_Format__c) {
                startTime = event.Start_Time_Format__c;
                console.log(`Time from event.Start_Time_Format__c: ${startTime}`);
            }
            
            // 4. Try event.startTime
            if (!startTime && event.startTime) {
                startTime = event.startTime;
                console.log(`Time from event.startTime: ${startTime}`);
            }
            
            // 5. Default to 9:00 if no time found
            if (!startTime) {
                startTime = '09:00';
                console.log('Using default time: 09:00');
            }
            
            // Similar process for end time
            let endTime = null;
            
            // 1. Try to get time from End_Date_Time__c
            if (event.sessionData && event.sessionData.End_Date_Time__c) {
                const endDateTime = new Date(event.sessionData.End_Date_Time__c);
                const endHour = endDateTime.getHours();
                const endMinute = endDateTime.getMinutes();
                endTime = `${endHour.toString().padStart(2, '0')}:${endMinute.toString().padStart(2, '0')}`;
            }
            
            // 2. Try End_Time_Format__c
            if (!endTime && event.sessionData && event.sessionData.End_Time_Format__c) {
                endTime = event.sessionData.End_Time_Format__c;
            }
            
            // 3. Try event.End_Time_Format__c
            if (!endTime && event.End_Time_Format__c) {
                endTime = event.End_Time_Format__c;
            }
            
            // 4. Try event.endTime
            if (!endTime && event.endTime) {
                endTime = event.endTime;
            }
            
            // 5. Default to start + 1 hour if no end time found
            if (!endTime) {
                // Parse start time to add 1 hour
                const startParts = startTime.split(':');
                if (startParts.length >= 2) {
                    let hour = parseInt(startParts[0], 10);
                    let minute = parseInt(startParts[1], 10);
                    
                    hour += 1;
                    if (hour >= 24) hour = 23;
                    
                    endTime = `${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}`;
                } else {
                    endTime = '10:00'; // Default if startTime parsing fails
                }
            }
            
            // Create a display title that starts with the time
            let displayTitle = event.title;
            
            // If title doesn't already start with the time, add it
            if (!displayTitle.match(/^\d{1,2}:\d{2}/)) {
                displayTitle = `${startTime} ${displayTitle}`;
            }
            
            console.log(`Final event: ${displayTitle}, start: ${startTime}, end: ${endTime}`);
            
            // Return the processed event
            return {
                id: event.id,
                facultyId: event.facultyId,
                date: event.date,
                // Use our determined times
                startTime: startTime,
                endTime: endTime,
                // Add the formatted time fields
                Start_Time_Format__c: startTime,
                End_Time_Format__c: endTime,
                status: event.status === 'default' ? 'filled' : event.status,
                // Use our display title with time
                title: displayTitle,
                // Include full session data
                sessionData: {
                    ...event.sessionData,
                    startTimeFormat: startTime,
                    endTimeFormat: endTime
                }
            };
        });
    }
    
    // Process faculty for day view format
    processFacultyForDayView() {
        // Extract unique faculty values from events
        const uniqueFaculty = new Map();
        
        this.events.forEach(event => {
            if (event.facultyId && !uniqueFaculty.has(event.facultyId)) {
                uniqueFaculty.set(event.facultyId, {
                    id: event.facultyId,
                    name: event.facultyName || event.facultyId,
                    shortName: event.facultyName ? event.facultyName.split(' ')[0] : event.facultyId
                });
            }
        });
        
        return Array.from(uniqueFaculty.values());
    }
   
    /**
     * Load sessions from server for the current date range
     */
    // Enhanced method for loading sessions with better date handling for week view
loadSessionsFromServer() {
    // Show loading state
    this.isLoading = true;
    console.clear(); // Clear previous logs
    console.log("Loading sessions for view:", this.currentView);
    let startDate, endDate;
    
    // Determine date range based on the current view
    if (this.currentView === 'week') {
        // For week view, get the week's start and end dates
        const currentDate = new Date(this.currentDate);
        console.log("Current date for week view:", currentDate);
        const day = currentDate.getDay();
     //   const diff = currentDate.getDate() - day + (day === 0 ? -6 : 1); // Adjust for Sunday
     const diff = day === 0 ? -6 : -(day - 1);
        // Start date is Monday of the week (or Sunday depending on locale)
        startDate = new Date(currentDate);
        startDate.setDate(currentDate.getDate() + diff);
        
        // End date is Sunday of the week (6 days after start)
        endDate = new Date(startDate);
        endDate.setDate(startDate.getDate() + 6);
        
        console.log(`Week view date range: ${this.formatDate(startDate)} to ${this.formatDate(endDate)}`);
    } else if (this.currentView === 'day') {
        // For day view, use the current date
        startDate = new Date(this.currentDate);
        endDate = new Date(this.currentDate);
    } else {
        // For month view or default, get first and last day of current month
        const currentDate = new Date(this.currentDate);
        startDate = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1);
        endDate = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0);
    }
    
    // Format dates for apex method
    const formattedStartDate = this.formatDate(startDate);
    const formattedEndDate = this.formatDate(endDate);
    
    console.log('Loading sessions from', formattedStartDate, 'to', formattedEndDate);
    
    // Call apex method to get sessions
    getSessions({ startDate: formattedStartDate, endDate: formattedEndDate })
        .then(result => {
            console.log('Loaded', result.length, 'sessions');
            
            // Clear existing events
            this.events = [];
            
            // Convert sessions to events format
            if (result && result.length > 0) {
                this.events = result
                    .map(session => this.convertSessionToEvent(session))
                    .filter(event => event !== null); // Filter out any null events
            }
            
            console.log('Converted to', this.events.length, 'events');
            
            // Extract faculty list from events for use in week view
            this.facultyList = this.extractFacultyFromEvents(this.events);
            
            // Update calendar data for month view
            this.generateCalendarData();
            
            // Update the appropriate view based on current view
            if (this.currentView === 'month') {
                this.updateMonthViewData();
            } else if (this.currentView === 'day') {
                this.updateDayViewData();
            } else if (this.currentView === 'week') {
                this.updateWeekViewData();
            }
            
            // Show success toast if needed
            if (result && result.length > 0) {
                this.showToastMessage('Success', `Loaded ${result.length} sessions`, 'success');
            }
        })
        .catch(error => {
            console.error('Error loading sessions:', error);
            // Show error message
            this.showToastMessage('Error', 'Failed to load sessions: ' + (error.body ? error.body.message : error.message), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
}

// New helper method to extract faculty from events
extractFacultyFromEvents(events) {
    if (!events || events.length === 0) {
        return [];
    }
    
    const facultyMap = new Map();
    
    events.forEach(event => {
        if (event.facultyId && !facultyMap.has(event.facultyId)) {
            facultyMap.set(event.facultyId, {
                id: event.facultyId,
                name: event.facultyName || event.facultyId,
                shortName: event.facultyName ? 
                    (event.facultyName.includes(' ') ? event.facultyName.split(' ')[0] : event.facultyName) : 
                    event.facultyId
            });
        }
    });
    
    return Array.from(facultyMap.values());
}

    // Update the various view components with current data
    updateDayViewData() {
        const dayViewComponent = this.template.querySelector('c-day-view-component');
        if (dayViewComponent) {
            console.log('Updating day view data, showFacility =', this.showFacility);
            
            // Process and set the events
            const processedEvents = this.processDayViewEvents();
            dayViewComponent.events = processedEvents;
            
            // Set both faculty and facility data regardless of current view
            dayViewComponent.facultyListRaw = this.processFacultyForDayView();
            dayViewComponent.facilityListRaw = this.processFacilityForDayView();
            
            // IMPORTANT: Make sure we're setting the properties in the correct order
            // First update the toggle flags
            dayViewComponent.showFaculty = !this.showFacility;
            dayViewComponent.showFacility = this.showFacility;
            
            // Then explicitly call the refresh method
            if (typeof dayViewComponent.refreshData === 'function') {
                dayViewComponent.refreshData();
            }
            
            console.log('Day view data updated');
        } else {
            console.log('Day view component not found');
        }
    }
    updateWeekViewData() {
        const weekViewComponent = this.template.querySelector('c-week-view-component');
        if (weekViewComponent) {
            // Set the events and faculty data
            weekViewComponent.events = this.events;
            weekViewComponent.facultyListRaw = this.facultyList;
            weekViewComponent.currentDate = this.currentDate;
            
            // Force refresh
            if (typeof weekViewComponent.refreshData === 'function') {
                weekViewComponent.refreshData();
            }
            
            // Debug events
            if (typeof weekViewComponent.debugEventVisibility === 'function') {
                setTimeout(() => weekViewComponent.debugEventVisibility(), 500);
            }
            
            console.log('Week view updated with', this.events.length, 'events and', 
                       this.facultyList.length, 'faculty members');
        }
    }
    /**
     * Convert a Session__c record to an event object for the calendar
     */
    // Add these methods to your TimetableParentComponent.js file

// Enhanced method for session conversion
convertSessionToEvent(session) {
    // Skip invalid sessions
    if (!session || !session.Id || !session.Start_Date_Time__c) {
        console.log('Invalid session, skipping:', session);
        return null;
    }
    
    console.log('Converting session to event:', session.Id);
    
    // Extract date and time parts from DateTime fields
    const startDateTime = session.Start_Date_Time__c ? new Date(session.Start_Date_Time__c) : null;
    const endDateTime = session.End_Date_Time__c ? new Date(session.End_Date_Time__c) : null;
    
    if (!startDateTime) {
        console.log('Session has no valid start date time:', session.Id);
        return null;
    }
    
    // Format date for grid display (YYYY-MM-DD)
    const formattedDate = this.formatDate(startDateTime);
    
    // Format times for display (HH:MM)
    const formattedStartTime = startDateTime ? 
        `${startDateTime.getHours().toString().padStart(2, '0')}:${startDateTime.getMinutes().toString().padStart(2, '0')}` : '';
    
    const formattedEndTime = endDateTime ? 
        `${endDateTime.getHours().toString().padStart(2, '0')}:${endDateTime.getMinutes().toString().padStart(2, '0')}` : '';
    
    // Get course/subject name
    let courseName = '';
    
    // Try different paths to get the course name
    if (session.Course_Offering__r && session.Course_Offering__r.hed__Course__r && 
        session.Course_Offering__r.hed__Course__r.Name) {
        courseName = session.Course_Offering__r.hed__Course__r.Name;
    } else if (session.Course__r && session.Course__r.Name) {
        courseName = session.Course__r.Name;
    } else if (session.Name) {
        courseName = session.Name;
    }
    
    // Get faculty information - IMPORTANT FIX
    let facultyId = session.Faculty__c || '';
    let facultyName = '';
    
    // Explicitly check for the Faculty__c field
    if (session.Faculty__c) {
        facultyId = session.Faculty__c;
        // If there's a relationship field with name, use it
        if (session.Faculty__r && session.Faculty__r.Name) {
            facultyName = session.Faculty__r.Name;
        } else {
            // Otherwise use the text field itself
            facultyName = session.Faculty__c;
        }
    }
    
    console.log(`Faculty info: ID=${facultyId}, Name=${facultyName}`);
    
    // Create title with time and course name
    const title = formattedStartTime + ' ' + courseName;
    
    return {
        id: session.Id,
        title: title,
        courseName: courseName,
        // IMPORTANT: Set facultyId and facultyName correctly
        facultyId: facultyId,
        facultyName: facultyName,
        // Facility information if available
        facilityId: session.Facility__c,
        facilityName: session.Facility__r ? session.Facility__r.Name : '',
        // Date and time information
        date: formattedDate,
        startTime: formattedStartTime,
        endTime: formattedEndTime,
        Start_Time_Format__c: formattedStartTime,
        End_Time_Format__c: formattedEndTime,
        // Status for styling
        status: 'filled',
        // Store full session data for reference
        sessionData: session
    };
}
    
    
    // Handle refreshing from server
    handleRefreshFromServer() {
        this.loadSessionsFromServer();
    }
   
    /**
     * Handle event click from various view components
     * Shows details of the clicked session
     */
    handleEventClick(event) {
        const { eventId } = event.detail;
        console.log('Event clicked:', eventId);
       
        // Find the event in our events array
        const selectedEvent = this.events.find(evt => evt.id === eventId);
       
        if (selectedEvent) {
            // Format the date and time for display
            const dateObj = new Date(selectedEvent.date);
            const formattedDate = dateObj.toLocaleDateString();
           
            // Create session info for toast
            const sessionInfo = `
                Activity: ${selectedEvent.title}
                Date: ${formattedDate}
                Time: ${selectedEvent.Start_Time_Format__c} - ${selectedEvent.End_Time_Format__c}
                Faculty: ${selectedEvent.facultyName || 'N/A'}
                Facility: ${selectedEvent.facilityName || 'N/A'}
            `;
           
            // Show toast with session details
            this.showToastMessage('Session Details', sessionInfo, 'info');
        }
    }

    /**
     * Handle specific event click handlers from different view components
     */
    handleMonthViewEventClick(event) {
        this.handleEventClick(event);
    }

    handleDayViewEventClick(event) {
        this.handleEventClick(event);
    }
    
    handleWeekViewEventClick(event) {
        this.handleEventClick(event);
    }
   
    // Wire adapters to fetch data from Salesforce
   
    // Fetch academic programs
    @wire(getAcademicPrograms)
    wiredAcademicPrograms({ error, data }) {
        this.isLoadingPrograms = true;
        if (data) {
            this.programOptions = data;
            this.error = undefined;
           
            // If we have programs, select the first one by default
           /* if (this.programOptions.length > 0) {
                this.selectedProgramId = this.programOptions[0].value;
                // Fetch related program plans
                this.fetchProgramPlans();
            } */
           
            this.isLoadingPrograms = false;
        } else if (error) {
            this.error = error;
            this.programOptions = [];
            this.isLoadingPrograms = false;
            console.error('Error fetching academic programs', error);
        }
    }
   
    // Method to fetch program plans based on selected program
    fetchProgramPlans() {
        if (!this.selectedProgramId) return;
       
        this.isLoadingPlans = true;
        this.planOptions = [];
        this.selectedPlanId = undefined;
        this.termOptions = [];
        this.selectedTermId = undefined;
        this.sectionOptions = [];
        this.selectedSectionId = undefined;
        this.subjects = [];
       
        getProgramPlans({ academicProgramId: this.selectedProgramId })
            .then(result => {
                this.planOptions = result;
                this.error = undefined;
               
                // If we have plans, select the first one by default
              /*  if (this.planOptions.length > 0) {
                    this.selectedPlanId = this.planOptions[0].value;
                    // Fetch related terms
                    this.fetchTerms();
                } */
               
                this.isLoadingPlans = false;
            })
            .catch(error => {
                this.error = error;
                this.planOptions = [];
                this.isLoadingPlans = false;
                console.error('Error fetching program plans', error);
            });
    }
   
    // Method to fetch terms based on selected program plan
    fetchTerms() {
        if (!this.selectedPlanId) return;
       
        this.isLoadingTerms = true;
        this.termOptions = [];
        this.selectedTermId = undefined;
        this.sectionOptions = [];
        this.selectedSectionId = undefined;
        this.subjects = [];
       
        getTerms({ programPlanId: this.selectedPlanId })
            .then(result => {
                this.termOptions = result;
                this.error = undefined;
               
                // If we have terms, select the first one by default
              /*  if (this.termOptions.length > 0) {
                    this.selectedTermId = this.termOptions[0].value;
                    // Fetch related sections
                    this.fetchSections();
                } */
               
                this.isLoadingTerms = false;
            })
            .catch(error => {
                this.error = error;
                this.termOptions = [];
                this.isLoadingTerms = false;
                console.error('Error fetching terms', error);
            });
    }
   
    // Method to fetch sections based on selected term
    fetchSections() {
        if (!this.selectedTermId) return;
       
        this.isLoadingSections = true;
        this.sectionOptions = [];
        this.selectedSectionId = undefined;
        this.subjects = [];
       
        getSections({ termId: this.selectedTermId })
            .then(result => {
                this.sectionOptions = result;
                this.error = undefined;
               
                // If we have sections, select the first one by default
              /*  if (this.sectionOptions.length > 0) {
                    this.selectedSectionId = this.sectionOptions[0].value;
                    // Fetch related subjects
                    this.fetchSubjects();
                } */
               
                this.isLoadingSections = false;
            })
            .catch(error => {
                this.error = error;
                this.sectionOptions = [];
                this.isLoadingSections = false;
                console.error('Error fetching sections', error);
            });
    }
   
    // Method to fetch subjects based on selected term and section
    fetchSubjects() {
        if (!this.selectedTermId || !this.selectedSectionId) return;
       
        this.isLoadingSubjects = true;
        this.subjects = [];
       
        // Now we're passing sectionIdsList which is a serialized list of course offering IDs
        getSubjects({ termId: this.selectedTermId, sectionIdsList: this.selectedSectionId })
            .then(result => {
                // Process the subjects to separate name and code
                this.subjects = result.map(subject => {
                    let displayName = subject.name;
                    let code = subject.code;
                   
                    // If the name already includes the code (like "Business Forecasting 4.8.2")
                    // then parse it to separate the name and code
                    if (displayName && displayName.includes(code)) {
                        displayName = displayName.replace(code, '').trim();
                        // Remove any trailing characters like spaces, dots, dashes
                        displayName = displayName.replace(/[\s\.\-]+$/, '');
                    }
                   
                    // If name is something like "Business Forecasting 4.8.2" and code is not defined
                    // Try to extract the code from the name
                    if (!code && displayName) {
                        // Look for patterns like "X.Y.Z" or numeric codes at the end of the name
                        const codeMatch = displayName.match(/\s+([\d\.]+)$/);
                        if (codeMatch) {
                            code = codeMatch[1];
                            displayName = displayName.replace(codeMatch[0], '').trim();
                        }
                    }
                   
                    return {
                        ...subject,
                        displayName: displayName,
                        code: code,
                        selected: false
                    };
                });
               
                this.error = undefined;
                this.isLoadingSubjects = false;
               
                setTimeout(() => {
                    this.updateMonthViewSubjects();
                }, 0);
               
                // After loading subjects, fetch the actual sessions from server
                this.loadSessionsFromServer();
            })
            .catch(error => {
                this.error = error;
                this.subjects = [];
                this.isLoadingSubjects = false;
                console.error('Error fetching subjects', error);
            });
    }  
   
    // Helper to load mock event data for the calendar
    loadMockEvents() {
        // Mock faculty data
        this.facultyList = [
            { id: 'fac1', name: 'Prof. Varun Kumar', shortName: 'Varun' },
            { id: 'fac2', name: 'Dr. Sarah Williams', shortName: 'Sarah' },
            { id: 'fac3', name: 'Prof. Emily Johnson', shortName: 'Emily' },
            { id: 'fac4', name: 'Mr. James Brown', shortName: 'James' },
            { id: 'fac5', name: 'Ms. Linda Garcia', shortName: 'Linda' },
        ];
       
        // Regenerate calendar data to include events
        this.generateCalendarData();
       
        // Also update the appropriate view component
        if (this.currentView === 'month') {
            this.updateMonthViewData();
        } else if (this.currentView === 'day') {
            this.updateDayViewData();
        } else if (this.currentView === 'week') {
            this.updateWeekViewData();
        }
    }
   
    // Update the month view component with current data
    updateMonthViewData() {
        const monthViewComponent = this.template.querySelector('c-month-view-component');
        if (monthViewComponent) {
            monthViewComponent.events = this.events;
            monthViewComponent.refreshCalendar();
        }
    }
   
    // Generate calendar data - similar to what was in the MonthViewComponent
    generateCalendarData() {
        if (!this.currentDate) return;
       
        const date = new Date(this.currentDate);
        const year = date.getFullYear();
        const month = date.getMonth();
       
        // Get the first day of the month
        const firstDay = new Date(year, month, 1);
       
        // Get the day of the week of the first day (0 = Sunday, 6 = Saturday)
        const firstDayOfWeek = firstDay.getDay();
       
        // Calculate the starting date for the calendar grid
        // We need to show days from the previous month to fill the first week
        const startDate = new Date(firstDay);
        startDate.setDate(startDate.getDate() - firstDayOfWeek);
       
        // Generate 6 weeks to ensure we have enough rows for all months
        const weeks = [];
       
        for (let weekIndex = 0; weekIndex < 6; weekIndex++) {
            const weekNumber = this.getWeekNumber(new Date(startDate.getFullYear(),
                                              startDate.getMonth(),
                                              startDate.getDate() + (weekIndex * 7)));
           
            const week = {
                id: `week-${weekIndex}`,
                weekNumber,
                days: []
            };
           
            for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
                const currDate = new Date(
                    startDate.getFullYear(),
                    startDate.getMonth(),
                    startDate.getDate() + (weekIndex * 7) + dayIndex
                );
               
                const isCurrentMonth = currDate.getMonth() === month;
               
                // Format the date for comparison with events
                const formattedDate = this.formatDate(currDate);
               
                // Find events for this day by comparing the formatted date strings
                const dayEvents = this.events.filter(event => {
                    return event.date === formattedDate;
                });
               
                // Process events to include display properties
                const processedEvents = dayEvents.map(event => {
                    return {
                        ...event,
                        className: `event ${event.status || 'default'}`
                    };
                });
               
                week.days.push({
                    id: `day-${currDate.getFullYear()}-${currDate.getMonth()}-${currDate.getDate()}`,
                    date: formattedDate,
                    dayNumber: currDate.getDate(),
                    isCurrentMonth,
                    className: `day-cell ${isCurrentMonth ? 'current-month' : 'other-month'}`,
                    events: processedEvents,
                    hasEvents: processedEvents.length > 0
                });
            }
           
            weeks.push(week);
        }
       
        this.calendarWeeks = weeks;
    }
   
    // Helper method to format date
    formatDate(date) {
        return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
    }


    // Format time helper
    formatTime(date) {
        return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
    }
   
    // Helper method to get the week number
    getWeekNumber(date) {
        const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
        const pastDaysOfYear = (date - firstDayOfYear) / 86400000;
        return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
    }
   
    // Calendar title formatting
    get formattedCalendarTitle() {
        if (!this.currentDate) return '';
       
        const date = new Date(this.currentDate);
        const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                           'July', 'August', 'September', 'October', 'November', 'December'];
       
        return `${monthNames[date.getMonth()]} ${date.getFullYear()}`;
    }
   
    get subjectOptionsForMonthView() {
        return this.subjects.map(subject => {
            return {
                // For the dropdown in the Add Session modal, include both name and code
                label: subject.displayName + (subject.code ? ` (${subject.code})` : ''),
                value: subject.id
            };
        });
    }
   
    // Get the selected program name for display
    get selectedProgram() {
        const program = this.programOptions.find(p => p.value === this.selectedProgramId);
        return program ? program.label : '';
    }
   
    // Get the selected plan name for display
    get selectedPlan() {
        const plan = this.planOptions.find(p => p.value === this.selectedPlanId);
        return plan ? plan.label : '';
    }
   
    // Get the selected term name for display
    get selectedTerm() {
        const term = this.termOptions.find(t => t.value === this.selectedTermId);
        return term ? term.label : '';
    }
   
    // Get the selected section name for display
    get selectedSection() {
        const section = this.sectionOptions.find(s => s.value === this.selectedSectionId);
        return section ? section.label : '';
    }
   
    // Computed properties for view state
    get isMonthView() {
        return this.currentView === 'month';
    }
   
    get isWeekView() {
        return this.currentView === 'week';
    }
   
    get isDayView() {
        return this.currentView === 'day';
    }
   
    // Button style getters
    get dayButtonVariant() {
        return this.currentView === 'day' ? 'brand' : 'neutral';
    }
   
    get weekButtonVariant() {
        return this.currentView === 'week' ? 'brand' : 'neutral';
    }
   
    get monthButtonVariant() {
        return this.currentView === 'month' ? 'brand' : 'neutral';
    }
   
    get facultyButtonVariant() {
        return this.showFaculty ? 'brand' : 'neutral';
    }
   
    get facilityButtonVariant() {
        return this.showFacility ? 'brand' : 'neutral';
    }
   
    // ===== Event Handlers =====
   
    // Calendar navigation handlers
    handlePreviousPeriod() {
        const date = new Date(this.currentDate);
       
        if (this.currentView === 'month') {
            date.setMonth(date.getMonth() - 1);
        } else if (this.currentView === 'week') {
            date.setDate(date.getDate() - 7);
        } else {
            date.setDate(date.getDate() - 1);
        }
       
        this.currentDate = date;
        this.generateCalendarData();
       
        // Load sessions for the new period
        this.loadSessionsFromServer();
       
        // Update the appropriate view component
        if (this.currentView === 'month') {
            this.updateMonthViewData();
        } else if (this.currentView === 'day') {
            this.updateDayViewData();
        } else if (this.currentView === 'week') {
            this.updateWeekViewData();
        }
    }
   
    handleNextPeriod() {
        const date = new Date(this.currentDate);
       
        if (this.currentView === 'month') {
            date.setMonth(date.getMonth() + 1);
        } else if (this.currentView === 'week') {
            date.setDate(date.getDate() + 7);
        } else {
            date.setDate(date.getDate() + 1);
        }
       
        this.currentDate = date;
        this.generateCalendarData();
       
        // Load sessions for the new period
        this.loadSessionsFromServer();
       
        // Update the appropriate view component
        if (this.currentView === 'month') {
            this.updateMonthViewData();
        } else if (this.currentView === 'day') {
            this.updateDayViewData();
        } else if (this.currentView === 'week') {
            this.updateWeekViewData();
        }
    }
   
    handleToday() {
        this.currentDate = new Date();
        this.generateCalendarData();
       
        // Load sessions for today
        this.loadSessionsFromServer();
       
        // Update the appropriate view component
        if (this.currentView === 'month') {
            this.updateMonthViewData();
        } else if (this.currentView === 'day') {
            this.updateDayViewData();
        } else if (this.currentView === 'week') {
            this.updateWeekViewData();
        }
    }
   
    // View switching handlers
    handleDayView() {
        this.currentView = 'day';
        // If we're switching to day view, make sure the DayViewComponent is updated
        setTimeout(() => {
            this.updateDayViewData();
        }, 0);
    }
   
    
handleWeekView() {
    this.currentView = 'week';
    
    // Reload sessions with the proper date range for week view
    this.loadSessionsFromServer();
}
   
    handleMonthView() {
        this.currentView = 'month';
        // If we're switching to month view, make sure the MonthViewComponent is updated
        setTimeout(() => {
            this.updateMonthViewData();
        }, 0);
    }
   
    // Event handlers for week view component
    handleWeekChange(event) {
        this.currentDate = event.detail.date;
        // Reload sessions for the new week
        this.loadSessionsFromServer();
    }
   
    // Event handlers for day view component
    handleDayChange(event) {
        this.currentDate = event.detail.date;
        this.loadSessionsFromServer();
        setTimeout(() => {
            this.updateDayViewData();
        }, 0);
    }
   
    handleViewChange(event) {
        this.currentView = event.detail.view;
        // Update the appropriate view based on the new current view
        setTimeout(() => {
            if (this.currentView === 'month') {
                this.updateMonthViewData();
            } else if (this.currentView === 'day') {
                this.updateDayViewData();
            } else if (this.currentView === 'week') {
                this.updateWeekViewData();
            }
        }, 0);
    }
   
    // Event handlers for day and event clicks
    handleDayClick(event) {
        const date = event.currentTarget.dataset.date;
       
        // Only handle clicks on the day cell itself, not on events
        if (event.target.classList.contains('day-cell') ||
            event.target.classList.contains('day-number') ||
            event.target.classList.contains('day-add-text')) {
           
            console.log(`Day clicked: ${date}, Add event: true`);
            // Here you would typically open a modal to add an event
        }
    }
   
    handleEventClick(event) {
        event.stopPropagation();
        const eventId = event.currentTarget.dataset.eventId;
        const selectedEvent = this.events.find(evt => evt.id === eventId);
       
        if (selectedEvent) {
            console.log('Event clicked:', selectedEvent);
            // Here you would typically open a modal to view/edit the event
        }
    }
   
    // Form field handlers
    handleProgramChange(event) {
        this.selectedProgramId = event.detail.value;
        this.fetchProgramPlans();
        this.updateMonthViewContextData();
    }
   
    handlePlanChange(event) {
        this.selectedPlanId = event.detail.value;
        this.fetchTerms();
        this.updateMonthViewContextData();
    }
   
    handleTermChange(event) {
        this.selectedTermId = event.detail.value;
        this.fetchSections();
        this.updateMonthViewContextData();
    }
   
    handleSectionChange(event) {
        this.selectedSectionId = event.detail.value;
        this.fetchSubjects();
        this.updateMonthViewContextData();
    }
   
    // Update MonthViewComponent with the latest context data
    updateMonthViewContextData() {
        const monthViewComponent = this.template.querySelector('c-month-view-component');
        if (monthViewComponent) {
            monthViewComponent.updateContextData(
                this.selectedProgramId,
                this.selectedTermId,
                this.selectedSectionId
            );
        }
    }
   
    handleAllSubjectsChange(event) {
        this.allSubjectsSelected = event.target.checked;
       
        this.subjects = this.subjects.map(subject => ({
            ...subject,
            selected: this.allSubjectsSelected
        }));
    }
   
    handleSubjectChange(event) {
        const subjectId = event.target.name;
        const isChecked = event.target.checked;
       
        this.subjects = this.subjects.map(subject => {
            if (subject.id === subjectId) {
                return { ...subject, selected: isChecked };
            }
            return subject;
        });
       
        this.allSubjectsSelected = this.subjects.every(subject => subject.selected);
        this.updateMonthViewSubjects();
    }
   
    // Event handlers for the month view component
    handleMonthViewDayClick(event) {
        console.log('Day clicked in month view:', event.detail);
    }
   
    // Updated event handler for month view session save
    handleMonthViewSessionSave(event) {
        console.log('Session saved in month view:', event.detail);
       
        if (event.detail.success) {
            // Process the saved session data and update the events array
            this.processSessionSave(event.detail.sessionData);
           
            // Show success message
            this.showToastMessage('Success', 'Session saved successfully', 'success');
           
            // Refresh the data from the server to get the latest sessions
            this.loadSessionsFromServer();
        } else {
            // Show error message
            this.showToastMessage('Error', 'Error saving session: ' + event.detail.error, 'error');
        }
    }
   
    // Process and store a new session from the month view
    processSessionSave(sessionData) {
        // Get start time and course name
        const startTime = sessionData.startTime || '';
        const courseName = sessionData.subjectLabel || '';
       
        // Create a new event object from the session data
        const newEvent = {
            id: sessionData.id || ('event-' + new Date().getTime()),
            title: startTime + ' ' + courseName, // Include start time
            facultyId: sessionData.faculty,
            date: sessionData.startDate,
            startTime: sessionData.startTime,
            endTime: sessionData.endTime,
            status: 'default',
            sessionData: sessionData
        };
       
        // Add to the events array
        this.events = [...this.events, newEvent];
       
        // Regenerate calendar data
        this.generateCalendarData();
       
        // Update appropriate view
        if (this.currentView === 'month') {
            this.updateMonthViewData();
        } else if (this.currentView === 'day') {
            this.updateDayViewData();
        } else if (this.currentView === 'week') {
            this.updateWeekViewData();
        }
    }
   
    // Button click handlers
    handleClearFilters() {
        this.allSubjectsSelected = false;
        this.subjects = this.subjects.map(subject => ({
            ...subject,
            selected: false
        }));
    }
   
    handleFacultyClick() {
        console.log('Faculty toggle clicked');
        
        // Toggle the state
        this.showFaculty = true;
        this.showFacility = false;
        
        // If currently in day view, update the component
        if (this.currentView === 'day') {
            // A small delay can help ensure the component updates properly
            setTimeout(() => {
                this.updateDayViewData();
            }, 0);
        }
    }
    
    handleFacilityClick() {
        console.log('Facility toggle clicked');
        
        // Toggle the state
        this.showFacility = true;
        this.showFaculty = false;
        
        // If currently in day view, update the component
        if (this.currentView === 'day') {
            // A small delay can help ensure the component updates properly
            setTimeout(() => {
                this.updateDayViewData();
            }, 0);
        }
    }
   
    // Action button handlers
    handleBulkUpload() {
        console.log('Bulk upload clicked');
        // Implement bulk upload functionality
    }
   
    handleDownload() {
        console.log('Download clicked');
        // Implement download functionality
    }
   
    handleClear() {
        console.log('Clear clicked');
        // Implement clear functionality
    }
   
    handleCancel() {
        console.log('Cancel clicked');
        // Implement cancel functionality
    }
   
    handleSaveAsDraft() {
        console.log('Save as draft clicked');
        // Implement save as draft functionality
    }
   
    handleSaveDetails() {
        console.log('Save details clicked');
        // Implement save details functionality
    }

    // Add this method to your parent component
    updateMonthViewSubjects() {
        // Create an array of subjects from the sidebar checkboxes
        const selectedSubjects = [];
       
        // Get all the subject checkboxes from the sidebar
        const subjectCheckboxes = this.template.querySelectorAll('.subject-checkbox');
       
        // Process each checkbox to build the subjects list
        subjectCheckboxes.forEach(checkbox => {
            if (checkbox.checked) {
                selectedSubjects.push({
                    id: checkbox.dataset.id,
                    name: checkbox.dataset.name,
                    code: checkbox.dataset.code
                });
            }
        });
       
        // Or if "All Subjects" is checked, include all subjects
        if (this.allSubjectsSelected) {
            this.subjects.forEach(subject => {
                selectedSubjects.push({
                    id: subject.id,
                    name: subject.name,
                    code: subject.code
                });
            });
        }
       
        // Update the MonthViewComponent with the selected subjects
        const monthViewComponent = this.template.querySelector('c-month-view-component');
        if (monthViewComponent) {
            monthViewComponent.updateSubjects(selectedSubjects);
        }
    }


    // Show a toast message
    showToastMessage(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
                mode: variant === 'info' ? 'sticky' : 'dismissable'
            })
        );
    }
   
    get toastClasses() {
        return `slds-notify slds-notify_toast slds-theme_${this.toastVariant}`;
    }
   
    get toastIconName() {
        switch(this.toastVariant) {
            case 'success':
                return 'utility:success';
            case 'warning':
                return 'utility:warning';
            case 'error':
                return 'utility:error';
            default:
                return 'utility:info';
        }
    }
   
    // Method to manually close the toast
    closeToast() {
        this.showToast = false;
    }
    
    handleMonthViewMonthChange(event) {
        try {
            if (event.detail && event.detail.date) {
                this.currentDate = new Date(event.detail.date);
                this.generateCalendarData();
                // Load sessions for the new month
                this.loadSessionsFromServer();
            }
        } catch (error) {
            console.error('Error handling month change:', error);
            // Reset to current month if there's an error
            this.currentDate = new Date();
            this.generateCalendarData();
        }
    }

    processFacilityForDayView() {
        // Extract unique facility values from events
        const uniqueFacility = new Map();
        
        // Process events to collect unique facilities with their capacities
        if (this.events && Array.isArray(this.events)) {
            this.events.forEach(event => {
                if (event.facilityId && !uniqueFacility.has(event.facilityId)) {
                    let capacity = '30'; // Default capacity
                    
                    // Try to extract capacity from event data if available
                    if (event.Facility__r && event.Facility__r.hed__Capacity__c) {
                        capacity = event.Facility__r.hed__Capacity__c;
                    } else if (event.sessionData && event.sessionData.Facility__r && 
                               event.sessionData.Facility__r.hed__Capacity__c) {
                        capacity = event.sessionData.Facility__r.hed__Capacity__c;
                    }
                    
                    uniqueFacility.set(event.facilityId, {
                        id: event.facilityId,
                        name: event.facilityName || `Room ${event.facilityId}`,
                        shortName: event.facilityId,
                        capacity: capacity
                    });
                }
            });
        }
        
        // If no facilities found in events, use default facilities that match the screenshot
        if (uniqueFacility.size === 0) {
            const defaultFacilities = [
                { id: 'B13', name: 'Room B13', capacity: '30' },
                { id: 'A1', name: 'Room A1', capacity: '60' },
                { id: 'B17', name: 'Room B17', capacity: '40' },
                { id: 'A2', name: 'Room A2', capacity: '30' },
                { id: 'A3', name: 'Room A3', capacity: '60' },
                { id: 'A8', name: 'Room A8', capacity: '30' }
            ];
            
            defaultFacilities.forEach(facility => {
                uniqueFacility.set(facility.id, facility);
            });
        }
        
        return Array.from(uniqueFacility.values());
    }
    
}