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

        // [WHEN] The processor runs the entry through its public Run path.
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

        // [WHEN] The processor runs the entry through its public Run path.
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

        // [WHEN] The processor runs the entry through its public Run path.
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

        // [WHEN] The processor runs the entry through its public Run path.
        this.RunProcessor(Inbox);

        // [THEN] The entry is left untouched: no further attempt is made once attempts are exhausted.
        this.AssertInboxUntouched(EntryNo, Enum::"AMC Int. Inbox Status"::ReadyToProcess, MaxAttempts);
    end;

    local procedure RunProcessor(var Inbox: Record "AMC Int. Inbox Entry")
    var
        InboxProcessor: Codeunit "AMC Inbox Processor";
    begin
        // Drive DoShouldProcessEntry through the public Run path, mirroring production dispatch.
        this.Assert.IsTrue(InboxProcessor.Run(Inbox), 'A skipped entry should run without error.');
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
