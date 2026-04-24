/*
 *********************************************************
 Apex Class Name    : DocuproxAsyncService
 Created Date       : April 04, 2026
 @description       : This class handles is the primary service class for Async callouts to Docuprox.
 @author            : uddhav.sharma@xccelerance.com
 Modification Log:
 Ver   Date         Author                               Modification
 1.0   04-04-2026   Uddhav Sharma                      Initial Version
 *********************************************************
 */
global with sharing class DocuproxAsyncService {

    /**
     * @Method Name    : startAsyncProcess
     * @description    : New entry point that orchestrates the entire async process.
     * @param          : Id contentDocumentId - File to process
     * @param          : String templateId - Docuprox Template
     * @param          : String staticValues - JSON values
     * @param          : String metadataName - DeveloperName of the Metadata record
     * @param          : String format - Result format (json/csv)
     */
    global static void startAsyncProcess(Id contentDocumentId, String templateId, String staticValues, String metadataName, String format) {
        System.debug('Docuprox [Service]: Starting Async Process for Document: ' + contentDocumentId);

        // Create a new Log record to track the process
        DP_Log__c log = new DP_Log__c();
        log.CDId__c = contentDocumentId;
        log.Template_Id__c = templateId;
        log.Static_Value__c = staticValues;
        log.Metadata_Name__c = metadataName;
        log.Format__c = format;
        log.Status__c = 'Enqueued';
        log.Callouts__c = 0;
        
        insert log;


        // Start the Batch process which will pick up this specific log
        DocuproxUserBatch batch = new DocuproxUserBatch(log.Id);
        Database.executeBatch(batch, 1);

    }


    /*
    *********************************************************
    @Method Name    : processDocument
    @author         : Uddhav Sharma
    @description    : Fetches file content by ContentDocumentId and sends it to the Docuprox Async API via the registered External Service.
    @param          : Id contentDocumentId - The Id of the ContentDocument to send
    @param          : String templateId - The Docuprox portal template identifier
    @param          : String staticValues - (Optional) JSON string of static values to be used in the template
    @return         : String - The response body from the API
    *********************************************************
    */
    global static String processDocument(Id contentDocumentId, String templateId, String staticValues) {
        if (contentDocumentId == null)
            throw new DocuproxAsyncException('contentDocumentId is required.');

        if (String.isBlank(templateId))
            throw new DocuproxAsyncException('templateId is required.');

        try {
            // Call the registered External Service for Docuprox Async callout
            ExternalService.dcprx.DocuproxAsync myService = new ExternalService.dcprx.DocuproxAsync();
            ExternalService.dcprx.DocuproxAsync.aysncDocuprox_Request request = new ExternalService.dcprx.DocuproxAsync.aysncDocuprox_Request();
            request.tx5fid = templateId;
            request.body = contentDocumentId;

            if (String.isNotBlank(staticValues))
                request.staticx5fvalues = staticValues;

            ExternalService.dcprx.DocuproxAsync.aysncDocuprox_Response response = myService.aysncDocuprox(request);
            return response.Code202 != null ? response.Code202 : null;
        } catch (ExternalService.dcprx.DocuproxAsync.aysncDocuprox_ResponseException e) {
            throw e;
        } catch (DocuproxAsyncException e) {
            throw e;
        } catch (Exception e) {
            throw new DocuproxAsyncException('Docuprox async callout failed: ' + e.getTypeName() + ' – ' + e.getMessage(), e);
        }
    }

    /*
    *********************************************************
    @Method Name    : getJobStatus
    @author         : Uddhav Sharma
    @description    : Queries the Docuprox Async API for the current status of a previously submitted job.
    @param          : String jobId - The UUID of the job to check status for
    @return         : String - The response body containing job status
    *********************************************************
    */
    global static String getJobStatus(String jobId) {
        if (String.isBlank(jobId))
            throw new DocuproxAsyncException('jobId is required.');

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Docuprox_Async/v1/job-status?job_id=' + jobId);
            req.setMethod('GET');
            Http http = new Http();
            HttpResponse res = http.send(req);

            return res.getStatusCode() == 200 ? res.getBody() : null;
        } catch (DocuproxAsyncException e) {
            throw e;
        } catch (Exception e) {
            throw new DocuproxAsyncException('Docuprox job status callout failed: ' + e.getTypeName() + ' – ' + e.getMessage(), e);
        }
    }

    /*
    *********************************************************
    @Method Name    : getResult
    @author         : Uddhav Sharma
    @description    : Retrieves the results of a completed Docuprox job in the specified format.
    @param          : String jobId - The UUID of the completed job
    @param          : String resultFormat - (Optional) Output format: "json" (default) or "csv"
    @return         : String - The response body containing job results
    *********************************************************
    */
    global static String getResult(String jobId, String resultFormat) {
        if (String.isBlank(jobId))
            throw new DocuproxAsyncException('jobId is required.');

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Docuprox_Async/v1/job-results');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');

            Map<String, String> body = new Map<String, String>();
            body.put('job_id', jobId);
            if (String.isNotBlank(resultFormat))
                body.put('result_format', resultFormat);

            req.setBody(JSON.serialize(body));

            Http http = new Http(); 
            HttpResponse res = http.send(req);

            return res.getStatusCode() == 200 ? res.getBody() : null;
        } catch (DocuproxAsyncException e) {
            throw e;
        } catch (Exception e) {
            throw new DocuproxAsyncException('Docuprox result callout failed: ' + e.getTypeName() + ' – ' + e.getMessage(), e);
        }
    }

    // Custom exception class for Docuprox Async Service errors
    global class DocuproxAsyncException extends Exception {
        
    }
}
