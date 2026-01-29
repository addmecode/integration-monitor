page 50112 "AMC Int. Outbox Entries"
{
  PageType = List;
  SourceTable = "AMC Int. Outbox Entry";
  ApplicationArea = All;
  UsageCategory = Lists;
  Caption = 'Outbox Entries';

  layout
  {
    area(content)
    {
      repeater(Entries)
      {
        field("Entry No."; Rec."Entry No.")
        {
          ApplicationArea = All;
        }
        field("Message Type"; Rec."Message Type")
        {
          ApplicationArea = All;
        }
        field(Status; Rec.Status)
        {
          ApplicationArea = All;
        }
        field("Created At"; Rec."Created At")
        {
          ApplicationArea = All;
        }
        field("Next Attempt At"; Rec."Next Attempt At")
        {
          ApplicationArea = All;
        }
        field("Attempt Count"; Rec."Attempt Count")
        {
          ApplicationArea = All;
        }
        field("Correlation ID"; Rec."Correlation ID")
        {
          ApplicationArea = All;
        }
        field("Last Error"; Rec."Last Error")
        {
          ApplicationArea = All;
        }
      }
    }
  }

  actions
  {
    area(processing)
    {
      action(Retry)
      {
        ApplicationArea = All;
        Caption = 'Retry';
        Image = Repeat;
        trigger OnAction()
        begin
          if Rec.Status = Rec.Status::Cancelled then
            exit;

          Rec.Status := Rec.Status::Ready;
          Rec."Next Attempt At" := CurrentDateTime();
          Rec.Modify(true);
        end;
      }
      action(Cancel)
      {
        ApplicationArea = All;
        Caption = 'Cancel';
        Image = Cancel;
        trigger OnAction()
        begin
          Rec.Status := Rec.Status::Cancelled;
          Rec.Modify(true);
        end;
      }
      action(ViewPayload)
      {
        ApplicationArea = All;
        Caption = 'View Payload';
        Image = View;
        trigger OnAction()
        begin
          PayloadPage.SetRecord(Rec);
          PayloadPage.SetReadOnly(true);
          PayloadPage.RunModal();
        end;
      }
      action(EditPayload)
      {
        ApplicationArea = All;
        Caption = 'Edit Payload';
        Image = Edit;
        trigger OnAction()
        begin
          PayloadPage.SetRecord(Rec);
          PayloadPage.SetReadOnly(false);
          PayloadPage.RunModal();
        end;
      }
      action(ViewErrorDetails)
      {
        ApplicationArea = All;
        Caption = 'View Error Details';
        Image = Error;
        trigger OnAction()
        begin
          ErrorPage.SetRecord(Rec);
          ErrorPage.RunModal();
        end;
      }
    }
  }

  var
    PayloadPage: Page "AMC Int. Outbox Payload";
    ErrorPage: Page "AMC Int. Outbox Error";
}

