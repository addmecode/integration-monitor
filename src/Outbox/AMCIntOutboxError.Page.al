page 50117 "AMC Int. Outbox Error"
{
  PageType = Card;
  SourceTable = "AMC Int. Outbox Entry";
  ApplicationArea = All;
  UsageCategory = None;
  Caption = 'Outbox Error Details';
  Editable = false;
  InsertAllowed = false;
  DeleteAllowed = false;

  layout
  {
    area(content)
    {
      group(General)
      {
        field(ErrorDetailsText; ErrorDetailsText)
        {
          ApplicationArea = All;
          Caption = 'Error Details';
          MultiLine = true;
        }
      }
    }
  }

  trigger OnOpenPage()
  begin
    LoadDetails();
  end;

  trigger OnAfterGetRecord()
  begin
    LoadDetails();
  end;

  local procedure LoadDetails()
  var
    OutboxRef: RecordRef;
  begin
    OutboxRef.GetTable(Rec);
    ErrorDetailsText := BlobHelper.ReadBlobAsText(OutboxRef, Rec.FieldNo("Error Details"));
  end;

  var
    BlobHelper: Codeunit "AMC Int. Blob Helper";
    ErrorDetailsText: Text;
}

