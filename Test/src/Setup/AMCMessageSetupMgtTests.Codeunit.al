namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Setup;
using System.TestLibraries.Utilities;

codeunit 50147 "AMC Message Setup Mgt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";
        ValidEndpointUrlLbl: Label 'https://api.example.com/validate', Locked = true;

    [Test]
    procedure WhenCleanupFormulaBlank_ThenNoError()
    var
        Setup: Record "AMC Int. Message Setup";
        BlankFormula: DateFormula;
    begin
        // [SCENARIO] A blank cleanup date formula validates without error.
        // [GIVEN] A message setup and a blank "Delete Outbox Entr. Older Than" formula.
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);

        // [WHEN] The blank formula is validated.
        Setup.Validate("Delete Outbox Entr. Older Than", BlankFormula);

        // [THEN] No error is raised and the field stays blank.
        this.Assert.AreEqual('', Format(Setup."Delete Outbox Entr. Older Than"), 'A blank cleanup formula should be accepted.');
    end;

    [Test]
    procedure WhenCleanupFormulaResolvesToday_ThenErrors()
    var
        Setup: Record "AMC Int. Message Setup";
        TodayFormula: DateFormula;
        MustBeBeforeTodayErr: Label 'must calculate to a date before today', Locked = true;
    begin
        // [SCENARIO] A cleanup formula that resolves to today is rejected.
        // [GIVEN] A message setup and a formula that resolves to today.
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);
        Evaluate(TodayFormula, '<0D>');

        // [WHEN] The formula is validated.
        asserterror Setup.Validate("Delete Outbox Entr. Older Than", TodayFormula);

        // [THEN] It errors that the formula must calculate to a date before today.
        this.Assert.ExpectedError(MustBeBeforeTodayErr);
    end;

    [Test]
    procedure WhenCleanupFormulaResolvesFuture_ThenErrors()
    var
        Setup: Record "AMC Int. Message Setup";
        FutureFormula: DateFormula;
        MustBeBeforeTodayErr: Label 'must calculate to a date before today', Locked = true;
    begin
        // [SCENARIO] A cleanup formula that resolves to a future date is rejected.
        // [GIVEN] A message setup and a formula that resolves to tomorrow.
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);
        Evaluate(FutureFormula, '<1D>');

        // [WHEN] The formula is validated.
        asserterror Setup.Validate("Delete Outbox Entr. Older Than", FutureFormula);

        // [THEN] It errors that the formula must calculate to a date before today.
        this.Assert.ExpectedError(MustBeBeforeTodayErr);
    end;

    [Test]
    procedure WhenCleanupFormulaResolvesPast_ThenNoError()
    var
        Setup: Record "AMC Int. Message Setup";
        PastFormula: DateFormula;
    begin
        // [SCENARIO] A cleanup formula that resolves to a past date is accepted.
        // [GIVEN] A message setup and a formula that resolves to yesterday.
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);
        Evaluate(PastFormula, '<-1D>');

        // [WHEN] The formula is validated.
        Setup.Validate("Delete Outbox Entr. Older Than", PastFormula);

        // [THEN] No error is raised and the formula is stored.
        this.Assert.AreEqual('-1D', Format(Setup."Delete Outbox Entr. Older Than"), 'A past cleanup formula should be accepted.');
    end;

    [Test]
    procedure WhenEnabledWithBlankEndpoint_ThenErrors()
    var
        Setup: Record "AMC Int. Message Setup";
    begin
        // [SCENARIO] Enabling a setup with no endpoint URL is rejected by the transport handler.
        // [GIVEN] A disabled HTTP setup whose Endpoint URL is blank.
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);

        // [WHEN] The setup is enabled.
        asserterror Setup.Validate(Enabled, true);

        // [THEN] It errors on the missing Endpoint URL.
        this.Assert.ExpectedError(Setup.FieldCaption("Endpoint URL"));
    end;

    [Test]
    procedure WhenEnabledWithInvalidEndpoint_ThenErrors()
    var
        Setup: Record "AMC Int. Message Setup";
        InvalidUrlErr: Label 'is not valid', Locked = true;
    begin
        // [SCENARIO] Enabling a setup with a malformed endpoint URL is rejected by the transport handler.
        // [GIVEN] A disabled HTTP setup whose Endpoint URL is not a valid HTTP URL.
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);
        Setup."Endpoint URL" := 'not-a-valid-url';
        Setup.Modify(true);

        // [WHEN] The setup is enabled.
        asserterror Setup.Validate(Enabled, true);

        // [THEN] It errors that the URL is not valid.
        this.Assert.ExpectedError(InvalidUrlErr);
    end;

    [Test]
    procedure WhenEnabledWithAuthProfileWithoutSecret_ThenErrors()
    var
        Setup: Record "AMC Int. Message Setup";
        Profile: Record "AMC Int. Auth Profile";
        MissingSecretErr: Label 'does not have a stored secret', Locked = true;
    begin
        // [SCENARIO] Enabling a setup whose auth profile has no stored secret is rejected by the auth check.
        // [GIVEN] A disabled setup with a valid endpoint and an auth profile that lacks a secret.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, false);
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);
        Setup."Endpoint URL" := CopyStr(this.ValidEndpointUrlLbl, 1, MaxStrLen(Setup."Endpoint URL"));
        Setup."Auth Profile Code" := Profile.Code;
        Setup.Modify(true);

        // [WHEN] The setup is enabled.
        asserterror Setup.Validate(Enabled, true);

        // [THEN] It errors that the profile does not have a stored secret.
        this.Assert.ExpectedError(MissingSecretErr);
    end;

    [Test]
    procedure WhenEnabledWithValidEndpointAndAuth_ThenNoError()
    var
        Setup: Record "AMC Int. Message Setup";
        Profile: Record "AMC Int. Auth Profile";
    begin
        // [SCENARIO] A setup with a valid endpoint and a fully configured auth profile can be enabled.
        // [GIVEN] A disabled setup with a valid endpoint and an auth profile that has a stored secret.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, true);
        Setup := this.TestLibrary.CreateMessageSetup(Enum::"AMC Int. Message Type"::Mock, false, 1, 0);
        Setup."Endpoint URL" := CopyStr(this.ValidEndpointUrlLbl, 1, MaxStrLen(Setup."Endpoint URL"));
        Setup."Auth Profile Code" := Profile.Code;
        Setup.Modify(true);

        // [WHEN] The setup is enabled.
        Setup.Validate(Enabled, true);

        // [THEN] No error is raised and the setup is enabled.
        this.Assert.IsTrue(Setup.Enabled, 'A setup with a valid endpoint and configured auth profile should be enabled.');
    end;
}
