namespace Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Setup;
using Addmecode.IntegrationMonitor.Transport;

codeunit 50127 "AMC Inbox Processor"
{
    TableNo = "AMC Int. Inbox Entry";

    trigger OnRun()
    begin
        this.ProcessEntry(Rec);
    end;

    local procedure ProcessEntry(var Inbox: Record "AMC Int. Inbox Entry")
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        MessageHandler: Interface "AMC IMessageHandler";
    begin
        this.ProcessOn := CurrentDateTime();
        IntMessageSetup.Get(Inbox."Message Type");
        if not this.ShouldProcessEntry(Inbox, IntMessageSetup) then
            exit;
        this.ValidateSetupBeforeProcessingEntry(IntMessageSetup);

        MessageHandler := Inbox."Message Type";
        MessageHandler.ProcessResponse(Inbox);
        Inbox.Status := Inbox.Status::Processed;
        Inbox."Processed At" := this.ProcessOn;
        Inbox.Modify(true);
    end;

    local procedure ShouldProcessEntry(Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"): Boolean
    var
        IsHandled: Boolean;
        ShouldProcess: Boolean;
    begin
        this.OnBeforeShouldProcessEntry(Inbox, IntMessageSetup, ShouldProcess, IsHandled);
        if IsHandled then
            exit(ShouldProcess);

        ShouldProcess := this.DoShouldProcessEntry(Inbox, IntMessageSetup);
        this.OnAfterShouldProcessEntry(Inbox, IntMessageSetup, ShouldProcess);
        exit(ShouldProcess);
    end;

    local procedure DoShouldProcessEntry(Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"): Boolean
    begin
        if not IntMessageSetup.Enabled then
            exit(false);
        if Inbox."Next Attempt At" > this.ProcessOn then
            exit(false);
        if Inbox."Attempt Count" > IntMessageSetup."Max Attempts" then
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

    [IntegrationEvent(false, false)]
    local procedure OnBeforeShouldProcessEntry(Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"; var ShouldProcess: Boolean; var IsHandled: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterShouldProcessEntry(Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"; var ShouldProcess: Boolean)
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

    var
        ProcessOn: DateTime;
}
