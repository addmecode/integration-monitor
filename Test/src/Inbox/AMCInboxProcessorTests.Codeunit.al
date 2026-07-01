namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using System.TestLibraries.Utilities;

codeunit 50141 "AMC Inbox Processor Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenSetupDisabled_ThenEntryLeftUntouched()
    var
        Inbox: Record "AMC Int. Inbox Entry";
        EntryNo: Integer;
    begin
        // [SCENARIO] The processor skips an entry whose message setup is disabled, leaving it untouched.
        // [GIVEN] A disabled message setup and a ReadyToProcess inbox entry.
        this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, false, 5, 0);
        Inbox := this.TestLibrary.CreateInboxEntry(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Enum::"AMC Int. Inbox Status"::ReadyToProcess);
        EntryNo := Inbox."Entry No.";

        // [WHEN] The processor runs the entry through its public Run path.
        this.RunProcessor(Inbox);

        // [THEN] The entry is left untouched: a disabled setup means no claim and no processing.
        this.AssertInboxUntouched(EntryNo, Enum::"AMC Int. Inbox Status"::ReadyToProcess, 0);
    end;

    local procedure RunProcessor(var Inbox: Record "AMC Int. Inbox Entry")
    var
        InboxProcessor: Codeunit "AMC Inbox Processor";
    begin
        // Drive DoShouldProcessEntry through the public Run path, mirroring production dispatch.
        this.Assert.IsTrue(InboxProcessor.Run(Inbox), 'A skipped entry should run without error.');
    end;

    local procedure AssertInboxUntouched(EntryNo: Integer; ExpectedStatus: Enum "AMC Int. Inbox Status"; ExpectedAttemptCount: Integer)
    var
        Inbox: Record "AMC Int. Inbox Entry";
    begin
        // "Skip" = the entry's status/attempt fields are unchanged after running (no claim, no processing).
        Inbox.Get(EntryNo);
        this.Assert.AreEqual(ExpectedStatus, Inbox.Status, 'A skipped entry should keep its status.');
        this.Assert.AreEqual(ExpectedAttemptCount, Inbox."Attempt Count", 'A skipped entry should not change its Attempt Count.');
        this.Assert.AreEqual(0DT, Inbox."Last Attempt At", 'A skipped entry should not record a processing attempt.');
    end;
}
