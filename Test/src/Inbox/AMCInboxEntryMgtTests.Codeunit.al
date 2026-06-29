namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using System.TestLibraries.Utilities;

codeunit 50145 "AMC Inbox Entry Mgt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenInsertWithoutTimestamps_ThenDefaultsToNow()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        BeforeInsert: DateTime;
        AfterInsert: DateTime;
    begin
        // [SCENARIO] OnInsert defaults Created At and Next Attempt At to the current date/time when they are left blank.
        // [GIVEN] A new inbox entry whose Created At and Next Attempt At are left as 0DT.
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        Inbox.Init();
        Inbox.Validate("Message Type", Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);

        // [WHEN] The entry is inserted, firing the OnInsert trigger.
        BeforeInsert := CurrentDateTime();
        Inbox.Insert(true);
        AfterInsert := CurrentDateTime();

        // [THEN] Both timestamps are set to approximately the current date/time.
        this.TestLibrary.AssertDateTimeWithinRange(Inbox."Created At", BeforeInsert, AfterInsert, 'Created At');
        this.TestLibrary.AssertDateTimeWithinRange(Inbox."Next Attempt At", BeforeInsert, AfterInsert, 'Next Attempt At');
    end;

    [Test]
    procedure WhenInsertWithTimestamps_ThenLeftUnchanged()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        PresetDateTime: DateTime;
    begin
        // [SCENARIO] OnInsert leaves Created At and Next Attempt At unchanged when they are already set.
        // [GIVEN] A new inbox entry with both timestamps explicitly pre-set to a known value.
        this.TestLibrary.EnsureMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        PresetDateTime := CreateDateTime(DMY2Date(1, 1, 2020), 0T);
        Inbox.Init();
        Inbox.Validate("Message Type", Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        Inbox."Created At" := PresetDateTime;
        Inbox."Next Attempt At" := PresetDateTime;

        // [WHEN] The entry is inserted, firing the OnInsert trigger.
        Inbox.Insert(true);

        // [THEN] The pre-set timestamps are left unchanged.
        this.Assert.AreEqual(PresetDateTime, Inbox."Created At", 'A pre-set Created At should be left unchanged on insert.');
        this.Assert.AreEqual(PresetDateTime, Inbox."Next Attempt At", 'A pre-set Next Attempt At should be left unchanged on insert.');
    end;
}
