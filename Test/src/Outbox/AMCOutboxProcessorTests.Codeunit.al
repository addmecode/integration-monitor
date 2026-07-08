namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;
using Addmecode.IntegrationMonitor.Transport;
using System.TestLibraries.Utilities;

/// <remarks>
/// Tests invoke the processor's internal <c>ProcessEntry</c> directly rather than <c>Codeunit.Run</c>:
/// with the test's pending (uncommitted) writes, Run executes in the same transaction, so an inner
/// error cannot be isolated and surfaces as "the transaction is stopped" instead of a caught false.
/// </remarks>
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
        OutboxProcessor: Codeunit "AMC Outbox Processor";
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an entry whose message setup is disabled, leaving it untouched.
        // [GIVEN] A disabled message setup and a ReadyToProcess outbox entry.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, 0);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        EntryNo := Outbox."Entry No.";

        // [WHEN] The processor processes the entry.
        OutboxProcessor.ProcessEntry(Outbox);

        // [THEN] The entry is left untouched: a disabled setup means no claim and no processing.
        this.AssertOutboxUntouched(EntryNo, Enum::"AMC Int. Outbox Status"::ReadyToProcess, 0);
    end;

    [Test]
    procedure WhenStatusSending_ThenEntryLeftUntouched()
    begin
        // [SCENARIO] The processor skips a Sending entry: its status is outside the eligible set.
        this.AssertSkippedForIneligibleStatus(Enum::"AMC Int. Outbox Status"::Sending);
    end;

    [Test]
    procedure WhenStatusProcessed_ThenEntryLeftUntouched()
    begin
        // [SCENARIO] The processor skips a Processed entry: its status is outside the eligible set.
        this.AssertSkippedForIneligibleStatus(Enum::"AMC Int. Outbox Status"::Processed);
    end;

    [Test]
    procedure WhenStatusCancelled_ThenEntryLeftUntouched()
    begin
        // [SCENARIO] The processor skips a Cancelled entry: its status is outside the eligible set.
        this.AssertSkippedForIneligibleStatus(Enum::"AMC Int. Outbox Status"::Cancelled);
    end;

    [Test]
    procedure WhenNextAttemptInFuture_ThenEntryLeftUntouched()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
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

        // [WHEN] The processor processes the entry.
        OutboxProcessor.ProcessEntry(Outbox);

        // [THEN] The entry is left untouched: the retry delay has not yet elapsed.
        this.AssertOutboxUntouched(EntryNo, Enum::"AMC Int. Outbox Status"::ReadyToProcess, 0);
    end;

    [Test]
    procedure WhenAttemptsExhausted_ThenEntryLeftUntouched()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
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

        // [WHEN] The processor processes the entry.
        OutboxProcessor.ProcessEntry(Outbox);

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
        Response: HttpResponseMessage;
    begin
        // [SCENARIO] ValidateResponse accepts a success (2xx) HTTP response without raising an error.
        // [GIVEN] A fabricated response. A fresh AL HttpResponseMessage reports IsSuccessStatusCode = true
        // (default 2xx), and AL exposes no setter for HttpStatusCode, so only the success branch is reachable
        Response.Content.WriteFrom('any-body');
        this.Assert.IsTrue(Response.IsSuccessStatusCode, 'Guard: a fabricated response should report a success status.');

        // [WHEN] ValidateResponse inspects the response.
        // [THEN] It completes without raising an error (the TryFunction wrapper returns true).
        this.Assert.IsTrue(this.TryValidateResponse(Response), 'ValidateResponse should not error on a success (2xx) status.');
    end;

    [TryFunction]
    local procedure TryValidateResponse(Response: HttpResponseMessage)
    var
        OutboxProcessor: Codeunit "AMC Outbox Processor";
    begin
        OutboxProcessor.ValidateResponse(Response);
    end;

    [Test]
    procedure WhenSendSucceedsWithProcessResponse_ThenStoresResponseAndCreatesInbox()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        Inbox: Record "AMC Int. Inbox Entry";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        InboxRef: RecordRef;
        BeforeRun: DateTime;
        AfterRun: DateTime;
        ResponseBody: Text;
        EntryNo: Integer;
    begin
        // [SCENARIO] A successful send with Process Response = true stores the response payload and creates an inbox entry.
        // [GIVEN] An enabled mock-transport setup with Process Response = true and a mock returning a known body.
        ResponseBody := 'mock-success-body';
        this.ConfigureMockSetup(true);
        this.SetMockResponse(200, ResponseBody);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::Mock, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        EntryNo := Outbox."Entry No.";

        // [WHEN] The processor sends the entry.
        BeforeRun := CurrentDateTime();
        OutboxProcessor.ProcessEntry(Outbox);
        AfterRun := CurrentDateTime();

        // [THEN] The mock response body is stored and Response Received At ~ now.
        Outbox.Get(EntryNo);
        OutboxRef.GetTable(Outbox);
        this.Assert.AreEqual(ResponseBody, BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Response Payload")), 'The mock response body should be stored on the outbox entry.');
        this.TestLibrary.AssertDateTimeIsRecent(Outbox."Response Received At", BeforeRun, AfterRun, 'Response Received At');

        // [THEN] The entry is finalized Processed (MarkOutboxAsProcessed runs after the response is stored).
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::Processed, Outbox.Status, 'A completed send should leave the entry Processed.');

        // [THEN] An inbox entry is created, linked to the outbox entry and carrying the copied response payload.
        Inbox.SetRange("Outbox Entry No.", EntryNo);
        this.Assert.IsTrue(Inbox.FindFirst(), 'A successful send with Process Response should create an inbox entry.');
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::ReadyToProcess, Inbox.Status, 'The new inbox entry should be ReadyToProcess.');
        InboxRef.GetTable(Inbox);
        this.Assert.AreEqual(ResponseBody, BlobHelper.ReadBlobAsText(InboxRef, Inbox.FieldNo("Response Payload")), 'The response payload should be copied to the inbox entry.');
    end;

    [Test]
    procedure WhenSendSucceedsWithoutProcessResponse_ThenNoInboxAndProcessed()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        Inbox: Record "AMC Int. Inbox Entry";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
        BeforeRun: DateTime;
        AfterRun: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] A successful send with Process Response = false marks the entry Processed without storing a response or creating an inbox entry.
        // [GIVEN] An enabled mock-transport setup with Process Response = false and a mock returning a body.
        this.ConfigureMockSetup(false);
        this.SetMockResponse(200, 'ignored-body');
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::Mock, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        EntryNo := Outbox."Entry No.";

        // [WHEN] The processor sends the entry.
        BeforeRun := CurrentDateTime();
        OutboxProcessor.ProcessEntry(Outbox);
        AfterRun := CurrentDateTime();

        // [THEN] The entry is finalized Processed with a recorded attempt.
        Outbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::Processed, Outbox.Status, 'A completed send should leave the entry Processed.');
        this.Assert.AreEqual(1, Outbox."Attempt Count", 'A completed send should increment Attempt Count by 1.');
        this.TestLibrary.AssertDateTimeIsRecent(Outbox."Last Attempt At", BeforeRun, AfterRun, 'Last Attempt At');

        // [THEN] No response is stored when Process Response is false.
        Outbox.CalcFields("Response Payload");
        this.Assert.IsFalse(Outbox."Response Payload".HasValue(), 'No response should be stored when Process Response is false.');

        // [THEN] No inbox entry is created.
        Inbox.SetRange("Outbox Entry No.", EntryNo);
        this.Assert.IsFalse(Inbox.FindFirst(), 'No inbox entry should be created when Process Response is false.');
    end;

    [Test]
    procedure WhenSendFails_ThenRoutedThroughFailureHandler()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        Inbox: Record "AMC Int. Inbox Entry";
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        BeforeRun: DateTime;
        AfterRun: DateTime;
        LastError: Text;
        EntryNo: Integer;
    begin
        // [SCENARIO] A failing send routes the entry through the failure handler: it ends Failed with a populated Last Error.
        // [GIVEN] An enabled mock-transport setup (Max Attempts = 5) and a mock configured to fail with HTTP 500.
        this.ConfigureMockSetup(true);
        this.SetMockResponse(500, 'server-error-body');
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::Mock, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        EntryNo := Outbox."Entry No.";

        // Commit the staged data so ProcessEntry runs without an outer uncommitted write transaction,
        // mirroring the dispatcher job (its top-level loop only reads before ProcessEntry). ClaimForSending
        // commits mid-send, and a "commit then error" inside Codeunit.Run is only catchable when no outer
        // write transaction is open; without this commit the send error escalates to "the transaction is stopped".
        Commit();

        // [WHEN] The entry is processed via the Mgt wrapper, which catches the send error and runs the failure handler.
        BeforeRun := CurrentDateTime();
        OutboxEntryMgt.ProcessEntry(Outbox);
        AfterRun := CurrentDateTime();

        // [THEN] The entry ends Failed with a recorded attempt (the claim set Sending, then the send failed).
        Outbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::Failed, Outbox.Status, 'A failing send should leave the entry Failed.');
        this.Assert.AreEqual(1, Outbox."Attempt Count", 'A failing send should increment Attempt Count by 1.');
        this.TestLibrary.AssertDateTimeIsRecent(Outbox."Last Attempt At", BeforeRun, AfterRun, 'Last Attempt At');

        // [THEN] The Last Error blob is populated with the formatted failure message.
        Outbox.CalcFields("Last Error");
        this.Assert.IsTrue(Outbox."Last Error".HasValue(), 'A failing send should populate the Last Error blob.');
        OutboxRef.GetTable(Outbox);
        LastError := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Last Error"));
        this.Assert.IsTrue(LastError.Contains('Error:'), 'The Last Error blob should carry the formatted "Error:…" failure message.');

        // [THEN] No inbox entry is created for a send that never received a response.
        Inbox.SetRange("Outbox Entry No.", EntryNo);
        this.Assert.IsFalse(Inbox.FindFirst(), 'A failing send should not create an inbox entry.');
    end;

    [Test]
    procedure WhenReadyToProcess_ThenClaimForSendingSetsSending()
    begin
        // [SCENARIO] ClaimForSending claims a ReadyToProcess entry, transitioning it to Sending.
        this.AssertClaimForSending(Enum::"AMC Int. Outbox Status"::ReadyToProcess, true, Enum::"AMC Int. Outbox Status"::Sending);
    end;

    [Test]
    procedure WhenFailed_ThenClaimForSendingSetsSending()
    begin
        // [SCENARIO] ClaimForSending claims a Failed entry (a retry), transitioning it to Sending.
        this.AssertClaimForSending(Enum::"AMC Int. Outbox Status"::Failed, true, Enum::"AMC Int. Outbox Status"::Sending);
    end;

    [Test]
    procedure WhenResponseReceived_ThenClaimForSendingReturnsFalse()
    begin
        // [SCENARIO] ClaimForSending refuses a ResponseReceived entry: only ReadyToProcess/Failed are claimable for sending.
        this.AssertClaimForSending(Enum::"AMC Int. Outbox Status"::ResponseReceived, false, Enum::"AMC Int. Outbox Status"::ResponseReceived);
    end;

    [Test]
    procedure WhenProcessed_ThenClaimForSendingReturnsFalse()
    begin
        // [SCENARIO] ClaimForSending refuses a terminal Processed entry, leaving it unchanged.
        this.AssertClaimForSending(Enum::"AMC Int. Outbox Status"::Processed, false, Enum::"AMC Int. Outbox Status"::Processed);
    end;

    [Test]
    procedure WhenCancelled_ThenClaimForSendingReturnsFalse()
    begin
        // [SCENARIO] ClaimForSending refuses a Cancelled entry, leaving it unchanged.
        this.AssertClaimForSending(Enum::"AMC Int. Outbox Status"::Cancelled, false, Enum::"AMC Int. Outbox Status"::Cancelled);
    end;

    [Test]
    procedure WhenSending_ThenClaimForSendingReturnsFalse()
    begin
        // [SCENARIO] ClaimForSending refuses an entry already Sending (no double-claim), leaving it unchanged.
        this.AssertClaimForSending(Enum::"AMC Int. Outbox Status"::Sending, false, Enum::"AMC Int. Outbox Status"::Sending);
    end;

    local procedure AssertClaimForSending(Status: Enum "AMC Int. Outbox Status"; ExpectedClaimed: Boolean; ExpectedStatusAfter: Enum "AMC Int. Outbox Status")
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
        EntryNo: Integer;
        Claimed: Boolean;
    begin
        // [GIVEN] An outbox entry in the given status. ClaimForSending reads only the outbox row (no setup lookup).
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Status);
        EntryNo := Outbox."Entry No.";

        // [WHEN] The entry is claimed for sending.
        Claimed := OutboxProcessor.ClaimForSending(Outbox);

        // [THEN] Only ReadyToProcess/Failed are claimed (and committed as Sending); any other status returns false and is unchanged.
        this.Assert.AreEqual(ExpectedClaimed, Claimed, 'ClaimForSending should only claim ReadyToProcess/Failed entries.');
        Outbox.Get(EntryNo);
        this.Assert.AreEqual(ExpectedStatusAfter, Outbox.Status, 'ClaimForSending should set Sending only for a claimed entry and leave others unchanged.');
    end;

    local procedure ConfigureMockSetup(ProcessResponse: Boolean)
    var
        Setup: Record "AMC Int. Message Setup";
    begin
        // Enable a mock-message-type setup wired to the mock transport. Enabled is set directly by the
        // factory (bypassing OnValidate), so no endpoint/auth validation runs; Transport and Process
        // Response are assigned here without triggering table validation.
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, true, 5, 0);
        Setup.Transport := Enum::"AMC Int. Transport Type"::Mock;
        Setup."Process Response" := ProcessResponse;
        Setup.Modify(true);
    end;

    local procedure SetMockResponse(StatusCode: Integer; Body: Text)
    var
        State: Codeunit "AMC Mock Transport State";
    begin
        // A 2xx status returns the body only; a non-success status makes the mock error on Send,
        // driving the failure path (a fabricated response cannot report a genuine non-2xx status).
        State.SetResponse(StatusCode, Body);
    end;

    local procedure AssertSkippedForIneligibleStatus(Status: Enum "AMC Int. Outbox Status")
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
        EntryNo: Integer;
    begin
        // [GIVEN] An enabled setup and an outbox entry whose status is outside the eligible set
        // (eligible = ReadyToProcess/Failed/ResponseReceived).
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, true, 5, 0);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Status);
        EntryNo := Outbox."Entry No.";

        // [WHEN] The processor processes the entry.
        OutboxProcessor.ProcessEntry(Outbox);

        // [THEN] The entry is left untouched: an ineligible status is skipped.
        this.AssertOutboxUntouched(EntryNo, Status, 0);
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
