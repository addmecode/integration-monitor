codeunit 50111 "AMC Outbox Dispatcher Job"
{
    trigger OnRun()
    begin
        ProcessEntries();
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
                    MarkOutboxAsFailed(Outbox, GetLastErrorText, GetLastErrorCallStack); // todo: what if this fail?
                    commit();
                end;
            until Outbox.Next() = 0;
    end;

    local procedure MarkOutboxAsFailed(Outbox: Record "AMC Int. Outbox Entry"; LastErrorText: Text; LastErrorCallStack: Text)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRecRef: RecordRef;
        OutboxErrorMessageLbl: Label 'Error: %1 /Call Stack: %2', Comment = '%1 = Error text, %2 = Error call stack', Locked = true;
    begin
        if not IntMessageSetup.Get(Outbox."Message Type") then
            exit; // todo

        Outbox."Sent At" := 0DT;
        Outbox."Attempt Count" += 1;
        Outbox."Last Attempt At" := CurrentDateTime;
        if Outbox."Attempt Count" >= IntMessageSetup."Max Attempts" then
            Outbox.Status := Outbox.Status::Cancelled
        else begin
            Outbox.Status := Outbox.Status::Failed;
            Outbox."Next Attempt At" := GetNextAttemptAt(IntMessageSetup, Outbox."Last Attempt At");
        end;

        OutboxRecRef.GetTable(Outbox);
        // todo: instead of using WriteTextToBlob, create AddError function to outbox table 
        BlobHelper.WriteTextToBlob(OutboxRecRef, Outbox.FieldNo(Outbox."Error Message"), StrSubstNo(OutboxErrorMessageLbl, LastErrorText, LastErrorCallStack));
    end;

    local procedure GetNextAttemptAt(IntMessageSetup: Record "AMC Int. Message Setup"; LastAttemptAt: DateTime): DateTime
    var
        Delay: Duration;
    begin
        if IntMessageSetup."Base Retry Delay (sec)" <= 0 then
            exit(LastAttemptAt);

        Delay := IntMessageSetup."Base Retry Delay (sec)" * 1000;
        exit(LastAttemptAt + Delay);
    end;
}
