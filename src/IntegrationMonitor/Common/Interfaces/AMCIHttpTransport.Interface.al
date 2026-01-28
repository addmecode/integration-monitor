interface "AMC IHttpTransport"
{
    procedure Send(Request: HttpRequestMessage; var Response: HttpResponseMessage; var ResponseBody: InStream): Boolean;
}
