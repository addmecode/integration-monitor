codeunit 50108 "AMC Outbox Dispatcher Job"
{
    trigger OnRun()
    begin
        ProcessEntries();
    end;

    local procedure ProcessEntries()
    var
        Outbox: Record "AMC Int. Outbox Entry";
    begin
        Outbox.SetLoadFields("Entry No.", "Message Type", Status, "Next Attempt At");
        Outbox.SetFilter(Status, '%1|%2|%3', Outbox.Status::New, Outbox.Status::Ready, Outbox.Status::Failed);
        Outbox.SetFilter("Next Attempt At", '<=%1', CurrentDateTime());
        if Outbox.FindSet() then
            repeat
                ProcessEntry(Outbox);
            until Outbox.Next() = 0;
    end;

    local procedure ProcessEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        Setup: Record "AMC Int. Message Setup";
        Handler: Interface "AMC IMessageHandler";
        Transport: Interface "AMC IHttpTransportHandler";
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        ResponseBody: InStream;
        HandlerResponseStream: InStream;
        InboxResponseStream: InStream;
        ErrorDetail: Text;
        TempBlob: Codeunit "Temp Blob";
        CreateInbox: Boolean;
        ErrorText: Text;
        HandlerErrorText: Text;
        TransportErrorText: Text;
        SendOk: Boolean;
        Now: DateTime;
        EndpointUrlMissingErr: Label 'Endpoint URL is required for message type %1.', Comment = '%1 = Message Type';

    begin
        Now := CurrentDateTime();

        if not Setup.Get(Outbox."Message Type") then
            exit;

        if not Setup.Enabled then
            exit;

        if Setup."Endpoint URL" = '' then
            Error(EndpointUrlMissingErr, Format(Setup."Message Type"));

        if not TryClaimOutbox(Outbox, Setup, Now) then
            exit;

        if Outbox."Attempt Count" > Setup."Max Attempts" then begin
            MarkMaxAttemptsExceeded(Outbox);
            exit;
        end;

        Handler := Outbox."Message Type";

        if not TryBuildRequest(Handler, Outbox, Request) then begin
            ErrorText := GetLastErrorText();
            EnsureEmptyTempBlob(TempBlob);
            FailOutbox(Outbox, Setup, ErrorText, ErrorDetail, TempBlob, Now);
            exit;
        end;

        Transport := Setup.Transport;

        SendOk := false;
        TransportErrorText := '';
        if not TrySend(Transport, Setup, Request, Response, ResponseBody, SendOk) then
            TransportErrorText := GetLastErrorText();

        if SendOk then
            EnsureTempBlob(ResponseBody, TempBlob)
        else
            EnsureEmptyTempBlob(TempBlob);

        TempBlob.CreateInStream(HandlerResponseStream);

        CreateInbox := false;
        HandlerErrorText := '';
        ErrorDetail := '';

        if not TryHandleSendResult(Handler, Outbox, SendOk, Response, HandlerResponseStream, CreateInbox, HandlerErrorText, ErrorDetail) then
            HandlerErrorText := GetLastErrorText();

        if HandlerErrorText <> '' then
            ErrorText := HandlerErrorText
        else
            if not SendOk then
                if TransportErrorText <> '' then
                    ErrorText := TransportErrorText
                else
                    ErrorText := SendFailedErr;

        if ErrorText <> '' then begin
            FailOutbox(Outbox, Setup, ErrorText, ErrorDetail, TempBlob, Now);
            exit;
        end;

        if CreateInbox then begin
            TempBlob.CreateInStream(InboxResponseStream);
            CreateInboxEntry(Outbox, InboxResponseStream, Now);
            Outbox.Status := Outbox.Status::WaitingResponse;
        end else
            Outbox.Status := Outbox.Status::Sent;

        Outbox."Sent At" := Now;
        ClearErrorInfo(Outbox);
        Outbox.Modify(true);
    end;

    local procedure CreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; var ResponseStream: InStream; Now: DateTime)
    var
        Inbox: Record "AMC Int. Inbox Entry";
        ResponseOutStream: OutStream;
    begin
        Inbox.Init();
        Inbox."Outbox Entry No." := Outbox."Entry No.";
        Inbox."Message Type" := Outbox."Message Type";
        Inbox.Status := Inbox.Status::New;
        Inbox."Correlation ID" := Outbox."Correlation ID";
        Inbox."Received At" := Now;
        Inbox."Next Attempt At" := Now;
        Inbox."Attempt Count" := 0;
        Inbox."Response Payload".CreateOutStream(ResponseOutStream);
        CopyStream(ResponseOutStream, ResponseStream);
        Inbox.Insert(true);
    end;

    local procedure ClearErrorInfo(var Outbox: Record "AMC Int. Outbox Entry")
    begin
        Outbox."Last Error" := '';
        Clear(Outbox."Error Details");
    end;

    local procedure MarkMaxAttemptsExceeded(var Outbox: Record "AMC Int. Outbox Entry")
    begin
        Outbox.Status := Outbox.Status::Failed;
        Outbox."Last Error" := MaxAttemptsExceededErr;
        Outbox.Modify(true);
    end;

    local procedure FailOutbox(var Outbox: Record "AMC Int. Outbox Entry"; Setup: Record "AMC Int. Message Setup"; ErrorText: Text; ErrorDetail: Text; var TempBlob: Codeunit "Temp Blob"; Now: DateTime)
    var
        OutboxRef: RecordRef;
    begin
        Outbox.Status := Outbox.Status::Failed;
        Outbox."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(Outbox."Last Error"));
        Outbox."Next Attempt At" := GetNextAttemptAt(Setup, Now);
        Outbox."Sent At" := 0DT;
        Outbox.Modify(true);

        OutboxRef.GetTable(Outbox);
        BlobHelper.WriteTextToBlob(OutboxRef, Outbox.FieldNo("Error Details"), ErrorDetail);
    end;

    local procedure GetNextAttemptAt(Setup: Record "AMC Int. Message Setup"; Now: DateTime): DateTime
    var
        Delay: Duration;
    begin
        if Setup."Base Retry Delay (sec)" <= 0 then
            exit(Now);

        Delay := Setup."Base Retry Delay (sec)" * 1000;
        exit(Now + Delay);
    end;

    [TryFunction]
    local procedure TryBuildRequest(Handler: Interface "AMC IMessageHandler"; Outbox: Record "AMC Int. Outbox Entry"; var Request: HttpRequestMessage)
    begin
        Handler.BuildRequest(Outbox, Request);
    end;

    [TryFunction]
    local procedure TryHandleSendResult(Handler: Interface "AMC IMessageHandler"; Outbox: Record "AMC Int. Outbox Entry"; SendOk: Boolean; Response: HttpResponseMessage; ResponseBody: InStream; var CreateInbox: Boolean; var ErrorText: Text; var ErrorDetail: Text)
    begin
        Handler.HandleSendResult(Outbox, SendOk, Response, ResponseBody, CreateInbox, ErrorText, ErrorDetail);
    end;

    [TryFunction]
    local procedure TrySend(Transport: Interface "AMC IHttpTransportHandler"; Setup: Record "AMC Int. Message Setup"; Request: HttpRequestMessage; var Response: HttpResponseMessage; var ResponseBody: InStream; var SendOk: Boolean)
    begin
        SendOk := Transport.Send(Request, Setup, Response, ResponseBody);
    end;

    [TryFunction]
    local procedure TryClaimOutbox(var Outbox: Record "AMC Int. Outbox Entry"; Setup: Record "AMC Int. Message Setup"; Now: DateTime): Boolean
    var
        CurrentOutbox: Record "AMC Int. Outbox Entry";
    begin
        if not CurrentOutbox.Get(Outbox."Entry No.") then
            exit(false);

        if not IsEligible(CurrentOutbox, Now) then
            exit(false);

        if CurrentOutbox."Attempt Count" > Setup."Max Attempts" then
            exit(false);

        CurrentOutbox.Status := CurrentOutbox.Status::Sending;
        CurrentOutbox."Attempt Count" := CurrentOutbox."Attempt Count" + 1;
        CurrentOutbox."Last Attempt At" := Now;
        CurrentOutbox.Modify(true);
        Commit();
        Outbox := CurrentOutbox;
        exit(true);
    end;

    local procedure IsEligible(Outbox: Record "AMC Int. Outbox Entry"; Now: DateTime): Boolean
    begin
        if Outbox.Status in [Outbox.Status::New, Outbox.Status::Ready, Outbox.Status::Failed] then
            exit(Outbox."Next Attempt At" <= Now);

        exit(false);
    end;

    local procedure EnsureTempBlob(var ResponseBody: InStream; var TempBlob: Codeunit "Temp Blob")
    var
        TempOutStream: OutStream;
    begin
        if TryCopyResponse(ResponseBody, TempBlob) then
            exit;

        TempBlob.CreateOutStream(TempOutStream);
        TempOutStream.WriteText('');
    end;

    local procedure EnsureEmptyTempBlob(var TempBlob: Codeunit "Temp Blob")
    var
        TempOutStream: OutStream;
    begin
        TempBlob.CreateOutStream(TempOutStream);
        TempOutStream.WriteText('');
    end;

    [TryFunction]
    local procedure TryCopyResponse(var ResponseBody: InStream; var TempBlob: Codeunit "Temp Blob")
    var
        TempOutStream: OutStream;
    begin
        TempBlob.CreateOutStream(TempOutStream);
        CopyStream(TempOutStream, ResponseBody);
    end;

    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        MaxAttemptsExceededErr: Label 'Max attempts exceeded.', Locked = true;
        SendFailedErr: Label 'HTTP send failed.', Locked = true;
}
