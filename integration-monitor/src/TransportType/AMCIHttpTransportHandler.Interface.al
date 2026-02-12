interface "AMC IHttpTransportHandler"
{
    procedure Send(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage);
}
