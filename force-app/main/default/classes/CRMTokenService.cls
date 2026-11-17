public class CRMTokenService {
    public static void callNodeAPIWithJWT() {
        // Step 1: JWT Header and Payload
        String header = '"alg":"RS256","typ":"JWT"';
        String payload = '{"iss":"Salesforce","sub":"integration@yourorg.com","iat":"Welcome"}';

        // Base64 encode
        String encodedHeader = EncodingUtil.urlEncode(EncodingUtil.base64Encode(Blob.valueOf(header)), 'UTF-8');
        String encodedPayload = EncodingUtil.urlEncode(EncodingUtil.base64Encode(Blob.valueOf(payload)), 'UTF-8');

        // Create unsigned JWT
        String jwtToSign = encodedHeader + '.' + encodedPayload;

        // Sign the JWT using Salesforce private key
        Blob cert =Crypto.signWithCertificate('RSA-SHA256', Blob.valueOf(jwtToSign), 'CRMSigningCert');
        String signature = EncodingUtil.urlEncode(EncodingUtil.base64Encode(cert), 'UTF-8');
        String jwt = jwtToSign + '.' + signature;
        /*CRM_Org_Parameters__c certificate = new CRM_Org_Parameters__c(
            Name = 'CRM Cert1',
            Client_ID__c = 'cgshag72',
            Client_Secret__c = 'dui921y89ey',
            Is_Active__c = True,
            Last_Token_Generated_Date__c = System.now(),
        	Token__c = signature.substring(0,255));
        upsert certificate;*/
        CRM_Org_Parameters__c certificate = [SELECT Id FROM CRM_Org_Parameters__c WHERE Name = 'CRM Cert' LIMIT 1];
        certificate.Token__c = signature.substring(0,255);
        certificate.Last_Token_Generated_Date__c = System.now();
        update certificate;
        System.debug(cert);
        System.debug(signature);
        System.debug(jwt);
    }
}