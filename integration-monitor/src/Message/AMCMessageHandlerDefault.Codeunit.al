namespace Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;

codeunit 50114 "AMC Message Handler Default" implements "AMC IMessageHandler"
{
    /// <summary>
    /// Builds an outbound HTTP request based on the outbox entry and setup.
    /// </summary>
    /// <param name="Outbox">Outbox entry to send.</param>
    /// <param name="Setup">Message setup for the entry.</param>
    /// <param name="Request">HTTP request message to populate.</param>
    procedure BuildRequest(Outbox: Record "AMC Int. Outbox Entry"; var Request: HttpRequestMessage)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        PayloadText: Text;
    begin
        IntMessageSetup.Get(Outbox."Message Type");

        Request.Method := 'POST';
        Request.SetRequestUri(IntMessageSetup."Endpoint URL");

        OutboxRef.GetTable(Outbox);
        PayloadText := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Request Payload"));
        if PayloadText <> '' then begin
            Content.WriteFrom(PayloadText);
            Content.GetHeaders(ContentHeaders);
            ContentHeaders.Clear();
            ContentHeaders.Add('Content-Type', 'application/json');
            Request.Content := Content;
        end;
    end;

    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry")
    begin

    end;
}
