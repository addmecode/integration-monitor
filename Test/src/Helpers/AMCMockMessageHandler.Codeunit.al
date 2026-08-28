namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;

/// <summary>
/// Test message handler whose <c>ProcessResponse</c> is a no-op that always succeeds.
/// Lets inbox-processor tests drive a full, successful Run (claim → handler → finalize)
/// without depending on a concrete message handler's payload/source-record requirements.
/// </summary>
codeunit 50142 "AMC Mock Message Handler" implements "AMC IMessageHandler"
{
    procedure BuildRequest(Outbox: Record "AMC Int. Outbox Entry"; var Request: HttpRequestMessage)
    begin
        // Not exercised by the inbox-processing path.
    end;

    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry")
    begin
        // Successful no-op: the handler leaves finalization to the processor.
    end;
}
