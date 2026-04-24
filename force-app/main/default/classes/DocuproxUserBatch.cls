/**
 * @description: Standard Batch class that processes DP_Log__c records.
 *               Handles the 3-phase callout structure with automatic self-rescheduling.
 */
global with sharing class DocuproxUserBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {

    private Id targetRecordId;

    /**
     * @description: Constructor that accepts a specific DP_Log__c Record ID.
     */
    global DocuproxUserBatch(Id recordId) {
        this.targetRecordId = recordId;
    }

    /**
     * @description: Queries only the specific DP_Log__c record passed in the constructor.
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, CDId__c, Template_Id__c, Static_Value__c, Metadata_Name__c, Format__c, Status__c, Job_Id__c, Callouts__c 
            FROM DP_Log__c 
            WHERE Id = :targetRecordId
        ]);
    }

    /**
     * @description: Processes each record based on its current status.
     */
    global void execute(Database.BatchableContext bc, List<DP_Log__c> scope) {
        System.debug('Docuprox [Batch]: Executing batch for ' + scope.size() + ' record(s).');
        for (DP_Log__c log : scope) {
            try {
                System.debug('Docuprox [Batch]: Processing record: ' + log.Id + ' with current status: ' + log.Status__c);
                
                // PHASE 1: Initial Submission
                if (log.Status__c == 'Enqueued') {
                    System.debug('Docuprox [Batch]: Sending Phase 1 (Submit) callout...');
                    String response = DocuproxAsyncService.processDocument(log.CDId__c, log.Template_Id__c, log.Static_Value__c);
                    log.Job_Id__c = extractJobId(response);
                    log.Status__c = 'Submit';
                    System.debug('Docuprox [Batch]: Phase 1 Success. Job Id: ' + log.Job_Id__c);
                } 
                // PHASE 2: Polling Status
                else if (log.Status__c == 'Submit' || log.Status__c == 'Pending') {
                    System.debug('Docuprox [Batch]: Sending Phase 2 (Status Check) callout for Job: ' + log.Job_Id__c);
                    String response = DocuproxAsyncService.getJobStatus(log.Job_Id__c);
                    if (isStatusCompleted(response)) {
                        log.Status__c = 'Success';
                        System.debug('Docuprox [Batch]: Phase 2 Success. Job is ready.');
                    } else if (log.Callouts__c >= 4) {
                        log.Status__c = 'Error';
                        System.debug('Docuprox [Batch]: Phase 2 Error. Max retries (4) reached.');
                    } else {
                        log.Status__c = 'Pending';
                        log.Callouts__c = (log.Callouts__c == null ? 0 : log.Callouts__c) + 1;
                        System.debug('Docuprox [Batch]: Phase 2 Pending. Attempt #' + log.Callouts__c);
                    }
                }
                
                // PHASE 3: Retrieving Results
                if (log.Status__c == 'Success') {
                    System.debug('Docuprox [Batch]: Sending Phase 3 (Get Result) callout...');
                    String result = DocuproxAsyncService.getResult(log.Job_Id__c, log.Format__c);
                    invokeCallback(log.Metadata_Name__c, result);
                    log.Status__c = 'Completed';
                    System.debug('Docuprox [Batch]: Phase 3 Success. Process Completed.');
                }
            } catch (Exception e) {
                log.Status__c = 'Error';
                System.debug('Docuprox [Batch]: EXCEPTION at record ' + log.Id + ': ' + e.getMessage());
            }
        }
        update scope;
    }

    /**
     * @description: If records are still pending, schedule the batch to run again in 1 minute.
     */
    global void finish(Database.BatchableContext bc) {
        DP_Log__c log = [
            SELECT Status__c FROM DP_Log__c 
            WHERE Id = :targetRecordId 
            LIMIT 1
        ];
        
        System.debug('Docuprox [Batch]: Finish method reached. Final Record Status: ' + log.Status__c);
        
        if (log.Status__c != 'Completed' && log.Status__c != 'Error') {
            System.debug('Docuprox [Batch]: Rescheduling next attempt in 1 minute...');
            // Self-reschedule for this specific record after 1 minute
            System.scheduleBatch(new DocuproxUserBatch(targetRecordId), 'Docuprox_Batch_Retry_' + targetRecordId + '_' + System.now().getTime(), 1);
        } else {
            System.debug('Docuprox [Batch]: Processing finished for this record.');
        }
    }


    // --- Helper Methods ---

    private String extractJobId(String response) {
        if (String.isBlank(response)) return null;
        if (response.startsWith('{')) {
            Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(response);
            return (String)data.get('job_id');
        }
        return response;
    }

    private Boolean isStatusCompleted(String response) {
        if (String.isBlank(response)) return false;
        try {
            Map<String, Object> data = (Map<String, Object>)JSON.deserializeUntyped(response);
            String status = (String)data.get('status');
            return status == 'PROCESS IMAGE SUCCESS' || status == 'UNZIP FILE SUCCESS';
        } catch (Exception e) {
            return response.contains('PROCESS IMAGE SUCCESS') || response.contains('UNZIP FILE SUCCESS');
        }
    }

    private void invokeCallback(String metadataName, String result) {
        if (String.isBlank(metadataName)) return;
        
        List<dcprx__Docuprox_Callback_Setting__mdt> settings = [
            SELECT dcprx__Class_Name__c 
            FROM dcprx__Docuprox_Callback_Setting__mdt 
            WHERE DeveloperName = :metadataName 
            LIMIT 1
        ];
        
        if (settings.isEmpty()) return;
        
        String className = settings[0].dcprx__Class_Name__c;
        System.debug('Docuprox [Batch]: Invoking callback class: ' + className);
        Type t = Type.forName(className);
        if (t != null) {
            Object instance = t.newInstance();
            if (instance instanceof DocuproxResultHandler) {
                ((DocuproxResultHandler)instance).execute(result);
            }
        }
    }
}   
