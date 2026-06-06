namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;

codeunit 50118 "AMC Outbox Failure Handler"
{
    TableNo = "AMC Int. Outbox Entry";

    trigger OnRun()
    var
        OutboxErrorMessageLbl: Label 'Error: %1 /Call Stack: %2', Comment = '%1 = Error text, %2 = Error call stack', Locked = true;
    begin
        this.MarkOutboxAsFailed(Rec, StrSubstNo(OutboxErrorMessageLbl, GetLastErrorText(), GetLastErrorCallStack()));
    end;

    local procedure MarkOutboxAsFailed(var Outbox: Record "AMC Int. Outbox Entry"; ErrorText: Text)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        ResponseAlreadyReceived: Boolean;
    begin
        Outbox.LockTable();
        if not Outbox.Get(Outbox."Entry No.") then
            exit;

        ResponseAlreadyReceived := Outbox.Status = Outbox.Status::ResponseReceived;
        Outbox."Processed At" := 0DT;
        Outbox."Attempt Count" += 1;
        Outbox."Last Attempt At" := CurrentDateTime;
        if not ResponseAlreadyReceived then
            Outbox.Status := Outbox.Status::Failed;
        if IntMessageSetup.Get(Outbox."Message Type") then
            if Outbox."Attempt Count" < IntMessageSetup."Max Attempts" then
                Outbox."Next Attempt At" := this.GetNextAttemptAt(Outbox, IntMessageSetup);

        this.SetLastError(Outbox, ErrorText);
        Outbox.Modify(true);
    end;

    local procedure GetNextAttemptAt(Outbox: Record "AMC Int. Outbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"): DateTime
    var
        Delay: Duration;
    begin
        Delay := IntMessageSetup."Base Retry Delay (sec)" * 1000;
        exit(Outbox."Last Attempt At" + Delay);
    end;

    local procedure SetLastError(var Outbox: Record "AMC Int. Outbox Entry"; ErrorText: Text)
    var
        LastErrorResponseOutStream: OutStream;
    begin
        //todo: test this
        Outbox."Last Error".CreateOutStream(LastErrorResponseOutStream);
        LastErrorResponseOutStream.Write(ErrorText);
    end;
}
