/*
*********************************************************
Apex Class Name    : DocuproxService
Created Date       : April 08, 2026
@description       : This class handles is the primary service class for Docuprox integration.
@author            : uddhav.sharma@xccelerance.com
Modification Log:
Ver   Date         Author                               Modification
1.0   08-04-2026   Uddhav Sharma                      Initial Version
*********************************************************
*/
global with sharing class DocuproxService {
    /*
    *********************************************************
    @Method Name    : sendToDocuprox
    @author         : Uddhav Sharma
    @description    : Processes a file from ContentDocumentId, converts it to Base64, and sends to API.
    @param          : Id contentDocumentId - The Id of the ContentDocument
    @param          : String templateId - The template identifier for processing
    @return         : String - The response body from the API.
    *********************************************************
    */
    global static String sendToDocuprox(Id contentDocumentId, String templateId) {
        try {
            ExternalService.DocuproxAsync myService = new ExternalService.DocuproxAsync();
            ExternalService.DocuproxAsync.syncDocuprox_Request request = new ExternalService.DocuproxAsync.syncDocuprox_Request();
            request.tx5fid = templateId;
            request.body = contentDocumentId;

            // Make the callout and return the filled PDF's ContentDocumentId
            ExternalService.DocuproxAsync.syncDocuprox_Response response = myService.syncDocuprox(request);
            return response.Code200 != null ? response.Code200 : null;
        } catch (ExternalService.DocuproxAsync.syncDocuprox_ResponseException e) {
            throw e;
        } catch (Exception e) {
            throw new DocuproxAsyncService.DocuproxAsyncException(
                'Docuprox sync callout failed: ' + e.getTypeName() + ' – ' + e.getMessage(),
                e
            );
        }
    }
}
