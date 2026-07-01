namespace Addmecode.IntegrationMonitor.Auth;

page 50105 "AMC Int. Auth Profiles"
{
    PageType = List;
    SourceTable = "AMC Int. Auth Profile";
    ApplicationArea = All;
    Caption = 'Integration Auth Profiles';
    UsageCategory = None;
    Editable = false;
    CardPageId = "AMC Int. Auth Profile Card";

    layout
    {
        area(content)
        {
            repeater(Profiles)
            {
                field("Code"; Rec.Code)
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field("Auth Type"; Rec."Auth Type")
                {
                    ApplicationArea = All;
                }
                field(Username; Rec.Username)
                {
                    ApplicationArea = All;
                }
                field("Has Secret"; Rec."Has Secret")
                {
                    ApplicationArea = All;
                }
                field("Secret Updated At"; Rec."Secret Updated At")
                {
                    ApplicationArea = All;
                }
            }
        }
    }
}
