codeunit 50109 "AMC Inbox Processor Job"
{
    trigger OnRun()
    begin
        ProcessEntries();
    end;

    local procedure ProcessEntries()
    var
        Inbox: Record "AMC Int. Inbox Entry";
    begin
        Inbox.SetLoadFields("Entry No.", "Message Type", Status, "Next Attempt At");
        Inbox.SetFilter(Status, '%1|%2|%3', Inbox.Status::New, Inbox.Status::Ready, Inbox.Status::Failed);
        Inbox.SetFilter("Next Attempt At", '<=%1', CurrentDateTime());
        if Inbox.FindSet() then
            repeat
                ProcessEntry(Inbox);
            until Inbox.Next() = 0;
    end;

    local procedure ProcessEntry(var Inbox: Record "AMC Int. Inbox Entry")
    var
        Setup: Record "AMC Int. Message Setup";
        Handler: Interface "AMC IMessageHandler";
        ErrorDetailsStream: InStream;
        ErrorText: Text;
        Success: Boolean;
        Now: DateTime;
    begin
        Now := CurrentDateTime();

        if not Setup.Get(Inbox."Message Type") then
            exit;

        if not Setup.Enabled then
            exit;

        if not TryClaimInbox(Inbox, Setup, Now) then
            exit;

        if Inbox."Attempt Count" > Setup."Max Attempts" then begin
            MarkMaxAttemptsExceeded(Inbox);
            exit;
        end;

        Handler := Inbox."Message Type";
        Success := false;
        ErrorText := '';
        Clear(ErrorDetailsStream);

        if not TryProcessResponse(Handler, Inbox, Setup, Success, ErrorText, ErrorDetailsStream) then
            ErrorText := GetLastErrorText();

        if (not Success) or (ErrorText <> '') then begin
            if ErrorText = '' then
                ErrorText := ProcessingFailedErr;

            FailInbox(Inbox, Setup, ErrorText, ErrorDetailsStream, Now);
            exit;
        end;

        Inbox.Status := Inbox.Status::Sent;
        Inbox."Processed At" := Now;
        ClearErrorInfo(Inbox);
        Inbox.Modify(true);
    end;

    local procedure ClearErrorInfo(var Inbox: Record "AMC Int. Inbox Entry")
    begin
        Inbox."Last Error" := '';
        Clear(Inbox."Error Details");
    end;

    local procedure MarkMaxAttemptsExceeded(var Inbox: Record "AMC Int. Inbox Entry")
    begin
        Inbox.Status := Inbox.Status::Failed;
        Inbox."Last Error" := MaxAttemptsExceededErr;
        Inbox.Modify(true);
    end;

    local procedure FailInbox(var Inbox: Record "AMC Int. Inbox Entry"; Setup: Record "AMC Int. Message Setup"; ErrorText: Text; var ErrorDetailsStream: InStream; Now: DateTime)
    var
        VariantInbox: Variant;
    begin
        Inbox.Status := Inbox.Status::Failed;
        Inbox."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(Inbox."Last Error"));
        Inbox."Next Attempt At" := GetNextAttemptAt(Setup, Now);
        Inbox."Processed At" := 0DT;
        Inbox.Modify(true);

        VariantInbox := Inbox;
        BlobHelper.TryCopyInStreamToBlob(VariantInbox, Inbox.FieldNo("Error Details"), ErrorDetailsStream);
    end;

    local procedure GetNextAttemptAt(Setup: Record "AMC Int. Message Setup"; Now: DateTime): DateTime
    var
        Delay: Duration;
    begin
        if Setup."Base Retry Delay (sec)" <= 0 then
            exit(Now);

        Delay := Setup."Base Retry Delay (sec)" * 1000;
        exit(Now + Delay);
    end;

    [TryFunction]
    local procedure TryProcessResponse(Handler: Interface "AMC IMessageHandler"; Inbox: Record "AMC Int. Inbox Entry"; Setup: Record "AMC Int. Message Setup"; var Success: Boolean; var ErrorText: Text; var ErrorDetailsStream: InStream)
    begin
        Handler.ProcessResponse(Inbox, Setup, Success, ErrorText, ErrorDetailsStream);
    end;

    [TryFunction]
    local procedure TryClaimInbox(var Inbox: Record "AMC Int. Inbox Entry"; Setup: Record "AMC Int. Message Setup"; Now: DateTime): Boolean
    var
        CurrentInbox: Record "AMC Int. Inbox Entry";
    begin
        if not CurrentInbox.Get(Inbox."Entry No.") then
            exit(false);

        if not IsEligible(CurrentInbox, Now) then
            exit(false);

        if CurrentInbox."Attempt Count" > Setup."Max Attempts" then
            exit(false);

        CurrentInbox.Status := CurrentInbox.Status::Sending;
        CurrentInbox."Attempt Count" := CurrentInbox."Attempt Count" + 1;
        CurrentInbox."Last Attempt At" := Now;
        CurrentInbox.Modify(true);
        Commit();
        Inbox := CurrentInbox;
        exit(true);
    end;

    local procedure IsEligible(Inbox: Record "AMC Int. Inbox Entry"; Now: DateTime): Boolean
    begin
        if Inbox.Status in [Inbox.Status::New, Inbox.Status::Ready, Inbox.Status::Failed] then
            exit(Inbox."Next Attempt At" <= Now);

        exit(false);
    end;

    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        MaxAttemptsExceededErr: Label 'Max attempts exceeded.', Locked = true;
        ProcessingFailedErr: Label 'Processing failed.', Locked = true;
}

