/*
*********************************************************
Apex Interface Name : DocuproxResultHandler
@description       : Interface to be implemented by users to handle the results of Docuprox asynchronous processing.
*********************************************************
*/
public interface DocuproxResultHandler {
    /**
     * @description This method is called once the Docuprox job is successfully completed.
     * @param result The result string returned from Docuprox (JSON or CSV based on the requested format).
     */
    void execute(String result);
}
