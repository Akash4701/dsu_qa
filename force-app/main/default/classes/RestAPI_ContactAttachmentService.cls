@RestResource(urlMapping='/ContactAttachment/*')

global class RestAPI_ContactAttachmentService{
    
    
    @HttpPost
    global static void initPostService( ) {
        
        String response = '';
        RestContext.response.addHeader('Content-Type', 'application/json');
        
        try{
            
            RestRequest req = RestContext.request; 
            Map<String, String> headers = (Map<String, String>)req.headers;
            Map<String, String> params = (Map<String, String>)req.params;  
            
            response = '{ "success": "false", "message":"Invalid request", "error": "Data not available" }';
            
            if(req.requestBody.size() > 0){
                
                String parentid;
                if(req.requestURI.lastIndexOf('/') != -1){
                    parentid = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
                    system.debug('The RecordId'+parentid);
                }
                if (String.isNotBlank(parentId)) {
                List<Attachment> previousAttachments = [SELECT Id FROM Attachment WHERE ParentId = :parentId];
                delete previousAttachments;
            	}
                
                // Create Attachment
                if( String.isNotBlank(parentid) ){
                    
                    List<String> errors = new List<String>();
                    if(params.containskey('filename') && params.get('filename').length() > 80){
                        errors.add('File Name length is Maximum 80 character');
                    }   
                    if( !headers.containskey('Content-Type') || (headers.containskey('Content-Type') && String.isBlank(headers.get('Content-Type'))) ){
                        errors.add('Content Type not found');
                    }
                    if( !params.containskey('filename') || (params.containskey('filename') && String.isBlank(params.get('filename'))) ){
                        errors.add('File Name not found');
                    }
                    
                    if(errors.size() > 0){
                        response = '{ "success": "false" , "message":"Bad request", "errors":'+ JSON.serialize(errors) +' }';
                    }else{ 
                        Attachment att = new Attachment();
                        att.Id=params.get('recordId');
                        att.parentId = parentId;
                        att.contentType = headers.get('Content-Type');
                        att.Name = params.get('filename');
                        att.body = req.requestBody;
                        upsert att;
                        att.body = null;
                        
                        response = '{ "success": "true" , "parentid": "'+ parentId +'", "fileid": "'+att.id+'"  }';
                    }
                    
                }
            }
            RestContext.response.addHeader('Content-Type', 'application/json');        
            RestContext.response.responseBody = Blob.valueOf( response );
            RestContext.response.statusCode=200;
        }catch(Exception e){
            
            response = '{ "success": "false", "message":"Bad request", "errors":"'+e.getMessage()+'"}';
            RestContext.response.addHeader('Content-Type', 'application/json');
            RestContext.response.responseBody = Blob.valueOf( response );    
            RestContext.response.statusCode=401;
        }
        
    }
    
    
    @HttpGet
    global static void getAttachments() {
        
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestRequest req = RestContext.request;
        String fileName=req.params.get('fileName');
        String recordId=req.params.get('recordId');
        String response = '';
        System.debug(recordId);
        System.debug(fileName);
        //System.debug([Select id, ContentDocumentId, ContentDocument.Title,ContentDocument.LatestPublishedVersion.VersionData,ContentDocument.FileType from ContentDocumentLink where LinkedEntityId =:recordId]);
        try{
            String fileNameLike='%'+fileName+'%';
            // String recordId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            if(String.isNotBlank(recordId) && String.isNotBlank(fileName) ){
                List<FileModel> allAtt = new List<FileModel> ();          
                /* for(ContentDocumentLink  at : [Select id, ContentDocumentId, ContentDocument.Title,ContentDocument.LatestPublishedVersion.VersionData,ContentDocument.FileType from ContentDocumentLink where LinkedEntityId =:recordId and ContentDocument.Title=:fileName]){
allAtt.add( new FileModel(String.valueOf(at.Id), at.ContentDocument.Title, at.ContentDocument.FileType,at.ContentDocument.LatestPublishedVersion.VersionData) );
} */
                for(Attachment  at : [SELECT Id, Name,Body,ContentType FROM Attachment where ParentId=:recordId and Name like:fileNameLike ORDER BY CREATEDDATE ASC]){
                    allAtt.add( new FileModel(String.valueOf(at.Id), at.Name, at.ContentType,at.Body) );
                }
                
                response = '{ "success": "true" , "parentid": "'+ recordId +'", "files": '+  JSON.serialize(allAtt) +' }';
            } else {
                response = '{ "success": "false" , "message": "Please check recordId or fileName data not found" }';
            }   
            RestContext.response.addHeader('Content-Type', 'application/json');
            RestContext.response.responseBody = Blob.valueOf( response );
            RestContext.response.statusCode=200;
        }catch(Exception e){         
            RestContext.response.statusCode=401;
            RestContext.response.addHeader('Content-Type', 'application/json');
            RestContext.response.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'"' );
        }
        
    }
    @HttpDelete
    global Static void deleteAttachment(){
        RestRequest req = RestContext.request;
        RestResponse res = Restcontext.response;
        String id=req.params.get('Id');
        List<Attachment> delte=[select id from Attachment where id=:id];
        if(delte.size()>0){
            delete delte;
            res.responseBody = blob.valueOf('{"Status": "200","Message": "Record is deleted Successfully"}');
        }else{
            res.responseBody = blob.valueOf('{"Status": "200","Message": "No record is matched for this Id"}');
        }
    }
    
    // File Model Class
    global class FileModel{
        
        public String fileId; 
        public String fileName; 
        public String fileType;
        public blob body;
        
        public FileModel(String fileId, String fileName, String fileType,blob body){
            this.fileId = fileId;
            this.fileName = fileName;
            this.fileType = fileType;
            this.body = body;
        }
        
    }
    
}