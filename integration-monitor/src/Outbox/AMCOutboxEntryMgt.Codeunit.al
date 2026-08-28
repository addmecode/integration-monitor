namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using System.Utilities;

codeunit 50106 "AMC Outbox Entry Mgt."
{
    internal procedure EnqueueEntry(MessageType: Enum "AMC Int. Message Type"; var RequestPayloadTempBlob: Codeunit "Temp Blob"; SourceRecordId: RecordId): Integer
    var
        Outbox: Record "AMC Int. Outbox Entry";
    begin
        Outbox.Init();
        Outbox.Validate("Message Type", MessageType);
        Outbox.Status := Outbox.Status::ReadyToProcess;
        Outbox."Source Record ID" := SourceRecordId;
        this.SetRequestPayload(Outbox, RequestPayloadTempBlob);
        Outbox.Insert(true);

        exit(Outbox."Entry No.");
    end;

    local procedure SetRequestPayload(var Outbox: Record "AMC Int. Outbox Entry"; var RequestPayloadTempBlob: Codeunit "Temp Blob")
    var
        PayloadInStream: InStream;
        PayloadOutStream: OutStream;
    begin
        RequestPayloadTempBlob.CreateInStream(PayloadInStream, TextEncoding::UTF8);
        Outbox."Request Payload".CreateOutStream(PayloadOutStream);
        CopyStream(PayloadOutStream, PayloadInStream);
    end;

    internal procedure OnInsertOutboxEntry(var Outbox: Record "AMC Int. Outbox Entry")
    begin
        if Outbox."Created At" = 0DT then
            Outbox."Created At" := CurrentDateTime();

        if Outbox."Next Attempt At" = 0DT then
            Outbox."Next Attempt At" := CurrentDateTime();
    end;

    internal procedure OnDeleteOutboxEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        Inbox: Record "AMC Int. Inbox Entry";
    begin
        Inbox.LockTable();
        this.ValidateOutboxDeletion(Outbox);
        this.DeleteRelatedInboxEntry(Outbox);
    end;

    local procedure ValidateOutboxDeletion(Outbox: Record "AMC Int. Outbox Entry")
    var
        Inbox: Record "AMC Int. Inbox Entry";
        InboxEntryIsBeingProcessedErr: Label 'Cannot delete record because a related Inbox Entry is being processed.';
        OutboxEntryIsSendingErr: Label 'Cannot delete record because the outbox entry is being sent.';
    begin
        if Outbox.Status = Outbox.Status::Sending then
            Error(OutboxEntryIsSendingErr);

        Inbox.SetRange("Outbox Entry No.", Outbox."Entry No.");
        Inbox.SetRange(Status, Inbox.Status::Processing);
        if not Inbox.IsEmpty() then
            Error(InboxEntryIsBeingProcessedErr);
    end;

    internal procedure DeleteRelatedInboxEntry(Outbox: Record "AMC Int. Outbox Entry")
    var
        Inbox: Record "AMC Int. Inbox Entry";
    begin
        Inbox.SetRange("Outbox Entry No.", Outbox."Entry No.");
        Inbox.DeleteAll(false);
    end;

    procedure ResetEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        CannotResetEntryErr: Label 'Cannot reset entry with status = %1', Comment = '%1 = entry status';
    begin
        if (Outbox.Status = Outbox.Status::Processed) or (Outbox.Status = Outbox.Status::Sending) or (Outbox.Status = Outbox.Status::ResponseReceived) then
            Error(CannotResetEntryErr, Outbox.Status);

        Outbox.Status := Outbox.Status::ReadyToProcess;
        Outbox."Next Attempt At" := CurrentDateTime();
        Outbox."Last Attempt At" := 0DT;
        Outbox."Processed At" := 0DT;
        Outbox."Attempt Count" := 0;
        Clear(Outbox."Last Error");
        Clear(Outbox."Response Payload");
        Outbox."Response Received At" := 0DT;
        Outbox.Modify(true);
    end;

    procedure CancelEntry(var Outbox: Record "AMC Int. Outbox Entry")
    begin
        if Outbox.Status = Outbox.Status::Cancelled then
            exit;
        Outbox.Status := Outbox.Status::Cancelled;
        Outbox.Modify(true);
    end;

    procedure ProcessEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        OutboxFailureHandler: Codeunit "AMC Outbox Failure Handler";
        OutboxProcessor: Codeunit "AMC Outbox Processor";
    begin
        if OutboxProcessor.Run(Outbox) then
            exit;

        if not OutboxFailureHandler.Run(Outbox) then
            ClearLastError();
    end;

    procedure ViewPayload(Outbox: Record "AMC Int. Outbox Entry")
    var
        PayloadPage: Page "AMC Int. Blob Viewer";
        OutboxRef: RecordRef;
    begin
        OutboxRef.GetTable(Outbox);
        PayloadPage.SetBlob(OutboxRef, Outbox.FieldNo("Request Payload"));
        PayloadPage.SetReadOnly(true);
        PayloadPage.RunModal();
    end;

    procedure EditPayload(Outbox: Record "AMC Int. Outbox Entry")
    var
        PayloadPage: Page "AMC Int. Blob Viewer";
        OutboxRef: RecordRef;
        StatusMustBeCancelledForEditingPayloadErr: Label 'To be able to modify the payload the status must be set to Cancelled';
    begin
        if Outbox.Status <> Outbox.Status::Cancelled then
            Error(StatusMustBeCancelledForEditingPayloadErr);

        OutboxRef.GetTable(Outbox);
        PayloadPage.SetBlob(OutboxRef, Outbox.FieldNo("Request Payload"));
        PayloadPage.SetReadOnly(false);
        PayloadPage.RunModal();
        PayloadPage.GetBlob(OutboxRef, Outbox.FieldNo("Request Payload"));
    end;

    procedure ViewErrorDetails(Outbox: Record "AMC Int. Outbox Entry")
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        LastErrorResponseAsText: Text;
    begin
        if not GuiAllowed then
            exit;
        OutboxRef.GetTable(Outbox);
        LastErrorResponseAsText := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Last Error"));
        Message(LastErrorResponseAsText);
    end;
}
