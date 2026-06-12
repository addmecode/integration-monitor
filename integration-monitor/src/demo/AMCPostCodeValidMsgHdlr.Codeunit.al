namespace Addmecode.IntegrationMonitor.Demo;
using Addmecode.IntegrationMonitor.Helpers;
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
        Payload: JsonObject;
        CountryRegionCode: Text;
        PostCode: Text;
        RequestUri: Text;
        CountryRegionCodePropertyNameLbl: Label 'countryRegionCode', Locked = true;
        PostCodePropertyNameLbl: Label 'code', Locked = true;
        HttpGetMethodLbl: Label 'GET', Locked = true;
    begin
        this.GetMessageSetup(Outbox."Message Type", IntMessageSetup);
        this.ReadRequestPayload(Outbox, Payload);
        CountryRegionCode := this.GetPayloadText(Payload, CountryRegionCodePropertyNameLbl);
        PostCode := this.GetPayloadText(Payload, PostCodePropertyNameLbl);

        Request.Method := HttpGetMethodLbl;
        RequestUri := this.BuildRequestUri(IntMessageSetup."Endpoint URL", CountryRegionCode, PostCode);
        Request.SetRequestUri(RequestUri);
    end;

    procedure ProcessResponse(Inbox: Record "AMC Int. Inbox Entry")
    var
        PostCode: Record "Post Code";
        ResponsePayload: JsonObject;
    begin
        this.ReadResponsePayload(Inbox, ResponsePayload);
        this.GetSourcePostCode(Inbox, PostCode);

        if this.ResponseMatchesPostCodeDetails(ResponsePayload, PostCode) then
            PostCode.Validate("AMC Validation Status", PostCode."AMC Validation Status"::Valid)
        else
            PostCode.Validate("AMC Validation Status", PostCode."AMC Validation Status"::Invalid);

        PostCode.Modify(true);
    end;

    local procedure GetMessageSetup(MessageType: Enum "AMC Int. Message Type"; var IntMessageSetup: Record "AMC Int. Message Setup")
    var
        MissingMessageSetupErr: Label 'Integration message setup for message type %1 does not exist.', Comment = '%1 = message type';
    begin
        if not IntMessageSetup.Get(MessageType) then
            Error(MissingMessageSetupErr, Format(MessageType));
    end;

    local procedure ReadRequestPayload(Outbox: Record "AMC Int. Outbox Entry"; var Payload: JsonObject)
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
    begin
        OutboxRef.GetTable(Outbox);
        BlobHelper.ReadBlobAsJsonObject(OutboxRef, Outbox.FieldNo("Request Payload"), Payload);
    end;

    local procedure ReadResponsePayload(Inbox: Record "AMC Int. Inbox Entry"; var ResponsePayload: JsonObject)
    var
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        InboxRef: RecordRef;
    begin
        InboxRef.GetTable(Inbox);
        BlobHelper.ReadBlobAsJsonObject(InboxRef, Inbox.FieldNo("Response Payload"), ResponsePayload);
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

    local procedure ResponseMatchesPostCodeDetails(ResponsePayload: JsonObject; PostCode: Record "Post Code"): Boolean
    var
        Result: JsonObject;
        Results: JsonArray;
        ResultToken: JsonToken;
        Index: Integer;
    begin
        this.GetResults(ResponsePayload, Results);
        if Results.Count() = 0 then
            exit(false);

        for Index := 0 to Results.Count() - 1 do begin
            Results.Get(Index, ResultToken);
            Result := ResultToken.AsObject();
            if this.ResultMatchesPostCodeDetails(Result, PostCode) then
                exit(true);
        end;

        exit(false);
    end;

    local procedure GetResults(ResponsePayload: JsonObject; var Results: JsonArray)
    var
        ResultsToken: JsonToken;
        ResultsPropertyNameLbl: Label 'results', Locked = true;
    begin
        this.GetPayloadToken(ResponsePayload, ResultsPropertyNameLbl, ResultsToken);
        Results := ResultsToken.AsArray();
    end;

    local procedure ResultMatchesPostCodeDetails(Result: JsonObject; PostCode: Record "Post Code"): Boolean
    var
        CountryCodePropertyNameLbl: Label 'country_code', Locked = true;
        PostalCodePropertyNameLbl: Label 'postal_code', Locked = true;
        AdminCodePropertyNameLbl: Label 'admin_code1', Locked = true;
    begin
        exit(
            this.ResultCityMatchesPostCode(Result, PostCode) and
            this.PayloadValueMatchesPostCodeValue(Result, CountryCodePropertyNameLbl, PostCode."Country/Region Code") and
            this.PayloadValueMatchesPostCodeValue(Result, PostalCodePropertyNameLbl, PostCode.Code) and
            this.PayloadValueMatchesPostCodeValue(Result, AdminCodePropertyNameLbl, PostCode.County));
    end;

    local procedure ResultCityMatchesPostCode(Result: JsonObject; PostCode: Record "Post Code"): Boolean
    var
        AdminNameFromPayload: Text;
        CityFromPayload: Text;
        CityFromTable: Text;
        AdminNamePropertyNameLbl: Label 'admin_name1', Locked = true;
        PlaceNamePropertyNameLbl: Label 'place_name', Locked = true;
    begin
        AdminNameFromPayload := this.NormalizeValue(this.GetPayloadText(Result, AdminNamePropertyNameLbl));
        CityFromPayload := this.NormalizeValue(this.GetPayloadText(Result, PlaceNamePropertyNameLbl));
        CityFromTable := this.NormalizeValue(PostCode.City);

        exit((CityFromPayload = CityFromTable) or (AdminNameFromPayload = CityFromTable));
    end;

    local procedure PayloadValueMatchesPostCodeValue(Payload: JsonObject; PropertyName: Text; PostCodeValue: Text): Boolean
    begin
        exit(this.NormalizeValue(this.GetPayloadText(Payload, PropertyName)) = this.NormalizeValue(PostCodeValue));
    end;

    local procedure NormalizeValue(Value: Text): Text
    begin
        exit(UpperCase(DelChr(Value, '<>', ' ')));
    end;

    local procedure BuildRequestUri(BaseUrl: Text; CountryRegionCode: Text; PostCode: Text): Text
    var
        Uri: Codeunit Uri;
        WhereClause: Text;
        QueryStringLbl: Label '?where=%1&limit=10', Locked = true;
        WhereClauseLbl: Label 'country_code="%1" AND postal_code="%2"', Locked = true, Comment = '%1 = country/region code, %2 = postal code';
    begin
        WhereClause := StrSubstNo(WhereClauseLbl, CountryRegionCode, PostCode);
        exit(this.TrimTrailingSlash(BaseUrl) + StrSubstNo(QueryStringLbl, Uri.EscapeDataString(WhereClause)));
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
    begin
        this.GetPayloadToken(Payload, PropertyName, Token);
        exit(Token.AsValue().AsText());
    end;

    local procedure GetPayloadToken(Payload: JsonObject; PropertyName: Text; var Token: JsonToken)
    var
        MissingPayloadPropertyErr: Label 'The postal code validation payload does not contain property %1.', Comment = '%1 = JSON property name';
    begin
        if not Payload.Get(PropertyName, Token) then
            Error(MissingPayloadPropertyErr, PropertyName);
    end;
}
