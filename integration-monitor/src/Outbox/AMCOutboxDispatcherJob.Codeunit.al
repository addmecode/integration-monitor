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
        OutboxFailureHandler: Codeunit "AMC Outbox Failure Handler";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
    begin
        Outbox.SetFilter(Status, '%1|%2', Outbox.Status::ReadyToProcess, Outbox.Status::Failed);
        Outbox.SetFilter("Next Attempt At", '<=%1', CurrentDateTime());
        if Outbox.FindSet() then
            repeat
                if not OutboxProcessor.Run(Outbox) then
                    if not OutboxFailureHandler.Run(Outbox) then
                        ClearLastError();
            until Outbox.Next() = 0;
    end;
}
