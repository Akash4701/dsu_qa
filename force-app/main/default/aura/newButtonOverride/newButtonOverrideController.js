({
    doInit: function(component, event, helper) {
        try {
            var recordId;
            
            // Get pageReference
            var pageRef = component.get("v.pageReference");
            console.log("Page Reference: ", JSON.stringify(pageRef));
            
            if (pageRef && pageRef.state) {
                // Method 1: Standard record ID from state
                recordId = pageRef.state.recordId || pageRef.state.c__recordId;
                
                // Method 2: Extract from inContextOfRef (this is where your record ID is!)
                if (!recordId && pageRef.state.inContextOfRef) {
                    recordId = helper.extractRecordIdFromContext(pageRef.state.inContextOfRef);
                }
            }
            
            // Method 3: Get from component's recordId attribute
            if (!recordId) {
                recordId = component.get("v.recordId");
            }
            
            console.log("Final Record ID: ", recordId);
            
            if (recordId) {
                component.set("v.recordId", recordId);
            } else {
                console.error("No record ID found");
            }
            
        } catch (error) {
            console.error("Error in doInit: ", error);
        }
    }
})