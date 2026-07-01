namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using System.TestLibraries.Utilities;

codeunit 50140 "AMC Outbox Processor Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenSetupDisabled_ThenEntryLeftUntouched()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an entry whose message setup is disabled, leaving it untouched.
        // [GIVEN] A disabled message setup and a ReadyToProcess outbox entry.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, 0);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        EntryNo := Outbox."Entry No.";

        // [WHEN] The processor runs the entry through its public Run path.
        this.RunProcessor(Outbox);

        // [THEN] The entry is left untouched: a disabled setup means no claim and no processing.
        this.AssertOutboxUntouched(EntryNo, Enum::"AMC Int. Outbox Status"::ReadyToProcess, 0);
    end;

    [Test]
    procedure WhenStatusNotEligible_ThenEntryLeftUntouched()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an entry whose status is outside the eligible set
        // (Outbox: ReadyToProcess/Failed/ResponseReceived), even when the setup is enabled.
        // [GIVEN] An enabled setup and a Cancelled outbox entry.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, true, 5, 0);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::Cancelled);
        EntryNo := Outbox."Entry No.";

        // [WHEN] The processor runs the entry through its public Run path.
        this.RunProcessor(Outbox);

        // [THEN] The entry is left untouched: an ineligible status is skipped.
        this.AssertOutboxUntouched(EntryNo, Enum::"AMC Int. Outbox Status"::Cancelled, 0);
    end;

    [Test]
    procedure WhenNextAttemptInFuture_ThenEntryLeftUntouched()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        FutureDateTime: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an otherwise eligible entry whose retry delay has not yet elapsed.
        // [GIVEN] An enabled setup and a ReadyToProcess entry whose Next Attempt At is in the future.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, true, 5, 0);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        EntryNo := Outbox."Entry No.";
        FutureDateTime := CurrentDateTime() + (60 * 60 * 1000);
        Outbox."Next Attempt At" := FutureDateTime;
        Outbox.Modify(true);

        // [WHEN] The processor runs the entry through its public Run path.
        this.RunProcessor(Outbox);

        // [THEN] The entry is left untouched: the retry delay has not yet elapsed.
        this.AssertOutboxUntouched(EntryNo, Enum::"AMC Int. Outbox Status"::ReadyToProcess, 0);
    end;

    [Test]
    procedure WhenAttemptsExhausted_ThenEntryLeftUntouched()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        MaxAttempts: Integer;
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an entry whose attempts are exhausted (Attempt Count >= Max Attempts).
        // [GIVEN] An enabled setup with Max Attempts = 3 and a ReadyToProcess entry already at 3 attempts.
        MaxAttempts := 3;
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, true, MaxAttempts, 0);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        EntryNo := Outbox."Entry No.";
        Outbox."Attempt Count" := MaxAttempts;
        Outbox.Modify(true);

        // [WHEN] The processor runs the entry through its public Run path.
        this.RunProcessor(Outbox);

        // [THEN] The entry is left untouched: no further attempt is made once attempts are exhausted.
        this.AssertOutboxUntouched(EntryNo, Enum::"AMC Int. Outbox Status"::ReadyToProcess, MaxAttempts);
    end;

    local procedure RunProcessor(var Outbox: Record "AMC Int. Outbox Entry")
    var
        OutboxProcessor: Codeunit "AMC Outbox Processor";
    begin
        // Drive DoShouldProcessEntry through the public Run path, mirroring production dispatch.
        this.Assert.IsTrue(OutboxProcessor.Run(Outbox), 'A skipped entry should run without error.');
    end;

    local procedure AssertOutboxUntouched(EntryNo: Integer; ExpectedStatus: Enum "AMC Int. Outbox Status"; ExpectedAttemptCount: Integer)
    var
        Outbox: Record "AMC Int. Outbox Entry";
    begin
        // "Skip" = the entry's status/attempt fields are unchanged after running (no claim, no processing).
        Outbox.Get(EntryNo);
        this.Assert.AreEqual(ExpectedStatus, Outbox.Status, 'A skipped entry should keep its status.');
        this.Assert.AreEqual(ExpectedAttemptCount, Outbox."Attempt Count", 'A skipped entry should not change its Attempt Count.');
        this.Assert.AreEqual(0DT, Outbox."Last Attempt At", 'A skipped entry should not record a processing attempt.');
    end;
}
