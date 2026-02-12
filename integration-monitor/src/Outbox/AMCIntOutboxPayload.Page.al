page 50115 "AMC Int. Outbox Payload"
{
    PageType = Card;
    SourceTable = "AMC Int. Outbox Entry";
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Outbox Payload';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            group(General)
            {
                field(PayloadText; PayloadText)
                {
                    ApplicationArea = All;
                    Caption = 'Request Payload';
                    MultiLine = true;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        LoadPayload();
        if ReadOnly then
            CurrPage.Editable(false);
    end;

    trigger OnAfterGetRecord()
    begin
        LoadPayload();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if ReadOnly then
            exit(true);

        if CloseAction = Action::OK then
            SavePayload();

        exit(true);
    end;

    procedure SetReadOnly(IsReadOnly: Boolean)
    begin
        ReadOnly := IsReadOnly;
    end;

    local procedure LoadPayload()
    var
        OutboxRef: RecordRef;
    begin
        OutboxRef.GetTable(Rec);
        PayloadText := BlobHelper.ReadBlobAsText(OutboxRef, Rec.FieldNo("Request Payload"));
    end;

    local procedure SavePayload()
    var
        OutboxRef: RecordRef;
    begin
        OutboxRef.GetTable(Rec);
        BlobHelper.WriteTextToBlob(OutboxRef, Rec.FieldNo("Request Payload"), PayloadText);
    end;

    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        PayloadText: Text;
        ReadOnly: Boolean;
}
