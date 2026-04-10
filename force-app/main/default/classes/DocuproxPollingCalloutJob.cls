/*
*********************************************************
Apex Class Name    : DocuproxPollingCalloutJob
Created Date       : April 10, 2026
@description       : Queueable class that performs the actual Docuprox callouts.
                     If polling is not complete, it reschedules the Schedulable timer.
*********************************************************
*/
public class DocuproxPollingCalloutJob implements Queueable, Database.AllowsCallouts {
    
    private String jobId;
    private String callbackClass;
    private String format;

    public DocuproxPollingCalloutJob(String jobId, String callbackClass, String format) {
        this.jobId = jobId;
        this.callbackClass = callbackClass;
        this.format = format;
    }

    public void execute(QueueableContext context) {
        try {
            // STEP 2: getJobStatus - Check status (Allowed here!)
            String response = DocuproxAsyncService.getJobStatus(jobId);
            System.debug('Docuprox Polling Status: ' + response);
            
            if (isStatusCompleted(response)) {
                // STEP 3: Success! Get Result
                String result = DocuproxAsyncService.getResult(jobId, format);
                invokeCallback(result);
            } else {
                // STILL PENDING: Schedule the NEXT Schedulable timer for 1 minute later.
                // Chaining Schedulable from Queueable resets the stack depth limit.
                scheduleNextTimer();
            }
        } catch (Exception e) {
            System.debug('Docuprox Callout Job Error: ' + e.getMessage());
        }
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

    private void scheduleNextTimer() {
        DateTime nextRun = System.now().addMinutes(1);
        String cronStr = nextRun.second() + ' ' + nextRun.minute() + ' ' + nextRun.hour() + ' ' + nextRun.day() + ' ' + nextRun.month() + ' ? ' + nextRun.year();
        String jobName = 'DocuproxPollTimer_' + jobId + '_' + System.now().getTime();
        
        System.schedule(jobName, cronStr, new DocuproxPollingScheduled(jobId, callbackClass, format));
    }

    private void invokeCallback(String result) {
        if (String.isBlank(callbackClass)) return;
        Type t = Type.forName(callbackClass);
        if (t != null) {
            Object instance = t.newInstance();
            if (instance instanceof DocuproxResultHandler) {
                ((DocuproxResultHandler)instance).execute(result);
            }
        }
    }
}
