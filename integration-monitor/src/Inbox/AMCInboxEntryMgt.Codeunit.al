namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Inbox;

codeunit 50126 "AMC Inbox Entry Mgt."
{
    internal procedure OnInsertInboxEntry(var Inbox: Record "AMC Int. Inbox Entry")
    begin
        if Inbox."Created At" = 0DT then
            Inbox."Created At" := CurrentDateTime();

        if Inbox."Next Attempt At" = 0DT then
            Inbox."Next Attempt At" := CurrentDateTime();
    end;

    procedure ResetEntry(var Inbox: Record "AMC Int. Inbox Entry")
    var
        CannotResetEntryErr: label 'Cannot reset entry with status = %1', Comment = '%1 is entry status';
    begin
        //todo only for testing
        // if (Inbox.Status = Inbox.Status::Processed) or (Inbox.Status = Inbox.Status::Processing) then
        //     Error(CannotResetEntryErr, Inbox.Status);
        Inbox.Status := Inbox.Status::ReadyToProcess;
        Inbox."Next Attempt At" := CurrentDateTime();
        Inbox."Last Attempt At" := 0DT;
        Inbox."Processed At" := 0DT;
        Inbox."Attempt Count" := 0;
        Clear(Inbox."Last Error");
        Inbox.Modify(true);
    end;

    procedure CancelEntry(var Inbox: Record "AMC Int. Inbox Entry")
    begin
        if Inbox.Status = Inbox.Status::Cancelled then
            exit;
        Inbox.Status := Inbox.Status::Cancelled;
        Inbox.Modify(true);
    end;

    procedure ProcessEntry(var Inbox: Record "AMC Int. Inbox Entry")
    var
        InboxFailureHandler: Codeunit "AMC Inbox Failure Handler";
        InboxProcessor: Codeunit "AMC Inbox Processor";
    begin
        if not InboxProcessor.Run(Inbox) then
            if not InboxFailureHandler.Run(Inbox) then
                ClearLastError();
    end;

    procedure ViewPayload(Inbox: Record "AMC Int. Inbox Entry")
    var
        PayloadPage: Page "AMC Int. Blob Viewer";
        InboxRef: RecordRef;
    begin
        InboxRef.GetTable(Inbox);
        PayloadPage.SetBlob(InboxRef, Inbox.FieldNo("Response Payload"));
        PayloadPage.SetReadOnly(true);
        PayloadPage.RunModal();
    end;

    procedure EditPayload(Inbox: Record "AMC Int. Inbox Entry")
    var
        PayloadPage: Page "AMC Int. Blob Viewer";
        InboxRef: RecordRef;
        StatusMustBeCancelledForEditingPayloadErr: Label 'To be able to modify the payload the status must be set to Cancelled';
    begin
        if Inbox.Status <> Inbox.Status::Cancelled then
            Error(StatusMustBeCancelledForEditingPayloadErr);
        InboxRef.GetTable(Inbox);
        PayloadPage.SetBlob(InboxRef, Inbox.FieldNo("Response Payload"));
        PayloadPage.SetReadOnly(false);
        PayloadPage.RunModal();
        PayloadPage.GetBlob(InboxRef, Inbox.FieldNo("Response Payload"));
    end;

    procedure ViewErrorDetails(Inbox: Record "AMC Int. Inbox Entry")
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        InboxRef: RecordRef;
        LastErrorResponseAsText: Text;
    begin
        if not GuiAllowed then
            exit;
        InboxRef.GetTable(Inbox);
        LastErrorResponseAsText := BlobHelper.ReadBlobAsText(InboxRef, Inbox.FieldNo("Last Error"));
        Message(LastErrorResponseAsText);
    end;
}
