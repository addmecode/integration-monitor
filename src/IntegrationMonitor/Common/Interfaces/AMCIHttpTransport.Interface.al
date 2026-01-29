interface "AMC IHttpTransport"
{
    procedure Send(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage; var ResponseBody: InStream): Boolean;
}
