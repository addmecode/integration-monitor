namespace Addmecode.IntegrationMonitor.Demo;
using Microsoft.Foundation.Address;

codeunit 50129 "AMC Post Code Validation Job"
{
    trigger OnRun()
    begin
        this.EnqueuePostCodesForValidation();
    end;

    local procedure EnqueuePostCodesForValidation()
    var
        PostCode: Record "Post Code";
        PostCodeToValidate: Record "Post Code";
        PostCodeValidationMgt: Codeunit "AMC Post Code Validation Mgt";
        ProcessedCount: Integer;
        COMMIT_BATCH_SIZE: Integer;
    begin
        COMMIT_BATCH_SIZE := 100;

        PostCode.SetRange("AMC Validation Status", PostCode."AMC Validation Status"::" ");
        if PostCode.FindSet() then
            repeat
                PostCodeToValidate := PostCode;
                PostCodeValidationMgt.ValidatePostCode(PostCodeToValidate);
                ProcessedCount += 1;
                if ProcessedCount mod COMMIT_BATCH_SIZE = 0 then
                    Commit();
            until PostCode.Next() = 0;
    end;
}
