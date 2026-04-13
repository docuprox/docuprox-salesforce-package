/**
 * @description: Test class for DocuproxPollingScheduled
 */
@IsTest
private class DocuproxPollingScheduledTest {

    /**
     * @description: Tests that the polling job can be successfully scheduled and executed in the test context.
     */
    @IsTest
    static void testScheduledExecution() {
        String jobId = 'job-123';
        String callbackClass = 'DocuproxMockHandler';
        String format = 'json';

        DocuproxPollingScheduled sched = new DocuproxPollingScheduled(jobId, callbackClass, format);
        
        Test.startTest();
        // Schedule the job. In test context, it will run once at Test.stopTest()
        String cronStr = '0 0 0 1 1 ? 2099';
        System.schedule('TestDocuproxPolling', cronStr, sched);
        Test.stopTest();

    }
}

