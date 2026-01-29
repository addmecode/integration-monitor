codeunit 50110 "AMC Message Handler Default" implements "AMC IMessageHandler"
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

    /// <summary>
    /// Handles the HTTP send result and determines if an inbox entry should be created.
    /// </summary>
    /// <param name="Outbox">Outbox entry that was sent.</param>
    /// <param name="Setup">Message setup for the entry.</param>
    /// <param name="SendOk">True if the transport reported send success.</param>
    /// <param name="Response">HTTP response message.</param>
    /// <param name="ResponseBody">Response body stream.</param>
    /// <param name="CreateInbox">Set to true to create an inbox entry.</param>
    /// <param name="ErrorText">Error text if processing failed.</param>
    /// <param name="ErrorDetail">Optional error details text.</param>
    procedure HandleSendResult(Outbox: Record "AMC Int. Outbox Entry"; SendOk: Boolean; Response: HttpResponseMessage; ResponseBody: InStream; var CreateInbox: Boolean; var ErrorText: Text; var ErrorDetail: Text)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        SendFailedErr: Label 'HTTP send failed.', Locked = true;
        HttpStatusErr: Label 'HTTP request failed with status %1.', Comment = '%1 = HTTP status code';
    begin
        CreateInbox := false;
        ErrorText := '';
        ErrorDetail := '';

        if not SendOk then begin
            ErrorText := SendFailedErr;
            exit;
        end;

        if not Response.IsSuccessStatusCode then begin
            ErrorText := StrSubstNo(HttpStatusErr, Format(Response.HttpStatusCode));
            ResponseBody.Read(ErrorDetail);
            exit;
        end;

        if IntMessageSetup."Process Response" then
            CreateInbox := true;
    end;

    /// <summary>
    /// Processes an inbound response entry.
    /// </summary>
    /// <param name="Inbox">Inbox entry to process.</param>
    /// <param name="Setup">Message setup for the entry.</param>
    /// <param name="Success">Set to true if processing succeeded.</param>
    /// <param name="ErrorText">Error text if processing failed.</param>
    /// <param name="ErrorDetail">Optional error details text.</param>
    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry"; var Success: Boolean; var ErrorText: Text; var ErrorDetail: Text)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
    begin
        Success := true;
        ErrorText := '';
        ErrorDetail := '';
    end;
}
