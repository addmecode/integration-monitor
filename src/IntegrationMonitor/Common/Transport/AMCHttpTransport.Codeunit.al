codeunit 50107 "AMC Http Transport" implements "AMC IHttpTransport"
{
  /// <summary>
  /// Sends an HTTP request and returns the response and response body.
  /// </summary>
  /// <param name="Request">HTTP request message to send.</param>
  /// <param name="Response">HTTP response message.</param>
  /// <param name="ResponseBody">Response body stream, if available.</param>
  /// <returns>True if the request was sent, otherwise false.</returns>
  procedure Send(Request: HttpRequestMessage; var Response: HttpResponseMessage; var ResponseBody: InStream): Boolean
  var
    Client: HttpClient;
  begin
    if Timeout > 0 then
      Client.Timeout := Timeout;

    if AuthProfileCode <> '' then
      ApplyAuth(Client, Request, AuthProfileCode);

    if not Client.Send(Request, Response) then
      exit(false);

    TryReadResponseBody(Response, ResponseBody);
    exit(true);
  end;

  /// <summary>
  /// Sets the timeout (in milliseconds) for HTTP requests.
  /// </summary>
  /// <param name="TimeoutMs">Timeout in milliseconds.</param>
  procedure SetTimeout(TimeoutMs: Integer)
  begin
    if TimeoutMs <= 0 then
      Timeout := 0
    else
      Timeout := TimeoutMs;
  end;

  /// <summary>
  /// Sets the authentication profile code used by the transport.
  /// </summary>
  /// <param name="NewAuthProfileCode">Auth profile code.</param>
  procedure SetAuthProfileCode(NewAuthProfileCode: Code[20])
  begin
    AuthProfileCode := NewAuthProfileCode;
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

  var
    Timeout: Duration;
    AuthProfileCode: Code[20];
}

