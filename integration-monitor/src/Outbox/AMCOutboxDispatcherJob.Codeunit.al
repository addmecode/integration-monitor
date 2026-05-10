namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;
codeunit 50115 "AMC Outbox Dispatcher Job"
{
    trigger OnRun()
    begin
        this.ProcessEntries();
    end;

    local procedure ProcessEntries()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
    begin
        Outbox.SetFilter(Status, '%1|%2', Outbox.Status::ReadyToProcess, Outbox.Status::Failed);
        Outbox.SetFilter("Next Attempt At", '<=%1', CurrentDateTime());
        if Outbox.FindSet() then
            repeat
                if not OutboxProcessor.Run(Outbox) then begin
                    this.MarkOutboxAsFailed(Outbox, GetLastErrorText, GetLastErrorCallStack);
                    commit();
                end;
            until Outbox.Next() = 0;
    end;

    local procedure MarkOutboxAsFailed(Outbox: Record "AMC Int. Outbox Entry"; LastErrorText: Text; LastErrorCallStack: Text)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        OutboxErrorMessageLbl: Label 'Error: %1 /Call Stack: %2', Comment = '%1 = Error text, %2 = Error call stack', Locked = true;
        MaxAttempts: Integer;
    begin
        MaxAttempts := 0;
        if IntMessageSetup.Get(Outbox."Message Type") then
            MaxAttempts := IntMessageSetup."Max Attempts";

        Outbox."Sent At" := 0DT;
        Outbox."Attempt Count" += 1;
        Outbox."Last Attempt At" := CurrentDateTime;
        if Outbox."Attempt Count" >= MaxAttempts then
            Outbox.Status := Outbox.Status::Cancelled
        else begin
            Outbox.Status := Outbox.Status::Failed;
            Outbox."Next Attempt At" := Outbox.GetNextAttemptAt();
        end;

        Outbox.AddError(StrSubstNo(OutboxErrorMessageLbl, LastErrorText, LastErrorCallStack));
        Outbox.Modify(true);
    end;
}
