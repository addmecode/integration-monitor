namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Transport;
using Addmecode.IntegrationMonitor.Setup;

/// <summary>
/// Test transport handler. Returns the body configured in
/// <c>AMC Mock Transport State</c> instead of performing a real HTTP send.
///
/// LIMITATION: AL exposes no setter for <c>HttpResponseMessage.HttpStatusCode</c>
/// (it is a get-only built-in). A fabricated response therefore always reports
/// the default status (non-success), which only drives the FAILURE path through
/// <c>AMC Outbox Processor.ValidateResponse</c>. Simulating a successful (2xx)
/// response needs a different mechanism — to be decided in Phase 6 (e.g. mocking
/// the real HttpClient used by the default transport). See TESTPLAN Phase 6 note.
/// </summary>
codeunit 50144 "AMC Mock Http Transport" implements "AMC IHttpTransportHandler"
{
    procedure ValidateSetup(Setup: Record "AMC Int. Message Setup")
    begin
        // No endpoint validation for the mock transport.
    end;

    procedure Send(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage)
    var
        State: Codeunit "AMC Mock Transport State";
    begin
        Response.Content.WriteFrom(State.GetBody());
    end;
}
