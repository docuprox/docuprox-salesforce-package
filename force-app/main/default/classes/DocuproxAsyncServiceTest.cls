/**
 * @description: Test class for DocuproxAsyncService
 *               Covers startAsyncProcess, processDocument, getJobStatus, and getResult methods.
 */
@IsTest
private class DocuproxAsyncServiceTest {

    /**
     * @description: Tests startAsyncProcess when no matching custom metadata record is found.
     */
    @IsTest
    static void testStartAsyncProcess_NoMetadata() {
        ContentVersion cv = new ContentVersion(Title='T', PathOnClient='T.pdf', VersionData=Blob.valueOf('T'), IsMajorVersion=true);
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id].ContentDocumentId;
        
        Test.startTest();
        try {
            DocuproxAsyncService.startAsyncProcess(contentDocId, 'temp', '{}', 'NonExistent', 'json');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('No Docuprox Callback Setting found'));
        }
        Test.stopTest();
    }

    /**
     * @description: Tests successful document processing callout.
     */
    @IsTest
    static void testProcessDocument_Success() {
        ContentVersion cv = new ContentVersion(Title='T', PathOnClient='T.pdf', VersionData=Blob.valueOf('T'), IsMajorVersion=true);
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id].ContentDocumentId;
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock());
        
        Test.startTest();
        String result = DocuproxAsyncService.processDocument(contentDocId, 'temp', '{"v":1}');
        Test.stopTest();
        
        System.assertEquals('Async Job Queued', result);
    }

    /**
     * @description: Tests successful document processing callout without providing optional static values.
     */
    @IsTest
    static void testProcessDocument_SuccessNoStaticValues() {
        ContentVersion cv = new ContentVersion(Title='T', PathOnClient='T.pdf', VersionData=Blob.valueOf('T'), IsMajorVersion=true);
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id].ContentDocumentId;
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock());
        
        Test.startTest();
        String result = DocuproxAsyncService.processDocument(contentDocId, 'temp', null);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }

    /**
     * @description: Tests parameter validation for the processDocument method.
     */
    @IsTest
    static void testProcessDocument_ValidationErrors() {
        // Null Id
        try {
            DocuproxAsyncService.processDocument(null, 'temp', '');
            System.assert(false, 'Should have thrown exception for null Id');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('contentDocumentId is required'));
        }
        // Blank Template
        try {
            DocuproxAsyncService.processDocument(UserInfo.getUserId(), '', '');
            System.assert(false, 'Should have thrown exception for blank template');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('templateId is required'));
        }
    }

    /**
     * @description: Tests successful job status retrieval.
     */
    @IsTest
    static void testGetJobStatus_Success() {
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock());
        Test.startTest();
        String result = DocuproxAsyncService.getJobStatus('job-123');
        Test.stopTest();
        System.assertEquals('{"status":"completed"}', result);
    }

    /**
     * @description: Tests job status retrieval when the job is not found (404 response).
     */
    @IsTest
    static void testGetJobStatus_NotFound() {
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock(404));
        Test.startTest();
        String result = DocuproxAsyncService.getJobStatus('job-123');
        Test.stopTest();
        System.assertEquals(null, result);
    }

    /**
     * @description: Tests validation for empty job ID when checking status.
     */
    @IsTest
    static void testGetJobStatus_EmptyJobId() {
        try {
            DocuproxAsyncService.getJobStatus('');
            System.assert(false, 'Should have thrown exception');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('jobId is required'));
        }
    }

    /**
     * @description: Tests successful job result retrieval.
     */
    @IsTest
    static void testGetResult_Success() {
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock());
        Test.startTest();
        String result = DocuproxAsyncService.getResult('job-123', 'json');
        Test.stopTest();
        System.assertEquals('{"data":"result"}', result);
    }

    /**
     * @description: Tests job result retrieval when the results are not found (404 response).
     */
    @IsTest
    static void testGetResult_NotFound() {
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock(404));
        Test.startTest();
        String result = DocuproxAsyncService.getResult('job-123', 'csv');
        Test.stopTest();
        System.assertEquals(null, result);
    }

    /**
     * @description: Tests validation for empty job ID when retrieving results.
     */
    @IsTest
    static void testGetResult_EmptyJobId() {
        try {
            DocuproxAsyncService.getResult(null, 'json');
            System.assert(false, 'Should have thrown exception');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('jobId is required.'));
        }
    }

    /**
     * @description: Tests general exception handling for various callout failures.
     */
    @IsTest
    static void testExceptions() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        
        // getJobStatus Exception
        try {
            DocuproxAsyncService.getJobStatus('job-123');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Docuprox job status callout failed'));
        }

        // getResult Exception
        try {
            DocuproxAsyncService.getResult('job-123', 'json');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Docuprox result callout failed'));
        }
    }

    /**
     * @description: Tests error response (500) during document submission.
     */
    @IsTest
    static void testProcessDocument_Error() {
        ContentVersion cv = new ContentVersion(Title='T', PathOnClient='T.pdf', VersionData=Blob.valueOf('T'), IsMajorVersion=true);
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id].ContentDocumentId;
        
        // Status 500
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock(500));
        try {
            DocuproxAsyncService.processDocument(contentDocId, 'temp', '');
            System.assert(false, 'Should have thrown exception');
        } catch (Exception e) {
            System.assert(true);
        }
    }

    /**
     * @description: Tests specific catching and rethrowing of DocuproxAsyncException.
     */
    @IsTest
    static void testDocuproxAsyncExceptionCatching() {
        // Test covering catch (DocuproxAsyncException e) { throw e; }
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncExceptionMock());
        
        try {
            DocuproxAsyncService.getJobStatus('job-123');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assertEquals('Test Exception', e.getMessage());
        }

        try {
            DocuproxAsyncService.getResult('job-123', 'json');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assertEquals('Test Exception', e.getMessage());
        }
    }

    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Callout failed');
        }
    }

    private class DocuproxAsyncExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new DocuproxAsyncService.DocuproxAsyncException('Test Exception');
        }
    }

    private class DocuproxAsyncMock implements HttpCalloutMock {
        private Integer code;
        public DocuproxAsyncMock() { this.code = 200; }
        public DocuproxAsyncMock(Integer code) { this.code = code; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.code);
            String ep = req.getEndpoint();
            if (ep.contains('job-status')) {
                res.setBody('{"status":"completed"}');
            } else if (ep.contains('job-results')) {
                res.setBody('{"data":"result"}');
            } else { 
                res.setStatusCode(this.code == 200 ? 202 : this.code);
                res.setBody('Async Job Queued'); 
            }
            return res;
        }
    }
}


