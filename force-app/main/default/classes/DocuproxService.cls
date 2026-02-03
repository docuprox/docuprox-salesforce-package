/**
*********************************************************
Apex Class Name    : DocuproxService
Created Date       : December 29, 2025
@description       : This class handles is the primary service class for Docuprox integration.
@author            : uddhav.sharma@xccelerance.com
Modification Log:
Ver   Date         Author                               Modification
1.0   29-12-2025   Uddhav Sharma                      Initial Version
*********************************************************
*/
global with sharing class DocuproxService {
    /**
    *********************************************************
    @Method Name    : processWithFile
    @author         : Uddhav Sharma
    @description    : Processes a file from ContentDocumentId, converts it to Base64, and sends to API.
    @param          : Id contentDocumentId - The Id of the ContentDocument
    @param          : String templateId - The template identifier for processing
    @return         : void
    *********************************************************
    */
    global static String processWithFile(Id contentDocumentId, String templateId) {
        if (contentDocumentId == null || String.isBlank(templateId)) {
            return null;
        }

        try {
            // Send HTTP request
            return sendToApi(
                templateId,
                EncodingUtil.base64Encode(
                    [
                        SELECT VersionData
                        FROM ContentVersion
                        WHERE ContentDocumentId = :contentDocumentId AND IsLatest = TRUE
                        WITH USER_MODE
                        LIMIT 1
                    ]
                    .VersionData
                )
            );
        } catch (Exception e) {
            return null;
        }
    }

    /**
    *********************************************************
    @Method Name    : processWithBase64
    @author         : Uddhav Sharma
    @description    : Processes a Base64 encoded string and sends to Docuprox API.
    @param          : String base64Data - The Base64 encoded string of the file.
    @param          : String templateId - The template identifier for processing.
    @return         : String - The response body from the API or null if an error occurs.
    *********************************************************
    */
    global static String processWithBase64(String base64Data, String templateId) {
        if (String.isBlank(base64Data) || String.isBlank(templateId)) {
            return null;
        }

        return sendToApi(templateId, base64Data);
    }

    /*
    *********************************************************
    @Method Name    : sendToApi
    @author         : Uddhav Sharma
    @description    : Sends HTTP request to Docuprox API.
    @param          : String templateId - The template identifier for processing.
    @param          : String base64Image - The Base64 encoded image string.
    @return         : String - The response body from the API or null if an error occurs.
    *********************************************************
    */
    private static String sendToApi(String templateId, String base64Image) {
        try {
            String jsonPayload = JSON.serialize(new Map<String, Object>{ 'actual_image' => base64Image, 'template_id' => templateId });
            HttpRequest request = prepareRequest(jsonPayload);
            Http http = new Http();
            HttpResponse response = http.send(request);
            return (response.getStatusCode() >= 200 && response.getStatusCode() < 300) ? response.getBody() : null;
        } catch (Exception e) {
            return null;
        }
    }

    /*
    *********************************************************
    @Method Name    : prepareRequest
    @author         : Uddhav Sharma
    @description    : Prepares the HTTP request with appropriate headers and endpoint.
    @param          : String jsonPayload - The JSON payload to be sent in the request body.
    @return         : HttpRequest - The prepared HTTP request object.
    *********************************************************
    */
    private static HttpRequest prepareRequest(String jsonPayload) {
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json;charset=UTF-8');
        request.setTimeout(120000);
        request.setBody(jsonPayload);

        Docuprox__c cstm = Docuprox__c.getOrgDefaults();
        if (cstm != null && String.isNotBlank(cstm.Endpoint_URL__c)) {
            request.setEndpoint(cstm.Endpoint_URL__c);
            if (String.isNotBlank(cstm.API_Key__c)) {
                request.setHeader('x-auth', cstm.API_Key__c);
            }
        } else {
            String namedCredName = cstm != null ? cstm.Named_Credential__c : null;
            request.setEndpoint('callout:' + namedCredName + '/v1/process');
        }

        return request;
    }
}
