# Docuprox Salesforce Integration

This Salesforce DX project contains the integration logic for connecting Salesforce with the Docuprox API. It supports both synchronous and robust asynchronous workflows for document processing.

## Features

- **File Processing**: Directly process Salesforce Files (`ContentDocument`) by converting them to Base64 and sending them to Docuprox.
- **Synchronous Workflow**: Immediate document processing using `DocuproxService` with support for static values.
- **Asynchronous Workflow**: A state-machine based workflow using `DocuproxUserBatch` for long-running document generation tasks.
- **Status Tracking**: Track the lifecycle of each request (Enqueued, Submit, Pending, Success, Completed, Error) via the `DP_Log__c` object.
- **Callback Support**: Dynamically process results using custom handler classes defined in `Docuprox_Callback_Setting__mdt`.
- **Secure Integration**: Managed via Named Credentials (`Docuprox_Async`) and External Services for seamless API connectivity.

## Components

### Core Classes

- **`DocuproxService`**: Handles synchronous callouts to the Docuprox API.
    - `sendToDocuprox(Id contentDocumentId, String templateId, String staticValues)`: Directly processes a file and returns the API response body containing the generated document ID.
- **`DocuproxAsyncService`**: Orchestrates callouts to the Docuprox Async API.
    - `processDocument(Id fileId, String templateId, String staticValues)`: Initiates the document generation request.
    - `getJobStatus(String jobId)`: Polls the API for the current status of a job.
    - `getResult(String jobId, String format)`: Retrieves the final processed result.
- **`DocuproxUserBatch`**: A stateful batch class that manages the lifecycle of a request, including automatic polling and callback invocation.
- **`DocuproxResultHandler`**: Interface used for creating custom callback processors.

### Custom Metadata & Objects

- **`DP_Log__c`**: Tracks every processing request.
    - `Status__c`: Current state (e.g., Submit, Success, Completed).
    - `Job_Id__c`: The unique job identifier from Docuprox.
- **`Docuprox_Callback_Setting__mdt`**: Maps a configuration name to a specific Apex class that implements `DocuproxResultHandler`.

## Installation

To install the **Docuprox** unlocked package:

**Installation URL:** [Install Package](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tT1000000LLCjIAO)

```bash
sf package install --package 04tT1000000LLCjIAO --target-org <target-org-alias> --wait 10
```

## Usage

### Synchronous Processing Example

You can initiate the synchronous workflow for immediate document generation using the `DocuproxService` class.

```apex
// Direct synchronous call to Docuprox
String responseBody = dcprx.DocuproxService.sendToDocuprox(
    '069xxxxxxxxxxxx', // ContentDocumentId
    'my_template',     // Template ID
    '{"key":"value"}'  // Static Values (JSON string)
);

System.debug('Sync Response: ' + responseBody);
```

### Asynchronous Processing Example

You can initiate the asynchronous workflow by creating a `DP_Log__c` record and starting the batch.

```apex
// 1. Create the Log record
dcprx__DP_Log__c log = new dcprx__DP_Log__c(
    dcprx__CDId__c = '069xxxxxxxxxxxx', // ContentDocumentId
    dcprx__Template_Id__c = 'my_template',
    dcprx__Status__c = 'Enqueued',
    dcprx__Metadata_Name__c = 'MyCallbackConfig'
);
insert log;

// 2. Start the Batch process
dcprx.DocuproxUserBatch batch = new dcprx.DocuproxUserBatch(log.Id);
Database.executeBatch(batch, 1);
```

### Implementing a Callback Handler

Create a class that implements the `DocuproxResultHandler` interface to process results automatically when the job is completed.

```apex
public class MyResultProcessor implements dcprx.DocuproxResultHandler {
    public void execute(String resultJson) {
        // Your logic to handle the processed document data
        System.debug('Received Result: ' + resultJson);
    }
}
```
