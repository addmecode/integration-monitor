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
                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;

                    trigger OnValidate()
                    begin
                        this.SetControlEditability();
                        CurrPage.Update(false);
                    end;
                }
            }

            group(Connection)
            {
                Editable = this.SetupFieldsEditable;

                field("Message Type"; Rec."Message Type")
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
                Editable = this.SetupFieldsEditable;

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

    trigger OnAfterGetRecord()
    begin
        this.SetControlEditability();
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        this.SetControlEditability();
    end;

    local procedure SetControlEditability()
    begin
        this.SetupFieldsEditable := not Rec.Enabled;
    end;

    var
        SetupFieldsEditable: Boolean;
}
