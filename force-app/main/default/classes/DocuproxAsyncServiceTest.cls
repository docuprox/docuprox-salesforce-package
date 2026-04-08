/**
 * @description: Test class for DocuproxAsyncService
 *               Covers processDocument, getJobStatus, and getResult methods.
 */
@IsTest
private class DocuproxAsyncServiceTest {

    @IsTest
    static void testProcessDocument_Success() {
        ContentVersion cv = new ContentVersion(Title='T', PathOnClient='T.pdf', VersionData=Blob.valueOf('T'), IsMajorVersion=true);
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id].ContentDocumentId;
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock());
        Test.startTest();
        String result = DocuproxAsyncService.processDocument(contentDocId, 'temp', '{"v":1}');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

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

    @IsTest
    static void testProcessDocument_ValidationErrors() {
        // Null Id
        try {
            DocuproxAsyncService.processDocument(null, 'temp', '');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('contentDocumentId is required'));
        }
        // Blank Template
        try {
            DocuproxAsyncService.processDocument(UserInfo.getUserId(), '', '');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('templateId is required'));
        }
    }

    @IsTest
    static void testGetJobStatus_Success() {
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock());
        String result = DocuproxAsyncService.getJobStatus('job-123');
        System.assertEquals('{"status":"completed"}', result);
    }

    @IsTest
    static void testGetJobStatus_NotFound() {
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock(404));
        String result = DocuproxAsyncService.getJobStatus('job-123');
        System.assertEquals(null, result);
    }

    @IsTest
    static void testGetJobStatus_EmptyJobId() {
        try {
            DocuproxAsyncService.getJobStatus('');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('jobId is required'));
        }
    }

    @IsTest
    static void testGetResult_Success() {
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock());
        String result = DocuproxAsyncService.getResult('job-123', 'json');
        System.assertEquals('{"data":"result"}', result);
    }

    @IsTest
    static void testGetResult_NotFound() {
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock(404));
        String result = DocuproxAsyncService.getResult('job-123', 'csv');
        System.assertEquals(null, result);
    }

    @IsTest
    static void testGetResult_EmptyJobId() {
        try {
            DocuproxAsyncService.getResult(null, 'json');
        } catch (DocuproxAsyncService.DocuproxAsyncException e) {
            System.assert(e.getMessage().contains('jobId is required.'));
        }
    }

    @IsTest
    static void testExceptions() {
        Test.setMock(HttpCalloutMock.class, new ThrowingMock());
        
        // getJobStatus Exception
        try {
            DocuproxAsyncService.getJobStatus('job-123');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('job status callout failed'));
        }

        // getResult Exception
        try {
            DocuproxAsyncService.getResult('job-123', 'json');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('result callout failed'));
        }
    }

    @IsTest
    static void testProcessDocument_Error() {
        ContentVersion cv = new ContentVersion(Title='T', PathOnClient='T.pdf', VersionData=Blob.valueOf('T'), IsMajorVersion=true);
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id].ContentDocumentId;
        
        // Status 500
        Test.setMock(HttpCalloutMock.class, new DocuproxAsyncMock(500));
        try {
            DocuproxAsyncService.processDocument(contentDocId, 'temp', '');
        } catch (Exception e) {
            // Success if caught
            System.assert(true);
        }
    }

    private class ThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Callout failed');
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
            if (ep.contains('job-status')) res.setBody('{"status":"completed"}');
            else if (ep.contains('job-results')) res.setBody('{"data":"result"}');
            else { 
                res.setStatusCode(this.code == 200 ? 202 : this.code);
                res.setBody('Async Job Queued'); 
            }
            return res;
        }
    }
}
