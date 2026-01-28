page 50118 "AMC Int. Inbox Error"
{
  PageType = Card;
  SourceTable = "AMC Int. Inbox Entry";
  ApplicationArea = All;
  UsageCategory = None;
  Caption = 'Inbox Error Details';
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

