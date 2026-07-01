namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using System.TestLibraries.Utilities;

codeunit 50132 "AMC Inbox Failure Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

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
        this.TestLibrary.AssertDateTimeIsRecent(Inbox."Last Attempt At", BeforeRun, AfterRun, 'Last Attempt At');
        this.Assert.AreEqual(0DT, Inbox."Processed At", 'The failure handler should clear Processed At.');
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::Failed, Inbox.Status, 'The failure handler should mark the entry Failed.');
    end;

    [Test]
    procedure WhenFailureUnderMaxAttempts_ThenAppliesLinearBackoff()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        ExpectedNextAttempt: DateTime;
        RetryDelay: Duration;
        RetryDelaySeconds: Integer;
        EntryNo: Integer;
    begin
        // [SCENARIO] Under Max Attempts, Next Attempt At is scheduled at Last Attempt At + the linear delay.
        // [GIVEN] An entry whose resulting Attempt Count (2) stays below Max Attempts (5), with Base Retry Delay = 60s.
        RetryDelaySeconds := 60;
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, RetryDelaySeconds);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::Processing);
        EntryNo := Inbox."Entry No.";
        Inbox."Attempt Count" := 1;
        Inbox.Modify(true);

        // [WHEN] The failure handler runs against it with a populated last error.
        this.RunFailureHandler(Inbox);

        // [THEN] Next Attempt At equals the persisted Last Attempt At plus the linear backoff delay.
        Inbox.Get(EntryNo);
        RetryDelay := RetryDelaySeconds * 1000;
        ExpectedNextAttempt := Inbox."Last Attempt At" + RetryDelay;
        this.Assert.AreEqual(ExpectedNextAttempt, Inbox."Next Attempt At", 'Next Attempt At should be Last Attempt At plus the linear backoff delay.');
    end;

    [Test]
    procedure WhenFailureAtMaxAttempts_ThenNextAttemptStaysEmpty()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        PastDateTime: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] At or over Max Attempts, no further retry is scheduled (Next Attempt At stays 0DT).
        // [GIVEN] An entry whose resulting Attempt Count (3) reaches Max Attempts (3), with a non-zero Base Retry Delay.
        PastDateTime := CreateDateTime(DMY2Date(1, 1, 2020), 0T);
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 3, 60);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::Processing);
        EntryNo := Inbox."Entry No.";
        Inbox."Attempt Count" := 2;
        Inbox."Next Attempt At" := PastDateTime;
        Inbox.Modify(true);

        // [WHEN] The failure handler runs against it with a populated last error.
        this.RunFailureHandler(Inbox);

        // [THEN] Next Attempt At is cleared: attempts are exhausted, so no backoff is scheduled.
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(3, Inbox."Attempt Count", 'Guard: the resulting Attempt Count should reach Max Attempts.');
        this.Assert.AreEqual(0DT, Inbox."Next Attempt At", 'At/over Max Attempts, Next Attempt At should stay empty.');
    end;

    [Test]
    procedure WhenFailure_ThenLastErrorBlobPopulated()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        InboxRef: RecordRef;
        LastErrorText: Text;
        SimulatedError: Text;
        EntryNo: Integer;
    begin
        // [SCENARIO] The failure handler stores the formatted error text and call stack in the Last Error blob.
        // [GIVEN] An entry ready to be failed with a known last error.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, 0);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::Processing);
        EntryNo := Inbox."Entry No.";

        // [WHEN] The failure handler runs against it with a populated last error.
        SimulatedError := this.RunFailureHandler(Inbox);

        // [THEN] The Last Error blob carries the formatted "Error:…\Call Stack:…" message.
        Inbox.Get(EntryNo);
        InboxRef.GetTable(Inbox);
        LastErrorText := BlobHelper.ReadBlobAsText(InboxRef, Inbox.FieldNo("Last Error"));
        this.Assert.IsTrue(StrPos(LastErrorText, 'Error:') > 0, 'The Last Error blob should contain the Error: section.');
        this.Assert.IsTrue(StrPos(LastErrorText, SimulatedError) > 0, 'The Last Error blob should contain the simulated error text.');
        this.Assert.IsTrue(StrPos(LastErrorText, 'Call Stack:') > 0, 'The Last Error blob should contain the Call Stack: section.');
    end;

    local procedure RunFailureHandler(var Inbox: Record "AMC Int. Inbox Entry"): Text
    var
        InboxFailureHandler: Codeunit "AMC Inbox Failure Handler";
        SimulatedError: Text;
    begin
        // Populate the last-error context the handler reads, mirroring a failed processor Run,
        // then run the handler. Returns the simulated error text for Last Error blob assertions.
        SimulatedError := this.TestLibrary.SimulateLastError();
        InboxFailureHandler.Run(Inbox);
        exit(SimulatedError);
    end;
}
