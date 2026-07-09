namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Setup;
using System.TestLibraries.Utilities;

codeunit 50143 "AMC Auth Profile Mgt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        TestLibrary: Codeunit "AMC Test Library";
        Assert: Codeunit "Library Assert";

    [Test]
    procedure WhenSetSecretEmpty_ThenErrors()
    var
        Profile: Record "AMC Int. Auth Profile";
        EmptySecret: SecretText;
        EmptySecretErr: Label 'The secret value cannot be empty.', Locked = true;
    begin
        // [SCENARIO] SetSecret refuses an empty secret value.
        // [GIVEN] An auth profile without a stored secret and an empty SecretText.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, false);

        // [WHEN] SetSecret is called with an empty secret.
        asserterror Profile.SetSecret(EmptySecret);

        // [THEN] It errors that the secret value cannot be empty, and no secret was recorded.
        this.Assert.ExpectedError(EmptySecretErr);
        this.Assert.IsFalse(Profile.HasSecret(), 'An empty SetSecret should not store a secret.');
    end;

    [Test]
    procedure WhenSetSecret_ThenStoresAndRecordsAudit()
    var
        Profile: Record "AMC Int. Auth Profile";
        BeforeSet: DateTime;
        AfterSet: DateTime;
        ProfileCode: Code[20];
        SecretValue: Text;
    begin
        // [SCENARIO] SetSecret stores the secret and stamps the audit fields.
        // [GIVEN] An auth profile without a stored secret.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, false);
        ProfileCode := Profile.Code;
        SecretValue := 's3cr3t-value';

        // [WHEN] SetSecret is called with a real secret.
        BeforeSet := CurrentDateTime();
        Profile.SetSecret(SecretValue);
        AfterSet := CurrentDateTime();

        // [THEN] The persisted profile records the secret and the audit stamp.
        Profile.Get(ProfileCode);
        this.Assert.IsTrue(Profile."Has Secret", 'Has Secret should be set after SetSecret.');
        this.Assert.IsTrue(Profile.HasSecret(), 'The secret store should hold the secret after SetSecret.');
        this.TestLibrary.AssertDateTimeIsRecent(Profile."Secret Updated At", BeforeSet, AfterSet, 'Secret Updated At');
        this.Assert.AreEqual(CopyStr(UserId(), 1, MaxStrLen(Profile."Secret Updated By")), Profile."Secret Updated By", 'Secret Updated By should be the current user.');
    end;

    [Test]
    procedure WhenDeleteSecret_ThenClearsSecretAndAudit()
    var
        Profile: Record "AMC Int. Auth Profile";
    begin
        // [SCENARIO] DeleteSecret removes the stored secret and clears the audit fields.
        // [GIVEN] An auth profile with a stored secret and a recorded audit stamp.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, true);
        this.Assert.IsTrue(Profile.HasSecret(), 'Guard: the profile should start with a stored secret.');

        // [WHEN] DeleteSecret runs against it.
        Profile.DeleteSecret();

        // [THEN] The secret store no longer holds the secret and the audit fields are cleared.
        this.Assert.IsFalse(Profile.HasSecret(), 'The secret store should no longer hold the secret after DeleteSecret.');
        this.Assert.IsFalse(Profile."Has Secret", 'Has Secret should be cleared after DeleteSecret.');
        this.Assert.AreEqual(0DT, Profile."Secret Updated At", 'Secret Updated At should be cleared after DeleteSecret.');
        this.Assert.AreEqual('', Profile."Secret Updated By", 'Secret Updated By should be cleared after DeleteSecret.');
    end;

    [Test]
    procedure WhenAuthTypeChanged_ThenDeletesSecret()
    var
        Profile: Record "AMC Int. Auth Profile";
    begin
        // [SCENARIO] Switching Auth Type drops the stored secret so a stale secret cannot survive the type change.
        // [GIVEN] A Basic auth profile with a stored secret.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, true);
        this.Assert.IsTrue(Profile.HasSecret(), 'Guard: the profile should start with a stored secret.');

        // [WHEN] The Auth Type is validated to Bearer Token.
        Profile.Validate("Auth Type", Enum::"AMC Int. Auth Type"::"Bearer Token");

        // [THEN] The stored secret is deleted.
        this.Assert.IsFalse(Profile.HasSecret(), 'Changing the Auth Type should delete the stored secret.');
    end;

    [Test]
    procedure WhenRenameWithSecret_ThenBlocked()
    var
        Profile: Record "AMC Int. Auth Profile";
        CannotRenameErr: Label 'cannot be renamed because it has a stored secret', Locked = true;
    begin
        // [SCENARIO] A profile that holds a stored secret cannot be renamed.
        // [GIVEN] An auth profile with a stored secret.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, true);

        // [WHEN] Its Code is renamed.
        asserterror Profile.Rename('RENAMED');

        // [THEN] It errors that the profile cannot be renamed while it has a stored secret.
        this.Assert.ExpectedError(CannotRenameErr);
    end;

    [Test]
    procedure WhenRenameWithoutSecret_ThenSucceeds()
    var
        Profile: Record "AMC Int. Auth Profile";
        NewCode: Code[20];
    begin
        // [SCENARIO] A profile without a stored secret can be renamed freely.
        // [GIVEN] An auth profile without a stored secret.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, false);
        NewCode := 'RENAMED';

        // [WHEN] Its Code is renamed.
        Profile.Rename(NewCode);

        // [THEN] The profile now lives under the new Code.
        this.Assert.IsTrue(Profile.Get(NewCode), 'A secret-less profile should be renamable to the new Code.');
    end;

    [Test]
    [HandlerFunctions('ConfirmYesHandler')]
    procedure WhenClearSecretConfirmed_ThenDisablesSetupsAndClears()
    var
        Profile: Record "AMC Int. Auth Profile";
        SetupA: Record "AMC Int. Message Setup";
        SetupB: Record "AMC Int. Message Setup";
    begin
        // [SCENARIO] Clearing a secret used by enabled setups disables those setups when the user confirms.
        // [GIVEN] A profile with a stored secret referenced by two enabled message setups.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, true);
        this.CreateEnabledSetupForProfile(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Profile.Code);
        this.CreateEnabledSetupForProfile(Enum::"AMC Int. Message Type"::Mock, Profile.Code);

        // [WHEN] ClearSecretWithEnabledSetupCheck runs and the confirmation is answered yes.
        Profile.ClearSecretWithEnabledSetupCheck();

        // [THEN] Both dependent setups are disabled and the secret is cleared.
        SetupA.Get(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        this.Assert.IsFalse(SetupA.Enabled, 'A dependent setup should be disabled when the secret is cleared on confirm.');
        SetupB.Get(Enum::"AMC Int. Message Type"::Mock);
        this.Assert.IsFalse(SetupB.Enabled, 'A dependent setup should be disabled when the secret is cleared on confirm.');
        this.Assert.IsFalse(Profile.HasSecret(), 'The secret should be cleared after a confirmed ClearSecretWithEnabledSetupCheck.');
    end;

    [Test]
    [HandlerFunctions('ConfirmNoHandler')]
    procedure WhenClearSecretDeclined_ThenNothingChanges()
    var
        Profile: Record "AMC Int. Auth Profile";
        Setup: Record "AMC Int. Message Setup";
    begin
        // [SCENARIO] Declining the confirmation leaves the secret and the dependent setups untouched.
        // [GIVEN] A profile with a stored secret referenced by an enabled message setup.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, true);
        this.CreateEnabledSetupForProfile(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation, Profile.Code);

        // [WHEN] ClearSecretWithEnabledSetupCheck runs and the confirmation is answered no.
        Profile.ClearSecretWithEnabledSetupCheck();

        // [THEN] The setup stays enabled and the secret is retained.
        Setup.Get(Enum::"AMC Int. Message Type"::AMCPostalCodeValidation);
        this.Assert.IsTrue(Setup.Enabled, 'A declined clear should leave the dependent setup enabled.');
        this.Assert.IsTrue(Profile.HasSecret(), 'A declined clear should retain the stored secret.');
    end;

    [Test]
    procedure WhenTestProfileWithoutSecret_ThenErrors()
    var
        Profile: Record "AMC Int. Auth Profile";
        MissingSecretErr: Label 'does not have a stored secret', Locked = true;
    begin
        // [SCENARIO] TestProfile requires a stored secret.
        // [GIVEN] A valid Basic profile (Code and Username set) but without a stored secret.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, false);

        // [WHEN] TestProfile runs against it.
        asserterror Profile.TestProfile();

        // [THEN] It errors that the profile does not have a stored secret.
        this.Assert.ExpectedError(MissingSecretErr);
    end;

    [Test]
    procedure WhenTestProfileBasicWithoutUsername_ThenErrors()
    var
        Profile: Record "AMC Int. Auth Profile";
    begin
        // [SCENARIO] TestProfile runs the type-specific ValidateProfile, which requires the Username for Basic.
        // [GIVEN] A Basic profile with a blank Username.
        Profile := this.TestLibrary.CreateAuthProfile(Enum::"AMC Int. Auth Type"::Basic, false);
        Profile.Username := '';
        Profile.Modify(true);

        // [WHEN] TestProfile runs against it.
        asserterror Profile.TestProfile();

        // [THEN] It errors via TestField(Username).
        this.Assert.ExpectedError(Profile.FieldCaption(Username));
    end;

    local procedure CreateEnabledSetupForProfile(MessageType: Enum "AMC Int. Message Type"; AuthProfileCode: Code[20])
    var
        Setup: Record "AMC Int. Message Setup";
    begin
        Setup := this.TestLibrary.CreateMessageSetup(MessageType, true, 1, 0);
        Setup."Auth Profile Code" := AuthProfileCode;
        Setup.Modify(true);
    end;

    [ConfirmHandler]
    procedure ConfirmYesHandler(Question: Text; var Reply: Boolean)
    begin
        Reply := true;
    end;

    [ConfirmHandler]
    procedure ConfirmNoHandler(Question: Text; var Reply: Boolean)
    begin
        Reply := false;
    end;
}
