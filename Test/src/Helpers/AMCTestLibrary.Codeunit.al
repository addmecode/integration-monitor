namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;
using System.TestLibraries.Utilities;

/// <summary>
/// Deterministic setup factory for Integration Monitor tests. Keeps tests DRY:
/// every helper inserts a valid record using <c>Any</c> for values that do not matter.
/// </summary>
codeunit 50134 "AMC Test Library"
{
    /// <summary>
    /// Creates (or replaces) a Message Setup for the given type. Enabled is assigned
    /// directly, bypassing OnValidate, so callers can stage an enabled setup without
    /// satisfying the transport/auth requirements those tests assert on separately.
    /// </summary>
    procedure CreateMessageSetup(MessageType: Enum "AMC Int. Message Type"; Enabled: Boolean; MaxAttempts: Integer; BaseRetryDelaySec: Integer): Record "AMC Int. Message Setup"
    var
        Setup: Record "AMC Int. Message Setup";
    begin
        if Setup.Get(MessageType) then
            Setup.Delete(true);

        Setup.Init();
        Setup."Message Type" := MessageType;
        Setup."Max Attempts" := MaxAttempts;
        Setup."Base Retry Delay (sec)" := BaseRetryDelaySec;
        Setup.Enabled := Enabled;
        Setup.Insert(true);
        exit(Setup);
    end;

    /// <summary>Ensures a (disabled) Message Setup exists so entries of this type can be inserted.</summary>
    procedure EnsureMessageSetup(MessageType: Enum "AMC Int. Message Type")
    var
        Setup: Record "AMC Int. Message Setup";
    begin
        if Setup.Get(MessageType) then
            exit;
        this.CreateMessageSetup(MessageType, false, 1, 0);
    end;

    procedure CreateOutboxEntry(MessageType: Enum "AMC Int. Message Type"; Status: Enum "AMC Int. Outbox Status"): Record "AMC Int. Outbox Entry"
    var
        Outbox: Record "AMC Int. Outbox Entry";
    begin
        this.EnsureMessageSetup(MessageType);
        Outbox.Init();
        Outbox.Validate("Message Type", MessageType);
        Outbox.Insert(true);
        Outbox.Status := Status;
        Outbox.Modify(true);
        exit(Outbox);
    end;

    procedure CreateInboxEntry(MessageType: Enum "AMC Int. Message Type"; Status: Enum "AMC Int. Inbox Status"): Record "AMC Int. Inbox Entry"
    var
        Inbox: Record "AMC Int. Inbox Entry";
    begin
        this.EnsureMessageSetup(MessageType);
        Inbox.Init();
        Inbox.Validate("Message Type", MessageType);
        Inbox.Insert(true);
        Inbox.Status := Status;
        Inbox.Modify(true);
        exit(Inbox);
    end;

    procedure CreateAuthProfile(AuthType: Enum "AMC Int. Auth Type"; WithSecret: Boolean): Record "AMC Int. Auth Profile"
    var
        Profile: Record "AMC Int. Auth Profile";
        Any: Codeunit "Any";
    begin
        Profile.Init();
        Profile.Code := CopyStr(Any.AlphabeticText(10), 1, MaxStrLen(Profile.Code));
        Profile."Auth Type" := AuthType;
        Profile.Username := CopyStr(Any.AlphabeticText(10), 1, MaxStrLen(Profile.Username));
        Profile.Insert(true);

        if WithSecret then
            Profile.SetSecret(Any.AlphabeticText(20));
        exit(Profile);
    end;

    /// <summary>Writes text into a BLOB field of any record, via the production Blob Helper.</summary>
    procedure WriteBlobText(var TargetRecordRef: RecordRef; FieldNo: Integer; Value: Text)
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
    begin
        BlobHelper.WriteTextToBlob(TargetRecordRef, FieldNo, Value);
    end;

    /// <summary>Asserts a DateTime falls within the inclusive [LowerBound, UpperBound] window.</summary>
    procedure AssertDateTimeWithinRange(ActualDateTime: DateTime; LowerBound: DateTime; UpperBound: DateTime; FieldCaption: Text)
    var
        Assert: Codeunit "Library Assert";
        DateTimeOutOfRangeErr: Label '%1 should be within the expected date/time range.', Comment = '%1 = field caption';
    begin
        Assert.IsTrue(
            (ActualDateTime >= LowerBound) and (ActualDateTime <= UpperBound),
            StrSubstNo(DateTimeOutOfRangeErr, FieldCaption));
    end;

    /// <summary>
    /// Asserts a DateTime is ≈ now: within [LowerBound, UpperBound] widened by a small tolerance
    /// that absorbs SQL <c>datetime</c> rounding (~3.33 ms) and Windows clock granularity (~15 ms),
    /// so bracketed "just happened" checks stay deterministic. Use this for every "≈ now" assertion.
    /// </summary>
    procedure AssertDateTimeIsRecent(ActualDateTime: DateTime; LowerBound: DateTime; UpperBound: DateTime; FieldCaption: Text)
    var
        Tolerance: Duration;
    begin
        Tolerance := 1000;
        this.AssertDateTimeWithinRange(ActualDateTime, LowerBound - Tolerance, UpperBound + Tolerance, FieldCaption);
    end;

    /// <summary>
    /// Populates the platform last-error context (GetLastErrorText/GetLastErrorCallStack) the way a
    /// failed processor Run would, so failure-handler tests can drive the handler through Codeunit.Run.
    /// It fails a TryFunction, which rolls back only its own scope — the caller's staged records
    /// survive (a bare asserterror would roll back to the last commit and wipe them). Returns the
    /// simulated error text so callers can assert on the stored Last Error blob.
    /// </summary>
    procedure SimulateLastError(): Text
    begin
        if this.ThrowSimulatedError() then;
        exit(this.SimulatedErrorLbl());
    end;

    [TryFunction]
    local procedure ThrowSimulatedError()
    begin
        Error(this.SimulatedErrorLbl());
    end;

    local procedure SimulatedErrorLbl(): Text
    var
        SimulatedErrorTxt: Label 'Simulated processing failure.', Locked = true;
    begin
        exit(SimulatedErrorTxt);
    end;
}
