import { LightningElement, api, track } from 'lwc';

export default class DayViewComponent extends LightningElement {
    @api currentDate = new Date();
    @api events = [];
    @api facultyListRaw = [];
    @api selectedView = 'day';
   
    @track timeSlots = [];
    @track facultyList = [];
    @track searchTerm = '';
    @track selectedFacultyId = null;
    @track weekNumber = '';
   
    connectedCallback() {
        console.log('DayViewComponent connected');
        this.generateTimeSlots();
        this.calculateWeekNumber();
        this.processFacultyList();
    }

    // Calculate the current week number
    calculateWeekNumber() {
        const date = new Date(this.currentDate);
        const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
        const pastDaysOfYear = (date - firstDayOfYear) / 86400000;
        this.weekNumber = `W${Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7)}`;
    }
   
    // Class getters for view buttons
    get dayButtonClass() {
        return this.selectedView === 'day' ? 'view-button selected' : 'view-button';
    }
   
    get weekButtonClass() {
        return this.selectedView === 'week' ? 'view-button selected' : 'view-button';
    }
   
    get monthButtonClass() {
        return this.selectedView === 'month' ? 'view-button selected' : 'view-button';
    }
   
    // Get formatted date for display
    get formattedCurrentDate() {
        if (!this.currentDate) return '';
        const date = new Date(this.currentDate);
        const options = { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }
   
    generateTimeSlots() {
        // Generate time slots for 24 hours
        const slots = [];
        for (let hour = 0; hour < 24; hour++) {
            const hourFormatted = hour % 12 === 0 ? 12 : hour % 12;
            const amPm = hour < 12 ? 'am' : 'pm';
           
            // Short label for horizontal header (e.g., "6am")
            const shortLabel = `${hourFormatted}${amPm}`;
           
            let cellClass = 'time-slot';
            if (hour === 0) {
                cellClass += ' midnight';
            } else if (hour < 6) {
                cellClass += ' night-hours';
            } else if (hour >= 9 && hour <= 17) {
                cellClass += ' business-hours';
            } else if (hour >= 18) {
                cellClass += ' evening-hours';
            }
           
            slots.push({
                id: `time-${hour}`,
                hour: hour,
                label: `${hourFormatted} ${amPm}`,
                shortLabel: shortLabel,
                value: `${hour}:00`,
                cellClass: cellClass
            });
        }
       
        this.timeSlots = slots;
        console.log('Time slots generated:', this.timeSlots.length);
    }
   
    processFacultyList() {
        // Extract unique faculty from events instead of using hardcoded data
        const facultyMap = new Map();
        
        if (this.events && Array.isArray(this.events) && this.events.length > 0) {
            // Collect all unique faculty IDs from events
            this.events.forEach(event => {
                if (event.facultyId) {
                    // If this faculty ID isn't in our map yet, add it
                    if (!facultyMap.has(event.facultyId)) {
                        // Extract faculty details from event if available
                        let displayName = 'Faculty';
                        
                        // Try to get faculty name from the event
                        if (event.facultyName) {
                            displayName = event.facultyName;
                        } else if (event.Faculty__r && event.Faculty__r.Name) {
                            displayName = event.Faculty__r.Name;
                        } else if (event.Contact__r && event.Contact__r.Name) {
                            displayName = event.Contact__r.Name;
                        } else if (event.hed__Faculty__r && event.hed__Faculty__r.Name) {
                            displayName = event.hed__Faculty__r.Name;
                        } else if (event.sessionData && event.sessionData.Faculty__r && event.sessionData.Faculty__r.Name) {
                            displayName = event.sessionData.Faculty__r.Name;
                        }
                        
                        // If we still have just an ID, format it better
                        if (displayName === 'Faculty') {
                            if (event.facultyId.length > 10) {
                                displayName = 'Faculty ' + event.facultyId.substring(0, 6);
                            } else {
                                displayName = 'Faculty ' + event.facultyId;
                            }
                        }
                        
                        // Extract or create a shortName
                        const shortName = displayName.split(' ')[0];
                        
                        facultyMap.set(event.facultyId, {
                            id: event.facultyId,
                            name: event.facultyId,
                            displayName: displayName,
                            shortName: shortName,
                            rowClass: 'faculty-row',
                            events: []
                        });
                    }
                }
            });
        }
        
        // If facultyListRaw is provided, merge with the data from events
        if (this.facultyListRaw && Array.isArray(this.facultyListRaw) && this.facultyListRaw.length > 0) {
            this.facultyListRaw.forEach((faculty, index) => {
                // Extract faculty ID
                const facultyId = faculty.id || `faculty-${index}`;
                
                // Skip if we already have this faculty from events
                if (facultyMap.has(facultyId)) return;
                
                // Extract faculty name from the data
                let displayName = 'Faculty';
                
                // First try to get name from common fields
                if (faculty.name) {
                    displayName = faculty.name;
                } else if (faculty.Name) {
                    displayName = faculty.Name;
                } else if (faculty.Faculty__r && faculty.Faculty__r.Name) {
                    displayName = faculty.Faculty__r.Name;
                } else if (faculty.Contact__r && faculty.Contact__r.Name) {
                    displayName = faculty.Contact__r.Name;
                } else if (faculty.hed__Faculty__r && faculty.hed__Faculty__r.Name) {
                    displayName = faculty.hed__Faculty__r.Name;
                }
                
                // If we still have just an ID, try to make it look better
                if (displayName === 'Faculty' && facultyId) {
                    if (facultyId.length > 10) {
                        displayName = 'Faculty ' + facultyId.substring(0, 6);
                    } else {
                        displayName = 'Faculty ' + facultyId;
                    }
                }
                
                // Extract or create a shortName
                const shortName = faculty.shortName ||
                    (displayName ? displayName.split(' ')[0] : `F${index + 1}`);
                
                facultyMap.set(facultyId, {
                    id: facultyId,
                    name: facultyId,
                    displayName: displayName,
                    shortName: shortName,
                    rowClass: 'faculty-row',
                    events: []
                });
            });
        }
        
        // Convert map to array and set the first faculty as selected if none is selected
        this.facultyList = Array.from(facultyMap.values());
        
        // If no faculty, leave as empty array
        if (this.facultyList.length === 0) {
            console.log('No faculty found in events or facultyListRaw');
            return;
        }
        
        // Set the first faculty as selected if none is selected
        if (!this.selectedFacultyId && this.facultyList.length > 0) {
            this.selectedFacultyId = this.facultyList[0].id;
            this.facultyList[0].rowClass = 'faculty-row selected';
        }
        
        // Process events for each faculty
        this.facultyList = this.facultyList.map(faculty => {
            // Filter events for this faculty
            const facultyEvents = this.filterEventsForFaculty(faculty.id);
            
            return {
                ...faculty,
                events: facultyEvents
            };
        });
        
        console.log('Faculty list processed:', this.facultyList.length);
    }
   
    filterEventsForFaculty(facultyId) {
        // If no events are provided, return empty array
        if (!this.events || !Array.isArray(this.events) || this.events.length === 0) {
            return [];
        }
       
        // Get the formatted date for the current day
        const currentFormattedDate = this.formatDate(new Date(this.currentDate));
       
        // Filter real events for this faculty for the current day
        const filteredEvents = this.events
            .filter(event => {
                return event.facultyId === facultyId &&
                       (!event.date || event.date === currentFormattedDate);
            })
            .map(event => this.processEventForDisplay(event))
            .filter(event => event !== null);
       
        return filteredEvents;
    }
   
    processEventForDisplay(event) {
        // Safety check
        if (!event) return null;
       
        console.log('Processing event:', JSON.stringify(event));
       
        // DIRECT APPROACH: Extract the start hour and minute from the title first
        let startHour = null;
        let startMinute = null;
       
        // Look for a time pattern at the start of the title (e.g., "08:00 Class Name")
        if (event.title && event.title.match(/^\d{1,2}:\d{2}/)) {
            const timeParts = event.title.split(' ')[0].split(':');
            if (timeParts.length >= 2) {
                startHour = parseInt(timeParts[0], 10);
                startMinute = parseInt(timeParts[1], 10);
                console.log(`Time extracted from title: ${startHour}:${startMinute}`);
            }
        }
       
        // If not found in title, try Start_Time_Format__c
        if (startHour === null && event.Start_Time_Format__c) {
            const timeParts = event.Start_Time_Format__c.split(':');
            if (timeParts.length >= 2) {
                startHour = parseInt(timeParts[0], 10);
                startMinute = parseInt(timeParts[1], 10);
                console.log(`Time from Start_Time_Format__c: ${startHour}:${startMinute}`);
            }
        }
       
        // If still not found, try startTime
        if (startHour === null && event.startTime) {
            const timeParts = event.startTime.split(':');
            if (timeParts.length >= 2) {
                startHour = parseInt(timeParts[0], 10);
                startMinute = parseInt(timeParts[1], 10);
                console.log(`Time from startTime: ${startHour}:${startMinute}`);
            }
        }
       
        // If still not found and sessionData exists, try there
        if (startHour === null && event.sessionData) {
            if (event.sessionData.Start_Time_Format__c) {
                const timeParts = event.sessionData.Start_Time_Format__c.split(':');
                if (timeParts.length >= 2) {
                    startHour = parseInt(timeParts[0], 10);
                    startMinute = parseInt(timeParts[1], 10);
                    console.log(`Time from sessionData.Start_Time_Format__c: ${startHour}:${startMinute}`);
                }
            } else if (event.sessionData.Start_Date_Time__c) {
                // Try to extract time from Start_Date_Time__c
                const dateTime = new Date(event.sessionData.Start_Date_Time__c);
                startHour = dateTime.getHours();
                startMinute = dateTime.getMinutes();
                console.log(`Time from sessionData.Start_Date_Time__c: ${startHour}:${startMinute}`);
            }
        }
       
        // If we still don't have a valid time, default to 9:00 AM
        if (startHour === null || isNaN(startHour)) {
            startHour = 9;
            startMinute = 0;
            console.log('Using default time: 9:00 AM');
        }
       
        // Determine end time (default: 1 hour after start)
        let endHour = startHour + 1;
        let endMinute = startMinute;
       
        // Try to find a proper end time
        if (event.End_Time_Format__c) {
            const timeParts = event.End_Time_Format__c.split(':');
            if (timeParts.length >= 2) {
                endHour = parseInt(timeParts[0], 10);
                endMinute = parseInt(timeParts[1], 10);
            }
        } else if (event.endTime) {
            const timeParts = event.endTime.split(':');
            if (timeParts.length >= 2) {
                endHour = parseInt(timeParts[0], 10);
                endMinute = parseInt(timeParts[1], 10);
            }
        } else if (event.sessionData && event.sessionData.End_Time_Format__c) {
            const timeParts = event.sessionData.End_Time_Format__c.split(':');
            if (timeParts.length >= 2) {
                endHour = parseInt(timeParts[0], 10);
                endMinute = parseInt(timeParts[1], 10);
            }
        }
       
        // Make sure we have valid numbers
        startHour = parseInt(startHour, 10);
        startMinute = parseInt(startMinute, 10);
        endHour = parseInt(endHour, 10);
        endMinute = parseInt(endMinute, 10);
       
        // CRITICAL CALCULATION: Position events using absolute positioning
        // Each hour slot width is 60px in the grid
       
        // Calculate horizontal positioning
        // Get the left position based on cell width (60px per hour)
        const leftPosition = startHour * 60 + startMinute;
       
        // Calculate duration
        let duration = 0;
        if (endHour < startHour) {
            // Event spans midnight
            duration = ((24 - startHour) + endHour) * 60 + (endMinute - startMinute);
        } else {
            duration = (endHour - startHour) * 60 + (endMinute - startMinute);
        }
       
        // Minimum duration for visibility
        if (duration < 30) duration = 30;
       
        console.log(`Event positioning: startHour=${startHour}, leftPosition=${leftPosition}px, width=${duration}px`);
       
        // Create a readable time format for the title
        const timeText = `${startHour.toString().padStart(2, '0')}:${startMinute.toString().padStart(2, '0')}`;
       
        // If the title doesn't start with the time, add it
        let displayTitle = event.title || 'Event';
        if (!displayTitle.startsWith(timeText)) {
            displayTitle = `${timeText} ${displayTitle}`;
        }
       
        return {
            ...event,
            className: `event event-${event.status || 'filled'}`,
            style: `left: ${leftPosition}px; width: ${duration}px;`,
            title: displayTitle,
            showTitle: true,
            // Store hour info for debugging
            startHour: startHour,
            startMinute: startMinute
        };
    }
   
    // Navigation handlers
    handlePrevious() {
        const date = new Date(this.currentDate);
        date.setDate(date.getDate() - 1);
        this.currentDate = date;
        this.calculateWeekNumber();
        this.processFacultyList();
       
        this.dispatchEvent(new CustomEvent('daychange', {
            detail: { date: this.currentDate }
        }));
    }
   
    handleNext() {
        const date = new Date(this.currentDate);
        date.setDate(date.getDate() + 1);
        this.currentDate = date;
        this.calculateWeekNumber();
        this.processFacultyList();
       
        this.dispatchEvent(new CustomEvent('daychange', {
            detail: { date: this.currentDate }
        }));
    }
   
    handleToday() {
        this.currentDate = new Date();
        this.calculateWeekNumber();
        this.processFacultyList();
       
        this.dispatchEvent(new CustomEvent('daychange', {
            detail: { date: this.currentDate }
        }));
    }
   
    // View change handlers
    handleDayView() {
        if (this.selectedView !== 'day') {
            this.selectedView = 'day';
            this.dispatchEvent(new CustomEvent('viewchange', {
                detail: { view: 'day' }
            }));
        }
    }
   
    handleWeekView() {
        if (this.selectedView !== 'week') {
            this.selectedView = 'week';
            this.dispatchEvent(new CustomEvent('viewchange', {
                detail: { view: 'week' }
            }));
        }
    }
   
    handleMonthView() {
        if (this.selectedView !== 'month') {
            this.selectedView = 'month';
            this.dispatchEvent(new CustomEvent('viewchange', {
                detail: { view: 'month' }
            }));
        }
    }
   
    // Faculty selection handler
    handleFacultySelect(event) {
        const facultyId = event.currentTarget.dataset.id;
        if (!facultyId) return;
       
        this.selectedFacultyId = facultyId;
       
        // Update the selected state in the faculty list
        this.facultyList = this.facultyList.map(faculty => {
            return {
                ...faculty,
                rowClass: faculty.id === facultyId ? 'faculty-row selected' : 'faculty-row'
            };
        });
    }
   
    // Search handler
    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.filterFacultyList();
    }
   
    filterFacultyList() {
        if (!this.searchTerm) {
            this.processFacultyList();
            return;
        }
       
        const filteredList = this.facultyList.filter(faculty =>
            faculty && faculty.name && faculty.name.toLowerCase().includes(this.searchTerm) ||
            faculty && faculty.shortName && faculty.shortName.toLowerCase().includes(this.searchTerm)
        );
       
        // Keep events for the filtered faculty
        this.facultyList = filteredList;
    }
   
    // Event click handler
    handleEventClick(event) {
        const eventId = event.currentTarget.dataset.eventId;
        if (!eventId) return;
       
        this.dispatchEvent(new CustomEvent('eventclick', {
            detail: { eventId }
        }));
    }
   
    // Helper methods
    formatDate(date) {
        if (!date) return '';
        const d = new Date(date);
        return `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`;
    }
}