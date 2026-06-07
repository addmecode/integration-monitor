namespace Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Setup;

codeunit 50128 "AMC Inbox Failure Handler"
{
    TableNo = "AMC Int. Inbox Entry";

    trigger OnRun()
    var
        InboxErrorMessageLbl: Label 'Error:\ %1 \Call Stack:\ %2', Comment = '%1 = Error text, %2 = Error call stack', Locked = true;
    begin
        this.MarkInboxAsFailed(Rec, StrSubstNo(InboxErrorMessageLbl, GetLastErrorText(), GetLastErrorCallStack()));
    end;

    local procedure MarkInboxAsFailed(var Inbox: Record "AMC Int. Inbox Entry"; ErrorText: Text)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
    begin
        Inbox."Processed At" := 0DT;
        Inbox."Attempt Count" += 1;
        Inbox."Last Attempt At" := CurrentDateTime;

        if IntMessageSetup.Get(Inbox."Message Type") then begin
            if Inbox."Attempt Count" >= IntMessageSetup."Max Attempts" then
                Inbox.Status := Inbox.Status::Failed
            else begin
                Inbox.Status := Inbox.Status::Failed;
                Inbox."Next Attempt At" := this.GetNextAttemptAt(Inbox, IntMessageSetup);
            end;
        end else
            Inbox.Status := Inbox.Status::Failed;

        this.SetLastError(Inbox, ErrorText);
        Inbox.Modify(true);
    end;

    local procedure GetNextAttemptAt(Inbox: Record "AMC Int. Inbox Entry"; IntMessageSetup: Record "AMC Int. Message Setup"): DateTime
    var
        Delay: Duration;
    begin
        Delay := IntMessageSetup."Base Retry Delay (sec)" * 1000;
        exit(Inbox."Last Attempt At" + Delay);
    end;

    local procedure SetLastError(var Inbox: Record "AMC Int. Inbox Entry"; ErrorText: Text)
    var
        LastErrorResponseOutStream: OutStream;
    begin
        Inbox."Last Error".CreateOutStream(LastErrorResponseOutStream);
        LastErrorResponseOutStream.Write(ErrorText);
    end;
}
