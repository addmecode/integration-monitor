namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Helpers;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;
using System.TestLibraries.Utilities;

codeunit 50146 "AMC Blob Helper Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenWriteAndReadTextBlob_ThenReturnsOriginalText()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        ExpectedText: Text;
        ActualText: Text;
    begin
        // [SCENARIO] Text written to a BLOB field reads back identical, including non-ASCII (UTF-8).
        // [GIVEN] A persisted record with a BLOB field and a known non-ASCII string.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        OutboxRef.GetTable(Outbox);
        ExpectedText := 'Hello world';

        // [WHEN] The text is written via WriteTextToBlob and read back via ReadBlobAsText.
        BlobHelper.WriteTextToBlob(OutboxRef, Outbox.FieldNo("Request Payload"), ExpectedText);
        ActualText := BlobHelper.ReadBlobAsText(OutboxRef, Outbox.FieldNo("Request Payload"));

        // [THEN] The round-tripped text equals the original.
        this.Assert.AreEqual(ExpectedText, ActualText, 'BLOB text round-trip should preserve the original string.');
    end;

    [Test]
    procedure WhenReadJsonBlob_ThenReturnsExpectedProperties()
    var
        Outbox: Record "AMC Int. Outbox Entry";
        BlobHelper: Codeunit "AMC Int. Blob Helper";
        OutboxRef: RecordRef;
        ExpectedJson: JsonObject;
        ActualJson: JsonObject;
        CodeToken: JsonToken;
        CountryToken: JsonToken;
        SerializedJson: Text;
    begin
        // [SCENARIO] A BLOB written with a serialized JsonObject parses back into an equivalent JsonObject.
        // [GIVEN] A persisted record whose BLOB field holds a serialized JsonObject with known properties.
        Outbox := this.TestLibrary.CreateOutboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        OutboxRef.GetTable(Outbox);
        ExpectedJson.Add('code', '12345');
        ExpectedJson.Add('countryRegionCode', 'US');
        ExpectedJson.WriteTo(SerializedJson);
        BlobHelper.WriteTextToBlob(OutboxRef, Outbox.FieldNo("Request Payload"), SerializedJson);

        // [WHEN] The BLOB is read back via ReadBlobAsJsonObject.
        BlobHelper.ReadBlobAsJsonObject(OutboxRef, Outbox.FieldNo("Request Payload"), ActualJson);

        // [THEN] The parsed JsonObject exposes the expected properties and values.
        this.Assert.IsTrue(ActualJson.Get('code', CodeToken), 'Parsed JSON should contain the "code" property.');
        this.Assert.AreEqual('12345', CodeToken.AsValue().AsText(), 'The "code" property should round-trip its value.');
        this.Assert.IsTrue(ActualJson.Get('countryRegionCode', CountryToken), 'Parsed JSON should contain the "countryRegionCode" property.');
        this.Assert.AreEqual('US', CountryToken.AsValue().AsText(), 'The "countryRegionCode" property should round-trip its value.');
    end;
}
