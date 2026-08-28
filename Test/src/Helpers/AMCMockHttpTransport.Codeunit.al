namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Setup;
using Addmecode.IntegrationMonitor.Transport;

/// <summary>
/// Test transport handler. Returns the body configured in
/// <c>AMC Mock Transport State</c> instead of performing a real HTTP send.
///
/// STATUS-CODE LIMITATION: AL exposes no setter for <c>HttpResponseMessage.HttpStatusCode</c>
/// (it is a get-only built-in), and a fabricated response reports <c>IsSuccessStatusCode = true</c>
/// (default 2xx). So the mock cannot hand back a genuine non-2xx response to exercise the
/// <c>AMC Outbox Processor.ValidateResponse</c> error branch. Instead, when the configured status
/// code is non-success, the mock raises an error on <c>Send</c> — mirroring a real transport send
/// failure (<c>AMC Http Transport Default</c> likewise errors when the HTTP send does not succeed),
/// which routes the entry through the failure handler. A success (2xx) status returns the body only.
/// </summary>
codeunit 50136 "AMC Mock Http Transport" implements "AMC IHttpTransportHandler"
{
    procedure ValidateSetup(Setup: Record "AMC Int. Message Setup")
    begin
        // No endpoint validation for the mock transport.
    end;

    procedure Send(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage)
    var
        State: Codeunit "AMC Mock Transport State";
        MockSendFailedErr: Label 'HTTP request failed with status %1. Full response: \ %2', Comment = '%1 = HTTP status code, %2 = response body';
    begin
        Response.Content.WriteFrom(State.GetBody());
        if not State.IsSuccessStatusCode() then
            Error(MockSendFailedErr, State.GetStatusCode(), State.GetBody());
    end;
}
