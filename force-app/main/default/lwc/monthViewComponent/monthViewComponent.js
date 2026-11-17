import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getActivityTypes from '@salesforce/apex/TimetableController.getActivityTypes';
import getFacilities from '@salesforce/apex/TimetableController.getFacilities';
import getFacultyMembers from '@salesforce/apex/TimetableController.getFacultyMembers';
import getSubjects from '@salesforce/apex/TimetableController.getSubjects';
import getWorkingDays from '@salesforce/apex/TimetableController.getWorkingDays';
import createSession from '@salesforce/apex/TimetableController.createSession';
import updateSession from '@salesforce/apex/TimetableController.updateSession';
import deleteSession from '@salesforce/apex/TimetableController.deleteSession';
import getSessionDetails from '@salesforce/apex/TimetableController.getSessionDetails';
import getHolidays from '@salesforce/apex/TimetableController.getHolidays';

export default class MonthViewComponent extends LightningElement {
    @api currentDate = new Date();
    @api events = [];
    @api selectedView = 'month'; // Can be 'day', 'week', or 'month'
    @api hideViewSelector = false; // Property to hide the view selector
    @api selectedPlanId; // Program Plan ID for fetching working days
    @api academicProgramId; // Academic Program ID for Account reference
    @api selectedTermId; // Term ID for reference
    @api selectedSectionId; // Section ID for Course Offering reference
    
    // Allow parent component to pass subject options directly
    @api subjectOptionsFromParent = [];
    
    // NEW: Allow parent to pass the sidebar subject list
    @api sidebarSubjects = [];

    @track weeks = [];
    @track isModalOpen = false; // Track modal visibility
    @track selectedDate; // Track selected date for the modal

    // Track loading state
    @track isLoading = false;
    @track isSaving = false; // Track save operation

    // Track picklist options
    @track activityTypeOptions = [];
    @track facilityOptions = [];
    @track facultyOptions = [];
    @track subjectOptions = [];
    
    // Recurrent session properties
    @track isRecurring = false;
    @track workingDaysLabel = '';
    // Add these properties to your MonthViewComponent class
    @track isSessionDetailModalOpen = false;
@track isSessionEditModalOpen = false;
@track selectedEvent = null;
@track editSessionData = {};
//skip holidays
@track holidays = [];
@track isCheckingHolidays = false;
@track holidayWarningMessage = '';

@track endDateError = '';
@track isEndDateValid = true;

@track editEndDateError = '';
@track isEditEndDateValid = true;

    
    
    
    // Day checkboxes for recurrent sessions
    @track dayCheckboxes = [
        { label: 'Sun', value: 'Sunday', checked: false, startTime: '', endTime: '' },
        { label: 'Mon', value: 'Monday', checked: false, startTime: '', endTime: '' },
        { label: 'Tue', value: 'Tuesday', checked: false, startTime: '', endTime: '' },
        { label: 'Wed', value: 'Wednesday', checked: false, startTime: '', endTime: '' },
        { label: 'Thurs', value: 'Thursday', checked: false, startTime: '', endTime: '' },
        { label: 'Fri', value: 'Friday', checked: false, startTime: '', endTime: '' },
        { label: 'Sat', value: 'Saturday', checked: false, startTime: '', endTime: '' }
    ];

    // Form data for the add session modal
    @track sessionData = {
        activityType: '',
        subject: '',
        faculty: '',
        facility: '',
        isRecurrent: false,
        startDate: '',
        endDate: '',
        startTime: '',
        endTime: '',
        skipHolidays: false,
        selectedDays: [],
        accountId: '', // Academic program ID
        termId: '',    // Term ID
        sectionId: ''  // Section ID for Course Offering
    };

    weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    connectedCallback() {
        this.generateCalendarData();
        this.fetchRelatedData();
    }

    // Computed property to get only the selected days for display
    get selectedDaysForDisplay() {
        return this.dayCheckboxes.filter(day => day.checked);
    }
    
    // Getters for each day's checked state
    get isSunChecked() {
        return this.dayCheckboxes.find(day => day.value === 'Sunday')?.checked || false;
    }
    
    get isMonChecked() {
        return this.dayCheckboxes.find(day => day.value === 'Monday')?.checked || false;
    }
    
    get isTueChecked() {
        return this.dayCheckboxes.find(day => day.value === 'Tuesday')?.checked || false;
    }
    
    get isWedChecked() {
        return this.dayCheckboxes.find(day => day.value === 'Wednesday')?.checked || false;
    }
    
    get isThursChecked() {
        return this.dayCheckboxes.find(day => day.value === 'Thursday')?.checked || false;
    }
    
    get isFriChecked() {
        return this.dayCheckboxes.find(day => day.value === 'Friday')?.checked || false;
    }
    
    get isSatChecked() {
        return this.dayCheckboxes.find(day => day.value === 'Saturday')?.checked || false;
    }
    

// Getters for each day's time values
get sundayStartTime() {
    return this.dayCheckboxes.find(day => day.value === 'Sunday')?.startTime || '';
}

get sundayEndTime() {
    return this.dayCheckboxes.find(day => day.value === 'Sunday')?.endTime || '';
}

get mondayStartTime() {
    return this.dayCheckboxes.find(day => day.value === 'Monday')?.startTime || '';
}

get mondayEndTime() {
    return this.dayCheckboxes.find(day => day.value === 'Monday')?.endTime || '';
}

get tuesdayStartTime() {
    return this.dayCheckboxes.find(day => day.value === 'Tuesday')?.startTime || '';
}

get tuesdayEndTime() {
    return this.dayCheckboxes.find(day => day.value === 'Tuesday')?.endTime || '';
}

get wednesdayStartTime() {
    return this.dayCheckboxes.find(day => day.value === 'Wednesday')?.startTime || '';
}

get wednesdayEndTime() {
    return this.dayCheckboxes.find(day => day.value === 'Wednesday')?.endTime || '';
}

get thursdayStartTime() {
    return this.dayCheckboxes.find(day => day.value === 'Thursday')?.startTime || '';
}

get thursdayEndTime() {
    return this.dayCheckboxes.find(day => day.value === 'Thursday')?.endTime || '';
}

get fridayStartTime() {
    return this.dayCheckboxes.find(day => day.value === 'Friday')?.startTime || '';
}

get fridayEndTime() {
    return this.dayCheckboxes.find(day => day.value === 'Friday')?.endTime || '';
}

get saturdayStartTime() {
    return this.dayCheckboxes.find(day => day.value === 'Saturday')?.startTime || '';
}

get saturdayEndTime() {
    return this.dayCheckboxes.find(day => day.value === 'Saturday')?.endTime || '';
}

