namespace Addmecode.IntegrationMonitor.Demo;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;
using Microsoft.Foundation.Address;
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

    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry")
    var
        PostCode: Record "Post Code";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        InboxRef: RecordRef;
        ResponsePayload: JsonObject;
        PayloadText: Text;
    begin
        InboxRef.GetTable(Inbox);
        PayloadText := BlobHelper.ReadBlobAsText(InboxRef, Inbox.FieldNo("Response Payload"));
        ResponsePayload.ReadFrom(PayloadText);

        this.GetSourcePostCode(Inbox, PostCode);
        this.ValidateResponsePostCode(ResponsePayload, PostCode);

        if this.ResponseMatchesPostCodeDetails(ResponsePayload, PostCode) then
            PostCode.Validate("AMC Validation Status", PostCode."AMC Validation Status"::Valid)
        else
            PostCode.Validate("AMC Validation Status", PostCode."AMC Validation Status"::Invalid);

        PostCode.Modify(true);
    end;

    local procedure GetSourcePostCode(Inbox: Record "AMC Int. Inbox Entry"; var PostCode: Record "Post Code")
    var
        PostCodeRef: RecordRef;
        SourcePostCodeNotFoundErr: Label 'The source postal code record for inbox entry %1 no longer exists.', Comment = '%1 = inbox entry number';
    begin
        if not PostCodeRef.Get(Inbox."Source Record ID") then
            Error(SourcePostCodeNotFoundErr, Inbox."Entry No.");

        PostCodeRef.SetTable(PostCode);
    end;

    local procedure ValidateResponsePostCode(ResponsePayload: JsonObject; PostCode: Record "Post Code")
    var
        ResponsePostCode: Text;
        ResponsePostCodeMismatchErr: Label 'The postal code validation response contains post code %1, but inbox entry source post code is %2.', Comment = '%1 = response post code, %2 = source post code';
    begin
        ResponsePostCode := this.GetPayloadText(ResponsePayload, 'post code');
        if this.NormalizeValue(ResponsePostCode) <> this.NormalizeValue(PostCode.Code) then
            Error(ResponsePostCodeMismatchErr, ResponsePostCode, PostCode.Code);
    end;

    local procedure ResponseMatchesPostCodeDetails(ResponsePayload: JsonObject; PostCode: Record "Post Code"): Boolean
    var
        Place: JsonObject;
        Places: JsonArray;
        PlaceToken: JsonToken;
        PlacesToken: JsonToken;
        Index: Integer;
        MissingPayloadPropertyErr: Label 'The postal code validation payload does not contain property %1.', Comment = '%1 = JSON property name';
        CityFromPayload: Text;
        CityFromTable: Text;
        StateFromPayload: Text;
        StateFromTable: Text;
    begin
        if not ResponsePayload.Get('places', PlacesToken) then
            Error(MissingPayloadPropertyErr, 'places');

        Places := PlacesToken.AsArray();
        if Places.Count() = 0 then
            exit(false);

        CityFromTable := this.NormalizeValue(PostCode.City);
        StateFromTable := this.NormalizeValue(PostCode.County);
        for Index := 0 to Places.Count() - 1 do begin
            Places.Get(Index, PlaceToken);
            Place := PlaceToken.AsObject();
            CityFromPayload := this.NormalizeValue(this.GetPayloadText(Place, 'place name'));
            StateFromPayload := this.NormalizeValue(this.GetPayloadText(Place, 'state abbreviation'));
            if (CityFromPayload = CityFromTable) and (StateFromPayload = StateFromTable) then
                exit(true);
        end;

        exit(false);
    end;

    local procedure NormalizeValue(Value: Text): Text
    begin
        exit(UpperCase(DelChr(Value, '<>', ' ')));
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
