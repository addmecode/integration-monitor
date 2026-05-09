page 50117 "AMC Int. Message Setup Card"
{
  PageType = Card;
  SourceTable = "AMC Int. Message Setup";
  ApplicationArea = All;
  UsageCategory = None;
  Caption = 'Integration Message Setup';

  layout
  {
    area(content)
    {
      group(General)
      {
        field("Message Type"; Rec."Message Type")
        {
          ApplicationArea = All;
        }
        field(Enabled; Rec.Enabled)
        {
          ApplicationArea = All;
        }
        field(Transport; Rec.Transport)
        {
          ApplicationArea = All;
        }
        field("Endpoint URL"; Rec."Endpoint URL")
        {
          ApplicationArea = All;
        }
        field("Auth Profile Code"; Rec."Auth Profile Code")
        {
          ApplicationArea = All;
        }
      }

      group(Processing)
      {
        field("Max Attempts"; Rec."Max Attempts")
        {
          ApplicationArea = All;
        }
        field("Base Retry Delay (sec)"; Rec."Base Retry Delay (sec)")
        {
          ApplicationArea = All;
        }
        field("Timeout (ms)"; Rec."Timeout (ms)")
        {
          ApplicationArea = All;
        }
        field("Process Response"; Rec."Process Response")
        {
          ApplicationArea = All;
        }
      }
    }
  }
}
