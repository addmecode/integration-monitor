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
        Any: Codeunit "Any";
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

    [Test]
    procedure WhenValidatePostCode_ThenCreatesOutboxAndMarksSent()
    var
        PostCode: Record "Post Code";
        Outbox: Record "AMC Int. Outbox Entry";
        ValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        // [SCENARIO] Validating a post code enqueues an outbox entry for it and marks it Sent.
        // [GIVEN] A post code with a Code and a Country/Region Code.
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        PostCode := this.CreatePostCode();

        // [WHEN] The post code is validated.
        ValidationMgt.ValidatePostCode(PostCode);

        // [THEN] A postal-code-validation outbox entry exists for that source record.
        Outbox.SetRange("Message Type", Outbox."Message Type"::AMCPostalCodeValidation);
        Outbox.SetRange("Source Record ID", PostCode.RecordId());
        this.Assert.IsTrue(Outbox.FindFirst(), 'Validating a post code should enqueue an outbox entry for it.');

        // [THEN] The post code is marked Sent, both in memory and as persisted.
        this.Assert.AreEqual(PostCode."AMC Validation Status"::Sent, PostCode."AMC Validation Status", 'ValidatePostCode should mark the post code Sent.');
        PostCode.Get(PostCode.Code, PostCode.City);
        this.Assert.AreEqual(PostCode."AMC Validation Status"::Sent, PostCode."AMC Validation Status", 'The Sent status should be persisted on the post code.');
    end;

    [Test]
    procedure WhenValidatePostCodeWithoutCode_ThenErrors()
    var
        PostCode: Record "Post Code";
        ValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        // [SCENARIO] Validating a post code with no Code is rejected by TestField.
        // [GIVEN] A post code whose Code is blank.
        PostCode.Init();
        PostCode.City := 'CITY';
        PostCode."Country/Region Code" := 'US';

        // [WHEN] The post code is validated.
        asserterror ValidationMgt.ValidatePostCode(PostCode);

        // [THEN] It errors on the missing Code.
        this.Assert.ExpectedError(PostCode.FieldCaption(Code));
    end;

    [Test]
    procedure WhenValidatePostCodeWithoutCountry_ThenErrors()
    var
        PostCode: Record "Post Code";
        ValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        // [SCENARIO] Validating a post code with no Country/Region Code is rejected by TestField.
        // [GIVEN] A post code with a Code but a blank Country/Region Code.
        PostCode.Init();
        PostCode.Code := 'CODE';
        PostCode.City := 'CITY';

        // [WHEN] The post code is validated.
        asserterror ValidationMgt.ValidatePostCode(PostCode);

        // [THEN] It errors on the missing Country/Region Code.
        this.Assert.ExpectedError(PostCode.FieldCaption("Country/Region Code"));
    end;

    [Test]
    procedure WhenResetValidation_ThenDeletesPendingEntriesAndClearsStatus()
    var
        PostCode: Record "Post Code";
        OtherPostCode: Record "Post Code";
        Outbox: Record "AMC Int. Outbox Entry";
        ValidationMgt: Codeunit "AMC Post Code Validation Mgt";
        ReadyEntryNo: Integer;
        CancelledEntryNo: Integer;
        ProcessedEntryNo: Integer;
        SendingEntryNo: Integer;
        OtherReadyEntryNo: Integer;
    begin
        // [SCENARIO] ResetValidation deletes only the ReadyToProcess/Cancelled entries of the source record and blanks its status.
        // [GIVEN] A validated post code with outbox entries in various statuses, plus a ready entry on another post code.
        PostCode := this.CreatePostCode();
        PostCode."AMC Validation Status" := PostCode."AMC Validation Status"::Valid;
        PostCode.Modify();
        OtherPostCode := this.CreatePostCode();

        ReadyEntryNo := this.CreateOutboxEntry(PostCode.RecordId(), Enum::"AMC Int. Outbox Status"::ReadyToProcess);
        CancelledEntryNo := this.CreateOutboxEntry(PostCode.RecordId(), Enum::"AMC Int. Outbox Status"::Cancelled);
        ProcessedEntryNo := this.CreateOutboxEntry(PostCode.RecordId(), Enum::"AMC Int. Outbox Status"::Processed);
        SendingEntryNo := this.CreateOutboxEntry(PostCode.RecordId(), Enum::"AMC Int. Outbox Status"::Sending);
        OtherReadyEntryNo := this.CreateOutboxEntry(OtherPostCode.RecordId(), Enum::"AMC Int. Outbox Status"::ReadyToProcess);

        // [WHEN] ResetValidation runs for the post code.
        ValidationMgt.ResetValidation(PostCode);

        // [THEN] The ReadyToProcess and Cancelled entries of this source are deleted.
        this.Assert.IsFalse(Outbox.Get(ReadyEntryNo), 'The ReadyToProcess entry of the source should be deleted.');
        this.Assert.IsFalse(Outbox.Get(CancelledEntryNo), 'The Cancelled entry of the source should be deleted.');

        // [THEN] Entries in other statuses and entries of other sources are retained.
        this.Assert.IsTrue(Outbox.Get(ProcessedEntryNo), 'The Processed entry should be retained.');
        this.Assert.IsTrue(Outbox.Get(SendingEntryNo), 'The Sending entry should be retained.');
        this.Assert.IsTrue(Outbox.Get(OtherReadyEntryNo), 'A ready entry of another source should be retained.');

        // [THEN] The post code validation status is blanked.
        this.Assert.AreEqual(PostCode."AMC Validation Status"::" ", PostCode."AMC Validation Status", 'ResetValidation should blank the validation status.');
    end;

    [Test]
    procedure WhenStatusValid_ThenStyleFavorable()
    var
        PostCode: Record "Post Code";
        ValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        // [SCENARIO] GetValidationStyle maps a Valid status to the Favorable style.
        // [GIVEN] A post code whose validation status is Valid.
        PostCode.Init();
        PostCode."AMC Validation Status" := PostCode."AMC Validation Status"::Valid;

        // [THEN] The style is Favorable.
        this.Assert.AreEqual('Favorable', ValidationMgt.GetValidationStyle(PostCode), 'A Valid status should map to the Favorable style.');
    end;

    [Test]
    procedure WhenStatusInvalid_ThenStyleUnfavorable()
    var
        PostCode: Record "Post Code";
        ValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        // [SCENARIO] GetValidationStyle maps an Invalid status to the Unfavorable style.
        // [GIVEN] A post code whose validation status is Invalid.
        PostCode.Init();
        PostCode."AMC Validation Status" := PostCode."AMC Validation Status"::Invalid;

        // [THEN] The style is Unfavorable.
        this.Assert.AreEqual('Unfavorable', ValidationMgt.GetValidationStyle(PostCode), 'An Invalid status should map to the Unfavorable style.');
    end;

    [Test]
    procedure WhenStatusSent_ThenStyleEmpty()
    var
        PostCode: Record "Post Code";
        ValidationMgt: Codeunit "AMC Post Code Validation Mgt";
    begin
        // [SCENARIO] GetValidationStyle maps any other status to an empty style.
        // [GIVEN] A post code whose validation status is Sent (neither Valid nor Invalid).
        PostCode.Init();
        PostCode."AMC Validation Status" := PostCode."AMC Validation Status"::Sent;

        // [THEN] The style is empty.
        this.Assert.AreEqual('', ValidationMgt.GetValidationStyle(PostCode), 'A non-Valid/Invalid status should map to an empty style.');
    end;

    local procedure CreateOutboxEntry(SourceRecordId: RecordId; Status: Enum "AMC Int. Outbox Status"): Integer
    var
        Outbox: Record "AMC Int. Outbox Entry";
    begin
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        Outbox.Init();
        Outbox.Validate("Message Type", Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        Outbox.Insert(true);
        Outbox."Source Record ID" := SourceRecordId;
        Outbox.Status := Status;
        Outbox.Modify(true);
        exit(Outbox."Entry No.");
    end;

    local procedure CreatePostCode(): Record "Post Code"
    var
        PostCode: Record "Post Code";
        PostCodeKey: Code[20];
        CityKey: Text[30];
    begin
        // One shared Any (codeunit-level) advances its sequence across calls, so multiple post codes
        // in one test get distinct keys. Any reseeds per test, so a prior test can leave a same-keyed
        // row behind; delete it first (mirrors CreateAuthProfile) and re-Get so the record is DB-clean.
        PostCodeKey := CopyStr(this.Any.AlphabeticText(10), 1, MaxStrLen(PostCode.Code));
        CityKey := CopyStr(this.Any.AlphabeticText(10), 1, MaxStrLen(PostCode.City));
        if PostCode.Get(PostCodeKey, CityKey) then
            PostCode.Delete(true);

        PostCode.Init();
        PostCode.Code := PostCodeKey;
        PostCode.City := CityKey;
        PostCode."Country/Region Code" := CopyStr(this.Any.AlphabeticText(5), 1, MaxStrLen(PostCode."Country/Region Code"));
        PostCode.County := CopyStr(this.Any.AlphabeticText(10), 1, MaxStrLen(PostCode.County));
        PostCode.Insert();

        PostCode.Get(PostCodeKey, CityKey);
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
