public class TokenHandler {
	public static String getToken() {
        String accessToken;
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(Label.AttendanceModuleToken);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        String requestBody = 'grant_type=client_credentials' + '&client_id=' + Label.AttendanceModuleclientID + '&client_secret=' + Label.AttendanceModuleclientKey+ '&scope=' +Label.AttendanceModuleScope;
        request.setBody(requestBody);
        HttpResponse responseAuthentication = http.send(request);
        if(responseAuthentication != null && responseAuthentication.getStatus() == 'OK' && string.isNotBlank(responseAuthentication.getBody())){
            Map<String, Object> responseRec = (Map<String, Object>) JSON.deserializeUntyped(responseAuthentication.getBody());
            accesstoken = string.valueOf(responseRec.get('access_token'));
        } 
        system.debug('@@@accessToken'+accessToken);
        return accessToken;
    }
      
}