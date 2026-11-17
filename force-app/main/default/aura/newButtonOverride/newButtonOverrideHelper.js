({
    extractRecordIdFromContext: function(inContextOfRef) {
        try {
            console.log("Extracting from inContextOfRef: ", inContextOfRef);
            
            // The inContextOfRef contains a base64 encoded JSON string after the number prefix
            // Format: "1.base64EncodedJson"
            var parts = inContextOfRef.split('.');
            if (parts.length >= 2) {
                var base64String = parts[1];
                
                // Decode base64
                var decodedString = atob(base64String);
                console.log("Decoded context string: ", decodedString);
                
                // Parse the JSON
                var contextObj = JSON.parse(decodedString);
                console.log("Parsed context object: ", JSON.stringify(contextObj));
                
                // Extract recordId from the context
                if (contextObj && contextObj.attributes && contextObj.attributes.recordId) {
                    var recordId = contextObj.attributes.recordId;
                    console.log("Found recordId in context: ", recordId);
                    return recordId;
                }
            }
        } catch (error) {
            console.error("Error extracting recordId from context: ", error);
        }
        
        return null;
    },
    
    // Alternative method using regex to extract record IDs
    extractRecordIdWithRegex: function(inContextOfRef) {
        try {
            // Decode the base64 part
            var parts = inContextOfRef.split('.');
            if (parts.length >= 2) {
                var decodedString = atob(parts[1]);
                
                // Use regex to find Salesforce record ID pattern (15 or 18 characters)
                var recordIdPattern = /[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?/g;
                var matches = decodedString.match(recordIdPattern);
                
                if (matches && matches.length > 0) {
                    // Return the first valid record ID found
                    var recordId = matches[0];
                    console.log("Found recordId using regex: ", recordId);
                    return recordId;
                }
            }
        } catch (error) {
            console.error("Error extracting recordId with regex: ", error);
        }
        
        return null;
    }
})