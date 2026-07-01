namespace Addmecode.IntegrationMonitor.Transport;
using Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Setup;
using System.Integration;

codeunit 50104 "AMC Http Transport Default" implements "AMC IHttpTransportHandler"
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

    procedure Send(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage)
    var
        AuthApplier: Codeunit "AMC Int. Auth Applier";
        Client: HttpClient;
    begin
        this.ValidateSetup(Setup);
        this.ConfigureClient(Client, Setup);
        AuthApplier.ApplyAuth(Request, Setup."Auth Profile Code");
        this.SendRequest(Client, Request, Setup, Response);
    end;

    local procedure ConfigureClient(var Client: HttpClient; Setup: Record "AMC Int. Message Setup")
    begin
        Client.Timeout := Setup."Timeout (ms)";
    end;

    local procedure SendRequest(var Client: HttpClient; var Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage)
    var
        SendSucceeded: Boolean;
    begin
        SendSucceeded := Client.Send(Request, Response);
        if not SendSucceeded then
            this.RaiseSendFailedError(Request, Setup);
    end;

    local procedure RaiseSendFailedError(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup")
    var
        SendFailedErr: Label 'HTTP request could not be sent. Message type: %1. Method: %2. URL: %3. Timeout (ms): %4. No HTTP response was available.', Comment = '%1 = integration message type, %2 = HTTP method, %3 = request URL, %4 = timeout in milliseconds';
    begin
        Error(SendFailedErr, Format(Setup."Message Type"), Request.Method(), Request.GetRequestUri(), Setup."Timeout (ms)");
    end;
}
