/*
*********************************************************
Apex Class Name    : DocuproxPollingScheduled
Created Date       : April 10, 2026
@description       : Schedulable class that acts as a timer. 
                     It triggers a Queueable job to perform the actual callouts.
*********************************************************
*/
global with sharing class DocuproxPollingScheduled implements Schedulable {
    
    private String jobId;
    private String callbackClass;
    private String format;

    global DocuproxPollingScheduled(String jobId, String callbackClass, String format) {
        this.jobId = jobId;
        this.callbackClass = callbackClass;
        this.format = format;
    }

    global void execute(SchedulableContext sc) {
        // We cannot do callouts directly in Schedulable. 
        // So we start a Queueable job to do the work.
        System.enqueueJob(new DocuproxPollingCalloutJob(jobId, callbackClass, format));
        
        // Clean up: Abort the current cron job to keep the UI clean
        System.abortJob(sc.getTriggerId());
    }
}
