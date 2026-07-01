namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using System.TestLibraries.Utilities;

codeunit 50145 "AMC Inbox Entry Mgt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenInsertWithoutTimestamps_ThenDefaultsToNow()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        BeforeInsert: DateTime;
        AfterInsert: DateTime;
    begin
        // [SCENARIO] OnInsert defaults Created At and Next Attempt At to the current date/time when they are left blank.
        // [GIVEN] A new inbox entry whose Created At and Next Attempt At are left as 0DT.
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        Inbox.Init();
        Inbox.Validate("Message Type", Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);

        // [WHEN] The entry is inserted, firing the OnInsert trigger.
        BeforeInsert := CurrentDateTime();
        Inbox.Insert(true);
        AfterInsert := CurrentDateTime();

        // [THEN] Both timestamps are set to approximately the current date/time.
        this.TestLibrary.AssertDateTimeIsRecent(Inbox."Created At", BeforeInsert, AfterInsert, 'Created At');
        this.TestLibrary.AssertDateTimeIsRecent(Inbox."Next Attempt At", BeforeInsert, AfterInsert, 'Next Attempt At');
    end;

    [Test]
    procedure WhenInsertWithTimestamps_ThenLeftUnchanged()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        PresetDateTime: DateTime;
    begin
        // [SCENARIO] OnInsert leaves Created At and Next Attempt At unchanged when they are already set.
        // [GIVEN] A new inbox entry with both timestamps explicitly pre-set to a known value.
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        PresetDateTime := CreateDateTime(DMY2Date(1, 1, 2020), 0T);
        Inbox.Init();
        Inbox.Validate("Message Type", Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        Inbox."Created At" := PresetDateTime;
        Inbox."Next Attempt At" := PresetDateTime;

        // [WHEN] The entry is inserted, firing the OnInsert trigger.
        Inbox.Insert(true);

        // [THEN] The pre-set timestamps are left unchanged.
        this.Assert.AreEqual(PresetDateTime, Inbox."Created At", 'A pre-set Created At should be left unchanged on insert.');
        this.Assert.AreEqual(PresetDateTime, Inbox."Next Attempt At", 'A pre-set Next Attempt At should be left unchanged on insert.');
    end;

    [Test]
    procedure WhenDeleteInboxWithRelatedOutbox_ThenBlocked()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        Inbox: Record "AMC Int. Inbox Entry";
        OutboxEntryExistsErr: Label 'Cannot delete record because related outbox entry exists.', Locked = true;
    begin
        // [SCENARIO] An inbox entry cannot be deleted while it still references an existing outbox entry.
        // [GIVEN] An inbox entry whose Outbox Entry No. points at an existing outbox row.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        Inbox."Outbox Entry No." := Outbox."Entry No.";
        Inbox.Modify(true);

        // [WHEN] The inbox entry is deleted, firing the OnDelete trigger.
        asserterror Inbox.Delete(true);

        // [THEN] It errors that a related outbox entry still exists.
        this.Assert.ExpectedError(OutboxEntryExistsErr);
    end;

    [Test]
    procedure WhenDeleteInboxWithoutOutboxLink_ThenAllowed()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        EntryNo: Integer;
    begin
        // [SCENARIO] An inbox entry with no outbox link can be deleted freely.
        // [GIVEN] An inbox entry whose Outbox Entry No. is 0 (no related outbox row).
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        EntryNo := Inbox."Entry No.";
        this.Assert.AreEqual(0, Inbox."Outbox Entry No.", 'Guard: the entry under test must have no outbox link.');

        // [WHEN] The inbox entry is deleted, firing the OnDelete trigger.
        Inbox.Delete(true);

        // [THEN] The entry is removed.
        this.Assert.IsFalse(Inbox.Get(EntryNo), 'An inbox entry without an outbox link should be deletable.');
    end;

    [Test]
    procedure WhenResetEntryWhileProcessed_ThenBlocked()
    begin
        // [SCENARIO] ResetEntry refuses to reset a Processed entry and leaves it untouched.
        this.AssertResetBlockedForStatus(Enum::"AMC Int. Inbox Status"::Processed);
    end;

    [Test]
    procedure WhenResetEntryWhileProcessing_ThenBlocked()
    begin
        // [SCENARIO] ResetEntry refuses to reset a Processing entry and leaves it untouched.
        this.AssertResetBlockedForStatus(Enum::"AMC Int. Inbox Status"::Processing);
    end;

    [Test]
    procedure WhenResetEntryWhileFailed_ThenClearsRetryState()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
        InboxRef: RecordRef;
        PastDateTime: DateTime;
        BeforeReset: DateTime;
        AfterReset: DateTime;
        EntryNo: Integer;
    begin
        // [SCENARIO] ResetEntry on a Failed entry clears the retry state and re-arms it for processing.
        // [GIVEN] A Failed inbox entry carrying a non-zero attempt count, a last error, and timestamps.
        PastDateTime := CreateDateTime(DMY2Date(1, 1, 2020), 0T);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::Failed);
        EntryNo := Inbox."Entry No.";
        Inbox."Attempt Count" := 3;
        Inbox."Last Attempt At" := PastDateTime;
        Inbox."Processed At" := PastDateTime;
        Inbox."Next Attempt At" := PastDateTime;
        Inbox.Modify(true);
        InboxRef.GetTable(Inbox);
        this.TestLibrary.WriteBlobText(InboxRef, Inbox.FieldNo("Last Error"), 'boom');
        Inbox.Get(EntryNo);

        // [WHEN] ResetEntry runs against it.
        BeforeReset := CurrentDateTime();
        InboxEntryMgt.ResetEntry(Inbox);
        AfterReset := CurrentDateTime();

        // [THEN] Next Attempt At is re-armed to ≈ now.
        this.TestLibrary.AssertDateTimeIsRecent(Inbox."Next Attempt At", BeforeReset, AfterReset, 'Next Attempt At');

        // [THEN] The persisted entry is back to ReadyToProcess with its retry state cleared.
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::ReadyToProcess, Inbox.Status, 'A reset entry should be ReadyToProcess.');
        this.Assert.AreEqual(0, Inbox."Attempt Count", 'A reset entry should have its Attempt Count cleared.');
        this.Assert.AreEqual(0DT, Inbox."Last Attempt At", 'A reset entry should clear Last Attempt At.');
        this.Assert.AreEqual(0DT, Inbox."Processed At", 'A reset entry should clear Processed At.');
        Inbox.CalcFields("Last Error");
        this.Assert.IsFalse(Inbox."Last Error".HasValue(), 'A reset entry should clear the Last Error blob.');
    end;

    [Test]
    procedure WhenCancelEntry_ThenSetsCancelled()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
        EntryNo: Integer;
    begin
        // [SCENARIO] CancelEntry transitions a ReadyToProcess entry to Cancelled.
        // [GIVEN] A ReadyToProcess inbox entry.
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        EntryNo := Inbox."Entry No.";

        // [WHEN] CancelEntry runs against it.
        InboxEntryMgt.CancelEntry(Inbox);

        // [THEN] The persisted entry is Cancelled.
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::Cancelled, Inbox.Status, 'A cancelled entry should have status Cancelled.');
    end;

    [Test]
    procedure WhenCancelAlreadyCancelled_ThenStaysCancelled()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
        EntryNo: Integer;
    begin
        // [SCENARIO] CancelEntry is idempotent: re-cancelling an already-Cancelled entry stays Cancelled without error.
        // [GIVEN] An already-Cancelled inbox entry.
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::Cancelled);
        EntryNo := Inbox."Entry No.";

        // [WHEN] CancelEntry runs against it again.
        InboxEntryMgt.CancelEntry(Inbox);

        // [THEN] The entry remains Cancelled and no error was raised.
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(Enum::"AMC Int. Inbox Status"::Cancelled, Inbox.Status, 'Re-cancelling should leave the entry Cancelled.');
    end;

    local procedure AssertResetBlockedForStatus(Status: Enum "AMC Int. Inbox Status")
    var
        Inbox: Record "AMC Int. Inbox Entry";
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
        CannotResetEntryErr: Label 'Cannot reset entry with status = ', Locked = true;
    begin
        // [GIVEN] An inbox entry in a status that disallows reset.
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Status);

        // [WHEN] ResetEntry runs against it.
        asserterror InboxEntryMgt.ResetEntry(Inbox);

        // [THEN] It errors that the entry cannot be reset for that status.
        this.Assert.ExpectedError(CannotResetEntryErr);

        // [THEN] The entry is unchanged: ResetEntry errors before mutating any field, so the
        // in-memory record still carries its original status.
        this.Assert.AreEqual(Status, Inbox.Status, 'A blocked reset should leave the entry status unchanged.');
    end;
}