    // Method to update day checkboxes based on working days from program plan
    updateDayCheckboxes(workingDays) {
        // Reset all checkboxes
        this.dayCheckboxes = this.dayCheckboxes.map(day => {
            return { ...day, checked: false };
        });

        // Set checked property for working days
        if (workingDays && workingDays.length > 0) {
            this.dayCheckboxes = this.dayCheckboxes.map(day => {
                return {
                    ...day,
                    checked: workingDays.includes(day.value)
                };
            });
        }
    }

    handleRecurrentToggle(event) {
        this.isRecurring = event.target.checked;
        this.sessionData.isRecurrent = event.target.checked;

        if (this.isRecurring && this.selectedPlanId) {
            this.loadWorkingDaysFromProgramPlan();
        }
    }

    loadWorkingDaysFromProgramPlan() {
        this.isLoading = true;
        
        getWorkingDays({ programPlanId: this.selectedPlanId })
            .then(result => {
                const daysArray = result ? result.split(';') : [];
                this.updateDayCheckboxes(daysArray);
                this.workingDaysLabel = daysArray.join(' | ');
                
                // Update session data with selected days
                this.sessionData.selectedDays = this.dayCheckboxes
                    .filter(day => day.checked)
                    .map(day => ({
                        day: day.value,
                        startTime: '',
                        endTime: ''
                    }));
            })
            .catch(error => {
                console.error('Failed to load working days:', error);
                this.showToast('Error', 'Failed to load working days: ' + (error.body ? error.body.message : error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

   // Handler for day checkbox toggle
handleDayToggle(event) {
    const day = event.target.dataset.day;
    const isChecked = event.target.checked;
    
    // Update dayCheckboxes
    this.dayCheckboxes = this.dayCheckboxes.map(d => {
        if (d.value === day) {
            return { ...d, checked: isChecked };
        }
        return d;
    });
    
    // Update session data
    if (isChecked) {
        // Add day to selected days if not already there
        if (!this.sessionData.selectedDays.some(d => d.day === day)) {
            this.sessionData.selectedDays.push({
                day: day,
                startTime: '',
                endTime: ''
            });
        }
    } else {
        // Remove day from selected days
        this.sessionData.selectedDays = this.sessionData.selectedDays.filter(d => d.day !== day);
    }
}
    
    
// Handler for day time change
handleDayTimeChange(event) {
    const day = event.target.dataset.day;
    const type = event.target.dataset.type; // 'start' or 'end'
    const value = event.target.value;
    
    // Update dayCheckboxes for UI display
    this.dayCheckboxes = this.dayCheckboxes.map(d => {
        if (d.value === day) {
            return {
                ...d,
                startTime: type === 'start' ? value : d.startTime,
                endTime: type === 'end' ? value : d.endTime
            };
        }
        return d;
    });
    
    // Update session data
    this.sessionData.selectedDays = this.sessionData.selectedDays.map(d => {
        if (d.day === day) {
            return {
                ...d,
                startTime: type === 'start' ? value : d.startTime,
                endTime: type === 'end' ? value : d.endTime
            };
        }
        return d;
    });
}
    // Watch for changes to subjectOptionsFromParent
    renderedCallback() {
        // If subjectOptionsFromParent has values and our local subjectOptions is empty
        // then update our local options
        if (this.subjectOptionsFromParent && 
            this.subjectOptionsFromParent.length > 0 && 
            this.subjectOptions.length === 0) {
            this.subjectOptions = [...this.subjectOptionsFromParent];
        }
    }

    // Fetch activity types, facilities, faculty members, and subjects
    fetchRelatedData() {
        this.isLoading = true;

        // Get activity types from Session__c object
        getActivityTypes()
            .then(result => {
                this.activityTypeOptions = result;
                // Set default value if available
                if (this.activityTypeOptions.length > 0) {
                    this.sessionData.activityType = this.activityTypeOptions[0].value;
                }
            })
            .catch(error => {
                console.error('Error fetching activity types', error);
                this.showToast('Error', 'Failed to load activity types: ' + (error.body ? error.body.message : error.message), 'error');
            });

        // Get facilities from hed__Facility__c object
        getFacilities()
            .then(result => {
                this.facilityOptions = result;
            })
            .catch(error => {
                console.error('Error fetching facilities', error);
                this.showToast('Error', 'Failed to load facilities: ' + (error.body ? error.body.message : error.message), 'error');
            });

        // Get faculty members (Contact with RecordType=Faculty)
        getFacultyMembers()
            .then(result => {
                this.facultyOptions = result;
            })
            .catch(error => {
                console.error('Error fetching faculty members', error);
                this.showToast('Error', 'Failed to load faculty members: ' + (error.body ? error.body.message : error.message), 'error');
            });

        // Check if we have sidebar subjects first
        if (this.sidebarSubjects && this.sidebarSubjects.length > 0) {
            // Use sidebar subjects
            this.subjectOptions = this.sidebarSubjects.map(subject => {
                return {
                    label: subject.name + ' ' + (subject.code || ''),
                    value: subject.id
                };
            });
            this.isLoading = false;
        }
        // Otherwise check if subjects are provided by parent component
        else if (this.subjectOptionsFromParent && this.subjectOptionsFromParent.length > 0) {
            // Use subjects from parent
            this.subjectOptions = [...this.subjectOptionsFromParent];
            this.isLoading = false;
        }
        // If no subjects available from either source, fetch from server
        else {
            // Get subjects (First term ID and section ID will be null, populated when available)
            getSubjects({ termId: null, sectionIdsList: null })
                .then(result => {
                    // Convert the SubjectOption format to ComboboxOption
                    this.subjectOptions = result.map(item => {
                        return { label: item.name + ' (' + item.code + ')', value: item.id };
                    });
                })
                .catch(error => {
                    console.error('Error fetching subjects', error);
                    this.showToast('Error', 'Failed to load subjects: ' + (error.body ? error.body.message : error.message), 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    @api
    refreshCalendar() {
        this.generateCalendarData();
    }
    
    /**
     * @api method to update events from parent component
     */
    @api
    updateEvents(newEvents) {
        if (newEvents && Array.isArray(newEvents)) {
            this.events = [...newEvents];
            this.generateCalendarData();
        }
    }
    
    // Public method to update subjects from parent component
    @api
    updateSubjects(subjectsList) {
        if (subjectsList && Array.isArray(subjectsList)) {
            this.sidebarSubjects = [...subjectsList];
            
            // Update subject options
            this.subjectOptions = this.sidebarSubjects.map(subject => {
                // Format subjects to match what's expected in the dropdown
                return {
                    label: `${subject.name || ''} ${subject.code || ''}`.trim(),
                    value: subject.id || ''
                };
            });
        }
    }

    // Set parent component references 
    @api
    updateContextData(academicProgramId, termId, sectionId) {
        this.academicProgramId = academicProgramId;
        this.selectedTermId = termId;
        this.selectedSectionId = sectionId;
    }

    // Get calendar title (Month and Year)
    get calendarTitle() {
        const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];
        const date = new Date(this.currentDate);
        return `${monthNames[date.getMonth()]} ${date.getFullYear()}`;
    }

    // Button class getters for view selection
    get dayButtonClass() {
        return this.selectedView === 'day' ? 'view-button selected' : 'view-button';
    }

    get weekButtonClass() {
        return this.selectedView === 'week' ? 'view-button selected' : 'view-button';
    }

    get monthButtonClass() {
        return this.selectedView === 'month' ? 'view-button selected' : 'view-button';
    }

    generateCalendarData() {
        try {
            if (!this.currentDate) return;
            
            // Create a safe copy of the date to avoid reference issues
            const date = new Date(this.currentDate.getTime());
            const year = date.getFullYear();
            const month = date.getMonth();

        // Get the first day of the month
        const firstDay = new Date(year, month, 1);
        
        // Get the last day of the month
        const lastDay = new Date(year, month + 1, 0);
        
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

                // Format the date as YYYY-MM-DD for comparison with events
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

        this.weeks = weeks;

    } catch (error) {
        console.error('Error generating calendar data:', error);
        // Reset to current month if there's an error
        this.currentDate = new Date();
    }
    }

    // Helper method to format date as YYYY-MM-DD
    formatDate(date) {
        return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
    }

    // Handle navigation
    handlePrevious() {
        try {
            const date = new Date(this.currentDate);
            date.setMonth(date.getMonth() - 1);
            this.currentDate = date;
            this.generateCalendarData();
            
            // Notify parent component
            this.dispatchEvent(new CustomEvent('monthchange', {
                detail: {
                    date: this.currentDate
                }
            }));
        } catch (error) {
            console.error('Error navigating to previous month:', error);
            this.showToast('Error', 'Failed to navigate to previous month', 'error');
        }
    }
    
    handleNext() {
        try {
            const date = new Date(this.currentDate);
            date.setMonth(date.getMonth() + 1);
            this.currentDate = date;
            this.generateCalendarData();
            
            // Notify parent component
            this.dispatchEvent(new CustomEvent('monthchange', {
                detail: {
                    date: this.currentDate
                }
            }));
        } catch (error) {
            console.error('Error navigating to next month:', error);
            this.showToast('Error', 'Failed to navigate to next month', 'error');
        }
    }

    handleToday() {
        this.currentDate = new Date();
        this.generateCalendarData();
        
        // Notify parent component
        this.dispatchEvent(new CustomEvent('monthchange', {
            detail: {
                date: this.currentDate
            }
        }));
    }

    // Handle view changes
    handleDayView() {
        this.selectedView = 'day';
        this.dispatchEvent(new CustomEvent('viewchange', {
            detail: {
                view: 'day'
            }
        }));
    }

    handleWeekView() {
        this.selectedView = 'week';
        this.dispatchEvent(new CustomEvent('viewchange', {
            detail: {
                view: 'week'
            }
        }));
    }

    handleMonthView() {
        this.selectedView = 'month';
        this.dispatchEvent(new CustomEvent('viewchange', {
            detail: {
                view: 'month'
            }
        }));
    }

    // Helper method to get the week number
    getWeekNumber(date) {
        const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
        const pastDaysOfYear = (date - firstDayOfYear) / 86400000;
        return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
    }

    handleDayClick(event) {
        const date = event.currentTarget.dataset.date;
        
        // Only handle clicks on the day cell itself, not on events
        if (event.target.classList.contains('day-cell') || 
            event.target.classList.contains('day-number') || 
            event.target.classList.contains('day-add-text')) {
            
            // Set the selected date for the modal
            this.selectedDate = date;
            
            // Reset validation properties
            this.endDateError = '';
            this.isEndDateValid = true;
            
            // Initialize session data with the selected date
            this.sessionData = {
                activityType: this.activityTypeOptions.length > 0 ? this.activityTypeOptions[0].value : '',
                subject: '',
                faculty: '',
                facility: '',
                isRecurrent: false,
                startDate: date,
                endDate: date, // Set end date to same as start date by default
                startTime: '',
                endTime: '',
                skipHolidays: false,
                selectedDays: [],
                accountId: this.academicProgramId || '', // Academic program ID
                termId: this.selectedTermId || '',       // Term ID
                sectionId: this.selectedSectionId || ''  // Section ID for Course Offering
            };
            
            // Reset recurrent session settings
            this.isRecurring = false;
            this.dayCheckboxes = this.dayCheckboxes.map(day => {
                return { ...day, checked: false, startTime: '', endTime: '' };
            });
            
            // Open the modal
            this.isModalOpen = true;
            
            // Dispatch event to parent component
            this.dispatchEvent(new CustomEvent('dayclick', {
                detail: {
                    date,
                    isAddEvent: true
                }
            }));
        }
    }

    // Add these computed properties for formatting dates and times
// Enhanced date and time formatting methods
// Add these to your component class

// Improved date and time formatters
get formattedStartDate() {
    if (!this.selectedEvent || !this.selectedEvent.sessionData || !this.selectedEvent.sessionData.startDate) {
        return this.selectedEvent?.date || '';
    }
    return this.formatDateForDisplay(this.selectedEvent.sessionData.startDate);
}

get formattedEndDate() {
    if (!this.selectedEvent || !this.selectedEvent.sessionData || !this.selectedEvent.sessionData.endDate) {
        return this.selectedEvent?.date || '';
    }
    return this.formatDateForDisplay(this.selectedEvent.sessionData.endDate);
}

get formattedStartTime() {
    if (!this.selectedEvent || !this.selectedEvent.sessionData || !this.selectedEvent.sessionData.startTime) {
        return this.selectedEvent?.startTime || '';
    }
    return this.formatTimeForDisplay(this.selectedEvent.sessionData.startTime);
}

get formattedEndTime() {
    if (!this.selectedEvent || !this.selectedEvent.sessionData || !this.selectedEvent.sessionData.endTime) {
        return this.selectedEvent?.endTime || '';
    }
    return this.formatTimeForDisplay(this.selectedEvent.sessionData.endTime);
}

formatDateForDisplay(dateString) {
    try {
        if (!dateString) return '';
        
        // Handle different date formats
        let dateParts;
        
        if (dateString.includes('-')) {
            dateParts = dateString.split('-');
        } else if (dateString.includes('/')) {
            dateParts = dateString.split('/');
        } else {
            return dateString; // Return as is if not in expected format
        }
        
        if (dateParts.length !== 3) return dateString;
        
        // Determine date format (yyyy-MM-dd or MM/dd/yyyy)
        let year, month, day;
        
        if (dateParts[0].length === 4) {
            // Format: yyyy-MM-dd
            year = dateParts[0];
            month = dateParts[1];
            day = dateParts[2];
        } else {
            // Format: MM/dd/yyyy
            month = dateParts[0];
            day = dateParts[1];
            year = dateParts[2];
        }
        
        // Format as MM/DD/YYYY
        return `${month.padStart(2, '0')}/${day.padStart(2, '0')}/${year}`;
    } catch (error) {
        console.error('Error formatting date:', error);
        return dateString || '';
    }
}

formatTimeForDisplay(timeString) {
    try {
        if (!timeString) return '';
        
        // Handle both HH:MM format and plain text times (like "12:45 AM")
        if (timeString.includes('AM') || timeString.includes('PM')) {
            // Already in 12-hour format with AM/PM
            return timeString;
        }
        
        const timeParts = timeString.split(':');
        if (timeParts.length !== 2) return timeString;
        
        let hours = parseInt(timeParts[0]);
        const minutes = timeParts[1].padStart(2, '0');
        
        // Convert to 12-hour format with AM/PM
        const period = hours >= 12 ? 'PM' : 'AM';
        hours = hours % 12 || 12; // Convert 0 to 12 for 12 AM
        
        return `${hours}:${minutes} ${period}`;
    } catch (error) {
        console.error('Error formatting time:', error);
        return timeString || '';
    }
}

// Helper methods to extract information from the event title
extractActivityTypeFromTitle(title) {
    if (!title) return 'N/A';
    
    // Try to extract activity type from title
    // Common activity types to check for
    const activityTypes = ['Marketing', 'Legal Aspects', 'Research', 'Lecture', 'Seminar', 
                           'Workshop', 'Lab', 'Tutorial', 'Business', 'Economics'];
    
    for (const type of activityTypes) {
        if (title.includes(type)) {
            return type;
        }
    }
    
    // If no specific activity type found, use the first part after time (if any)
    const parts = title.split(' ');
    if (parts.length >= 2) {
        // Remove the time part (first part) and return the next part
        return parts[1] || 'Class'; 
    }
    
    return 'Class'; // Default activity type
}


extractSubjectFromTitle(title) {
    if (!title) return 'N/A';
    
    // Try to extract subject from title
    const parts = title.split(' ');
    if (parts.length >= 3) {
        // Remove the time part and what's likely the activity type, join the rest
        parts.shift(); // Remove time
        parts.shift(); // Remove likely activity type
        return parts.join(' '); // Join the rest as the subject
    } else if (parts.length === 2) {
        // If only two parts, assume second is subject
        return parts[1];
    }
    
    return title; // Return the whole title if we can't parse it
}
    
// Add this to your handleEventClick method
// Enhanced event click handler with better data extraction
// Fallback event data handler that works with the existing structure
    /**
 * Enhanced event click handler that directly fetches session details from server
 */
handleEventClick(event) {
    event.stopPropagation();
    const eventId = event.currentTarget.dataset.eventId;
    
    console.log('Event clicked with ID:', eventId);
    
    if (!eventId) {
        console.error('No event ID found');
        this.showToast('Error', 'Event details could not be loaded', 'error');
        return;
    }
    
    // Show loading spinner
    this.isLoading = true;
    
    // Call Apex to get session details
    getSessionDetails({ sessionId: eventId })
        .then(result => {
            console.log('Session details retrieved:', result);
            
            // Parse the returned JSON string
            const sessionData = JSON.parse(result);
            
            // Store the session data for displaying in the modal
            this.selectedEvent = {
                id: eventId,
                sessionData: sessionData
            };
            
            // Open the session detail modal
            this.isSessionDetailModalOpen = true;
        })
        .catch(error => {
            console.error('Error retrieving session details:', error);
            this.showToast('Error', 'Failed to load session details: ' + (error.body ? error.body.message : error.message), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    
    // Dispatch event to parent component
    this.dispatchEvent(new CustomEvent('eventclick', {
        detail: {
            eventId,
            isExistingSession: true
        }
    }));
}

// Helper method to create basic session data from event properties
createBasicSessionData(event) {
    // Extract as much information as possible from the event
    const title = event.title || '';
    
    // Get the activity type (might be embedded in the title)
    let activityType = '';
    let activityTypeLabel = '';
    
    // Parse title to extract activity type
    const activityTypes = ['Marketing', 'Legal Aspects', 'Research', 'Lecture', 'Seminar', 'Lab'];
    for (const type of activityTypes) {
        if (title.includes(type)) {
            activityType = type;
            activityTypeLabel = type;
            break;
        }
    }
    
    // Extract subject (often the second part of the title after the time)
    let subjectLabel = '';
    const timeParts = title.split(' ');
    if (timeParts.length > 1) {
        // Remove the time part and potentially the activity type
        timeParts.shift(); // Remove time
        if (activityType && timeParts[0].includes(activityType)) {
            timeParts.shift(); // Remove activity type if it's the next part
        }
        subjectLabel = timeParts.join(' ');
    }
    
    // Create a basic session data object
    return {
        id: event.id,
        activityType: activityType,
        activityTypeLabel: activityTypeLabel || this.getActivityTypeFromTitle(title),
        subject: event.subject || '',
        subjectLabel: subjectLabel || 'Unknown Subject',
        faculty: event.facultyId || '',
        facultyLabel: event.facultyName || 'N/A',
        facility: event.facilityId || '',
        facilityLabel: event.facilityName || 'N/A',
        startDate: event.date || '',
        endDate: event.date || '',
        startTime: event.startTime || '',
        endTime: event.endTime || ''
    };
}

// Helper to extract activity type from title
getActivityTypeFromTitle(title) {
    // Common activity types in educational settings
    const activityTypes = [
        'Marketing', 'Legal Aspects', 'Research', 'Lecture', 'Seminar', 
        'Workshop', 'Lab', 'Tutorial', 'Business', 'Economics'
    ];
    
    for (const type of activityTypes) {
        if (title.includes(type)) {
            return type;
        }
    }
    
    return 'Class'; // Default if no specific type is found
}


    // Handle modal close event
    handleModalClose() {
        this.isModalOpen = false;
    }

    // Handle input change events for the session form
    handleActivityTypeChange(event) {
        this.sessionData.activityType = event.target.value;
    }

    handleSubjectChange(event) {
        this.sessionData.subject = event.target.value;
    }

    handleFacultyChange(event) {
        this.sessionData.faculty = event.target.value;
    }

    handleFacilityChange(event) {
        this.sessionData.facility = event.target.value;
    }

    handleStartDateChange(event) {
        this.sessionData.startDate = event.target.value;
        console.log('Start date changed to:', this.sessionData.startDate);
        
        // If end date is already set, validate it again
        if (this.sessionData.endDate) {
            this.validateEndDate(this.sessionData.startDate, this.sessionData.endDate);
        }
        
        // Fetch holidays when date changes and skip holidays is checked
        if (this.sessionData.skipHolidays) {
            this.fetchHolidays();
        }
    }

    validateEndDate(startDate, endDate) {
        console.log('Validating dates:', startDate, endDate);
        
        if (!startDate || !endDate) {
            // If either date is not set, don't show an error
            this.endDateError = '';
            this.isEndDateValid = true;
            return true;
        }
        
        // Convert string dates to Date objects for comparison
        // Handle both YYYY-MM-DD and MM/DD/YYYY formats
        let start, end;
        
        try {
            // Parse the start date
            if (startDate.includes('-')) {
                // YYYY-MM-DD format
                const [year, month, day] = startDate.split('-');
                start = new Date(year, month - 1, day);
            } else if (startDate.includes('/')) {
                // MM/DD/YYYY format
                const [month, day, year] = startDate.split('/');
                start = new Date(year, month - 1, day);
            } else {
                // Try direct parsing
                start = new Date(startDate);
            }
            
            // Parse the end date
            if (endDate.includes('-')) {
                // YYYY-MM-DD format
                const [year, month, day] = endDate.split('-');
                end = new Date(year, month - 1, day);
            } else if (endDate.includes('/')) {
                // MM/DD/YYYY format
                const [month, day, year] = endDate.split('/');
                end = new Date(year, month - 1, day);
            } else {
                // Try direct parsing
                end = new Date(endDate);
            }
            
            // Reset time portion for pure date comparison
            start.setHours(0, 0, 0, 0);
            end.setHours(0, 0, 0, 0);
            
            console.log('Parsed dates for comparison:', start, end);
            
            // Compare dates
            if (end < start) {
                this.endDateError = 'End date cannot be earlier than start date';
                this.isEndDateValid = false;
                console.log('Validation failed: End date earlier than start date');
                return false;
            } else {
                this.endDateError = '';
                this.isEndDateValid = true;
                console.log('Validation passed: End date is valid');
                return true;
            }
        } catch (error) {
            console.error('Error parsing dates:', error);
            // If there's an error in parsing, don't block the form
            this.endDateError = '';
            this.isEndDateValid = true;
            return true;
        }
    }

    

    handleEndDateChange(event) {
        this.sessionData.endDate = event.target.value;
        this.validateEndDate(this.sessionData.startDate, this.sessionData.endDate);
        
        // Fetch holidays when date changes and skip holidays is checked
        if (this.sessionData.skipHolidays) {
            this.fetchHolidays();
        }
    }

    handleStartTimeChange(event) {
        this.sessionData.startTime = event.target.value;
    }

    handleEndTimeChange(event) {
        this.sessionData.endTime = event.target.value;
    }

    handleSkipHolidaysChange(event) {
        this.sessionData.skipHolidays = event.target.checked;
    }

   // Enhanced validation for recurring sessions
   // Enhanced form validation method with improved date validation
validateForm() {
    console.log('Validating form...');
    
    // First check the date validation
    if (!this.isEndDateValid) {
        console.log('Form validation failed: End date is invalid');
        return false;
    }
    
    const inputFields = this.template.querySelectorAll('lightning-input, select');
    let isValid = true;

    inputFields.forEach(field => {
        // Check if the field is required and empty
        if (field.required && !field.value) {
            field.reportValidity();
            isValid = false;
            console.log('Form validation failed: Required field is empty', field.name || field.id);
        }
    });

    // Additional validation for recurrent sessions
    if (this.isRecurring) {
        // Ensure at least one day is selected
        const hasDaysSelected = this.dayCheckboxes.some(day => day.checked);
        if (!hasDaysSelected) {
            this.showToast('Error', 'Please select at least one day for recurring sessions', 'error');
            isValid = false;
            console.log('Form validation failed: No days selected for recurring session');
        }

        // Validate times for selected days
        const selectedDays = this.dayCheckboxes.filter(day => day.checked);
        for (const day of selectedDays) {
            if (!day.startTime || !day.endTime) {
                this.showToast('Error', `Please set start and end times for ${day.label}`, 'error');
                isValid = false;
                console.log(`Form validation failed: Missing time for ${day.label}`);
                break;
            }
        }
    }

    console.log('Form validation result:', isValid);
    return isValid;
}

    // Handle save button click
    handleSave() {
        console.log('Save button clicked, checking validation...');
        console.log('Current validation state:', { isEndDateValid: this.isEndDateValid, endDateError: this.endDateError });
        
        // Explicitly run validation one more time to ensure it's up to date
        const isDateValid = this.validateEndDate(this.sessionData.startDate, this.sessionData.endDate);
        
        if (!isDateValid) {
            // Show a toast message about the invalid dates
            this.showToast('Error', this.endDateError, 'error');
            console.log('Save prevented due to date validation error:', this.endDateError);
            return; // Exit early
        }
        
        // Continue with the original validation
        if (this.validateForm()) {
            this.isSaving = true;
            console.log('Form validation passed, saving session...');
            
            // Create a copy of the session data for submission
            const sessionData = { ...this.sessionData };
            
            // Get label values for display purposes
            if (sessionData.activityType) {
                const activityTypeOption = this.activityTypeOptions.find(option => option.value === sessionData.activityType);
                sessionData.activityTypeLabel = activityTypeOption ? activityTypeOption.label : sessionData.activityType;
            }
            
            if (sessionData.subject) {
                const subjectOption = this.subjectOptions.find(option => option.value === sessionData.subject);
                sessionData.subjectLabel = subjectOption ? subjectOption.label : sessionData.subject;
            }
            
            if (sessionData.faculty) {
                const facultyOption = this.facultyOptions.find(option => option.value === sessionData.faculty);
                sessionData.facultyLabel = facultyOption ? facultyOption.label : sessionData.faculty;
            }
            
            if (sessionData.facility) {
                const facilityOption = this.facilityOptions.find(option => option.value === sessionData.facility);
                sessionData.facilityLabel = facilityOption ? facilityOption.label : sessionData.facility;
            }
            
            console.log('Sending session data to server:', JSON.stringify(sessionData));
            
            // Convert session data to JSON string for the Apex method
            const sessionDataJSON = JSON.stringify(sessionData);
            
            createSession({ sessionData: sessionDataJSON })
                .then(result => {
                    console.log('Session created with ID:', result);
                    
                    // Set the returned ID to the session data
                    sessionData.id = result;
                    
                    // Close the modal
                    this.isModalOpen = false;
                    
                    // Show success message
                    this.showToast('Success', 'Session saved successfully', 'success');
                    
                    // Dispatch event to parent component with the new session data
                    this.dispatchEvent(new CustomEvent('sessionsave', {
                        detail: {
                            sessionData,
                            date: this.selectedDate,
                            success: true,
                            id: result
                        }
                    }));
                    
                    // Add the session as an event in the calendar (for immediate display)
                    this.addSessionToCalendar(sessionData);
                    
                    // Force refresh from server in parent component
                    this.dispatchEvent(new CustomEvent('refreshfromserver'));
                })
                .catch(error => {
                    // Log the error
                    console.error('Error saving session:', error);
                    
                    // Check if the error is related to a holiday
                    const errorMsg = error.body ? error.body.message : error.message;
                    if (errorMsg.includes('holiday')) {
                        // Special handling for holiday-related errors
                        this.showToast('Holiday Conflict', errorMsg, 'warning');
                    } else {
                        // Generic error message
                        this.showToast('Error', 'Failed to save session: ' + errorMsg, 'error');
                    }
                    
                    // Dispatch event to parent component with error information
                    this.dispatchEvent(new CustomEvent('sessionsave', {
                        detail: {
                            error: errorMsg,
                            success: false
                        }
                    }));
                })
                .finally(() => {
                    this.isSaving = false;
                });
        } else {
            console.log('Form validation failed');
        }
    }
    
    
    // Add this method to show toast messages
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }

    // Add the new session to the calendar events
    // Add the new session to the calendar events
addSessionToCalendar(sessionData) {
    // Format the start time
    const startTime = sessionData.startTime || '';
    
    // Get course name from the session data
    const courseName = sessionData.subjectLabel || '';
    
    // Create event object for the calendar
    const newEvent = {
        id: sessionData.id || ('session-' + new Date().getTime()),
        title: startTime + ' ' + courseName, // Include start time in the title
        date: sessionData.startDate,
        startTime: sessionData.startTime,
        endTime: sessionData.endTime,
        status: 'default',
        sessionData: sessionData
    };
    
    // Add to existing events
    this.events = [...this.events, newEvent];
    
    // Refresh calendar to show the new event
    this.generateCalendarData();
}

    // Handle cancel button click
    handleCancel() {
        this.isModalOpen = false;
    }

    // Methods for session detail modal
handleSessionDetailModalClose() {
    this.isSessionDetailModalOpen = false;
    this.selectedEvent = null;
}

handleEditSession() {
    // Close the detail modal
    this.isSessionDetailModalOpen = false;
    
    // Set up the edit form with the selected event data
    this.setupEditForm();
    
    // Open the edit modal
    this.isSessionEditModalOpen = true;
}
setupEditForm() {
    console.log('Setting up edit form...');
    
    // Check if we have valid session data
    if (!this.selectedEvent || !this.selectedEvent.sessionData) {
        this.showToast('Error', 'Session data not available for editing', 'error');
        console.log('Edit form setup failed: No session data available');
        return;
    }
    
    // Reset validation properties
    this.editEndDateError = '';
    this.isEditEndDateValid = true;
    
    // Create a deep copy of the session data for editing
    this.editSessionData = JSON.parse(JSON.stringify(this.selectedEvent.sessionData));
    
    console.log('Setting up edit form with data:', JSON.stringify(this.editSessionData));
    
    // Set default values for any missing fields
    if (!this.editSessionData.startTime) this.editSessionData.startTime = '';
    if (!this.editSessionData.endTime) this.editSessionData.endTime = '';
    
    // Ensure both start and end dates are set
    if (!this.editSessionData.startDate) {
        this.editSessionData.startDate = this.selectedEvent.date || '';
    }
    
    if (!this.editSessionData.endDate) {
        this.editSessionData.endDate = this.selectedEvent.date || this.editSessionData.startDate;
    }
    
    // Explicitly validate the dates
    console.log('Validating initial edit dates:', this.editSessionData.startDate, this.editSessionData.endDate);
    this.validateEditEndDate(this.editSessionData.startDate, this.editSessionData.endDate);
    
    // Pre-select the options in the dropdowns
    this.updateDropdownSelections();
}


updateDropdownSelections() {
    // Helper function to set selected attribute on matching option
    const markSelectedOption = (options, value) => {
        if (!options || !value) return options;
        
        return options.map(option => {
            return {
                ...option,
                selected: option.value === value
            };
        });
    };
    
    // Mark the selected activity type
    this.activityTypeOptions = markSelectedOption(
        this.activityTypeOptions, 
        this.editSessionData.activityType
    );
    
    // Mark the selected subject
    this.subjectOptions = markSelectedOption(
        this.subjectOptions, 
        this.editSessionData.subject
    );
    
    // Mark the selected faculty
    this.facultyOptions = markSelectedOption(
        this.facultyOptions, 
        this.editSessionData.faculty
    );
    
    // Mark the selected facility
    this.facilityOptions = markSelectedOption(
        this.facilityOptions, 
        this.editSessionData.facility
    );
    
    console.log('Dropdown selections updated');
}

handleDeleteSession() {
    // Show confirmation dialog
    if (confirm('Are you sure you want to delete this session?')) {
        this.deleteSession();
    }
}

deleteSession() {
    if (!this.selectedEvent || !this.selectedEvent.id) {
        this.showToast('Error', 'No session selected for deletion', 'error');
        return;
    }
    
    this.isLoading = true;
    
    // Call Apex to delete the session
    deleteSession({ sessionId: this.selectedEvent.id })
        .then(() => {
            // Close the modal
            this.isSessionDetailModalOpen = false;
            
            // Remove the event from the events array
            this.events = this.events.filter(evt => evt.id !== this.selectedEvent.id);
            
            // Refresh the calendar
            this.generateCalendarData();
            
            // Show success message
            this.showToast('Success', 'Session deleted successfully', 'success');
            
            // Force refresh from server in parent component
            this.dispatchEvent(new CustomEvent('refreshfromserver'));
        })
        .catch(error => {
            console.error('Error deleting session:', error);
            this.showToast('Error', 'Failed to delete session: ' + (error.body ? error.body.message : error.message), 'error');
        })
        .finally(() => {
            this.isLoading = false;
            this.selectedEvent = null;
        });
}

// Methods for session edit modal
handleSessionEditModalClose() {
    this.isSessionEditModalOpen = false;
    this.editSessionData = {};
}

handleEditCancel() {
    this.isSessionEditModalOpen = false;
    this.editSessionData = {};
}

// Edit form change handlers
handleEditActivityTypeChange(event) {
    this.editSessionData.activityType = event.target.value;
    
    // Update the label for display
    const option = this.activityTypeOptions.find(opt => opt.value === event.target.value);
    if (option) {
        this.editSessionData.activityTypeLabel = option.label;
    }
}

handleEditSubjectChange(event) {
    this.editSessionData.subject = event.target.value;
    
    // Update the label for display
    const option = this.subjectOptions.find(opt => opt.value === event.target.value);
    if (option) {
        this.editSessionData.subjectLabel = option.label;
    }
}

handleEditFacultyChange(event) {
    this.editSessionData.faculty = event.target.value;
    
    // Update the label for display
    const option = this.facultyOptions.find(opt => opt.value === event.target.value);
    if (option) {
        this.editSessionData.facultyLabel = option.label;
    }
}

handleEditFacilityChange(event) {
    this.editSessionData.facility = event.target.value;
    
    // Update the label for display
    const option = this.facilityOptions.find(opt => opt.value === event.target.value);
    if (option) {
        this.editSessionData.facilityLabel = option.label;
    }
}

validateEditEndDate(startDate, endDate) {
    console.log('Validating edit dates:', startDate, endDate);
    
    if (!startDate || !endDate) {
        // If either date is not set, don't show an error
        this.editEndDateError = '';
        this.isEditEndDateValid = true;
        return true;
    }
    
    // Convert string dates to Date objects for comparison
    // Handle both YYYY-MM-DD and MM/DD/YYYY formats
    let start, end;
    
    try {
        // Parse the start date
        if (startDate.includes('-')) {
            // YYYY-MM-DD format
            const [year, month, day] = startDate.split('-');
            start = new Date(year, month - 1, day);
        } else if (startDate.includes('/')) {
            // MM/DD/YYYY format
            const [month, day, year] = startDate.split('/');
            start = new Date(year, month - 1, day);
        } else {
            // Try direct parsing
            start = new Date(startDate);
        }
        
        // Parse the end date
        if (endDate.includes('-')) {
            // YYYY-MM-DD format
            const [year, month, day] = endDate.split('-');
            end = new Date(year, month - 1, day);
        } else if (endDate.includes('/')) {
            // MM/DD/YYYY format
            const [month, day, year] = endDate.split('/');
            end = new Date(year, month - 1, day);
        } else {
            // Try direct parsing
            end = new Date(endDate);
        }
        
        // Reset time portion for pure date comparison
        start.setHours(0, 0, 0, 0);
        end.setHours(0, 0, 0, 0);
        
        console.log('Parsed edit dates for comparison:', start, end);
        
        // Compare dates
        if (end < start) {
            this.editEndDateError = 'End date cannot be earlier than start date';
            this.isEditEndDateValid = false;
            console.log('Edit validation failed: End date earlier than start date');
            return false;
        } else {
            this.editEndDateError = '';
            this.isEditEndDateValid = true;
            console.log('Edit validation passed: End date is valid');
            return true;
        }
    } catch (error) {
        console.error('Error parsing edit dates:', error);
        // If there's an error in parsing, don't block the form
        this.editEndDateError = '';
        this.isEditEndDateValid = true;
        return true;
    }
}


handleEditEndDateChange(event) {
    this.editSessionData.endDate = event.target.value;
    console.log('Edit end date changed to:', this.editSessionData.endDate);
    
    // Immediately validate the dates
    this.validateEditEndDate(this.editSessionData.startDate, this.editSessionData.endDate);
}


handleEditStartDateChange(event) {
    this.editSessionData.startDate = event.target.value;
    console.log('Edit start date changed to:', this.editSessionData.startDate);
    
    // If end date is already set, validate it again
    if (this.editSessionData.endDate) {
        this.validateEditEndDate(this.editSessionData.startDate, this.editSessionData.endDate);
    }
}


handleEditStartTimeChange(event) {
    this.editSessionData.startTime = event.target.value;
}

handleEditEndTimeChange(event) {
    this.editSessionData.endTime = event.target.value;
}

validateEditForm() {
    console.log('Validating edit form...');
    
    // First check the date validation
    if (!this.isEditEndDateValid) {
        console.log('Edit form validation failed: End date is invalid');
        return false;
    }
    
    const inputFields = this.template.querySelectorAll('.edit-session-container lightning-input, .edit-session-container select');
    let isValid = true;

    inputFields.forEach(field => {
        // Check if the field is required and empty
        if (field.required && !field.value) {
            field.reportValidity();
            isValid = false;
            console.log('Edit form validation failed: Required field is empty', field.name || field.id);
        }
    });

    console.log('Edit form validation result:', isValid);
    return isValid;
}


handleUpdateSession() {
    console.log('Update button clicked, checking validation...');
    console.log('Current edit validation state:', { isEditEndDateValid: this.isEditEndDateValid, editEndDateError: this.editEndDateError });
    
    // Explicitly run validation one more time to ensure it's up to date
    const isDateValid = this.validateEditEndDate(this.editSessionData.startDate, this.editSessionData.endDate);
    
    if (!isDateValid) {
        // Show a toast message about the invalid dates
        this.showToast('Error', this.editEndDateError, 'error');
        console.log('Update prevented due to date validation error:', this.editEndDateError);
        return; // Exit early
    }
    
    // Continue with the original validation
    if (this.validateEditForm()) {
        this.isLoading = true;
        console.log('Edit form validation passed, updating session...');
        
        // Create a copy of the edit session data for submission
        const sessionData = { ...this.editSessionData };
        
        console.log('Updating session with data:', JSON.stringify(sessionData));
        
        // Convert session data to JSON string for the Apex method
        const sessionDataJSON = JSON.stringify(sessionData);
        
        // Call Apex to update the session
        updateSession({ sessionData: sessionDataJSON, sessionId: this.selectedEvent.id })
            .then(result => {
                console.log('Session updated successfully with ID:', result);
                
                // Close the modal
                this.isSessionEditModalOpen = false;
                
                // Show success message
                this.showToast('Success', 'Session updated successfully', 'success');
                
                // Force refresh from server in parent component
                this.dispatchEvent(new CustomEvent('refreshfromserver'));
            })
            .catch(error => {
                console.error('Error updating session:', error);
                this.showToast('Error', 'Failed to update session: ' + (error.body ? error.body.message : error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    } else {
        console.log('Edit form validation failed');
    }
}

/**
 * Add this function to ensure the edit form correctly selects the initial values
 */
handleSessionEditModalOpen() {
    console.log('Opening edit session modal...');
    
    // Reset validation properties
    this.editEndDateError = '';
    this.isEditEndDateValid = true;
    
    // Re-fetch session details to ensure we have the most up-to-date data
    if (this.selectedEvent && this.selectedEvent.id) {
        this.isLoading = true;
        console.log('Fetching latest session details for edit with ID:', this.selectedEvent.id);
        
        getSessionDetails({ sessionId: this.selectedEvent.id })
            .then(result => {
                console.log('Successfully retrieved session details for edit');
                const sessionData = JSON.parse(result);
                
                this.selectedEvent = {
                    id: this.selectedEvent.id,
                    sessionData: sessionData
                };
                
                // Now set up the edit form with fresh data
                this.setupEditForm();
                this.isSessionEditModalOpen = true;
            })
            .catch(error => {
                console.error('Error retrieving session details for edit:', error);
                this.showToast('Error', 'Failed to prepare edit form: ' + (error.body ? error.body.message : error.message), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    } else {
        console.error('Cannot open edit modal: No selected event or event ID');
    }
}

fetchHolidays() {
    if (this.sessionData.startDate && this.sessionData.endDate && this.sessionData.skipHolidays) {
        this.isCheckingHolidays = true;
        
        getHolidays({ 
            startDateStr: this.sessionData.startDate, 
            endDateStr: this.sessionData.endDate 
        })
            .then(result => {
                this.holidays = result;
                const holidayCount = Object.keys(result).length;
                
                if (holidayCount > 0) {
                    // Create warning message
                    const holidayNames = Object.values(result).join(', ');
                    this.holidayWarningMessage = `Found ${holidayCount} holiday(s) in the selected date range: ${holidayNames}. These days will be skipped for session creation.`;
                } else {
                    this.holidayWarningMessage = '';
                }
            })
            .catch(error => {
                console.error('Error fetching holidays:', error);
                this.showToast('Error', 'Failed to check holidays: ' + (error.body ? error.body.message : error.message), 'error');
                this.holidayWarningMessage = '';
            })
            .finally(() => {
                this.isCheckingHolidays = false;
            });
    } else {
        this.holidayWarningMessage = '';
    }
}

// Update the handleSkipHolidaysChange method
handleSkipHolidaysChange(event) {
    this.sessionData.skipHolidays = event.target.checked;
    
    // Fetch holidays when the checkbox is checked
    if (this.sessionData.skipHolidays) {
        this.fetchHolidays();
    } else {
        this.holidayWarningMessage = '';
    }
}

// Update the handleStartDateChange method
handleStartDateChange(event) {
    this.sessionData.startDate = event.target.value;
    
    // Fetch holidays when date changes and skip holidays is checked
    if (this.sessionData.skipHolidays) {
        this.fetchHolidays();
    }
}

// Update the handleEndDateChange method
handleEndDateChange(event) {
    this.sessionData.endDate = event.target.value;
    console.log('End date changed to:', this.sessionData.endDate);
    
    // Immediately validate the dates
    this.validateEndDate(this.sessionData.startDate, this.sessionData.endDate);
    
    // Fetch holidays when date changes and skip holidays is checked
    if (this.sessionData.skipHolidays) {
        this.fetchHolidays();
    }
}

// Update the handleSave method to handle holiday errors
handleSave() {
    if (this.validateForm()) {
        this.isSaving = true;
        
        // Create a copy of the session data for submission
        const sessionData = { ...this.sessionData };
        
        // Get label values for display purposes
        if (sessionData.activityType) {
            const activityTypeOption = this.activityTypeOptions.find(option => option.value === sessionData.activityType);
            sessionData.activityTypeLabel = activityTypeOption ? activityTypeOption.label : sessionData.activityType;
        }
        
        if (sessionData.subject) {
            const subjectOption = this.subjectOptions.find(option => option.value === sessionData.subject);
            sessionData.subjectLabel = subjectOption ? subjectOption.label : sessionData.subject;
        }
        
        if (sessionData.faculty) {
            const facultyOption = this.facultyOptions.find(option => option.value === sessionData.faculty);
            sessionData.facultyLabel = facultyOption ? facultyOption.label : sessionData.faculty;
        }
        
        if (sessionData.facility) {
            const facilityOption = this.facilityOptions.find(option => option.value === sessionData.facility);
            sessionData.facilityLabel = facilityOption ? facilityOption.label : sessionData.facility;
        }
        
        // Log data being sent to the server
        console.log('Sending session data to server:', JSON.stringify(sessionData));
        
        // Convert session data to JSON string for the Apex method
        const sessionDataJSON = JSON.stringify(sessionData);
        
        createSession({ sessionData: sessionDataJSON })
            .then(result => {
                console.log('Session created with ID:', result);
                
                // Set the returned ID to the session data
                sessionData.id = result;
                
                // Close the modal
                this.isModalOpen = false;
                
                // Show success message
                this.showToast('Success', 'Session saved successfully', 'success');
                
                // Dispatch event to parent component with the new session data
                this.dispatchEvent(new CustomEvent('sessionsave', {
                    detail: {
                        sessionData,
                        date: this.selectedDate,
                        success: true,
                        id: result
                    }
                }));
                
                // Add the session as an event in the calendar (for immediate display)
                this.addSessionToCalendar(sessionData);
                
                // Force refresh from server in parent component
                this.dispatchEvent(new CustomEvent('refreshfromserver'));
            })
            .catch(error => {
                // Log the error
                console.error('Error saving session:', error);
                
                // Check if the error is related to a holiday
                const errorMsg = error.body ? error.body.message : error.message;
                if (errorMsg.includes('holiday')) {
                    // Special handling for holiday-related errors
                    this.showToast('Holiday Conflict', errorMsg, 'warning');
                } else {
                    // Generic error message
                    this.showToast('Error', 'Failed to save session: ' + errorMsg, 'error');
                }
                
                // Dispatch event to parent component with error information
                this.dispatchEvent(new CustomEvent('sessionsave', {
                    detail: {
                        error: errorMsg,
                        success: false
                    }
                }));
            })
            .finally(() => {
                this.isSaving = false;
            });
    }
}

}