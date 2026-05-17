namespace Addmecode.IntegrationMonitor.Demo;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;
using System.Utilities;

codeunit 50124 "AMC Post Code Valid Msg Hdlr" implements "AMC IMessageHandler"
{
    procedure BuildRequest(Outbox: Record "AMC Int. Outbox Entry"; var Request: HttpRequestMessage)
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        Payload: JsonObject;
        PayloadText: Text;
        CountryRegionCode: Text;
        PostCode: Text;
    begin
        IntMessageSetup.Get(Outbox."Message Type");

        OutboxRef.GetTable(Outbox);
        PayloadText := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Request Payload"));
        Payload.ReadFrom(PayloadText);
        CountryRegionCode := this.GetPayloadText(Payload, 'countryRegionCode');
        PostCode := this.GetPayloadText(Payload, 'code');

        Request.Method := 'GET';
        // todo: save BuildRequestUri to local var before using it
        Request.SetRequestUri(this.BuildRequestUri(IntMessageSetup."Endpoint URL", CountryRegionCode, PostCode));
    end;

    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry"; var Success: Boolean)
    begin
        Success := false;
    end;

    local procedure BuildRequestUri(BaseUrl: Text; CountryRegionCode: Text; PostCode: Text): Text
    var
        Uri: Codeunit Uri;
    begin
        exit(this.TrimTrailingSlash(BaseUrl) + '/' + Uri.EscapeDataString(CountryRegionCode) + '/' + Uri.EscapeDataString(PostCode));
    end;

    local procedure TrimTrailingSlash(Value: Text): Text
    begin
        if CopyStr(Value, StrLen(Value), 1) = '/' then
            exit(CopyStr(Value, 1, StrLen(Value) - 1));

        exit(Value);
    end;

    local procedure GetPayloadText(Payload: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
        MissingPayloadPropertyErr: Label 'The postal code validation payload does not contain property %1.', Comment = '%1 = JSON property name';
    begin
        if not Payload.Get(PropertyName, Token) then
            Error(MissingPayloadPropertyErr, PropertyName);

        exit(Token.AsValue().AsText());
    end;
}
