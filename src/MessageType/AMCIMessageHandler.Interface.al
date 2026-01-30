interface "AMC IMessageHandler"
{
    procedure BuildRequest(Outbox: Record "AMC Int. Outbox Entry"; var Request: HttpRequestMessage);
    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry"; var Success: Boolean);
}
