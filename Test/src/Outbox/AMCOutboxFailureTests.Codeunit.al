namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using System.TestLibraries.Utilities;

codeunit 50139 "AMC Outbox Failure Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";
        SimulatedErrorTxt: Label 'Simulated processing failure.', Locked = true;

    [Test]
    procedure WhenFailureUnderMaxAttempts_ThenIncrementsAndMarksFailed()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        PastDateTime: DateTime;
        BeforeRun: DateTime;
        AfterRun: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] The failure handler increments the attempt count and marks the entry Failed.
        // [GIVEN] An entry with Attempt Count = 2 and a setup whose Max Attempts (5) exceeds Attempt Count + 1.
        PastDateTime := CreateDateTime(DMY2Date(1, 1, 2020), 0T);
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, 0);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::Sending);
        EntryNo := Outbox."Entry No.";
        Outbox."Attempt Count" := 2;
        Outbox."Processed At" := PastDateTime;
        Outbox.Modify(true);

        // [WHEN] The failure handler runs against it with a populated last error.
        BeforeRun := CurrentDateTime();
        this.RunFailureHandler(Outbox);
        AfterRun := CurrentDateTime();

        // [THEN] Attempt Count is incremented, Last Attempt At is ≈ now, Processed At is cleared, and Status is Failed.
        Outbox.Get(EntryNo);
        this.Assert.AreEqual(3, Outbox."Attempt Count", 'The failure handler should increment Attempt Count by 1.');
        this.AssertRecentTimestamp(Outbox."Last Attempt At", BeforeRun, AfterRun, 'Last Attempt At');
        this.Assert.AreEqual(0DT, Outbox."Processed At", 'The failure handler should clear Processed At.');
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::Failed, Outbox.Status, 'The failure handler should mark the entry Failed.');
    end;

    [Test]
    procedure WhenFailureUnderMaxAttempts_ThenAppliesLinearBackoff()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        ExpectedNextAttempt: DateTime;
        RetryDelay: Duration;
        RetryDelaySeconds: Integer;
        EntryNo: Integer;
    begin
        // [SCENARIO] Under Max Attempts, Next Attempt At is scheduled at Last Attempt At + the linear delay.
        // [GIVEN] An entry whose resulting Attempt Count (2) stays below Max Attempts (5), with Base Retry Delay = 60s.
        RetryDelaySeconds := 60;
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, RetryDelaySeconds);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::Sending);
        EntryNo := Outbox."Entry No.";
        Outbox."Attempt Count" := 1;
        Outbox.Modify(true);

        // [WHEN] The failure handler runs against it with a populated last error.
        this.RunFailureHandler(Outbox);

        // [THEN] Next Attempt At equals the persisted Last Attempt At plus the linear backoff delay.
        Outbox.Get(EntryNo);
        RetryDelay := RetryDelaySeconds * 1000;
        ExpectedNextAttempt := Outbox."Last Attempt At" + RetryDelay;
        this.Assert.AreEqual(ExpectedNextAttempt, Outbox."Next Attempt At", 'Next Attempt At should be Last Attempt At plus the linear backoff delay.');
    end;

    local procedure RunFailureHandler(var Outbox: Record "AMC Int. Outbox Entry")
    var
        OutboxFailureHandler: Codeunit "AMC Outbox Failure Handler";
    begin
        // Populate the last-error context the handler reads, mirroring a failed processor Run.
        // A failed TryFunction rolls back only its own scope (unlike a bare asserterror, which
        // would roll back to the last commit and wipe the entry the test just created).
        if this.ThrowSimulatedError() then;
        OutboxFailureHandler.Run(Outbox);
    end;

    [TryFunction]
    local procedure ThrowSimulatedError()
    begin
        Error(this.SimulatedErrorTxt);
    end;

    local procedure AssertRecentTimestamp(ActualDateTime: DateTime; LowerBound: DateTime; UpperBound: DateTime; FieldCaption: Text)
    var
        Tolerance: Duration;
    begin
        // BC persists DateTime as SQL `datetime` (rounded to ~3.33 ms) and the Windows clock
        // granularity is ~15 ms, so widen the window slightly to keep the "≈ now" check deterministic.
        Tolerance := 1000;
        this.TestLibrary.AssertDateTimeWithinRange(ActualDateTime, LowerBound - Tolerance, UpperBound + Tolerance, FieldCaption);
    end;
}
