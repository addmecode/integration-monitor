namespace Addmecode.IntegrationMonitor.Outbox;

codeunit 50119 "AMC Outbox Entry Mgt."
{
    internal procedure OnInsertOutboxEntry(var Outbox: Record "AMC Int. Outbox Entry")
    begin
        if Outbox."Created At" = 0DT then
            Outbox."Created At" := CurrentDateTime();

        if Outbox."Next Attempt At" = 0DT then
            Outbox."Next Attempt At" := CurrentDateTime();
    end;

    procedure ResetEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        CannotResetEntryErr: label 'Cannot reset entry with status = %1', Comment = '%1 is entry status';
    begin
        if (Outbox.Status = Outbox.Status::Processed) or (Outbox.Status = Outbox.Status::Processing) then
            Error(CannotResetEntryErr, Outbox.Status);
        Outbox.Status := Outbox.Status::ReadyToProcess;
        Outbox."Next Attempt At" := CurrentDateTime();
        Outbox."Last Attempt At" := 0DT;
        Outbox."Processed At" := 0DT;
        Outbox."Attempt Count" := 0;
        Clear(Outbox."Last Error");
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
        if not OutboxProcessor.Run(Outbox) then
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
