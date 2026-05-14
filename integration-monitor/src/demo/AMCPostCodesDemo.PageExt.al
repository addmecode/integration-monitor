namespace Addmecode.IntegrationMonitor.Demo;
using Microsoft.Foundation.Address;

pageextension 50123 "AMC Post Codes Demo" extends "Post Codes"
{
    layout
    {
        modify(City)
        {
            Style = Unfavorable;
            StyleExpr = IsCityInvalid;
        }
        addlast(Control1)
        {
            field("AMC City Validation Status"; Rec."AMC City Validation Status")
            {
                ApplicationArea = All;
                Style = Unfavorable;
                StyleExpr = IsCityInvalid;
            }
            field("AMC City Validated At"; Rec."AMC City Validated At")
            {
                ApplicationArea = All;
                Style = Unfavorable;
                StyleExpr = IsCityInvalid;
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action("AMC Validate City")
            {
                ApplicationArea = All;
                Caption = 'Validate City';
                Image = Check;
                ToolTip = 'Create postal code validation outbox entries for the selected post code records.';

                trigger OnAction()
                var
                    SelectedPostCode: Record "Post Code";
                    PostalCodeValidationMgt: Codeunit "AMC Post Code Validation Mgt";
                    CreatedCount: Integer;
                    EntriesCreatedMsg: Label '%1 postal code validation outbox entries were created.', Comment = '%1 = number of created outbox entries';
                begin
                    CurrPage.SetSelectionFilter(SelectedPostCode);
                    CreatedCount := PostalCodeValidationMgt.EnqueueValidationForSelection(SelectedPostCode);
                    Message(EntriesCreatedMsg, CreatedCount);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        IsCityInvalid := Rec."AMC City Validation Status" = Rec."AMC City Validation Status"::Invalid;
    end;

    var
        IsCityInvalid: Boolean;
}
