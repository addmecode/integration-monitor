namespace Addmecode.IntegrationMonitor.Demo;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using Microsoft.Foundation.Address;
using System.Utilities;

codeunit 50123 "AMC Post Code Validation Mgt"
{
    internal procedure ResetValidationForSelection(var SelectedPostCode: Record "Post Code"): Integer
    var
        PostCode: Record "Post Code";
        PostCodeToReset: Record "Post Code";
        ResetCount: Integer;
    begin
        PostCode.Copy(SelectedPostCode);
        if PostCode.FindSet(true) then
            repeat
                PostCodeToReset := PostCode;
                PostCodeToReset.ResetValidation();
                PostCodeToReset.Modify(true);
                ResetCount += 1;
            until PostCode.Next() = 0;

        exit(ResetCount);
    end;

    internal procedure EnqueueValidationForSelection(var SelectedPostCode: Record "Post Code"): Integer
    var
        PostCode: Record "Post Code";
        PostCodeToValidate: Record "Post Code";
        CreatedCount: Integer;
    begin
        PostCode.Copy(SelectedPostCode);
        if PostCode.FindSet(true) then
            repeat
                PostCodeToValidate := PostCode;
                this.ValidatePostCode(PostCodeToValidate);
                CreatedCount += 1;
            until PostCode.Next() = 0;

        exit(CreatedCount);
    end;

    internal procedure ValidatePostCode(var PostCode: Record "Post Code")
    begin
        this.EnqueueValidation(PostCode);
        this.MarkValidationAsSent(PostCode);
    end;

    local procedure EnqueueValidation(PostCode: Record "Post Code")
    var
        Outbox: Record "AMC Int. Outbox Entry";
        PayloadTempBlob: Codeunit "Temp Blob";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        MessageType: Enum "AMC Int. Message Type";
        PayloadText: Text;
    begin
        PostCode.TestField(Code);
        PostCode.TestField("Country/Region Code");

        PayloadText := this.BuildValidationPayload(PostCode);
        BlobHelper.WriteTextToTempBlob(PayloadTempBlob, PayloadText);

        MessageType := MessageType::AMCPostalCodeValidation;
        Outbox.EnqueueEntry(MessageType, PayloadTempBlob, PostCode.RecordId());
    end;

    internal procedure ResetValidation(var PostCode: Record "Post Code")
    begin
        this.DeleteNotProcessedEntries(PostCode.RecordId());
        PostCode.Validate("AMC Validation Status", PostCode."AMC Validation Status"::" ");
    end;

    internal procedure UpdateValidationAudit(var PostCode: Record "Post Code")
    begin
        if PostCode."AMC Validation Status" = PostCode."AMC Validation Status"::" " then begin
            Clear(PostCode."AMC Validated At");
            Clear(PostCode."AMC Validated By");
            exit;
        end;

        PostCode."AMC Validated At" := CurrentDateTime();
        PostCode."AMC Validated By" := CopyStr(UserId(), 1, MaxStrLen(PostCode."AMC Validated By"));
    end;

    local procedure BuildValidationPayload(PostCode: Record "Post Code"): Text
    var
        Payload: JsonObject;
        PayloadText: Text;
        CodePropertyNameLbl: Label 'code', Locked = true;
        CountryRegionCodePropertyNameLbl: Label 'countryRegionCode', Locked = true;
    begin
        Payload.Add(CodePropertyNameLbl, PostCode.Code);
        Payload.Add(CountryRegionCodePropertyNameLbl, PostCode."Country/Region Code");
        Payload.WriteTo(PayloadText);
        exit(PayloadText);
    end;

    local procedure DeleteNotProcessedEntries(SourceRecordId: RecordId)
    var
        Outbox: Record "AMC Int. Outbox Entry";
    begin
        Outbox.SetRange("Message Type", Outbox."Message Type"::AMCPostalCodeValidation);
        Outbox.SetRange("Source Record ID", SourceRecordId);
        Outbox.SetFilter(Status, '%1|%2', Outbox.Status::ReadyToProcess, Outbox.Status::Cancelled);
        if not Outbox.IsEmpty() then
            Outbox.DeleteAll(true);
    end;

    local procedure MarkValidationAsSent(var PostCode: Record "Post Code")
    begin
        PostCode.Validate("AMC Validation Status", PostCode."AMC Validation Status"::Sent);
        PostCode.Modify(true);
    end;

    internal procedure GetValidationStyle(PostCode: Record "Post Code"): Text
    var
        FavorableStyleLbl: Label 'Favorable', Locked = true;
        UnfavorableStyleLbl: Label 'Unfavorable', Locked = true;
    begin
        case PostCode."AMC Validation Status" of
            PostCode."AMC Validation Status"::Valid:
                exit(FavorableStyleLbl);
            PostCode."AMC Validation Status"::Invalid:
                exit(UnfavorableStyleLbl);
            else
                exit('');
        end
    end;
}
