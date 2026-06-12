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
        MissingMessageSetupErr: Label 'Integration message setup for message type %1 does not exist. Inbox entry %2 cannot be processed.', Comment = '%1 = message type, %2 = inbox entry number';
    begin
        this.ProcessOn := CurrentDateTime();
        if not IntMessageSetup.Get(Inbox."Message Type") then
            Error(MissingMessageSetupErr, Format(Inbox."Message Type"), Inbox."Entry No.");

        if not this.ShouldProcessEntry(Inbox, IntMessageSetup) then
            exit;

        if not this.ClaimForProcessing(Inbox) then
            exit;

        this.ProcessClaimedEntry(Inbox, IntMessageSetup);
    end;

    local procedure ShouldProcessEntry(Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"): Boolean
    var
        ShouldProcess: Boolean;
    begin
        ShouldProcess := this.DoShouldProcessEntry(Inbox, IntMessageSetup);
        this.OnAfterShouldProcessEntry(Inbox, IntMessageSetup, ShouldProcess);

        exit(ShouldProcess);
    end;

    local procedure DoShouldProcessEntry(Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"): Boolean
    begin
        if not IntMessageSetup.Enabled then
            exit(false);
        if (Inbox.Status <> Inbox.Status::ReadyToProcess) and (Inbox.Status <> Inbox.Status::Failed) then
            exit(false);
        if Inbox."Next Attempt At" > this.ProcessOn then
            exit(false);
        if Inbox."Attempt Count" >= IntMessageSetup."Max Attempts" then
            exit(false);

        exit(true);
    end;

    local procedure ClaimForProcessing(var Inbox: Record "AMC Int. Inbox Entry"): Boolean
    begin
        Inbox.LockTable();
        if not Inbox.Get(Inbox."Entry No.") then
            exit(false);

        if (Inbox.Status <> Inbox.Status::ReadyToProcess) and (Inbox.Status <> Inbox.Status::Failed) then
            exit(false);

        Inbox.Status := Inbox.Status::Processing;
        Inbox.Modify(true);
        Commit();

        exit(true);
    end;

    local procedure ProcessClaimedEntry(var Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup")
    var
        MessageHandler: Interface "AMC IMessageHandler";
    begin
        this.ValidateSetupBeforeProcessingEntry(IntMessageSetup);

        MessageHandler := Inbox."Message Type";
        MessageHandler.ProcessResponse(Inbox);
        this.MarkInboxAsProcessed(Inbox);
    end;

    local procedure ValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup")
    begin
        this.DoValidateSetupBeforeProcessingEntry(IntMessageSetup);
        this.OnAfterValidateSetupBeforeProcessingEntry(IntMessageSetup);
    end;

    local procedure DoValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup")
    var
        MessageSetupDisabledErr: Label 'Integration message setup for message type %1 is disabled.', Comment = '%1 = message type';
    begin
        if not IntMessageSetup.Enabled then
            Error(MessageSetupDisabledErr, Format(IntMessageSetup."Message Type"));
    end;

    local procedure MarkInboxAsProcessed(var Inbox: Record "AMC Int. Inbox Entry")
    begin
        Inbox.Status := Inbox.Status::Processed;
        Inbox."Processed At" := this.ProcessOn;
        Inbox."Attempt Count" += 1;
        Inbox."Last Attempt At" := this.ProcessOn;
        Inbox.Modify(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterShouldProcessEntry(Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"; var ShouldProcess: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterValidateSetupBeforeProcessingEntry(IntMessageSetup: Record "AMC Int. Message Setup")
    begin
    end;

    var
        ProcessOn: DateTime;
}
