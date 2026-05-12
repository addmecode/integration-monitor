namespace Addmecode.IntegrationMonitor.Transport;
using Addmecode.IntegrationMonitor.Setup;
using System.Integration;

codeunit 50117 "AMC Http Transport Default" implements "AMC IHttpTransportHandler"
{
    procedure ValidateSetup(Setup: Record "AMC Int. Message Setup")
    var
        WebRequestHelper: Codeunit "Web Request Helper";
        InvalidEndpointUrlErr: Label 'The URL in %1 field is not valid.', Comment = '%1 is field name';
    begin
        Setup.TestField("Endpoint URL");
        if not WebRequestHelper.IsHttpUrl(Setup."Endpoint URL") then
            Error(InvalidEndpointUrlErr, Setup.FieldCaption("Endpoint URL"));
    end;

    /// <summary>
    /// Sends an HTTP request and returns the response and response body.
    /// </summary>
    /// <param name="Request">HTTP request message to send.</param>
    /// <param name="Setup">Message setup for the entry.</param>
    /// <param name="Response">HTTP response message.</param>
    /// <param name="ResponseBody">Response body stream, if available.</param>
    /// <returns>True if the request was sent, otherwise false.</returns>
    procedure Send(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage)
    var
        Client: HttpClient;
    begin
        Client.Timeout := Setup."Timeout (ms)";
        if Setup."Auth Profile Code" <> '' then
            this.ApplyAuth(Client, Request, Setup."Auth Profile Code");

        Client.Send(Request, Response);
    end;

    local procedure ApplyAuth(var Client: HttpClient; var Request: HttpRequestMessage; AuthProfile: Code[20])
    begin
        this.OnApplyAuth(Client, Request, AuthProfile);
        //todo
    end;

    [IntegrationEvent(false, false)]
    local procedure OnApplyAuth(var Client: HttpClient; var Request: HttpRequestMessage; AuthProfile: Code[20])
    begin
    end;

}
