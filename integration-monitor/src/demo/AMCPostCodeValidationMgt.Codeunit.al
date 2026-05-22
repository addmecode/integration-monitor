namespace Addmecode.IntegrationMonitor.Demo;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Outbox;
using Microsoft.Foundation.Address;

codeunit 50123 "AMC Post Code Validation Mgt"
{
    procedure ResetValidationForSelection(var SelectedPostCode: Record "Post Code"; var DeletedOutboxCount: Integer; var DeletedInboxCount: Integer): Integer
    var
        PostCode: Record "Post Code";
        ResetCount: Integer;
    begin
        PostCode.Copy(SelectedPostCode);
        if PostCode.FindSet() then
            repeat
                PostCode.ResetValidation(DeletedOutboxCount, DeletedInboxCount);
                PostCode.Modify(true);
                ResetCount += 1;
            until PostCode.Next() = 0;

        exit(ResetCount);
    end;

    procedure EnqueueValidationForSelection(var SelectedPostCode: Record "Post Code"): Integer
    var
        PostCode: Record "Post Code";
        CreatedCount: Integer;
    begin
        PostCode.Copy(SelectedPostCode);
        if PostCode.FindSet() then
            repeat
                this.ValidatePostCode(PostCode);
                CreatedCount += 1;
            until PostCode.Next() = 0;

        exit(CreatedCount);
    end;

    internal procedure ValidatePostCode(var PostCode: Record "Post Code")
    begin
        this.EnqueueValidation(PostCode);
        this.MarkValidationAsSent(PostCode);
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
        Payload.WriteTo(PayloadText);

        Outbox.Init();
        Outbox."Message Type" := Outbox."Message Type"::AMCPostalCodeValidation;
        Outbox.Status := Outbox.Status::ReadyToProcess;
        Outbox."Source Record ID" := PostCode.RecordId();
        Outbox."Request Payload".CreateOutStream(PayloadOutStream);
        PayloadOutStream.Write(PayloadText);
        Outbox.Insert(true);
    end;

    procedure ResetValidation(var PostCode: Record "Post Code"; var DeletedOutboxCount: Integer; var DeletedInboxCount: Integer)
    begin
        this.DeleteNotProcessedEntries(PostCode.RecordId(), DeletedOutboxCount, DeletedInboxCount);

        PostCode.Validate("AMC Validation Status", PostCode."AMC Validation Status"::" ");
    end;

    procedure UpdateValidationAudit(var PostCode: Record "Post Code")
    begin
        if PostCode."AMC Validation Status" = PostCode."AMC Validation Status"::" " then begin
            Clear(PostCode."AMC Validated At");
            Clear(PostCode."AMC Validated By");
            exit;
        end;

        PostCode."AMC Validated At" := CurrentDateTime();
        PostCode."AMC Validated By" := CopyStr(UserId(), 1, MaxStrLen(PostCode."AMC Validated By"));
    end;

    local procedure DeleteNotProcessedEntries(SourceRecordId: RecordId; var DeletedOutboxCount: Integer; var DeletedInboxCount: Integer)
    var
        Outbox: Record "AMC Int. Outbox Entry";
    begin
        Outbox.SetRange("Message Type", Outbox."Message Type"::AMCPostalCodeValidation);
        Outbox.SetRange("Source Record ID", SourceRecordId);
        Outbox.SetFilter(Status, '%1|%2', Outbox.Status::ReadyToProcess, Outbox.Status::Cancelled);
        Outbox.SetLoadFields("Entry No.");
        if Outbox.FindSet(true) then
            repeat
                this.DeleteNotProcessedInboxEntries(Outbox."Entry No.", DeletedInboxCount);
                Outbox.Delete(true);
                DeletedOutboxCount += 1;
            until Outbox.Next() = 0;
    end;

    local procedure DeleteNotProcessedInboxEntries(OutboxEntryNo: Integer; var DeletedInboxCount: Integer)
    var
        Inbox: Record "AMC Int. Inbox Entry";
    begin
        Inbox.SetRange("Outbox Entry No.", OutboxEntryNo);
        Inbox.SetFilter(Status, '%1|%2', Inbox.Status::ReadyToProcess, Inbox.Status::Cancelled);
        DeletedInboxCount += Inbox.Count();
        Inbox.DeleteAll(true);
    end;

    local procedure MarkValidationAsSent(var PostCode: Record "Post Code")
    begin
        PostCode.Validate("AMC Validation Status", PostCode."AMC Validation Status"::Sent);
        PostCode.Modify(true);
    end;

    internal procedure GetValidationStyle(PostCode: Record "Post Code"): Text
    begin
        case PostCode."AMC Validation Status" of
            PostCode."AMC Validation Status"::Valid:
                exit('Favorable');
            PostCode."AMC Validation Status"::Invalid:
                exit('Unfavorable');
            else
                exit('');
        end
    end;
}
