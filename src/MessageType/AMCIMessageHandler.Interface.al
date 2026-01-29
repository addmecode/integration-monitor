interface "AMC IMessageHandler"
{
    procedure BuildRequest(Outbox: Record "AMC Int. Outbox Entry"; Setup: Record "AMC Int. Message Setup"; var Request: HttpRequestMessage);
    procedure HandleSendResult(Outbox: Record "AMC Int. Outbox Entry"; Setup: Record "AMC Int. Message Setup"; SendOk: Boolean; Response: HttpResponseMessage; ResponseBody: InStream; var CreateInbox: Boolean; var ErrorText: Text; var ErrorDetail: Text);
    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry"; Setup: Record "AMC Int. Message Setup"; var Success: Boolean; var ErrorText: Text; var ErrorDetail: Text);
}
