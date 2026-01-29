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
  begin
    ErrorDetailsText := BlobHelper.ReadBlobAsText(Rec, Rec.FieldNo("Error Details"));
  end;

  var
    BlobHelper: Codeunit "AMC Int. Blob Helper";
    ErrorDetailsText: Text;
}

