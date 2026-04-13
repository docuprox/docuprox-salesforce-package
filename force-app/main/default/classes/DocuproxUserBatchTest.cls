/**
 * @description: Test class for DocuproxUserBatch
 */
@IsTest
private class DocuproxUserBatchTest {

    /**
     * @description: Tests successful batch execution with a valid JSON job_id response.
     */
    @IsTest
    static void testBatchExecution_Success() {
        // Setup data
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'TestDocument.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        // Set mock
        Test.setMock(HttpCalloutMock.class, new DocuproxBatchMock('{"job_id": "job-123"}'));

        // Start batch
        DocuproxUserBatch batch = new DocuproxUserBatch(contentDocId, 'template-123', '{"key":"value"}', 'DocuproxMockHandler', 'json');
        
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

        // Coverage for finish is automatic
    }

    /**
     * @description: Tests batch execution when the API returns a raw string instead of a JSON object.
     */
    @IsTest
    static void testBatchExecution_RawJobId() {
        ContentVersion cv = new ContentVersion(Title = 'T', PathOnClient = 'T.pdf', VersionData = Blob.valueOf('T'), IsMajorVersion = true);
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        // Mock returns raw string instead of JSON
        Test.setMock(HttpCalloutMock.class, new DocuproxBatchMock('job-456'));

        DocuproxUserBatch batch = new DocuproxUserBatch(contentDocId, 'temp', '{}', 'DocuproxMockHandler', 'json');
        
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();
    }

    /**
     * @description: Tests basic instantiation with null parameters for edge case coverage.
     */
    @IsTest
    static void testExtractJobId_EdgeCases() {
        DocuproxUserBatch batch = new DocuproxUserBatch(null, null, null, null, null);
    }

    /**
     * @description: Tests that exceptions during batch execution are correctly caught and rethrown as DocuproxAsyncException.
     */
    @IsTest
    static void testBatchErrorHandling() {
        // Test exception logic in execute
        // We pass nulls which should trigger DocuproxAsyncException in DocuproxAsyncService
        DocuproxUserBatch batch = new DocuproxUserBatch(null, null, null, null, null);
        
        Test.startTest();
        try {
            // Calling execute manually in test context allows us to catch the exception synchronously
            batch.execute(null, new List<User>{ new User(Id = UserInfo.getUserId()) });
            System.assert(false, 'Exception should have been thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Docuprox Batch Error'));
        }
        Test.stopTest();
    }


    // Mock for batch callouts
    private class DocuproxBatchMock implements HttpCalloutMock {
        private String responseBody;
        public DocuproxBatchMock(String body) {
            this.responseBody = body;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody(this.responseBody);
            return res;
        }
    }
}

