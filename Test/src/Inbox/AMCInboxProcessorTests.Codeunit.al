namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using System.TestLibraries.Utilities;

codeunit 50141 "AMC Inbox Processor Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenSetupDisabled_ThenEntryLeftUntouched()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an entry whose message setup is disabled, leaving it untouched.
        // [GIVEN] A disabled message setup and a ReadyToProcess inbox entry.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, 0);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        EntryNo := Inbox."Entry No.";

        // [WHEN] The processor processes the entry.
        this.RunProcessor(Inbox);

        // [THEN] The entry is left untouched: a disabled setup means no claim and no processing.
        this.AssertInboxUntouched(EntryNo, Enum::"AMC Int. Inbox Status"::ReadyToProcess, 0);
    end;

    [Test]
    procedure WhenStatusNotEligible_ThenEntryLeftUntouched()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an entry whose status is outside the eligible set
        // (Inbox: ReadyToProcess/Failed), even when the setup is enabled.
        // [GIVEN] An enabled setup and a Processed inbox entry.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, true, 5, 0);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::Processed);
        EntryNo := Inbox."Entry No.";

        // [WHEN] The processor processes the entry.
        this.RunProcessor(Inbox);

        // [THEN] The entry is left untouched: an ineligible status is skipped.
        this.AssertInboxUntouched(EntryNo, Enum::"AMC Int. Inbox Status"::Processed, 0);
    end;

    [Test]
    procedure WhenNextAttemptInFuture_ThenEntryLeftUntouched()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        FutureDateTime: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an otherwise eligible entry whose retry delay has not yet elapsed.
        // [GIVEN] An enabled setup and a ReadyToProcess entry whose Next Attempt At is in the future.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, true, 5, 0);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        EntryNo := Inbox."Entry No.";
        FutureDateTime := CurrentDateTime() + (60 * 60 * 1000);
        Inbox."Next Attempt At" := FutureDateTime;
        Inbox.Modify(true);

        // [WHEN] The processor processes the entry.
        this.RunProcessor(Inbox);

        // [THEN] The entry is left untouched: the retry delay has not yet elapsed.
        this.AssertInboxUntouched(EntryNo, Enum::"AMC Int. Inbox Status"::ReadyToProcess, 0);
    end;

    [Test]
    procedure WhenAttemptsExhausted_ThenEntryLeftUntouched()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        MaxAttempts: Integer;
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an entry whose attempts are exhausted (Attempt Count >= Max Attempts).
        // [GIVEN] An enabled setup with Max Attempts = 3 and a ReadyToProcess entry already at 3 attempts.
        MaxAttempts := 3;
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, true, MaxAttempts, 0);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        EntryNo := Inbox."Entry No.";
        Inbox."Attempt Count" := MaxAttempts;
        Inbox.Modify(true);

        // [WHEN] The processor processes the entry.
        this.RunProcessor(Inbox);

        // [THEN] The entry is left untouched: no further attempt is made once attempts are exhausted.
        this.AssertInboxUntouched(EntryNo, Enum::"AMC Int. Inbox Status"::ReadyToProcess, MaxAttempts);
    end;

    [Test]
    procedure WhenClaimEligibleEntry_ThenTransitionsToProcessing()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        InboxProcessor: Codeunit "AMC Inbox Processor";
        EntryNo: Integer;
    begin
        // [SCENARIO] ClaimForProcessing locks an eligible entry, commits the Processing status,
        // and refuses to re-claim an entry that is no longer eligible.
        // [GIVEN] An eligible (ReadyToProcess) inbox entry.
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        EntryNo := Inbox."Entry No.";

        // [WHEN] The entry is claimed for processing.
        // [THEN] The claim succeeds.
        this.Assert.IsTrue(InboxProcessor.ClaimForProcessing(Inbox), 'Claiming an eligible entry should succeed.');

        // [THEN] A fresh read confirms the lock-and-set committed the Processing status.
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::Processing, Inbox.Status, 'A claimed entry should be Processing.');

        // [THEN] A second claim on the now non-eligible (Processing) status returns false.
        this.Assert.IsFalse(InboxProcessor.ClaimForProcessing(Inbox), 'Re-claiming a non-eligible entry should return false.');
    end;

    [Test]
    procedure WhenClaimedEntryHandlerSucceeds_ThenMarkedProcessed()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        InboxProcessor: Codeunit "AMC Inbox Processor";
        BeforeRun: DateTime;
        AfterRun: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] Once a claimed entry's handler succeeds, MarkInboxAsProcessed finalizes the entry.
        // [GIVEN] An enabled mock-message-type setup (no-op, succeeding handler) and an eligible inbox entry.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, true, 5, 0);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::Mock, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        EntryNo := Inbox."Entry No.";

        // [WHEN] The processor runs the entry to completion (claim -> succeeding handler -> finalize).
        BeforeRun := CurrentDateTime();
        InboxProcessor.ProcessEntry(Inbox);
        AfterRun := CurrentDateTime();

        // [THEN] The entry is finalized: Processed, timestamps ~ now, Attempt Count incremented by 1.
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::Processed, Inbox.Status, 'A finalized entry should be Processed.');
        this.TestLibrary.AssertDateTimeIsRecent(Inbox."Processed At", BeforeRun, AfterRun, 'Processed At');
        this.TestLibrary.AssertDateTimeIsRecent(Inbox."Last Attempt At", BeforeRun, AfterRun, 'Last Attempt At');
        this.Assert.AreEqual(1, Inbox."Attempt Count", 'Finalizing should increment Attempt Count by 1.');
    end;

    local procedure RunProcessor(var Inbox: Record "AMC Int. Inbox Entry")
    var
        InboxProcessor: Codeunit "AMC Inbox Processor";
    begin
        // Drive DoShouldProcessEntry via the processor's ProcessEntry entry point. Codeunit.Run cannot be
        // used here: with the test's pending (uncommitted) writes it runs in the same transaction, so an
        // inner error cannot be isolated and surfaces as "the transaction is stopped" instead of a caught
        // false. ProcessEntry exercises the same should-process logic without that isolation constraint.
        InboxProcessor.ProcessEntry(Inbox);
    end;

    local procedure AssertInboxUntouched(EntryNo: Integer; ExpectedStatus: Enum "AMC Int. Inbox Status"; ExpectedAttemptCount: Integer)
    var
        Inbox: Record "AMC Int. Inbox Entry";
    begin
        // "Skip" = the entry's status/attempt fields are unchanged after running (no claim, no processing).
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(ExpectedStatus, Inbox.Status, 'A skipped entry should keep its status.');
        this.Assert.AreEqual(ExpectedAttemptCount, Inbox."Attempt Count", 'A skipped entry should not change its Attempt Count.');
        this.Assert.AreEqual(0DT, Inbox."Last Attempt At", 'A skipped entry should not record a processing attempt.');
    end;
}
