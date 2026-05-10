namespace Addmecode.IntegrationMonitor.Outbox;

page 50115 "AMC Int. Outbox Payload"
{
    PageType = Card;
    SourceTable = "AMC Int. Outbox Entry";
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Integration Outbox Payload';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            group(General)
            {
                field(PayloadText; this.PayloadText)
                {
                    ApplicationArea = All;
                    Caption = 'Request Payload';
                    MultiLine = true;
                    ToolTip = 'Specifies the request payload for the integration outbox entry.';
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        this.LoadPayload();
        if this.ReadOnly then
            CurrPage.Editable(false);
    end;

    trigger OnAfterGetRecord()
    begin
        //todo: do i need it?
        this.LoadPayload();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if this.ReadOnly then
            exit(true);

        if CloseAction = Action::OK then
            this.SavePayload();

        exit(true);
    end;

    procedure SetReadOnly(IsReadOnly: Boolean)
    begin
        this.ReadOnly := IsReadOnly;
    end;

    local procedure LoadPayload()
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
    begin
        OutboxRef.GetTable(Rec);
        this.PayloadText := BlobHelper.ReadBlobAsText(OutboxRef, Rec.FieldNo("Request Payload"));
    end;

    local procedure SavePayload()
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
    begin
        OutboxRef.GetTable(Rec);
        BlobHelper.WriteTextToBlob(OutboxRef, Rec.FieldNo("Request Payload"), this.PayloadText);
        Rec.Modify(true);
    end;

    var
        PayloadText: Text;
        ReadOnly: Boolean;
}
