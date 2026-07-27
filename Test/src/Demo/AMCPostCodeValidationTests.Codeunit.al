namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Demo;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using Microsoft.Foundation.Address;
using System.TestLibraries.Utilities;

codeunit 50149 "AMC Post Code Validation Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";
        CodePropertyNameLbl: Label 'code', Locked = true;
        CountryRegionCodePropertyNameLbl: Label 'countryRegionCode', Locked = true;

    [Test]
    procedure WhenValidatePostCode_ThenPayloadJsonHasCodeAndCountry()
    var
        PostCode: Record "Post Code";
        Outbox: Record "AMC Int. Outbox Entry";
        ValidationMgt: Codeunit "AMC Post Code Validation Mgt";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        Payload: JsonObject;
        PayloadText: Text;
    begin
        // [SCENARIO] The validation payload is JSON carrying the post code's Code and Country/Region Code.
        // [GIVEN] A post code with a Code and a Country/Region Code.
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        PostCode := this.CreatePostCode();

        // [WHEN] The post code is validated, enqueuing an outbox entry with the built payload.
        ValidationMgt.ValidatePostCode(PostCode);

        // [THEN] The enqueued outbox entry stores JSON with code and countryRegionCode set to the post code's values.
        Outbox.SetRange("Message Type", Outbox."Message Type"::AMCPostalCodeValidation);
        Outbox.SetRange("Source Record ID", PostCode.RecordId());
        this.Assert.IsTrue(Outbox.FindFirst(), 'Validating a post code should enqueue an outbox entry for it.');

        OutboxRef.GetTable(Outbox);
        PayloadText := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Request Payload"));
        this.Assert.IsTrue(Payload.ReadFrom(PayloadText), 'The stored request payload should be valid JSON.');
        this.Assert.AreEqual(PostCode.Code, this.GetJsonText(Payload, this.CodePropertyNameLbl), 'The payload code should equal the post code Code.');
        this.Assert.AreEqual(PostCode."Country/Region Code", this.GetJsonText(Payload, this.CountryRegionCodePropertyNameLbl), 'The payload countryRegionCode should equal the post code Country/Region Code.');
    end;

    local procedure CreatePostCode(): Record "Post Code"
    var
        PostCode: Record "Post Code";
        Any: Codeunit "Any";
    begin
        PostCode.Init();
        PostCode.Code := CopyStr(Any.AlphabeticText(10), 1, MaxStrLen(PostCode.Code));
        PostCode.City := CopyStr(Any.AlphabeticText(10), 1, MaxStrLen(PostCode.City));
        PostCode."Country/Region Code" := CopyStr(Any.AlphabeticText(5), 1, MaxStrLen(PostCode."Country/Region Code"));
        PostCode.County := CopyStr(Any.AlphabeticText(10), 1, MaxStrLen(PostCode.County));
        PostCode.Insert();
        exit(PostCode);
    end;

    local procedure GetJsonText(Payload: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        Payload.Get(PropertyName, Token);
        exit(Token.AsValue().AsText());
    end;
}
