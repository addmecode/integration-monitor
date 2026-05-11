namespace Addmecode.IntegrationMonitor.Outbox;

codeunit 50119 "AMC Outbox Entry Mgt."
{
    procedure ResetEntry(var Outbox: Record "AMC Int. Outbox Entry")
    var
        EntryAlreadySentErr: label 'The entry is already sent';
    begin
        if Outbox.Status = Outbox.Status::Sent then
            Error(EntryAlreadySentErr);
        Outbox.Status := Outbox.Status::ReadyToProcess;
        Outbox."Next Attempt At" := CurrentDateTime();
        Outbox."Last Attempt At" := 0DT;
        Outbox."Sent At" := 0DT;
        Outbox."Attempt Count" := 0;
        Clear(Outbox."Last Error Response");
        Outbox.Modify(true);
    end;

    procedure CancelEntry(var Outbox: Record "AMC Int. Outbox Entry")
    begin
        if Outbox.Status = Outbox.Status::Cancelled then
            exit;
        Outbox.Status := Outbox.Status::Cancelled;
        Outbox.Modify(true);
    end;

    procedure ViewPayload(Outbox: Record "AMC Int. Outbox Entry")
    var
        PayloadPage: Page "AMC Int. Outbox Payload";
    begin
        PayloadPage.SetRecord(Outbox);
        PayloadPage.SetReadOnly(true);
        PayloadPage.RunModal();
    end;

    procedure EditPayload(Outbox: Record "AMC Int. Outbox Entry")
    var
        PayloadPage: Page "AMC Int. Outbox Payload";
        StatusMustBeCancelledForEditingPayloadErr: Label 'To be able to modify the payload the status must be set to Cancelled';
    begin
        if Outbox.Status <> Outbox.Status::Cancelled then
            Error(StatusMustBeCancelledForEditingPayloadErr);
        PayloadPage.SetRecord(Outbox);
        PayloadPage.SetReadOnly(false);
        PayloadPage.RunModal();
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
        LastErrorResponseAsText := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Last Error Response"));
        Message(LastErrorResponseAsText);
    end;
}
