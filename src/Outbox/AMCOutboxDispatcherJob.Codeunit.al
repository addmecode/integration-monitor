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
        Outbox.SetFilter(Status, '%1|%2', Outbox.Status::ReadyToProcess, Outbox.Status::Failed);
        Outbox.SetFilter("Next Attempt At", '<=%1', CurrentDateTime());
        if Outbox.FindSet() then
            repeat
                ProcessEntry(Outbox);
            until Outbox.Next() = 0;
    end;

    local procedure ProcessEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        MessageHandler: Interface "AMC IMessageHandler";
        TransportHandler: Interface "AMC IHttpTransportHandler";
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        CreateInbox: Boolean;
        Now: DateTime;
    begin
        //todo delete the try functions and move the whole code to separate codeunit
        // how to handle status = failed or canceled, lastError and Error detail - global var? - leave only one field - error message as blob and add action that display its content

        Now := CurrentDateTime();
        IntMessageSetup.get(Outbox."Message Type");
        if not ShouldProcessEntry(Outbox, Now) then
            exit;
        ValidateSetupBeforeProcessingEntry(Outbox."Message Type");

        MessageHandler := Outbox."Message Type";
        TransportHandler := IntMessageSetup.Transport;
        MessageHandler.BuildRequest(Outbox, Request);
        TransportHandler.Send(Request, IntMessageSetup, Response); //todo move it for now to the message interface
        ValidateResponse(Response);

        if IntMessageSetup."Process Response" then
            CreateInboxEntry(Outbox, Response);

        Outbox.Status := Outbox.Status::Sent;
        Outbox."Sent At" := Now;
        Outbox."Last Error" := '';
        Outbox.Modify(true);
    end;

    local procedure ShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; TryToProcessOn: DateTime): Boolean
    var
        IsHandled: Boolean;
        ShouldProcess: Boolean;
    begin
        ShouldProcess := true;
        OnBeforeShouldProcessEntry(Outbox, TryToProcessOn, ShouldProcess, IsHandled);
        DoShouldProcessEntry(Outbox, TryToProcessOn, ShouldProcess, IsHandled);
        OnAfterShouldProcessEntry(Outbox, TryToProcessOn, ShouldProcess, IsHandled);
        exit(ShouldProcess);
    end;

    local procedure DoShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; TryToProcessOn: DateTime; var ShouldProcess: Boolean; IsHandled: Boolean)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
    begin
        if IsHandled or (not ShouldProcess) then
            exit;

        if not (Outbox.Status in [Outbox.Status::ReadyToProcess, Outbox.Status::Failed]) then begin
            ShouldProcess := false;
            exit;
        end;

        if Outbox."Next Attempt At" < TryToProcessOn then begin
            ShouldProcess := false;
            exit;
        end;

        IntMessageSetup.Get(Outbox."Message Type");
        if Outbox."Attempt Count" > IntMessageSetup."Max Attempts" then begin
            ShouldProcess := false;
            exit;
        end;
    end;

    local procedure ValidateSetupBeforeProcessingEntry(MessageType: Enum "AMC Int. Message Type"): Boolean
    var
        IsHandled: Boolean;
    begin
        OnBeforeValidateSetupBeforeProcessingEntry(MessageType, IsHandled);
        DoValidateSetupBeforeProcessingEntry(MessageType, IsHandled);
        OnAfterValidateSetupBeforeProcessingEntry(MessageType, IsHandled);
    end;

    local procedure DoValidateSetupBeforeProcessingEntry(MessageType: Enum "AMC Int. Message Type"; IsHandled: Boolean)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        EndpointUrlMissingErr: Label '%1 with %2 must have %3 configured', Comment = '%1 = Int. Message Setup table caption, %2 = Message Type, %3 = Endpoint URL field caption';
        IntMessageSetupMissingErr: Label '%1 is required with message type %2.', Comment = '%1 = Int. Message Setup table caption, %2 = Message Type';
        IntMessageSetupIsNotEnabledErr: Label '%1 with %2 must have %3 equal true.', Comment = '%1 = Int. Message Setup table caption, %2 = Message Type, %3 = Enabled field caption';
    begin
        if IsHandled then
            exit;

        if not IntMessageSetup.Get(MessageType) then
            Error(IntMessageSetupMissingErr, IntMessageSetup.TableCaption, Format(MessageType));

        if not IntMessageSetup.Enabled then
            Error(IntMessageSetupIsNotEnabledErr, IntMessageSetup.TableCaption, Format(MessageType), IntMessageSetup.FieldCaption(IntMessageSetup.Enabled));

        if IntMessageSetup."Endpoint URL" = '' then
            Error(EndpointUrlMissingErr, IntMessageSetup.TableCaption, Format(MessageType), IntMessageSetup.FieldCaption(IntMessageSetup."Endpoint URL"));
    end;

    procedure ValidateResponse(Response: HttpResponseMessage)
    var
        ResponseBody: Text;
        HttpStatusErr: Label 'HTTP request failed with status %1. Full response: \ %2', Comment = '%1 = HTTP status code, %2 = Response body';
    begin
        if not Response.IsSuccessStatusCode then begin
            Response.Content.ReadAs(ResponseBody);
            Error(HttpStatusErr, Format(Response.HttpStatusCode), ResponseBody);
        end;
    end;

    local procedure CreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage)
    var
        Inbox: Record "AMC Int. Inbox Entry";
        ResponseBody: Text;
        ResponseOutStream: OutStream;
    begin
        Inbox.Init();
        Inbox."Outbox Entry No." := Outbox."Entry No.";
        Inbox."Message Type" := Outbox."Message Type";
        Inbox.Status := Inbox.Status::ReadyToProcess;
        Inbox."Correlation ID" := Outbox."Correlation ID"; //todo why? Outbox Entry No. is the relation
        Inbox."Received At" := CurrentDateTime;
        Inbox."Next Attempt At" := Inbox."Received At";
        Inbox."Attempt Count" := 0;

        Response.Content.ReadAs(ResponseBody);
        Inbox."Response Payload".CreateOutStream(ResponseOutStream);
        ResponseOutStream.Write(ResponseBody);

        Inbox.Insert(true);
    end;


    local procedure MarkEntryAsFailed(var Outbox: Record "AMC Int. Outbox Entry"; LastError: Text; ErrorDetails: Text)
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRecRef: RecordRef;
    begin
        // todo: should be calles somewhere
        Outbox.Status := Outbox.Status::Failed;
        Outbox."Last Error" := CopyStr(LastError, 1, MaxStrLen(Outbox."Last Error"));
        OutboxRecRef.GetTable(Outbox);
        BlobHelper.WriteTextToBlob(OutboxRecRef, Outbox.FieldNo(Outbox."Error Details"), ErrorDetails);
    end;


    local procedure FailOutbox(var Outbox: Record "AMC Int. Outbox Entry"; Setup: Record "AMC Int. Message Setup"; ErrorText: Text; ErrorDetail: Text; var TempBlob: Codeunit "Temp Blob"; Now: DateTime)
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
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

    local procedure TryClaimOutbox(var Outbox: Record "AMC Int. Outbox Entry"; Setup: Record "AMC Int. Message Setup"; Now: DateTime): Boolean
    var
        CurrentOutbox: Record "AMC Int. Outbox Entry";
    begin
        // todo set these somewhere
        CurrentOutbox."Attempt Count" := CurrentOutbox."Attempt Count" + 1;
        CurrentOutbox."Last Attempt At" := Now;
        CurrentOutbox.Modify(true);
        Commit();
        Outbox := CurrentOutbox;
        exit(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeValidateSetupBeforeProcessingEntry(MessageType: Enum "AMC Int. Message Type"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterValidateSetupBeforeProcessingEntry(MessageType: Enum "AMC Int. Message Type"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; TryToProcessOn: DateTime; var ShouldProcess: Boolean; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; TryToProcessOn: DateTime; var ShouldProcess: Boolean; var IsHandled: Boolean)
    begin
    end;
}
