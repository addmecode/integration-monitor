namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;

codeunit 50131 "AMC Outbox Cleanup Job"
{
    trigger OnRun()
    begin
        this.DeleteOutboxEntries();
    end;

    local procedure DeleteOutboxEntries()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        MessageSetup: Record "AMC Int. Message Setup";
        OutboxCleanupProcessor: Codeunit "AMC Outbox Cleanup Processor";
        DeleteCreatedBefore: DateTime;
    begin
        if MessageSetup.FindSet() then
            repeat
                if not this.ShouldDeleteOutboxEntries(MessageSetup) then
                    continue;
                DeleteCreatedBefore := CreateDateTime(CalcDate(MessageSetup."Delete Outbox Entr. Older Than", Today), 0T);

                Outbox.SetCurrentKey("Entry No.");
                Outbox.SetRange("Message Type", MessageSetup."Message Type");
                Outbox.SetFilter(Status, '%1|%2', Outbox.Status::Cancelled, Outbox.Status::Processed);
                Outbox.SetFilter("Created At", '<%1', DeleteCreatedBefore);
                if Outbox.FindSet() then
                    repeat
                        if OutboxCleanupProcessor.Run(Outbox) then;
                    until Outbox.Next() = 0;
            until MessageSetup.Next() = 0;
    end;

    local procedure ShouldDeleteOutboxEntries(MessageSetup: Record "AMC Int. Message Setup"): Boolean
    begin
        exit(Format(MessageSetup."Delete Outbox Entr. Older Than") <> '');
    end;
}
