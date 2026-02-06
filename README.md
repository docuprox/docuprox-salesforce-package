# Docuprox Salesforce Integration

This Salesforce DX project contains the integration logic for connecting Salesforce with the Docuprox API. It provides a service class to handle document processing by sending files or base64 data to the Docuprox endpoint using configured templates.

## Features

- **File Processing**: Directly process Salesforce Files (`ContentDocument`) by converting them to Base64 and sending them to Docuprox.
- **Base64 Processing**: Support for processing raw base64 encoded strings.
- **Flexible Configuration**: Managed via Hierarchy Custom Settings and/or Named Credentials.
- **Secure Integration**: Uses protected custom settings for storing API keys and endpoints.

## Demo

[Watch the Demo Video](https://www.youtube.com/watch?v=WeUkBJPql_0&t=60s)

## Components

### Classes

- **`DocuproxService`**: Global service class containing methods to interact with the API.
    - `processWithFile(Id contentDocumentId, String templateId)`: Retrieves the latest `ContentVersion` for a given document ID, encodes it, and sends it for processing.
    - `processWithBase64`: Processes raw base64 data.

### Custom Objects / Settings

- **`Docuprox__c`**: A Hierarchy Custom Setting used to store integration details.
    - `API_Key__c`: The API key for authentication.
    - `Endpoint_URL__c`: The target URL for the Docuprox API.
    - `Named_Credential__c`: Name of the Named Credential to use (if applicable).

### Permissions

- **`Docuprox User`**: Permission set that grants access to the `DocuproxService` class.

### Remote Site Settings
- **`DocuproxProd`**: Whitelists the production endpoint for callouts.

## Installation

To install the **Docuprox** unlocked package, use the Salesforce CLI command below or the installation URL provided for the specific version.

**Installation URL:** [Install Package](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tdN000000IxUfQAK)

```bash
sf package install --package 04tdN000000IxUfQAK --target-org <target-org-alias> --wait 10
```

## Post-Installation Configuration

After the package is successfully installed, you must configure the custom settings and permissions.

1.  **Configure Custom Setting**:
    - Navigate to **Setup** > **Custom Code** > **Custom Settings**.
    - Click **Manage** next to **Docuprox**.
    - Click **New** above the "Default Organization Level Value" section to create a global setting (or create Profile/User specific instances if needed).
    - Enter your `API Key` and `Endpoint URL`.
    - *(Optional)* Define the `Named Credential` if you are using one.
    - Click **Save**.

2.  **Assign Permissions**:
    Assign the `Docuprox User` permission set to users who need to trigger document generation.
    - Go to **Setup** > **Users** > **Permission Sets**.
    - Select the **Docuprox User** permission set.
    - Click **Manage Assignments** > **Add Assignments**.
    - Select the users and click **Assign**.

## Usage

You can call the service from Apex (Triggers, Controllers, or Flow via Invocable Methods if implemented).

### Example: Processing a File

```apex
Id fileId = '069xxxxxxxxxxxx'; // ContentDocumentId
String templateId = 'template_123';

try {
    String response = DocuproxService.processWithFile(fileId, templateId);
    System.debug('Response: ' + response);
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
```
