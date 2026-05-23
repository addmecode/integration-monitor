namespace Addmecode.IntegrationMonitor.Demo;
using Microsoft.Foundation.Address;

pageextension 50123 "AMC Post Codes Demo" extends "Post Codes"
{
    layout
    {
        modify(City)
        {
            StyleExpr = ValidationStyle;
        }
        modify(County)
        {
            StyleExpr = ValidationStyle;
        }
        addlast(Control1)
        {
            field("AMC Validation Status"; Rec."AMC Validation Status")
            {
                ApplicationArea = All;
                StyleExpr = ValidationStyle;
            }
            field("AMC Validated At"; Rec."AMC Validated At")
            {
                ApplicationArea = All;
                StyleExpr = ValidationStyle;
            }
            field("AMC Validated By"; Rec."AMC Validated By")
            {
                ApplicationArea = All;
                StyleExpr = ValidationStyle;
            }
        }
    }

    actions
    {
        addlast(processing)
        {
            action("AMC Validate")
            {
                ApplicationArea = All;
                Caption = 'Validate';
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
            action("AMC Reset Validation")
            {
                ApplicationArea = All;
                Caption = 'Reset Validation';
                Image = ResetStatus;
                ToolTip = 'Clear postal code validation fields and delete unprocessed postal code validation queue entries for the selected records.';

                trigger OnAction()
                var
                    SelectedPostCode: Record "Post Code";
                    PostalCodeValidationMgt: Codeunit "AMC Post Code Validation Mgt";
                    DeletedInboxCount: Integer;
                    DeletedOutboxCount: Integer;
                    ResetCount: Integer;
                    EntriesResetMsg: Label '%1 postal code validation records were reset. %2 outbox entries and %3 inbox entries were deleted.', Comment = '%1 = number of reset post code records, %2 = number of deleted outbox entries, %3 = number of deleted inbox entries';
                begin
                    CurrPage.SetSelectionFilter(SelectedPostCode);
                    ResetCount := PostalCodeValidationMgt.ResetValidationForSelection(SelectedPostCode, DeletedOutboxCount, DeletedInboxCount);
                    Message(EntriesResetMsg, ResetCount, DeletedOutboxCount, DeletedInboxCount);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        ValidationStyle := Rec.GetValidationStyle();
    end;

    var
        ValidationStyle: Text;
}
