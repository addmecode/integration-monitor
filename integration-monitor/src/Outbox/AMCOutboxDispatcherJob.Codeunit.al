namespace Addmecode.IntegrationMonitor.Outbox;

codeunit 50115 "AMC Outbox Dispatcher Job"
{
    trigger OnRun()
    begin
        this.ProcessEntries();
    end;

    local procedure ProcessEntries()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
    begin
        Outbox.SetCurrentKey(Status, "Next Attempt At");
        Outbox.SetFilter(Status, '%1|%2|%3', Outbox.Status::ReadyToProcess, Outbox.Status::Failed, Outbox.Status::ResponseReceived);
        Outbox.SetFilter("Next Attempt At", '<=%1', CurrentDateTime());
        if Outbox.FindSet() then
            repeat
                OutboxEntryMgt.ProcessEntry(Outbox);
            until Outbox.Next() = 0;
    end;
}
