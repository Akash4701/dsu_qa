@RestResource(UrlMapping='/contactAllDetails/*')
global class RestApi_ContactAllDetails {
	
    @HttpGet
    global static void doGet(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String response = '';
        string jsonResponse;
        String jsonResponses;             
        try{
            String ContactID = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
            system.debug('The requested ContactId'+ContactID);
            Contact[] cc = [Select Id,Name from Contact where Id=:ContactID limit 1];
            List<Contact> contactList = new List<Contact>();
            List<EduHisWrapper> lData = new  List<EduHisWrapper>();
            EduHisWrapper edHistory;
            List<RelationshipWrapper> resData = new  List<RelationshipWrapper>();
            RelationshipWrapper reswapperObj;
            List<AddressWrapper> addData = new  List<AddressWrapper>();
            AddressWrapper addwapperObj;
            List<string> jsonreponse=new List<string>();
            if(string.isNotBlank(ContactID) && !cc.isEmpty()){
                for(Contact con:[Select Id,Name,FirstName,LastName,hed__Gender__c,Birthdate,Phone,Email,hed__Country_of_Origin__c,Nationality__c,Birth_Place__c,Passport_Number__c,National_ID__c,TAX_File_Number__c,Emirates_Id_Number__c,Name_on_invoice__c,Admin_Notes__c from Contact where Id=:ContactID]){
                    contactsWrapper conWrapObj = new contactsWrapper();
                    conWrapObj.firstName = con.FirstName;
                    conWrapObj.lastName = con.LastName;
                    conWrapObj.Gender = con.hed__Gender__c;
                    conWrapObj.BirthDate = String.valueOf(con.Birthdate);
                    conWrapObj.Phone = con.Phone;
                    conWrapObj.Email = con.Email;
                    conWrapObj.Nationality =con.Nationality__c;
                    conWrapObj.BirthPlace = con.Birth_Place__c;
                    conWrapObj.CountryOfResidence = con.hed__Country_of_Origin__c;
                    conWrapObj.PassportNumber = con.Passport_Number__c;
                    conWrapObj.NationalIdNumber = con.National_ID__c;
                    conWrapObj.TaxFileNum = con.TAX_File_Number__c;
                    conWrapObj.EmiratesIdNum = con.Emirates_Id_Number__c;
                    conWrapObj.NameOnInvoice = con.Name_on_invoice__c;
                    conWrapObj.adminNotes = con.Admin_Notes__c;
                    for(hed__Education_History__c eduHis:[select id,Name,HED__EDUCATIONAL_INSTITUTION_NAME__C from hed__Education_History__c where hed__Contact__c=:con.Id]){
                        edHistory = new EduHisWrapper(eduHis);
                        lData.add(edHistory);
                    }
                    for(hed__Relationship__c resObj:[Select Id,Name,hed__Contact__c,hed__Contact__r.Name,hed__RelatedContact__c,hed__RelatedContact__r.Name,hed__Type__c,hed__Status__c,CurrencyIsoCode from hed__Relationship__c where hed__Contact__c=:con.Id]){
                        reswapperObj = new RelationshipWrapper(resObj);
                        resData.add(reswapperObj);
                    }
                    for(hed__Address__c addObj:[Select Id,Name,hed__Address_Type__c,hed__Default_Address__c,hed__Geolocation__c,hed__Formula_MailingAddress__c,hed__MailingCity__c,hed__MailingCountry__c,hed__MailingState__c,hed__MailingStreet__c,hed__Formula_MailingStreetAddress__c,hed__MailingStreet2__c,hed__MailingPostalCode__c,hed__Parent_Account__c,hed__Parent_Contact__c from hed__Address__c where hed__Parent_Contact__c=:con.Id]){
                        addwapperObj = new AddressWrapper(addObj);
                        addData.add(addwapperObj);
                    }
                    conWrapObj.educationHistory = lData;
                    conWrapObj.relationship = resData;
                    conWrapObj.address = addData;
                    jsonreponse.add(JSON.serialize(conWrapObj));
                }
                jsonResponses = String.join(jsonreponse,',');
                jsonResponse = jsonResponses;
                if(jsonResponse!=null){    
                    res.responseBody=Blob.valueOf(jsonResponse);    
                }
                else{     
                    res.responseBody=Blob.valueOf('[]'); 
                }
            }else{
                res.statusCode = 400;
                res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "Invalid Parameters"  }' ); 
            }
        }Catch(Exception e){
            res.statusCode = 400;
            res.responseBody = Blob.valueOf( '{ "success": "false" , "message": "bad request", "errors": "'+e.getMessage()+'at Line Number'+e.getLineNumber()+'" }' );
        }
    }
    global class contactsWrapper{
        public string firstName;
		public string middleName;
        public string lastName;
        public string Gender;
        public string BirthDate;
        public string Phone;
        public string Email;
        public string CountryOfResidence;
		public string Nationality;
		public string BirthPlace;
		public string EmiratesCity;
		public string PassportNumber;
		public string NationalIdNumber;
		public string TaxFileNum;
		public string EmiratesIdNum;
		public string NameOnInvoice;
        public string adminNotes;
        Public List<EduHisWrapper> educationHistory;
        public List<RelationshipWrapper> relationship;
        public List<AddressWrapper> address;
    }
    global class EduHisWrapper
    {        
        global hed__Education_History__c edHis;
        global EduHisWrapper(hed__Education_History__c edHis){           
            this.edHis=edHis;
        }
    }
    global class RelationshipWrapper
    {        
        global hed__Relationship__c res;
        global RelationshipWrapper(hed__Relationship__c res){           
            this.res=res;
        }
    }
    global class AddressWrapper
    {        
        global hed__Address__c add;
        global AddressWrapper(hed__Address__c add){           
            this.add=add;
        }
    }
}