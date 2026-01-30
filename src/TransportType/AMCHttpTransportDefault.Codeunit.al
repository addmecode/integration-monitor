codeunit 50107 "AMC Http Transport Default" implements "AMC IHttpTransportHandler"
{
    /// <summary>
    /// Sends an HTTP request and returns the response and response body.
    /// </summary>
    /// <param name="Request">HTTP request message to send.</param>
    /// <param name="Setup">Message setup for the entry.</param>
    /// <param name="Response">HTTP response message.</param>
    /// <param name="ResponseBody">Response body stream, if available.</param>
    /// <returns>True if the request was sent, otherwise false.</returns>
    procedure Send(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage)
    var
        Client: HttpClient;
    begin
        if Setup."Timeout (ms)" > 0 then
            Client.Timeout := Setup."Timeout (ms)";

        if Setup."Auth Profile Code" <> '' then
            ApplyAuth(Client, Request, Setup."Auth Profile Code");

        Client.Send(Request, Response);
    end;

    local procedure ApplyAuth(var Client: HttpClient; var Request: HttpRequestMessage; AuthProfile: Code[20])
    begin
        OnApplyAuth(Client, Request, AuthProfile);
    end;

    [TryFunction]
    local procedure TryReadResponseBody(var Response: HttpResponseMessage; var ResponseBody: InStream)
    begin
        Response.Content.ReadAs(ResponseBody);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnApplyAuth(var Client: HttpClient; var Request: HttpRequestMessage; AuthProfile: Code[20])
    begin
    end;

}

