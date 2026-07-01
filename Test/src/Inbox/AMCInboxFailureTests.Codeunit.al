namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using System.TestLibraries.Utilities;

codeunit 50140 "AMC Inbox Failure Tests"
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
        Inbox: Record "AMC Int. Inbox Entry";
        PastDateTime: DateTime;
        BeforeRun: DateTime;
        AfterRun: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] The failure handler increments the attempt count and marks the entry Failed.
        // [GIVEN] An entry with Attempt Count = 2 and a setup whose Max Attempts (5) exceeds Attempt Count + 1.
        PastDateTime := CreateDateTime(DMY2Date(1, 1, 2020), 0T);
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, 0);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::Processing);
        EntryNo := Inbox."Entry No.";
        Inbox."Attempt Count" := 2;
        Inbox."Processed At" := PastDateTime;
        Inbox.Modify(true);

        // [WHEN] The failure handler runs against it with a populated last error.
        BeforeRun := CurrentDateTime();
        this.RunFailureHandler(Inbox);
        AfterRun := CurrentDateTime();

        // [THEN] Attempt Count is incremented, Last Attempt At is ≈ now, Processed At is cleared, and Status is Failed.
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(3, Inbox."Attempt Count", 'The failure handler should increment Attempt Count by 1.');
        this.AssertRecentTimestamp(Inbox."Last Attempt At", BeforeRun, AfterRun, 'Last Attempt At');
        this.Assert.AreEqual(0DT, Inbox."Processed At", 'The failure handler should clear Processed At.');
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::Failed, Inbox.Status, 'The failure handler should mark the entry Failed.');
    end;

    local procedure RunFailureHandler(var Inbox: Record "AMC Int. Inbox Entry")
    var
        InboxFailureHandler: Codeunit "AMC Inbox Failure Handler";
    begin
        // Populate the last-error context the handler reads, mirroring a failed processor Run.
        // A failed TryFunction rolls back only its own scope (unlike a bare asserterror, which
        // would roll back to the last commit and wipe the entry the test just created).
        if this.ThrowSimulatedError() then;
        InboxFailureHandler.Run(Inbox);
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
