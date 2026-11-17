@RestResource(urlMapping ='/SpecializationsByProgram/*')
    Global class RestApi_SpecializationsByProgram {
        @HttpGet
        // EndPoint :  /services/apexrest/SpecializationsByProgram/?academicProgramId=0011y00000P7qGqAAJ
        global static void doGet(){
          RestResponse res = RestContext.response;
            res.addHeader('Content-Type','application/json');
            try{
                string academicProgramId = RestContext.request.params.get('academicProgramId'); 
                if(!string.isEmpty(academicProgramId)){
                    List<Account> specializationList = [Select id,Name,ParentId from Account where ParentId =:academicProgramId];
                    if(!specializationList.isEmpty()){
                        List<WrapperClass> listOfSpecializations = new List<WrapperClass>(); 
                        for(Account acc : specializationList){
                            if(!acc.Name.contains('Core')){
                                WrapperClass wrapper = new WrapperClass();
                                wrapper.id = acc.id;
                                wrapper.Name = acc.Name;
                                wrapper.programid = acc.ParentId;
                                listOfSpecializations.add(wrapper);
                            }
                        }
                        if(!listOfSpecializations.isEmpty()){
                            res.statusCode = 200;
                            res.responseBody = Blob.valueOf(json.serialize(listOfSpecializations));  
                        }else{
                            res.responseBody = Blob.valueOf('{"success":"false","message" : "no data found"}');    
                        }
                        
                    }else{
                        res.responseBody = Blob.valueOf('{"success":"false","message" : "no data found"}');    
                    }
                }else{
                    res.responseBody = Blob.valueOf('{"success":"false","message" : "Please give Programe Id"}'); 
                } 
            }catch(exception e){
                res.responseBody = Blob.valueOf('{"success":"false","error" : "'+e.getMessage()+' at line number '+e.getLineNumber()+'"}');   
            }
            
        }
        @HttpPost
        /*
        EndPoint : /services/apexrest/SpecializationsByProgram
        PayLoad  :[
      {
        "Name": "Test",
        "programid": "0011y00000P7qGHAAZ"
      },
      {
        "Name": "Test1",
        "programid": "0011y00000P7qGHAAZ"
      }
    ] */
        global static void doPost(){
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            List<WrapperClass> requestedToInsert =( List<WrapperClass>) System.JSON.deserialize( req.requestBody.toString(),  List<WrapperClass>.class);
            system.debug(requestedToInsert);
            if(!requestedToInsert.isEmpty()){
                List<Account> accountsList = new List<Account>();
                for(WrapperClass wrapper : requestedToInsert){
                    Account acc = new Account();
                    if(!string.isEmpty(wrapper.id)){
                        acc.id = wrapper.id;
                    }
                    acc.Name = wrapper.Name;
                    acc.ParentId = wrapper.programid;
                    acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Program Specialization').getRecordTypeId();
                    accountsList.add(acc);
                } 
                if(!accountsList.isEmpty()){
                    try{
                        upsert accountsList;
                        res.statusCode =200;
                        res.responseBody = Blob.valueOf('{"success":"true","message" : "Record Upserted Successfully.."}'); 
                    }catch(exception e){
                        res.responseBody = Blob.valueOf('{"success":"false","error" : "'+e.getMessage()+' at line number '+e.getLineNumber()+'"}'); 
                    }
                }
            }
            
            
        }
        global class WrapperClass{
            global string id;
            global string Name;
            global string programid;
            
        }

}