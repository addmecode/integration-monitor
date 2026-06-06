namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Setup;
using Addmecode.IntegrationMonitor.Transport;

codeunit 50116 "AMC Outbox Processor"
{
    TableNo = "AMC Int. Outbox Entry";

    trigger OnRun()
    begin
        this.ProcessEntry(Rec);
    end;

    local procedure ProcessEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        MessageHandler: Interface "AMC IMessageHandler";
        TransportHandler: Interface "AMC IHttpTransportHandler";
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        MissingMessageSetupErr: Label 'Integration message setup for message type %1 does not exist. Outbox entry %2 cannot be processed.', Comment = '%1 = message type, %2 = outbox entry number';
    begin
        //todo: refactor
        this.ProcessOn := CurrentDateTime();
        if not IntMessageSetup.Get(Outbox."Message Type") then
            Error(MissingMessageSetupErr, Format(Outbox."Message Type"), Outbox."Entry No.");

        if not this.ShouldProcessEntry(Outbox, IntMessageSetup) then
            exit;
        if Outbox.Status = Outbox.Status::ResponseReceived then begin
            this.CreateInboxEntry(Outbox);
            this.MarkOutboxAsProcessed(Outbox);
            exit;
        end;

        if not this.ClaimForSending(Outbox) then
            exit;

        this.ValidateSetupBeforeProcessingEntry(IntMessageSetup);

        MessageHandler := Outbox."Message Type";
        TransportHandler := IntMessageSetup.Transport;
        MessageHandler.BuildRequest(Outbox, Request);
        TransportHandler.Send(Request, IntMessageSetup, Response);
        this.ValidateResponse(Response);

        if IntMessageSetup."Process Response" then begin
            this.StoreResponse(Outbox, Response);
            this.CreateInboxEntry(Outbox);
        end;

        this.MarkOutboxAsProcessed(Outbox);
    end;

    local procedure MarkOutboxAsProcessed(var Outbox: Record "AMC Int. Outbox Entry")
    begin
        Outbox.Status := Outbox.Status::Processed;
        Outbox."Processed At" := this.ProcessOn;
        Outbox."Attempt Count" += 1;
        Outbox."Last Attempt At" := this.ProcessOn;
        Outbox.Modify(true);
    end;

    local procedure ClaimForSending(var Outbox: Record "AMC Int. Outbox Entry"): Boolean
    begin
        Outbox.LockTable();
        if not Outbox.Get(Outbox."Entry No.") then
            exit(false);

        if (Outbox.Status <> Outbox.Status::ReadyToProcess) and (Outbox.Status <> Outbox.Status::Failed) then
            exit(false);

        Outbox.Status := Outbox.Status::Sending;
        Outbox.Modify(true);
        Commit();

        exit(true);
    end;

    local procedure ShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"): Boolean
    var
        IsHandled: Boolean;
        ShouldProcess: Boolean;
    begin
        this.OnBeforeShouldProcessEntry(Outbox, IntMessageSetup, ShouldProcess, IsHandled);
        if IsHandled then
            exit(ShouldProcess);

        ShouldProcess := this.DoShouldProcessEntry(Outbox, IntMessageSetup);
        this.OnAfterShouldProcessEntry(Outbox, IntMessageSetup, ShouldProcess);
        exit(ShouldProcess);
    end;

    local procedure DoShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"): Boolean
    begin
        if not IntMessageSetup.Enabled then
            exit(false);
        if Outbox."Next Attempt At" > this.ProcessOn then
            exit(false);
        if Outbox."Attempt Count" > IntMessageSetup."Max Attempts" then
            exit(false);
        exit(true);
    end;

    local procedure ValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup")
    var
        IsHandled: Boolean;
    begin
        this.OnBeforeValidateSetupBeforeProcessingEntry(IntMessageSetup, IsHandled);
        if IsHandled then
            exit;

        this.DoValidateSetupBeforeProcessingEntry(IntMessageSetup);
        this.OnAfterValidateSetupBeforeProcessingEntry(IntMessageSetup);
    end;

    local procedure DoValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup")
    begin
        //todo: nothing for now. All the mandatory fields are handled by properties on the table
        if IntMessageSetup.Enabled then
            exit;
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

    local procedure StoreResponse(var Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage)
    var
        ResponseBody: Text;
        ResponseOutStream: OutStream;
    begin
        //todo: use helper
        Response.Content.ReadAs(ResponseBody);
        Clear(Outbox."Response Payload");
        Outbox."Response Payload".CreateOutStream(ResponseOutStream);
        ResponseOutStream.Write(ResponseBody);
        Outbox."Response Received At" := this.ProcessOn;
        Outbox.Status := Outbox.Status::ResponseReceived;
        Outbox.Modify(true);
        Commit();
    end;

    local procedure CreateInboxEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        IsHandled: Boolean;
    begin
        this.OnBeforeCreateInboxEntry(Outbox, IsHandled);
        if IsHandled then
            exit;

        this.DoCreateInboxEntry(Outbox);
        this.OnAfterCreateInboxEntry(Outbox);
    end;

    local procedure DoCreateInboxEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        Inbox: Record "AMC Int. Inbox Entry";
        ResponseInStream: InStream;
        ResponseOutStream: OutStream;
    begin
        // todo: use validate
        Inbox.Init();
        Inbox."Outbox Entry No." := Outbox."Entry No.";
        Inbox.Validate("Message Type", Outbox."Message Type");
        Inbox.Status := Inbox.Status::ReadyToProcess;
        Inbox."Created At" := this.ProcessOn;
        Inbox."Next Attempt At" := Inbox."Created At";
        Inbox."Attempt Count" := 0;
        Inbox."Source Record ID" := Outbox."Source Record ID";

        //todo: move to inbox table
        Outbox.CalcFields("Response Payload");
        Outbox."Response Payload".CreateInStream(ResponseInStream);
        Inbox."Response Payload".CreateOutStream(ResponseOutStream);
        CopyStream(ResponseOutStream, ResponseInStream);

        Inbox.Insert(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"; var ShouldProcess: Boolean; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterShouldProcessEntry(Outbox: Record "AMC Int. Outbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"; var ShouldProcess: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry")
    begin
    end;

    var
        ProcessOn: DateTime;
}
