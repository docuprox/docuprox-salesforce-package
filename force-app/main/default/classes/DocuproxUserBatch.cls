/*
*********************************************************
Apex Class Name    : DocuproxUserBatch
Created Date       : April 09, 2026
@description       : Standard Batch class example to process Users and initiate Docuprox callouts.
                     Implements the 3-phase callout structure with polling.
@author            : Antigravity
*********************************************************
*/
global with sharing class DocuproxUserBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    // Member variables for batch state
    private String callbackClass;
    private String format;
    private String templateId;
    private Id contentDocumentId;
    private String staticValues;

    // Constructor to initialize all 5 parameters
    global DocuproxUserBatch(Id contentDocumentId, String templateId, String staticValues, String callbackClass, String format) {
        this.contentDocumentId = contentDocumentId;
        this.templateId = templateId;
        this.staticValues = staticValues;
        this.callbackClass = callbackClass;
        this.format = format;
    }

    /*
    *********************************************************
    @Method Name    : start
    @description    : 1st Method - Queries a temporary record (User) to initiate the batch process.
    *********************************************************
    */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        // As per requirement, querying a single User record to trigger execute.
        System.debug('Docuprox Batch Job started...!');
        return Database.getQueryLocator('SELECT Id FROM User LIMIT 1');
    }

    /*
    *********************************************************
    @Method Name    : execute
    @description    : 2nd Method - Calls processDocument using initialization parameters and starts polling.
    *********************************************************
    */
    global void execute(Database.BatchableContext bc, List<User> scope) {
     
        try {
            System.debug('Docuprox Batch Job execute method....!');
            // STEP 1: processDocument using the member variables
            String response = DocuproxAsyncService.processDocument(this.contentDocumentId, this.templateId, this.staticValues);
            
            // Extract JobId from the response
            String jobId = extractJobId(response);
            System.debug('JobId: ' + jobId);
            if (String.isNotBlank(jobId)) {
                // STEP 2: Initiate Polling with a 1-minute wait using Schedulable.
                DateTime nextRun = System.now().addMinutes(1);
                String cronStr = nextRun.second() + ' ' + nextRun.minute() + ' ' + nextRun.hour() + ' ' + nextRun.day() + ' ' + nextRun.month() + ' ? ' + nextRun.year();
                
                String jobName = 'DocuproxInitialPoll_' + jobId + '_' + System.now().getTime();
                System.schedule(jobName, cronStr, new DocuproxPollingScheduled(jobId, callbackClass, format));
            }
        } catch (Exception e) {
            throw new DocuproxAsyncService.DocuproxAsyncException('Docuprox Batch Error: ' + e.getMessage());
        }
    }

    /*
    *********************************************************
    @Method Name    : finish
    @description    : 3rd Method - Runs after all batches are processed.
    *********************************************************
    */
    global void finish(Database.BatchableContext bc) {
        System.debug('Docuprox Batch Job completed successfully! ----- FINISH');
    }

    // Helper method to extract the jobId from JSON or raw string
    private String extractJobId(String response) {
        if (String.isBlank(response)) return null;
        if (response.startsWith('{')) {
            Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(response);
            return (String)data.get('job_id');
        }
        return response;
    }
}
