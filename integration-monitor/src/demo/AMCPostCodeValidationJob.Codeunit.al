namespace Addmecode.IntegrationMonitor.Demo;
using Microsoft.Foundation.Address;

codeunit 50116 "AMC Post Code Validation Job"
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
        CommitBatchSize: Integer;
    begin
        CommitBatchSize := 100;
        PostCode.SetRange("AMC Validation Status", PostCode."AMC Validation Status"::" ");
        if PostCode.FindSet(true) then
            repeat
                PostCodeToValidate := PostCode;
                PostCodeValidationMgt.ValidatePostCode(PostCodeToValidate);
                ProcessedCount += 1;
                if ProcessedCount mod CommitBatchSize = 0 then
                    Commit();
            until PostCode.Next() = 0;
    end;
}
