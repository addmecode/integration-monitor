namespace Addmecode.IntegrationMonitor.Demo;
using Microsoft.Foundation.Address;

tableextension 50123 "AMC Post Code Demo" extends "Post Code"
{
    fields
    {
        field(50100; "AMC Validation Status"; Enum "AMC Validation Status")
        {
            Caption = 'Validation Status';
            DataClassification = CustomerContent;
            Editable = true;
            ToolTip = 'Specifies the validation status from the postal code validation API.';

            trigger OnValidate()
            begin
                UpdateValidationAudit();
            end;
        }
        field(50101; "AMC Validated At"; DateTime)
        {
            Caption = 'Validated At';
            DataClassification = CustomerContent;
            Editable = false;
            ToolTip = 'Specifies when the postal code details were last validated against the postal code validation API.';
        }
        field(50102; "AMC Validated By"; Code[50])
        {
            Caption = 'Validated By';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
            ToolTip = 'Specifies who last changed the postal code validation status.';
        }
        modify(County)
        {
            trigger OnAfterValidate()
            begin
                ResetValidation();
            end;
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

    internal procedure ResetValidation()
    var
        PostCodeValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        PostCodeValidationMgt.ResetValidation(Rec);
    end;

    internal procedure GetValidationStyle(): Text
    var
        PostCodeValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        exit(PostCodeValidationMgt.GetValidationStyle(Rec));
    end;

    local procedure UpdateValidationAudit()
    var
        PostCodeValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        PostCodeValidationMgt.UpdateValidationAudit(Rec);
    end;
}
