codeunit 50112 "AMC Outbox Processor"
{
    TableNo = "AMC Int. Outbox Entry";

    trigger OnRun()
    begin
        ProcessEntry(Rec);
    end;

    local procedure ProcessEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        MessageHandler: Interface "AMC IMessageHandler";
        TransportHandler: Interface "AMC IHttpTransportHandler";
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        TryProcessOn: DateTime;
    begin
        //todo delete the try functions and move the whole code to separate codeunit
        // how to handle status = failed or canceled, lastError and Error detail - global var? - leave only one field - error message as blob and add action that display its content

        TryProcessOn := CurrentDateTime();
        IntMessageSetup.get(Outbox."Message Type");
        if not ShouldProcessEntry(Outbox, TryProcessOn) then
            exit;
        ValidateSetupBeforeProcessingEntry(IntMessageSetup);

        MessageHandler := Outbox."Message Type";
        TransportHandler := IntMessageSetup.Transport;
        MessageHandler.BuildRequest(Outbox, Request);
        TransportHandler.Send(Request, IntMessageSetup, Response); //todo move it for now to the message interface
        ValidateResponse(Response);

        if IntMessageSetup."Process Response" then
            CreateInboxEntry(Outbox, Response);

        Outbox.Status := Outbox.Status::Sent;
        Outbox."Sent At" := TryProcessOn;
        Outbox.Modify(true);
    end;

    local procedure ShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; TryToProcessOn: DateTime): Boolean
    var
        ShouldProcess: Boolean;
    begin
        ShouldProcess := DoShouldProcessEntry(Outbox, TryToProcessOn);
        OnAfterShouldProcessEntry(Outbox, TryToProcessOn, ShouldProcess);
        exit(ShouldProcess);
    end;

    local procedure DoShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; TryToProcessOn: DateTime): Boolean
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
    begin
        //todo move to separate functions
        if not (Outbox.Status in [Outbox.Status::ReadyToProcess, Outbox.Status::Failed]) then
            exit(false);

        if Outbox."Next Attempt At" < TryToProcessOn then
            exit(false);

        IntMessageSetup.Get(Outbox."Message Type");
        if Outbox."Attempt Count" > IntMessageSetup."Max Attempts" then
            exit(false);
    end;

    local procedure ValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup"): Boolean
    var
        IsHandled: Boolean;
    begin
        OnBeforeValidateSetupBeforeProcessingEntry(IntMessageSetup, IsHandled);
        DoValidateSetupBeforeProcessingEntry(IntMessageSetup, IsHandled);
        OnAfterValidateSetupBeforeProcessingEntry(IntMessageSetup, IsHandled);
    end;

    local procedure DoValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup"; IsHandled: Boolean)
    var
        EndpointUrlMissingErr: Label '%1 with %2 must have %3 configured', Comment = '%1 = Int. Message Setup table caption, %2 = Message Type, %3 = Endpoint URL field caption';
        IntMessageSetupIsNotEnabledErr: Label '%1 with %2 must have %3 equal true.', Comment = '%1 = Int. Message Setup table caption, %2 = Message Type, %3 = Enabled field caption';
    begin
        if IsHandled then
            exit;

        if not IntMessageSetup.Enabled then
            Error(IntMessageSetupIsNotEnabledErr, IntMessageSetup.TableCaption, Format(IntMessageSetup."Message Type"), IntMessageSetup.FieldCaption(IntMessageSetup.Enabled));

        if IntMessageSetup."Endpoint URL" = '' then
            Error(EndpointUrlMissingErr, IntMessageSetup.TableCaption, Format(IntMessageSetup."Message Type"), IntMessageSetup.FieldCaption(IntMessageSetup."Endpoint URL"));
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
        IsHandled: Boolean;
    begin
        OnBeforeCreateInboxEntry(Outbox, Response, IsHandled);
        DoCreateInboxEntry(Outbox, Response, IsHandled);
        OnAfterCreateInboxEntry(Outbox, Response, IsHandled)
    end;

    local procedure DoCreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage; IsHandled: Boolean)
    var
        Inbox: Record "AMC Int. Inbox Entry";
        ResponseBody: Text;
        ResponseOutStream: OutStream;
    begin
        if IsHandled then
            exit;

        Inbox.Init();
        Inbox."Outbox Entry No." := Outbox."Entry No.";
        Inbox."Message Type" := Outbox."Message Type";
        Inbox.Status := Inbox.Status::ReadyToProcess;
        Inbox."Received At" := CurrentDateTime;
        Inbox."Next Attempt At" := Inbox."Received At";
        Inbox."Attempt Count" := 0;

        Response.Content.ReadAs(ResponseBody);
        Inbox."Response Payload".CreateOutStream(ResponseOutStream);
        ResponseOutStream.Write(ResponseBody);

        Inbox.Insert(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; TryToProcessOn: DateTime; var ShouldProcess: Boolean; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; TryToProcessOn: DateTime; var ShouldProcess: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage; var IsHandled: Boolean)
    begin
    end;
}
