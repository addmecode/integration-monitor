namespace Addmecode.IntegrationMonitor.Helpers;

page 50102 "AMC Int. Blob Viewer"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'BLOB Viewer';
    InsertAllowed = false;
    ModifyAllowed = true;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            group(General)
            {
                Editable = not this.ReadOnly;
                field(BlobAsText; this.BlobAsText)
                {
                    ApplicationArea = All;
                    Caption = 'BLOB as text';
                    MultiLine = true;
                    ToolTip = 'Specifies the BLOB value as text.';
                }
            }
        }
    }

    procedure SetReadOnly(IsReadOnly: Boolean)
    begin
        this.ReadOnly := IsReadOnly;
    end;

    internal procedure SetBlob(AnyRecord: RecordRef; FieldNo: Integer)
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
    begin
        this.BlobAsText := BlobHelper.ReadBlobAsText(AnyRecord, FieldNo);
    end;

    internal procedure GetBlob(var AnyRecord: RecordRef; FieldNo: Integer)
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
    begin
        if this.ReadOnly then
            exit;
        BlobHelper.WriteTextToBlob(AnyRecord, FieldNo, this.BlobAsText);
    end;

    var
        BlobAsText: Text;
        ReadOnly: Boolean;
}
