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
    begin
        this.ProcessOn := CurrentDateTime();
        IntMessageSetup.Get(Outbox."Message Type");
        if not this.ShouldProcessEntry(Outbox, IntMessageSetup) then
            exit;
        this.ValidateSetupBeforeProcessingEntry(IntMessageSetup);

        MessageHandler := Outbox."Message Type";
        TransportHandler := IntMessageSetup.Transport;
        MessageHandler.BuildRequest(Outbox, Request);
        TransportHandler.Send(Request, IntMessageSetup, Response);
        this.ValidateResponse(Response);

        if IntMessageSetup."Process Response" then
            this.CreateInboxEntry(Outbox, Response);

        Outbox.Status := Outbox.Status::Processed;
        Outbox."Processed At" := this.ProcessOn;
        Outbox.Modify(true);
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

    local procedure CreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage)
    var
        IsHandled: Boolean;
    begin
        this.OnBeforeCreateInboxEntry(Outbox, Response, IsHandled);
        if IsHandled then
            exit;

        this.DoCreateInboxEntry(Outbox, Response);
        this.OnAfterCreateInboxEntry(Outbox, Response);
    end;

    local procedure DoCreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage)
    var
        Inbox: Record "AMC Int. Inbox Entry";
        ResponseBody: Text;
        ResponseOutStream: OutStream;
    begin
        Inbox.Init();
        Inbox."Outbox Entry No." := Outbox."Entry No.";
        Inbox."Message Type" := Outbox."Message Type";
        Inbox.Status := Inbox.Status::ReadyToProcess;
        Inbox."Created At" := this.ProcessOn;
        Inbox."Next Attempt At" := Inbox."Created At";
        Inbox."Attempt Count" := 0;

        //todo: move to inbox table
        Response.Content.ReadAs(ResponseBody);
        Inbox."Response Payload".CreateOutStream(ResponseOutStream);
        ResponseOutStream.Write(ResponseBody);

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
    local procedure OnBeforeCreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterCreateInboxEntry(Outbox: Record "AMC Int. Outbox Entry"; Response: HttpResponseMessage)
    begin
    end;

    var
        ProcessOn: DateTime;
}
