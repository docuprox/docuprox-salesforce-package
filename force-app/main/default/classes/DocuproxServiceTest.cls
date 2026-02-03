/**
 * @description: Test class for DocuproxService
 *              Covers success, error, and exception scenarios
 */
@IsTest
private class DocuproxServiceTest {
    /**
     * @description: Mock class to simulate HTTP callouts
     */
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Boolean shouldThrowException;
        private Integer statusCode;

        /**
         * @description: Default constructor – success response
         */
        public MockHttpResponseGenerator() {
            this(false, 200);
        }

        /**
         * @description: Parameterized constructor to control exception and status code
         * @param shouldThrowException flag to simulate callout exception
         * @param statusCode HTTP status code to return
         */
        public MockHttpResponseGenerator(Boolean shouldThrowException, Integer statusCode) {
            this.shouldThrowException = shouldThrowException;
            this.statusCode = statusCode;
        }

        /**
         * @description: Responds with mocked HTTP response
         * @param req HTTPRequest
         * @return HTTPResponse mocked response
         */
        public HTTPResponse respond(HTTPRequest req) {
            if (shouldThrowException) {
                throw new CalloutException('Simulated API Exception');
            }

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(statusCode);

            if (statusCode >= 200 && statusCode < 300) {
                res.setBody('{"status":"success","amount":123.45,"invoice_number":"INV-101"}');
            } else {
                res.setBody('{"error":"Something went wrong"}');
            }
            return res;
        }
    }

    @TestSetup
    static void createUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'standt',
            Email = 'standarduser@testorg.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'docuprox_test_user' + DateTime.now().getTime() + '@testorg.com'
        );
        insert u;
    }

    /**
     * @description: Test Base64 processing success scenario
     */
    @IsTest
    static void testProcessWithBase64Success() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('dummy data'));
        String templateId = 'temp-001';

        System.runAs(u) {
            Test.startTest();
            String response = DocuproxService.processWithBase64(base64Data, templateId);
            Test.stopTest();

            System.assertNotEquals(null, response, 'Response should not be null');
        }
    }

    /**
     * @description: Test Base64 API error scenario
     */
    @IsTest
    static void testProcessWithBase64ApiError() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false, 400));

        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('dummy data'));
        String templateId = 'temp-001';

        System.runAs(u) {
            Test.startTest();
            String response = DocuproxService.processWithBase64(base64Data, templateId);
            Test.stopTest();

            System.assertEquals(null, response, 'Should return null on API error');
        }
    }

    /**
     * @description: Test Base64 exception scenario
     */
    @IsTest
    static void testProcessWithBase64Exception() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true, 200));

        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('dummy data'));
        String templateId = 'temp-001';

        System.runAs(u) {
            Test.startTest();
            String response = DocuproxService.processWithBase64(base64Data, templateId);
            Test.stopTest();

            System.assertEquals(null, response, 'Should return null on exception');
        }
    }

    /**
     * @description: Test file processing success scenario
     */
    @IsTest
    static void testProcessWithFileSuccess() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        System.runAs(u) {
            ContentVersion cv = new ContentVersion(
                Title = 'Test File',
                PathOnClient = 'test.txt',
                VersionData = Blob.valueOf('Test content'),
                IsMajorVersion = true
            );
            insert cv;

            cv = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ];

            Test.startTest();
            String response = DocuproxService.processWithFile(cv.ContentDocumentId, 'temp-001');
            Test.stopTest();

            System.assertNotEquals(null, response, 'Response should not be null');
        }
    }

    /**
     * @description: Test API error during file processing
     */
    @IsTest
    static void testProcessWithFileApiError() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(false, 500));

        System.runAs(u) {
            ContentVersion cv = new ContentVersion(
                Title = 'Test File',
                PathOnClient = 'test.txt',
                VersionData = Blob.valueOf('Test content'),
                IsMajorVersion = true
            );
            insert cv;

            cv = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ];

            Test.startTest();
            String response = DocuproxService.processWithFile(cv.ContentDocumentId, 'temp-001');
            Test.stopTest();

            System.assertEquals(null, response, 'Should return null on API error');
        }
    }

    /**
     * @description: Test callout exception during file processing
     */
    @IsTest
    static void testProcessWithFileCalloutException() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(true, 200));

        System.runAs(u) {
            ContentVersion cv = new ContentVersion(
                Title = 'Test File',
                PathOnClient = 'test.txt',
                VersionData = Blob.valueOf('Test content'),
                IsMajorVersion = true
            );
            insert cv;

            cv = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ];

            Test.startTest();
            String response = DocuproxService.processWithFile(cv.ContentDocumentId, 'temp-001');
            Test.stopTest();

            System.assertEquals(null, response, 'Should return null on callout exception');
        }
    }

    /**
     * @description: Test processing with Custom Settings (Endpoint URL and API Key)
     *               Covers the lines where custom endpoint and x-auth header are set.
     */
    @IsTest
    static void testProcessWithCustomSettings() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];

        // Setup Custom Setting to trigger the specific code block
        Docuprox__c cs = new Docuprox__c();
        cs.Endpoint_URL__c = 'https://custom-api.docuprox.com/v1/process';
        cs.API_Key__c = '12345-abcde';
        // Explicitly setting SetupOwnerId to Organization to ensure getOrgDefaults() picks it up reliably
        cs.SetupOwnerId = UserInfo.getOrganizationId();
        insert cs;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        System.runAs(u) {
            // Insert ContentVersion as requested
            ContentVersion cv = new ContentVersion(
                Title = 'Test File Settings',
                PathOnClient = 'test_settings.txt',
                VersionData = Blob.valueOf('Test content settings'),
                IsMajorVersion = true
            );
            insert cv;

            // Retrieve ContentDocumentId
            cv = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :cv.Id
            ];

            Test.startTest();
            // Call the service method, which will trigger the custom setting logic
            String response = DocuproxService.processWithFile(cv.ContentDocumentId, 'temp-CS');
            Test.stopTest();

            System.assertNotEquals(null, response, 'Response should not be null with Custom Settings');
        }
    }

    /**
     * @description: Test processing running as a specific user to ensure permissions/context work
     */
    @IsTest
    static void testProcessRunAs() {
        // Setup user
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('dummy data'));
        String templateId = 'temp-001';

        System.runAs(u) {
            Test.startTest();
            String response = DocuproxService.processWithBase64(base64Data, templateId);
            Test.stopTest();

            System.assertNotEquals(null, response, 'Response should not be null when running as Standard User');
        }
    }

    /**
     * @description: Test Base64 processing with invalid parameters (null inputs)
     */
    @IsTest
    static void testProcessWithBase64InvalidParameters() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            // Test with null base64Data
            String response1 = DocuproxService.processWithBase64(null, 'temp-001');
            // Test with null templateId
            String response2 = DocuproxService.processWithBase64('base64Data', null);
            // Test with empty strings
            String response3 = DocuproxService.processWithBase64('', 'temp-001');
            Test.stopTest();

            System.assertEquals(null, response1, 'Should return null when base64Data is null');
            System.assertEquals(null, response2, 'Should return null when templateId is null');
            System.assertEquals(null, response3, 'Should return null when base64Data is empty');
        }
    }

    /**
     * @description: Test File processing with invalid parameters (null inputs)
     */
    @IsTest
    static void testProcessWithFileInvalidParameters() {
        User u = [SELECT Id FROM User WHERE Email = 'standarduser@testorg.com' LIMIT 1];

        System.runAs(u) {
            Test.startTest();
            // Test with null contentDocumentId
            String response1 = DocuproxService.processWithFile(null, 'temp-001');

            // To test with valid Id but invalid template, we need a dummy ContentDocumentId.
            Id fakeId = '069000000000000AAA';

            // Test with null templateId
            String response2 = DocuproxService.processWithFile(fakeId, null);
            // Test with empty templateId
            String response3 = DocuproxService.processWithFile(fakeId, '');

            Test.stopTest();

            System.assertEquals(null, response1, 'Should return null when contentDocumentId is null');
            System.assertEquals(null, response2, 'Should return null when templateId is null');
            System.assertEquals(null, response3, 'Should return null when templateId is empty');
        }
    }
}
