namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;
using System.TestLibraries.Utilities;
using System.Utilities;

codeunit 50147 "AMC Outbox Entry Mgt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenEnqueueEntry_ThenCreatesReadyEntry()
    var
        Setup: Record "AMC Int. Message Setup";
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        PayloadTempBlob: Codeunit "Temp Blob";
        SourceRecordId: RecordId;
        OutboxRef: RecordRef;
        ExpectedPayload: Text;
        EntryNo: Integer;
    begin
        // [SCENARIO] EnqueueEntry inserts a ready-to-process outbox row carrying the supplied payload and source.
        // [GIVEN] A message setup, a payload Temp Blob, and a source RecordId.
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 1, 0);
        SourceRecordId := Setup.RecordId();
        ExpectedPayload := 'payload-body';
        BlobHelper.WriteTextToTempBlob(PayloadTempBlob, ExpectedPayload);

        // [WHEN] EnqueueEntry runs for that type, payload, and source.
        EntryNo := OutboxEntryMgt.EnqueueEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, PayloadTempBlob, SourceRecordId);

        // [THEN] A new outbox row exists, keyed by the returned Entry No.
        this.Assert.IsTrue(Outbox.Get(EntryNo), 'EnqueueEntry should insert an outbox row retrievable by the returned Entry No.');
        this.Assert.AreEqual(EntryNo, Outbox."Entry No.", 'The returned value should equal the new Entry No.');

        // [THEN] Status is ReadyToProcess, the source is recorded, and the stored payload equals the supplied one.
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::ReadyToProcess, Outbox.Status, 'A newly enqueued entry should be ReadyToProcess.');
        this.Assert.AreEqual(SourceRecordId, Outbox."Source Record ID", 'The source RecordId should be stored on the entry.');
        OutboxRef.GetTable(Outbox);
        this.Assert.AreEqual(ExpectedPayload, BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Request Payload")), 'The stored request payload should equal the supplied payload.');
    end;

    [Test]
    procedure WhenInsertWithoutTimestamps_ThenDefaultsToNow()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        BeforeInsert: DateTime;
        AfterInsert: DateTime;
    begin
        // [SCENARIO] OnInsert defaults Created At and Next Attempt At to the current date/time when they are left blank.
        // [GIVEN] A new outbox entry whose Created At and Next Attempt At are left as 0DT.
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        Outbox.Init();
        Outbox.Validate("Message Type", Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);

        // [WHEN] The entry is inserted, firing the OnInsert trigger.
        BeforeInsert := CurrentDateTime();
        Outbox.Insert(true);
        AfterInsert := CurrentDateTime();

        // [THEN] Both timestamps are set to approximately the current date/time.
        this.TestLibrary.AssertDateTimeWithinRange(Outbox."Created At", BeforeInsert, AfterInsert, 'Created At');
        this.TestLibrary.AssertDateTimeWithinRange(Outbox."Next Attempt At", BeforeInsert, AfterInsert, 'Next Attempt At');
    end;

    [Test]
    procedure WhenInsertWithTimestamps_ThenLeftUnchanged()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        PresetDateTime: DateTime;
    begin
        // [SCENARIO] OnInsert leaves Created At and Next Attempt At unchanged when they are already set.
        // [GIVEN] A new outbox entry with both timestamps explicitly pre-set to a known value.
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        PresetDateTime := CreateDateTime(DMY2Date(1, 1, 2020), 0T);
        Outbox.Init();
        Outbox.Validate("Message Type", Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        Outbox."Created At" := PresetDateTime;
        Outbox."Next Attempt At" := PresetDateTime;

        // [WHEN] The entry is inserted, firing the OnInsert trigger.
        Outbox.Insert(true);

        // [THEN] The pre-set timestamps are left unchanged.
        this.Assert.AreEqual(PresetDateTime, Outbox."Created At", 'A pre-set Created At should be left unchanged on insert.');
        this.Assert.AreEqual(PresetDateTime, Outbox."Next Attempt At", 'A pre-set Next Attempt At should be left unchanged on insert.');
    end;

    [Test]
    procedure WhenResetEntryWhileProcessed_ThenBlocked()
    begin
        // [SCENARIO] ResetEntry refuses to reset a Processed entry and leaves it untouched.
        this.AssertResetBlockedForStatus(Enum::"AMC Int. Outbox Status"::Processed);
    end;

    [Test]
    procedure WhenResetEntryWhileSending_ThenBlocked()
    begin
        // [SCENARIO] ResetEntry refuses to reset a Sending entry and leaves it untouched.
        this.AssertResetBlockedForStatus(Enum::"AMC Int. Outbox Status"::Sending);
    end;

    [Test]
    procedure WhenResetEntryWhileResponseReceived_ThenBlocked()
    begin
        // [SCENARIO] ResetEntry refuses to reset a ResponseReceived entry and leaves it untouched.
        this.AssertResetBlockedForStatus(Enum::"AMC Int. Outbox Status"::ResponseReceived);
    end;

    [Test]
    procedure WhenResetEntryWhileFailed_ThenClearsRetryState()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
        OutboxRef: RecordRef;
        PastDateTime: DateTime;
        BeforeReset: DateTime;
        AfterReset: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] ResetEntry on a Failed entry clears the retry state and re-arms it for processing.
        // [GIVEN] A Failed outbox entry carrying a non-zero attempt count, error/response payloads, and timestamps.
        PastDateTime := CreateDateTime(DMY2Date(1, 1, 2020), 0T);
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::Failed);
        EntryNo := Outbox."Entry No.";
        Outbox."Attempt Count" := 3;
        Outbox."Last Attempt At" := PastDateTime;
        Outbox."Processed At" := PastDateTime;
        Outbox."Response Received At" := PastDateTime;
        Outbox."Next Attempt At" := PastDateTime;
        Outbox.Modify(true);
        OutboxRef.GetTable(Outbox);
        this.TestLibrary.WriteBlobText(OutboxRef, Outbox.FieldNo("Last Error"), 'boom');
        this.TestLibrary.WriteBlobText(OutboxRef, Outbox.FieldNo("Response Payload"), 'response-body');
        Outbox.Get(EntryNo);

        // [WHEN] ResetEntry runs against it.
        BeforeReset := CurrentDateTime();
        OutboxEntryMgt.ResetEntry(Outbox);
        AfterReset := CurrentDateTime();

        // [THEN] Next Attempt At is re-armed to ≈ now.
        this.TestLibrary.AssertDateTimeWithinRange(Outbox."Next Attempt At", BeforeReset, AfterReset, 'Next Attempt At');

        // [THEN] The persisted entry is back to ReadyToProcess with its retry state cleared.
        Outbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::ReadyToProcess, Outbox.Status, 'A reset entry should be ReadyToProcess.');
        this.Assert.AreEqual(0, Outbox."Attempt Count", 'A reset entry should have its Attempt Count cleared.');
        this.Assert.AreEqual(0DT, Outbox."Last Attempt At", 'A reset entry should clear Last Attempt At.');
        this.Assert.AreEqual(0DT, Outbox."Processed At", 'A reset entry should clear Processed At.');
        this.Assert.AreEqual(0DT, Outbox."Response Received At", 'A reset entry should clear Response Received At.');
        Outbox.CalcFields("Last Error", "Response Payload");
        this.Assert.IsFalse(Outbox."Last Error".HasValue(), 'A reset entry should clear the Last Error blob.');
        this.Assert.IsFalse(Outbox."Response Payload".HasValue(), 'A reset entry should clear the Response Payload blob.');
    end;

    [Test]
    procedure WhenCancelEntry_ThenSetsCancelled()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
        EntryNo: Integer;
    begin
        // [SCENARIO] CancelEntry transitions a ReadyToProcess entry to Cancelled.
        // [GIVEN] A ReadyToProcess outbox entry.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        EntryNo := Outbox."Entry No.";

        // [WHEN] CancelEntry runs against it.
        OutboxEntryMgt.CancelEntry(Outbox);

        // [THEN] The persisted entry is Cancelled.
        Outbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::Cancelled, Outbox.Status, 'A cancelled entry should have status Cancelled.');
    end;

    [Test]
    procedure WhenCancelAlreadyCancelled_ThenStaysCancelled()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
        EntryNo: Integer;
    begin
        // [SCENARIO] CancelEntry is idempotent: re-cancelling an already-Cancelled entry stays Cancelled without error.
        // [GIVEN] An already-Cancelled outbox entry.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::Cancelled);
        EntryNo := Outbox."Entry No.";

        // [WHEN] CancelEntry runs against it again.
        OutboxEntryMgt.CancelEntry(Outbox);

        // [THEN] The entry remains Cancelled and no error was raised.
        Outbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Outbox Status"::Cancelled, Outbox.Status, 'Re-cancelling should leave the entry Cancelled.');
    end;

    [Test]
    procedure WhenDeleteWhileSending_ThenBlocked()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxEntryIsSendingErr: Label 'Cannot delete record because the outbox entry is being sent.', Locked = true;
    begin
        // [SCENARIO] An outbox entry that is being sent cannot be deleted.
        // [GIVEN] An outbox entry with Status = Sending.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::Sending);

        // [WHEN] The entry is deleted, firing the OnDelete trigger.
        asserterror Outbox.Delete(true);

        // [THEN] It errors that the entry is being sent.
        this.Assert.ExpectedError(OutboxEntryIsSendingErr);
    end;

    [Test]
    procedure WhenDeleteWithProcessingInbox_ThenBlocked()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        InboxEntryIsBeingProcessedErr: Label 'Cannot delete record because a related Inbox Entry is being processed.', Locked = true;
    begin
        // [SCENARIO] An outbox entry cannot be deleted while a related inbox entry is being processed.
        // [GIVEN] An outbox entry and a related inbox entry (matching Outbox Entry No.) with Status = Processing.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        this.CreateRelatedInbox(Outbox."Entry No.", Enum::"AMC Int. Inbox Status"::Processing);

        // [WHEN] The outbox entry is deleted, firing the OnDelete trigger.
        asserterror Outbox.Delete(true);

        // [THEN] It errors that a related inbox entry is being processed.
        this.Assert.ExpectedError(InboxEntryIsBeingProcessedErr);
    end;

    [Test]
    procedure WhenDeleteWithNonProcessingInbox_ThenCascades()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        Inbox: Record "AMC Int. Inbox Entry";
        ReadyInboxNo: Integer;
        FailedInboxNo: Integer;
    begin
        // [SCENARIO] Deleting a non-Sending outbox entry cascades to its related inbox entries when none are Processing.
        // [GIVEN] A non-Sending outbox entry with related inbox entries in non-Processing statuses.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::Processed);
        ReadyInboxNo := this.CreateRelatedInbox(Outbox."Entry No.", Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        FailedInboxNo := this.CreateRelatedInbox(Outbox."Entry No.", Enum::"AMC Int. Inbox Status"::Failed);

        // [WHEN] The outbox entry is deleted, firing the OnDelete trigger.
        Outbox.Delete(true);

        // [THEN] All inbox entries with that Outbox Entry No. are removed.
        this.Assert.IsFalse(Inbox.Get(ReadyInboxNo), 'The related ReadyToProcess inbox entry should be cascade-deleted.');
        this.Assert.IsFalse(Inbox.Get(FailedInboxNo), 'The related Failed inbox entry should be cascade-deleted.');
    end;

    local procedure CreateRelatedInbox(OutboxEntryNo: Integer; Status: Enum "AMC Int. Inbox Status"): Integer
    var
        Inbox: Record "AMC Int. Inbox Entry";
    begin
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Status);
        Inbox."Outbox Entry No." := OutboxEntryNo;
        Inbox.Modify(true);
        exit(Inbox."Entry No.");
    end;

    local procedure AssertResetBlockedForStatus(Status: Enum "AMC Int. Outbox Status")
    var
        Outbox: Record "AMC Int. Outbox Entry";
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
        CannotResetEntryErr: Label 'Cannot reset entry with status = ', Locked = true;
    begin
        // [GIVEN] An outbox entry in a status that disallows reset.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Status);

        // [WHEN] ResetEntry runs against it.
        asserterror OutboxEntryMgt.ResetEntry(Outbox);

        // [THEN] It errors that the entry cannot be reset for that status.
        this.Assert.ExpectedError(CannotResetEntryErr);

        // [THEN] The entry is unchanged: ResetEntry errors before mutating any field, so the
        // in-memory record still carries its original status
        this.Assert.AreEqual(Status, Outbox.Status, 'A blocked reset should leave the entry status unchanged.');
    end;
}
