namespace Addmecode.IntegrationMonitor.Auth;

page 50119 "AMC Int. Auth Profile Card"
{
    PageType = Card;
    SourceTable = "AMC Int. Auth Profile";
    ApplicationArea = All;
    UsageCategory = None;
    Caption = 'Integration Auth Profile';

    layout
    {
        area(content)
        {
            group(General)
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

                    trigger OnValidate()
                    begin
                        this.SetControlVisibility();
                        CurrPage.Update(false);
                    end;
                }
            }

            group(Basic)
            {
                Visible = this.BasicFieldsVisible;

                field(Username; Rec.Username)
                {
                    ApplicationArea = All;
                }
            }

            group(Secret)
            {
                field(NewSecretValue; this.NewSecretValue)
                {
                    ApplicationArea = All;
                    Caption = 'Password / Token';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies the password or bearer token to store for this authentication profile.';

                    trigger OnValidate()
                    begin
                        if this.NewSecretValue = '' then
                            exit;

                        CurrPage.SaveRecord();
                        Rec.SetSecret(this.NewSecretValue);
                        Clear(this.NewSecretValue);
                        CurrPage.Update(false);
                    end;
                }
                field("Has Secret"; Rec."Has Secret")
                {
                    ApplicationArea = All;
                }
                field("Secret Updated At"; Rec."Secret Updated At")
                {
                    ApplicationArea = All;
                }
                field("Secret Updated By"; Rec."Secret Updated By")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ClearSecret)
            {
                ApplicationArea = All;
                Caption = 'Clear Secret';
                Image = ClearLog;
                ToolTip = 'Deletes the stored password or token for this authentication profile.';

                trigger OnAction()
                begin
                    CurrPage.SaveRecord();
                    Rec.ClearSecretWithEnabledSetupCheck();
                    Clear(this.NewSecretValue);
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        this.SetControlVisibility();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        this.SetControlVisibility();
    end;

    local procedure SetControlVisibility()
    begin
        this.BasicFieldsVisible := Rec."Auth Type" = Rec."Auth Type"::Basic;
    end;

    var
        BasicFieldsVisible: Boolean;
        NewSecretValue: Text[2048];
}
