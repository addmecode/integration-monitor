page 50113 "AMC Int. Inbox Entries"
{
  PageType = List;
  SourceTable = "AMC Int. Inbox Entry";
  ApplicationArea = All;
  UsageCategory = Lists;
  Caption = 'Inbox Entries';

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
        field("Outbox Entry No."; Rec."Outbox Entry No.")
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
        field("Received At"; Rec."Received At")
        {
          ApplicationArea = All;
        }
        field("Processed At"; Rec."Processed At")
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
      action(ViewResponse)
      {
        ApplicationArea = All;
        Caption = 'View Response';
        Image = View;
        trigger OnAction()
        begin
          PayloadPage.SetRecord(Rec);
          PayloadPage.SetReadOnly(true);
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
    PayloadPage: Page "AMC Int. Inbox Payload";
    ErrorPage: Page "AMC Int. Inbox Error";
}

