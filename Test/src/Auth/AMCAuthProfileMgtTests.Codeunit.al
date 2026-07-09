namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Auth;
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
}
