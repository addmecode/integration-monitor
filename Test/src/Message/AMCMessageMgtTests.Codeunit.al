namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Setup;
using System.TestLibraries.Utilities;

codeunit 50148 "AMC Message Mgt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenGetMessageSetupMissing_ThenErrors()
    var
        Setup: Record "AMC Int. Message Setup";
        MessageMgt: Codeunit "AMC Message Mgt.";
        MissingSetupErr: Label 'does not exist', Locked = true;
    begin
        // [SCENARIO] GetMessageSetup errors when no setup row exists for the message type.
        // [GIVEN] A message type with no message setup row.
        this.RemoveMessageSetup(Enum::"AMC Int. Message Type"::Default);

        // [WHEN] GetMessageSetup runs for that message type.
        asserterror MessageMgt.GetMessageSetup(Enum::"AMC Int. Message Type"::Default, Setup);

        // [THEN] It errors that the setup does not exist.
        this.Assert.ExpectedError(MissingSetupErr);
    end;

    [Test]
    procedure WhenTestMessageSetupExistsMissing_ThenErrors()
    var
        MessageMgt: Codeunit "AMC Message Mgt.";
        MissingSetupErr: Label 'does not exist', Locked = true;
    begin
        // [SCENARIO] TestMessageSetupExists errors when no setup row exists for the message type.
        // [GIVEN] A message type with no message setup row.
        this.RemoveMessageSetup(Enum::"AMC Int. Message Type"::Default);

        // [WHEN] TestMessageSetupExists runs for that message type.
        asserterror MessageMgt.TestMessageSetupExists(Enum::"AMC Int. Message Type"::Default);

        // [THEN] It errors that the setup does not exist.
        this.Assert.ExpectedError(MissingSetupErr);
    end;

    [Test]
    procedure WhenGetMessageSetupExists_ThenReturnsIt()
    var
        Setup: Record "AMC Int. Message Setup";
        MessageMgt: Codeunit "AMC Message Mgt.";
    begin
        // [SCENARIO] GetMessageSetup returns the setup without error when it exists.
        // [GIVEN] A message type with an existing message setup row.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);

        // [WHEN] GetMessageSetup runs for that message type.
        MessageMgt.GetMessageSetup(Enum::"AMC Int. Message Type"::Mock, Setup);

        // [THEN] It returns the matching setup without error.
        this.Assert.AreEqual(Enum::"AMC Int. Message Type"::Mock, Setup."Message Type", 'GetMessageSetup should return the setup for the requested message type.');
    end;

    local procedure RemoveMessageSetup(MessageType: Enum "AMC Int. Message Type")
    var
        Setup: Record "AMC Int. Message Setup";
    begin
        if Setup.Get(MessageType) then
            Setup.Delete(true);
    end;
}
