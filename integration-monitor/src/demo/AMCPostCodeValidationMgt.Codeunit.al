namespace Addmecode.IntegrationMonitor.Demo;
using Addmecode.IntegrationMonitor.Outbox;
using Microsoft.Foundation.Address;

codeunit 50123 "AMC Post Code Validation Mgt"
{
    procedure EnqueueValidationForSelection(var SelectedPostCode: Record "Post Code"): Integer
    var
        PostCode: Record "Post Code";
        CreatedCount: Integer;
    begin
        PostCode.Copy(SelectedPostCode);
        if PostCode.FindSet() then
            repeat
                this.EnqueueValidation(PostCode);
                this.MarkValidationAsSent(PostCode);
                CreatedCount += 1;
            until PostCode.Next() = 0;

        exit(CreatedCount);
    end;

    procedure EnqueueValidation(PostCode: Record "Post Code")
    var
        Outbox: Record "AMC Int. Outbox Entry";
        Payload: JsonObject;
        PayloadText: Text;
        PayloadOutStream: OutStream;
    begin
        PostCode.TestField(Code);
        PostCode.TestField("Country/Region Code");

        Payload.Add('code', PostCode.Code);
        Payload.Add('countryRegionCode', PostCode."Country/Region Code");
        Payload.Add('city', PostCode.City);
        Payload.WriteTo(PayloadText);

        Outbox.Init();
        Outbox."Message Type" := Outbox."Message Type"::AMCPostalCodeValidation;
        Outbox.Status := Outbox.Status::ReadyToProcess;
        Outbox."Source Record ID" := PostCode.RecordId();
        Outbox."Request Payload".CreateOutStream(PayloadOutStream);
        PayloadOutStream.Write(PayloadText);
        Outbox.Insert(true);
    end;

    local procedure MarkValidationAsSent(var PostCode: Record "Post Code")
    begin
        PostCode."AMC City Validation Status" := PostCode."AMC City Validation Status"::Sent;
        Clear(PostCode."AMC City Validated At");
        PostCode.Modify(true);
    end;
}
