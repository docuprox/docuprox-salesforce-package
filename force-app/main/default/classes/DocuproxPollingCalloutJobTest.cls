/**
 * @description: Test class for DocuproxPollingCalloutJob
 */
@IsTest
private class DocuproxPollingCalloutJobTest {

    /**
     * @description: Tests the successful completion path where job status is 'PROCESS IMAGE SUCCESS'.
     */
    @IsTest
    static void testStatusCompleted() {
        Test.setMock(HttpCalloutMock.class, new PollingMock('PROCESS IMAGE SUCCESS'));
        
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', 'DocuproxMockHandler', 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    /**
     * @description: Tests the successful completion path where job status is 'UNZIP FILE SUCCESS'.
     */
    @IsTest
    static void testStatusUnzipSuccess() {
        Test.setMock(HttpCalloutMock.class, new PollingMock('UNZIP FILE SUCCESS'));
        
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', 'DocuproxMockHandler', 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    /**
     * @description: Tests the path where the job is still 'PENDING', triggering a reschedule of the timer.
     */
    @IsTest
    static void testStatusPending() {
        Test.setMock(HttpCalloutMock.class, new PollingMock('PENDING'));
        
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', 'DocuproxMockHandler', 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    /**
     * @description: Tests the scenario where the job status response is empty.
     */
    @IsTest
    static void testStatusEmpty() {
        Test.setMock(HttpCalloutMock.class, new PollingMock(''));
        
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', 'DocuproxMockHandler', 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    /**
     * @description: Tests handling of malformed JSON in the job status response.
     */
    @IsTest
    static void testMalformedJson() {
        // Triggers the catch block in isStatusCompleted
        Test.setMock(HttpCalloutMock.class, new PollingMock('{"status": "PROCESS IMAGE SUCCESS" broken'));
        
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', 'DocuproxMockHandler', 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    /**
     * @description: Tests behavior when an invalid/non-existent callback class is provided.
     */
    @IsTest
    static void testInvalidCallbackClass() {
        Test.setMock(HttpCalloutMock.class, new PollingMock('PROCESS IMAGE SUCCESS'));
        
        // Non-existent class
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', 'NonExistentClass', 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    /**
     * @description: Tests behavior when the callback class does not implement the DocuproxResultHandler interface.
     */
    @IsTest
    static void testCallbackNotMatchingInterface() {
        Test.setMock(HttpCalloutMock.class, new PollingMock('PROCESS IMAGE SUCCESS'));
        
        // Existing class but not a DocuproxResultHandler. 
        // Note: Using a standard class like 'DocuproxPollingScheduled' (it exists and doesn't implement the interface)
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', 'DocuproxPollingScheduled', 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    /**
     * @description: Tests behavior when no callback class is provided.
     */
    @IsTest
    static void testEmptyCallbackClass() {
        Test.setMock(HttpCalloutMock.class, new PollingMock('PROCESS IMAGE SUCCESS'));
        
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', null, 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    /**
     * @description: Tests general error handling when the callout throws an exception.
     */
    @IsTest
    static void testErrorScenario() {
        // Force an exception in the main try block by returning 500 or null
        Test.setMock(HttpCalloutMock.class, new PollingMock(null));
        
        DocuproxPollingCalloutJob job = new DocuproxPollingCalloutJob('job-123', 'DocuproxMockHandler', 'json');
        
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();
    }

    private class PollingMock implements HttpCalloutMock {
        private String status;
        public PollingMock(String status) {
            this.status = status;
        }
        public HttpResponse respond(HttpRequest req) {
            if (status == null) throw new CalloutException('Simulated Error');
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('job-status')) {
                // If status is empty string, we return it as is
                if (String.isEmpty(status)) {
                    res.setBody('');
                } else if (status.contains('broken')) {
                    res.setBody(status);
                } else {
                    res.setBody('{"status": "' + status + '"}');
                }
            } else if (req.getEndpoint().contains('job-results')) {
                res.setBody('{"result": "success"}');
            }
            return res;
        }
    }
}

