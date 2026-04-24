/**
 * @description: Test class for the new DP_Log__c based DocuproxUserBatch.
 */
@IsTest
private class DocuproxUserBatchTest {

    @TestSetup
    static void setup() {
        // Create initial log record
        DP_Log__c log = new DP_Log__c(
            CDId__c = UserInfo.getUserId(), // Dummy ID
            Template_Id__c = 'temp-123',
            Status__c = 'Enqueued',
            Format__c = 'json',
            Metadata_Name__c = 'DemoConfig'
        );
        insert log;
    }

    /**
     * @description: Tests the full batch cycle from Enqueued to Completed.
     */
    @IsTest
    static void testFullBatchCycle() {
        DP_Log__c log = [SELECT Id FROM DP_Log__c LIMIT 1];
        // Mock for processDocument (202), getJobStatus (200 SUCCESS), getResult (200 JSON)
        Test.setMock(HttpCalloutMock.class, new MultiStageMock());

        Test.startTest();
        DocuproxUserBatch batch = new DocuproxUserBatch(log.Id);
        Database.executeBatch(batch, 1);
        Test.stopTest();


        // Verify status
        log = [SELECT Status__c, Job_Id__c FROM DP_Log__c LIMIT 1];
        System.assertEquals('Completed', log.Status__c);
        System.assertEquals('job-123', log.Job_Id__c);

    }

    /**
     * @description: Tests retry logic when status is Pending.
     */
    @IsTest
    static void testRetryLogic() {
        // Mock returns Pending
        Test.setMock(HttpCalloutMock.class, new MultiStageMock('PENDING'));

        // Update log to 'Submit' to simulate already submitted
        DP_Log__c log = [SELECT Id FROM DP_Log__c LIMIT 1];
        log.Status__c = 'Submit';
        log.Job_Id__c = 'job-123';
        log.Callouts__c = 0;
        update log;


        Test.startTest();
        DocuproxUserBatch batch = new DocuproxUserBatch(log.Id);
        Database.executeBatch(batch, 1);
        Test.stopTest();

        log = [SELECT Status__c, Callouts__c FROM DP_Log__c LIMIT 1];
        System.assertEquals('Pending', log.Status__c);
        System.assertEquals(1, log.Callouts__c);

    }

    /**
     * @description: Tests that polling stops after 4 attempts.
     */
    @IsTest
    static void testMaxRetriesReached() {
        DP_Log__c log = [SELECT Id FROM DP_Log__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MultiStageMock('PENDING'));
        
        log.Status__c = 'Pending';
        log.Job_Id__c = 'job-123';
        log.Callouts__c = 4; // Already at limit
        update log;


        Test.startTest();
        DocuproxUserBatch batch = new DocuproxUserBatch(log.Id);
        Database.executeBatch(batch, 1);
        Test.stopTest();


        log = [SELECT Status__c FROM DP_Log__c LIMIT 1];
        System.assertEquals('Error', log.Status__c);
    }

    // Mock Class
    private class MultiStageMock implements HttpCalloutMock {
        private String forcedStatus;
        public MultiStageMock() {}
        public MultiStageMock(String status) { this.forcedStatus = status; }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String ep = req.getEndpoint();
            
            if (ep.contains('aysncDocuprox')) {
                res.setStatusCode(202);
                res.setBody('{"job_id": "job-123"}');
            } else if (ep.contains('job-status')) {
                String status = (forcedStatus != null) ? forcedStatus : 'PROCESS IMAGE SUCCESS';
                res.setBody('{"status": "' + status + '"}');
            } else if (ep.contains('job-results')) {
                res.setBody('{"result": "success"}');
            }
            return res;
        }
    }
}
