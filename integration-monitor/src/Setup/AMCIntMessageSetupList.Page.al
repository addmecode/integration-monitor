namespace Addmecode.IntegrationMonitor.Setup;

page 50116 "AMC Int. Message Setup List"
{
    PageType = List;
    SourceTable = "AMC Int. Message Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    Caption = 'Integration Message Setup';
    Editable = false;
    CardPageId = "AMC Int. Message Setup Card";


    layout
    {
        area(content)
        {
            repeater(Setup)
            {
                field("Message Type"; Rec."Message Type")
                {
                    ApplicationArea = All;
                }
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                }
                field("Max Attempts"; Rec."Max Attempts")
                {
                    ApplicationArea = All;
                }
                field("Base Retry Delay (sec)"; Rec."Base Retry Delay (sec)")
                {
                    ApplicationArea = All;
                }
                field("Endpoint URL"; Rec."Endpoint URL")
                {
                    ApplicationArea = All;
                }
                field("Timeout (ms)"; Rec."Timeout (ms)")
                {
                    ApplicationArea = All;
                }
                field("Auth Profile Code"; Rec."Auth Profile Code")
                {
                    ApplicationArea = All;
                }
                field(Transport; Rec.Transport)
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
