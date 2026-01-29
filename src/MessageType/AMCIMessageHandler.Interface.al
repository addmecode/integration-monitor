interface "AMC IMessageHandler"
{
    procedure BuildRequest(Outbox: Record "AMC Int. Outbox Entry"; var Request: HttpRequestMessage);
    procedure HandleSendResult(Outbox: Record "AMC Int. Outbox Entry"; SendOk: Boolean; Response: HttpResponseMessage; ResponseBody: InStream; var CreateInbox: Boolean; var ErrorText: Text; var ErrorDetail: Text);
    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry"; var Success: Boolean; var ErrorText: Text; var ErrorDetail: Text);
}
