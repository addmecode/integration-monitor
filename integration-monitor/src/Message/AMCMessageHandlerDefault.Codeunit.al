namespace Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;

codeunit 50114 "AMC Message Handler Default" implements "AMC IMessageHandler"
{
    procedure BuildRequest(Outbox: Record "AMC Int. Outbox Entry"; var Request: HttpRequestMessage)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        MessageMgt: Codeunit "AMC Message Mgt.";
    begin
        MessageMgt.GetMessageSetup(Outbox."Message Type", IntMessageSetup);
        this.InitializeJsonPostRequest(Request, IntMessageSetup."Endpoint URL");
        this.SetRequestContentFromOutbox(Outbox, Request);
    end;

    local procedure InitializeJsonPostRequest(var Request: HttpRequestMessage; EndpointUrl: Text)
    var
        HttpPostMethodLbl: Label 'POST', Locked = true;
    begin
        Request.Method := HttpPostMethodLbl;
        Request.SetRequestUri(EndpointUrl);
    end;

    local procedure SetRequestContentFromOutbox(Outbox: Record "AMC Int. Outbox Entry"; var Request: HttpRequestMessage)
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        Content: HttpContent;
        ContentHeaders: HttpHeaders;
        PayloadText: Text;
        ApplicationJsonContentTypeLbl: Label 'application/json', Locked = true;
        ContentTypeHeaderNameLbl: Label 'Content-Type', Locked = true;
    begin
        OutboxRef.GetTable(Outbox);
        PayloadText := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Request Payload"));
        if PayloadText = '' then
            exit;

        Content.WriteFrom(PayloadText);
        Content.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add(ContentTypeHeaderNameLbl, ApplicationJsonContentTypeLbl);
        Request.Content := Content;
    end;

    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry")
    begin
    end;

}
