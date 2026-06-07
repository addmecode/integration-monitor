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
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        Payload: JsonObject;
        PayloadText: Text;
        CountryRegionCode: Text;
        PostCode: Text;
        RequestUri: Text;
    begin
        IntMessageSetup.Get(Outbox."Message Type");

        OutboxRef.GetTable(Outbox);
        PayloadText := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Request Payload"));
        Payload.ReadFrom(PayloadText);
        CountryRegionCode := this.GetPayloadText(Payload, 'countryRegionCode');
        PostCode := this.GetPayloadText(Payload, 'code');

        Request.Method := 'GET';
        RequestUri := this.BuildRequestUri(IntMessageSetup."Endpoint URL", CountryRegionCode, PostCode);
        Request.SetRequestUri(RequestUri);
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

    local procedure ResponseMatchesPostCodeDetails(ResponsePayload: JsonObject; PostCode: Record "Post Code"): Boolean
    var
        Result: JsonObject;
        Results: JsonArray;
        ResultToken: JsonToken;
        ResultsToken: JsonToken;
        Index: Integer;
        MissingPayloadPropertyErr: Label 'The postal code validation payload does not contain property %1.', Comment = '%1 = JSON property name';
        AdminNameFromPayload: Text;
        CityFromPayload: Text;
        CityMatchesPayload: Boolean;
        CityFromTable: Text;
        CountryRegionFromPayload: Text;
        CountryRegionFromTable: Text;
        PostCodeFromPayload: Text;
        PostCodeFromTable: Text;
        StateFromPayload: Text;
        StateFromTable: Text;
    begin
        if not ResponsePayload.Get('results', ResultsToken) then
            Error(MissingPayloadPropertyErr, 'results');

        Results := ResultsToken.AsArray();
        if Results.Count() = 0 then
            exit(false);

        CityFromTable := this.NormalizeValue(PostCode.City);
        CountryRegionFromTable := this.NormalizeValue(PostCode."Country/Region Code");
        PostCodeFromTable := this.NormalizeValue(PostCode.Code);
        StateFromTable := this.NormalizeValue(PostCode.County);
        for Index := 0 to Results.Count() - 1 do begin
            Results.Get(Index, ResultToken);
            Result := ResultToken.AsObject();
            AdminNameFromPayload := this.NormalizeValue(this.GetPayloadText(Result, 'admin_name1'));
            CityFromPayload := this.NormalizeValue(this.GetPayloadText(Result, 'place_name'));
            CityMatchesPayload := (CityFromPayload = CityFromTable) or (AdminNameFromPayload = CityFromTable);
            CountryRegionFromPayload := this.NormalizeValue(this.GetPayloadText(Result, 'country_code'));
            PostCodeFromPayload := this.NormalizeValue(this.GetPayloadText(Result, 'postal_code'));
            StateFromPayload := this.NormalizeValue(this.GetPayloadText(Result, 'admin_code1'));
            if CityMatchesPayload and
               (CountryRegionFromPayload = CountryRegionFromTable) and
               (PostCodeFromPayload = PostCodeFromTable) and
               (StateFromPayload = StateFromTable)
            then
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
        WhereClause: Text;
    begin
        WhereClause := StrSubstNo('country_code="%1" AND postal_code="%2"', CountryRegionCode, PostCode);
        exit(this.TrimTrailingSlash(BaseUrl) + '?where=' + Uri.EscapeDataString(WhereClause) + '&limit=10');
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
