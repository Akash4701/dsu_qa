public class PublicLinks {
    public static void generatePublicLinks(List<ContentVersion> newRecords){
        /* Getting ContentVersion file using ContentDocument Id */
        List<ContentVersion> file = [SELECT Id, Title FROM ContentVersion WHERE Id =: newRecords];
        
        /* Creating ContentDistribution record */
        List<ContentDistribution> conDisList = new List<ContentDistribution>();
        for(ContentVersion fileObj:file){
            ContentDistribution conDisObj = new ContentDistribution();
            conDisObj.Name = fileObj.Title;
            conDisObj.ContentVersionId = fileObj.Id;
            conDisObj.PreferencesAllowViewInBrowser= true;
            conDisList.add(conDisObj);
        }
        if(!conDisList.isEmpty()){
            insert conDisList;
        }
    }
}