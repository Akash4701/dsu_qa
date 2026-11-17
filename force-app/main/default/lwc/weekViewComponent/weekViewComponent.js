import { LightningElement, api, track } from 'lwc';

export default class WeekViewComponent extends LightningElement {
    @api currentDate = new Date();
    @api events = [];
    @api facultyListRaw = [];
    @api selectedView = 'week';
    
    @track weekDays = [];
    @track timeSlots = [];
    @track facultyList = [];
    @track searchTerm = '';
    
    connectedCallback() {
        this.generateWeekDays();
        this.generateTimeSlots();
        this.processFacultyList();
    }
    
    renderedCallback() {
        this.positionEvents();
    }
    
    // Add this getter for week display
    get weekNumberDisplay() {
        return this.getWeekNumber(this.currentDate);
    }
    
    // Add this getter for date range display
    get weekDateRangeDisplay() {
        if (this.weekDays && this.weekDays.length > 0) {
            return `${this.weekDays[0].date} - ${this.weekDays[6].date}`;
        }
        return '';
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
    
    generateWeekDays() {
        const weekStart = this.getWeekStartDate(this.currentDate);
        const days = [];
        
        for (let i = 0; i < 7; i++) {
            const date = new Date(weekStart);
            date.setDate(weekStart.getDate() + i);
            
            const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
            const dayName = dayNames[date.getDay()];
            const formattedDate = this.formatDate(date);
            
            days.push({
                date: formattedDate,
                dayName: dayName,
                dayIndex: i,
                formattedDate: `${date.getDate()}/${date.getMonth() + 1} (${dayName})`,
                uniqueKey: `day-${formattedDate}`
            });
        }
        
        this.weekDays = days;
    }

    generateTimeSlots() {
        // Generate time slots for a full 24 hours (0 to 23)
        const slots = [];
        
        // Start from 0 (midnight) and go to 23 (11pm)
        for (let hour = 0; hour <= 23; hour++) {
            // Format hour for display (12-hour format with am/pm)
            const hourFormatted = hour % 12 === 0 ? 12 : hour % 12;
            const amPm = hour < 12 ? 'am' : 'pm';
            
            slots.push({
                id: `time-${hour}`,
                hour: hour,
                label: `${hourFormatted} ${amPm}`,
                value: `${hour}:00`
            });
        }
        
        this.timeSlots = slots;
    }
    
    processFacultyList() {
        // Use provided facultyListRaw if available
        if (this.facultyListRaw && this.facultyListRaw.length > 0) {
            this.facultyList = this.facultyListRaw.map((faculty, index) => {
                return {
                    ...faculty,
                    rowClass: index === 0 ? 'faculty-row selected' : 'faculty-row'
                };
            });
        } else {
            // Extract faculty from events if available
            if (this.events && this.events.length > 0) {
                const facultyMap = new Map();
                
                this.events.forEach(event => {
                    if (event.facultyId && !facultyMap.has(event.facultyId)) {
                        facultyMap.set(event.facultyId, {
                            id: event.facultyId,
                            name: event.facultyName || event.facultyId,
                            shortName: event.facultyName ? event.facultyName.split(' ')[0] : event.facultyId
                        });
                    }
                });
                
                const facultyArray = Array.from(facultyMap.values());
                if (facultyArray.length > 0) {
                    this.facultyList = facultyArray.map((faculty, index) => {
                        return {
                            ...faculty,
                            rowClass: index === 0 ? 'faculty-row selected' : 'faculty-row'
                        };
                    });
                } else {
                    this.setDefaultFacultyList();
                }
            } else {
                this.setDefaultFacultyList();
            }
        }
        
        // Process events for each faculty
        this.facultyList = this.facultyList.map(faculty => {
            const facultyEvents = this.filterEventsForFaculty(faculty.id);
            return {
                ...faculty,
                events: facultyEvents
            };
        });
    }
    
    setDefaultFacultyList() {
        // Default to empty list
        this.facultyList = [];
    }
    
    filterEventsForFaculty(facultyId) {
        if (!this.events || this.events.length === 0) {
            return [];
        }
        
        return this.events
            .filter(event => event.facultyId === facultyId)
            .map(event => this.processEventForDisplay(event))
            .filter(event => event !== null);
    }
    
    processEventForDisplay(event) {
        // Safety checks
        if (!event) return null;
        if (!this.weekDays || this.weekDays.length === 0) return null;
        
        // Make sure we have the correct date format
        const eventDate = event.date;
        
        // Find the day in our week days
        const dayIndex = this.weekDays.findIndex(day => day.date === eventDate);
        
        if (dayIndex === -1) {
            // Try to determine if the date is in a compatible format
            const potentialDateFormats = [
                eventDate, // Original format
                this.formatDate(new Date(eventDate)), // Try to convert if it's a Date object or string
                // Add more potential formats if needed
            ];
            
            // Try each format
            let found = false;
            for (const dateFormat of potentialDateFormats) {
                const newDayIndex = this.weekDays.findIndex(day => day.date === dateFormat);
                if (newDayIndex !== -1) {
                    found = true;
                    return this.positionEvent(event, newDayIndex);
                }
            }
            
            if (!found) {
                return null;
            }
        }
        
        return this.positionEvent(event, dayIndex);
    }
    
    positionEvent(event, dayIndex) {
        // Get the start and end times
        let startTime = event.startTime || event.Start_Time_Format__c || '';
        let endTime = event.endTime || event.End_Time_Format__c || '';
        
        // Default times if still not found
        if (!startTime) startTime = '09:00';
        if (!endTime) endTime = '10:00';
        
        // Parse times for positioning
        const startTimeParts = startTime.split(':');
        const endTimeParts = endTime.split(':');
        
        if (startTimeParts.length < 2 || endTimeParts.length < 2) {
            return null;
        }
        
        const startHour = parseInt(startTimeParts[0], 10);
        const startMinute = parseInt(startTimeParts[1], 10);
        const endHour = parseInt(endTimeParts[0], 10);
        const endMinute = parseInt(endTimeParts[1], 10);
        
        // Calculate position (relative to top of grid)
        const startPosition = startHour * 60 + startMinute;
        
        // Calculate duration
        let duration = (endHour * 60 + endMinute) - (startHour * 60 + startMinute);
        if (duration <= 0) {
            duration = 60; // Default 1 hour if calculation is weird
        }
        
        // Ensure minimum height for visibility
        duration = Math.max(duration, 30);
        
        // Calculate left position based on day index (as percentage)
        const dayWidth = 100 / 7; // 7 days in a week
        const leftPosition = dayIndex * dayWidth;
        
        // Status classes
        const statusClass = event.status ? `event-${event.status}` : 'event-default';
        
        // Style with proper positioning
        const style = `left: ${leftPosition}%; top: ${startPosition}px; height: ${duration}px; width: ${dayWidth - 1}%; z-index: 5;`;
        
        return {
            ...event,
            className: `event ${statusClass}`,
            style: style,
            displayTitle: event.title || `${startTime} - ${endTime}`,
            facultyName: event.facultyName,
            dayIndex: dayIndex,
            startPosition: startPosition,
            duration: duration,
            left: leftPosition,
            width: dayWidth - 1
        };
    }
    
    positionEvents() {
        // This method will re-position all events in the DOM after rendering
        if (!this.facultyList || this.facultyList.length === 0) return;
        
        this.facultyList.forEach(faculty => {
            if (!faculty.events || faculty.events.length === 0) return;
            
            faculty.events.forEach(event => {
                // Find the event element and set its style
                const eventElements = this.template.querySelectorAll(`[data-event-id="${event.id}"]`);
                if (eventElements && eventElements.length > 0) {
                    eventElements.forEach(elem => {
                        // Apply the calculated style
                        elem.style.left = `${event.left}%`;
                        elem.style.top = `${event.startPosition}px`;
                        elem.style.height = `${event.duration}px`;
                        elem.style.width = `${event.width}%`;
                        elem.style.zIndex = '5';
                    });
                }
            });
        });
    }
    
    // Navigation handlers
    handlePrevious() {
        const date = new Date(this.currentDate);
        date.setDate(date.getDate() - 7);
        this.currentDate = date;
        this.refreshView();
        
        this.dispatchEvent(new CustomEvent('weekchange', {
            detail: { date: this.currentDate }
        }));
    }
    
    handleNext() {
        const date = new Date(this.currentDate);
        date.setDate(date.getDate() + 7);
        this.currentDate = date;
        this.refreshView();
        
        this.dispatchEvent(new CustomEvent('weekchange', {
            detail: { date: this.currentDate }
        }));
    }
    
    handleToday() {
        this.currentDate = new Date();
        this.refreshView();
        
        this.dispatchEvent(new CustomEvent('weekchange', {
            detail: { date: this.currentDate }
        }));
    }
    
    // View change handlers
    handleDayView() {
        this.selectedView = 'day';
        this.dispatchEvent(new CustomEvent('viewchange', {
            detail: { view: 'day' }
        }));
    }
    
    handleWeekView() {
        this.selectedView = 'week';
        this.dispatchEvent(new CustomEvent('viewchange', {
            detail: { view: 'week' }
        }));
    }
    
    handleMonthView() {
        this.selectedView = 'month';
        this.dispatchEvent(new CustomEvent('viewchange', {
            detail: { view: 'month' }
        }));
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
        
        const filteredList = this.facultyListRaw.filter(faculty => 
            faculty && faculty.name && faculty.name.toLowerCase().includes(this.searchTerm) || 
            faculty && faculty.shortName && faculty.shortName.toLowerCase().includes(this.searchTerm)
        );
        
        this.facultyList = filteredList.map((faculty, index) => {
            return {
                ...faculty,
                rowClass: index === 0 ? 'faculty-row selected' : 'faculty-row',
                events: this.filterEventsForFaculty(faculty.id)
            };
        });

        // Re-position events after filtering
        setTimeout(() => {
            this.positionEvents();
        }, 0);
    }
    
    // Event click handler
    handleEventClick(event) {
        if (!event || !event.currentTarget) return;
        
        const eventId = event.currentTarget.dataset.eventId;
        if (!eventId) return;
        
        this.dispatchEvent(new CustomEvent('eventclick', {
            detail: { eventId }
        }));
    }
    
    // Faculty row click handler
    handleFacultyClick(event) {
        if (!event || !event.currentTarget) return;
        
        const facultyId = event.currentTarget.dataset.id;
        if (!facultyId) return;
        
        // Update selected state
        this.facultyList = this.facultyList.map(faculty => {
            return {
                ...faculty,
                rowClass: faculty.id === facultyId ? 'faculty-row selected' : 'faculty-row'
            };
        });
        
        this.dispatchEvent(new CustomEvent('facultyselect', {
            detail: { facultyId }
        }));
    }
    
    // Refresh view
    refreshView() {
        this.generateWeekDays();
        this.processFacultyList();
        
        // Re-position events after refreshing
        setTimeout(() => {
            this.positionEvents();
        }, 0);
    }
    
    // Helper methods
    getWeekStartDate(date) {
        if (!date) return new Date();
        
        const d = new Date(date);
        const day = d.getDay();
        const diff = d.getDate() - day + (day === 0 ? -6 : 1); // Adjust for Sunday
        return new Date(d.setDate(diff));
    }
    
    formatDate(date) {
        if (!date) return '';
        if (!(date instanceof Date)) {
            try {
                date = new Date(date);
            } catch (e) {
                return '';
            }
        }
        return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
    }
    
    getWeekNumber(date) {
        if (!date) return 0;
        
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
    }
    
    // Public methods
    @api
    refreshData() {
        this.refreshView();
    }

    @api
    setCurrentDate(date) {
        this.currentDate = new Date(date);
        this.refreshView();
    }
    
    @api
    updateEvents(newEvents) {
        this.events = newEvents;
        this.processFacultyList();
        
        // Re-position events after updating
        setTimeout(() => {
            this.positionEvents();
        }, 0);
    }

    @api
    debugEventVisibility() {
        // Debug event visibility
        console.log('Debug event visibility:');
        console.log('Week days:', this.weekDays);
        console.log('Events received:', this.events);
        
        if (this.events && this.events.length > 0) {
            this.events.forEach(event => {
                const dayIndex = this.weekDays.findIndex(day => day.date === event.date);
                console.log(`Event ${event.id || 'unknown'} date=${event.date}, found in day index: ${dayIndex}`);
                
                if (dayIndex === -1) {
                    console.log('Available dates in week:', this.weekDays.map(d => d.date));
                    console.log('Trying to convert date:', this.formatDate(new Date(event.date)));
                }
                
                // Show event details
                console.log('Event details:', {
                    startTime: event.startTime,
                    endTime: event.endTime,
                    faculty: event.facultyName,
                    date: event.date
                });
            });
        }
    }
}