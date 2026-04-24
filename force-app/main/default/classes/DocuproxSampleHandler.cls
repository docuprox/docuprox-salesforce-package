/**
 * @description: A sample implementation of the result handler.
 *               This class will be called automatically once the async process finishes.
 */
public with sharing class DocuproxSampleHandler implements DocuproxResultHandler {
    
    /**
     * @description: Process the final result from Docuprox.
     * @param result: The JSON string returned by the API.
     */
    public void execute(String result) {
        System.debug('--- DOCUPROX PROCESS COMPLETED ---');
        System.debug('Final Data: ' + result);
        
        // You can add logic here to:
        // 1. Parse the JSON result
        // 2. Update a Salesforce record
        // 3. Send an email notification
    }
}
