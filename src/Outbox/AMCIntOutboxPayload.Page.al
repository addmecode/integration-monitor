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
    begin
        PayloadText := BlobHelper.ReadBlobAsText(Rec, Rec.FieldNo("Request Payload"));
    end;

    local procedure SavePayload()
    var
        RecVar: Variant;
    begin
        RecVar := Rec;
        BlobHelper.WriteTextToBlob(RecVar, Rec.FieldNo("Request Payload"), PayloadText);
    end;

    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        PayloadText: Text;
        ReadOnly: Boolean;
}

