namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;
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

    [Test]
    procedure WhenResponseReceived_ThenCreatesInboxEntryAndCompletes()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        Inbox: Record "AMC Int. Inbox Entry";
        Setup: Record "AMC Int. Message Setup";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        InboxRef: RecordRef;
        SourceRecordId: RecordId;
        ResponseBody: Text;
        OutboxEntryNo: Integer;
    begin
        // [SCENARIO] A ResponseReceived outbox entry with a stored response creates an inbox entry
        // (copying the response and linkage) and is itself marked Processed.
        // [GIVEN] An enabled setup and a ResponseReceived outbox entry with a source record and a stored response payload.
        ResponseBody := 'stored-response-body';
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, true, 5, 0);
        SourceRecordId := Setup.RecordId();
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ResponseReceived);
        OutboxEntryNo := Outbox."Entry No.";
        Outbox."Source Record ID" := SourceRecordId;
        Outbox.Modify(true);
        OutboxRef.GetTable(Outbox);
        this.TestLibrary.WriteBlobText(OutboxRef, Outbox.FieldNo("Response Payload"), ResponseBody);

        // [WHEN] The processor runs the entry through its ProcessEntry entry point.
        OutboxProcessor.ProcessEntry(Outbox);

        // [THEN] The outbox entry is marked Processed.
        Outbox.Get(OutboxEntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::Processed, Outbox.Status, 'A processed ResponseReceived entry should be Processed.');

        // [THEN] A new inbox entry is created, linked to the outbox entry and ReadyToProcess.
        Inbox.SetRange("Outbox Entry No.", OutboxEntryNo);
        this.Assert.IsTrue(Inbox.FindFirst(), 'Processing a ResponseReceived entry should create a related inbox entry.');
        this.Assert.AreEqual(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Inbox."Message Type", 'The inbox entry should carry the outbox message type.');
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::ReadyToProcess, Inbox.Status, 'The new inbox entry should be ReadyToProcess.');
        this.Assert.AreEqual(SourceRecordId, Inbox."Source Record ID", 'The inbox entry should carry the outbox source record.');

        // [THEN] The stored response payload is copied onto the inbox entry.
        InboxRef.GetTable(Inbox);
        this.Assert.AreEqual(ResponseBody, BlobHelper.ReadBlobAsText(InboxRef, Inbox.FieldNo("Response Payload")), 'The response payload should be copied to the inbox entry.');
    end;

    [Test]
    procedure WhenValidateSuccessResponse_ThenNoError()
    var
        OutboxProcessor: Codeunit "AMC Outbox Processor";
        Response: HttpResponseMessage;
    begin
        // [SCENARIO] ValidateResponse accepts a success (2xx) HTTP response without raising an error.
        // [GIVEN] A fabricated response. A fresh AL HttpResponseMessage reports IsSuccessStatusCode = true
        // (default 2xx), and AL exposes no setter for HttpStatusCode, so only the success branch is reachable
        // by fabrication. The non-success branch (error carrying status + body) requires a genuine non-2xx
        // response and is exercised by the Phase 6 send-path test that drives a real HTTP failure.
        Response.Content.WriteFrom('any-body');
        this.Assert.IsTrue(Response.IsSuccessStatusCode, 'Guard: a fabricated response should report a success status.');

        // [WHEN]/[THEN] ValidateResponse returns without error for a success status.
        OutboxProcessor.ValidateResponse(Response);
    end;

    local procedure RunProcessor(var Outbox: Record "AMC Int. Outbox Entry")
    var
        OutboxProcessor: Codeunit "AMC Outbox Processor";
    begin
        // Drive DoShouldProcessEntry via the processor's ProcessEntry entry point. Codeunit.Run cannot be
        // used here: with the test's pending (uncommitted) writes it runs in the same transaction, so an
        // inner error cannot be isolated and surfaces as "the transaction is stopped" instead of a caught
        // false. ProcessEntry exercises the same should-process logic without that isolation constraint.
        OutboxProcessor.ProcessEntry(Outbox);
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
