namespace Addmecode.IntegrationMonitor.Demo;
using Microsoft.Foundation.Address;

tableextension 50123 "AMC Post Code Demo" extends "Post Code"
{
    fields
    {
        field(50100; "AMC City Validation Status"; Enum "AMC City Validation Status")
        {
            Caption = 'City Validation Status';
            DataClassification = CustomerContent;
            Editable = true;
            ToolTip = 'Specifies the city validation status from the postal code validation API.';

            trigger OnValidate()
            begin
                UpdateCityValidationAudit();
            end;
        }
        field(50101; "AMC City Validated At"; DateTime)
        {
            Caption = 'City Validated At';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies when the city was last validated against the postal code validation API.';
        }
        field(50102; "AMC City Validated By"; Code[50])
        {
            Caption = 'City Validated By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
            ToolTip = 'Specifies who last changed the city validation status.';
        }

        modify(Code)
        {
            trigger OnAfterValidate()
            begin
                ResetValidation();
            end;
        }
        modify(City)
        {
            trigger OnAfterValidate()
            begin
                ResetValidation();
            end;
        }
        modify("Country/Region Code")
        {
            trigger OnAfterValidate()
            begin
                ResetValidation();
            end;
        }
    }

    local procedure ResetValidation()
    var
        DeletedOutboxCount: Integer;
        DeletedInboxCount: Integer;
    begin
        Rec.ResetValidation(DeletedOutboxCount, DeletedInboxCount);
    end;

    internal procedure ResetValidation(var DeletedOutboxCount: Integer; var DeletedInboxCount: Integer)
    var
        PostCodeValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        PostCodeValidationMgt.ResetValidation(Rec, DeletedOutboxCount, DeletedInboxCount);
    end;

    local procedure UpdateCityValidationAudit()
    var
        PostCodeValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        PostCodeValidationMgt.UpdateCityValidationAudit(Rec);
    end;
}
