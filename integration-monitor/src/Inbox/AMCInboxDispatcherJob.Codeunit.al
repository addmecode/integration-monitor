namespace Addmecode.IntegrationMonitor.Inbox;

codeunit 50117 "AMC Inbox Dispatcher Job"
{
    trigger OnRun()
    begin
        this.ProcessEntries();
    end;

    local procedure ProcessEntries()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        InboxFailureHandler: Codeunit "AMC Inbox Failure Handler";
        InboxProcessor: Codeunit "AMC Inbox Processor";
    begin
        Inbox.SetCurrentKey("Entry No.");
        Inbox.SetFilter(Status, '%1|%2', Inbox.Status::ReadyToProcess, Inbox.Status::Failed);
        Inbox.SetFilter("Next Attempt At", '<=%1', CurrentDateTime());
        if Inbox.FindSet() then
            repeat
                if not InboxProcessor.Run(Inbox) then
                    if not InboxFailureHandler.Run(Inbox) then
                        ClearLastError();
            until Inbox.Next() = 0;
    end;
}
