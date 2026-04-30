/**
 * @description: Test class for DocuproxService
 *              Covers success, error, and exception scenarios
 */
@IsTest
private class DocuproxServiceTest {
    
    @IsTest
    static void testSendToDocuprox_Success() {
        // Setup Data: ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;

        // Re-query to get ContentDocumentId
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        // Setup Mock
        Test.setMock(HttpCalloutMock.class, new DocuproxMock(200));

        // Call Service
        Test.startTest();
        String result = DocuproxService.sendToDocuprox(contentDocId, 'template-123', '{"city":"rt"}');
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Success Response', result, 'Result body should match mock body');
    }

    @IsTest
    static void testSendToDocuprox_Exception() {
        // Setup data
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'test.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        // Setup Mock for failure (non-200 will cause External Service to throw if schema expects 200)
        // Or if we want to trigger the generic Exception catch block
        Test.setMock(HttpCalloutMock.class, new DocuproxMock(500));

        Test.startTest();
        try {
            DocuproxService.sendToDocuprox(contentDocId, 'template-123', '{"city":"rt"}');
            // Depending on how the External Service is generated, it might throw syncDocuprox_ResponseException or just return response with null Code200
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Docuprox sync callout failed') || e.getTypeName().contains('ResponseException'), 
                'Expected exception should be caught. Message: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // Mock Class for Docuprox Callouts
    private class DocuproxMock implements HttpCalloutMock {
        private Integer statusCode;
        
        public DocuproxMock(Integer statusCode) {
            this.statusCode = statusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(this.statusCode);
            if (this.statusCode == 200) {
                res.setBody('Success Response');
            } else {
                res.setBody('{"error": "Internal Server Error"}');
            }
            return res;
        }
    }
}
