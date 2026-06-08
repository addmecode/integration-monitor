namespace Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Setup;

codeunit 50120 "AMC Int. Auth Profile Mgt."
{

    internal procedure OnRename(var AuthProfileCurr: Record "AMC Int. Auth Profile"; AuthProfilePrev: Record "AMC Int. Auth Profile")
    var
        CannotRenameProfileWithSecretErr: Label 'Authentication profile %1 cannot be renamed because it has a stored secret. Clear the secret before renaming the profile.', Comment = '%1 = authentication profile code';
    begin
        if AuthProfileCurr.Code = AuthProfilePrev.Code then
            exit;
        if AuthProfileCurr.HasSecret() then
            Error(CannotRenameProfileWithSecretErr, AuthProfileCurr.Code);
    end;

    internal procedure AuthTypeOnValidate(var AuthProfileCurr: Record "AMC Int. Auth Profile"; AuthProfilePrev: Record "AMC Int. Auth Profile")
    var
    begin
        if AuthProfileCurr."Auth Type" = AuthProfilePrev."Auth Type" then
            exit;
        this.DeleteSecret(AuthProfileCurr);
    end;

    [NonDebuggable]
    procedure SetSecret(var AuthProfile: Record "AMC Int. Auth Profile"; SecretValue: SecretText)
    var
        AuthSecretStore: Codeunit "AMC Int. Auth Secret Store";
        EmptySecretErr: Label 'The secret value cannot be empty.';
    begin
        AuthProfile.TestField(Code);
        if SecretValue.IsEmpty() then
            Error(EmptySecretErr);

        AuthSecretStore.SetSecret(AuthProfile.Code, SecretValue);
        this.SetSecretStored(AuthProfile);
        AuthProfile.Modify(true);
    end;

    local procedure SetSecretStored(var AuthProfile: Record "AMC Int. Auth Profile")
    begin
        AuthProfile."Has Secret" := true;
        AuthProfile."Secret Updated At" := CurrentDateTime();
        AuthProfile."Secret Updated By" := CopyStr(UserId(), 1, MaxStrLen(AuthProfile."Secret Updated By"));
    end;

    [NonDebuggable]
    procedure GetSecret(AuthProfileCode: Code[20]; var SecretValue: SecretText): Boolean
    var
        AuthSecretStore: Codeunit "AMC Int. Auth Secret Store";
    begin
        exit(AuthSecretStore.GetSecret(AuthProfileCode, SecretValue));
    end;

    procedure HasSecret(AuthProfileCode: Code[20]): Boolean
    var
        AuthSecretStore: Codeunit "AMC Int. Auth Secret Store";
    begin
        exit(AuthSecretStore.HasSecret(AuthProfileCode));
    end;

    procedure DeleteSecret(var AuthProfile: Record "AMC Int. Auth Profile")
    var
        AuthSecretStore: Codeunit "AMC Int. Auth Secret Store";
    begin
        AuthSecretStore.DeleteSecret(AuthProfile.Code);
        this.ClearSecretStored(AuthProfile);
    end;

    local procedure ClearSecretStored(var AuthProfile: Record "AMC Int. Auth Profile")
    begin
        AuthProfile."Has Secret" := false;
        Clear(AuthProfile."Secret Updated At");
        Clear(AuthProfile."Secret Updated By");
    end;

    procedure ClearSecret(var AuthProfile: Record "AMC Int. Auth Profile")
    begin
        AuthProfile.TestField(Code);
        this.DeleteSecret(AuthProfile);
        AuthProfile.Modify(true);
    end;

    procedure ClearSecretWithEnabledSetupCheck(var AuthProfile: Record "AMC Int. Auth Profile")
    var
        EnabledSetupCount: Integer;
        ClearSecretQst: Label 'Authentication profile %1 is used by %2 enabled integration message setup(s). Do you want to clear the secret anyway? This will disable all enabled setup records that use this authentication profile.', Comment = '%1 = authentication profile code, %2 = enabled setup count';
    begin
        AuthProfile.TestField(Code);

        EnabledSetupCount := this.CountEnabledMessageSetups(AuthProfile.Code);
        if EnabledSetupCount > 0 then begin
            if not Confirm(ClearSecretQst, false, AuthProfile.Code, EnabledSetupCount) then
                exit;

            this.DisableEnabledMessageSetups(AuthProfile.Code);
        end;

        this.ClearSecret(AuthProfile);
    end;

    local procedure CountEnabledMessageSetups(AuthProfileCode: Code[20]): Integer
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
    begin
        IntMessageSetup.SetRange("Auth Profile Code", AuthProfileCode);
        IntMessageSetup.SetRange(Enabled, true);
        exit(IntMessageSetup.Count());
    end;

    local procedure DisableEnabledMessageSetups(AuthProfileCode: Code[20])
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
    begin
        IntMessageSetup.SetRange("Auth Profile Code", AuthProfileCode);
        IntMessageSetup.SetRange(Enabled, true);
        if IntMessageSetup.FindSet(true) then
            repeat
                IntMessageSetup.Validate(Enabled, false);
                IntMessageSetup.Modify(true);
            until IntMessageSetup.Next() = 0;
    end;

    procedure TestProfileCode(AuthProfileCode: Code[20])
    var
        AuthProfile: Record "AMC Int. Auth Profile";
        MissingProfileErr: Label 'Authentication profile %1 does not exist.', Comment = '%1 = authentication profile code';
    begin
        if AuthProfileCode = '' then
            exit;

        if not AuthProfile.Get(AuthProfileCode) then
            Error(MissingProfileErr, AuthProfileCode);

        this.TestProfile(AuthProfile);
    end;

    procedure TestProfile(AuthProfile: Record "AMC Int. Auth Profile")
    var
        MissingSecretErr: Label 'Authentication profile %1 does not have a stored secret.', Comment = '%1 = authentication profile code';
    begin
        AuthProfile.TestField(Code);

        case AuthProfile."Auth Type" of
            AuthProfile."Auth Type"::Basic:
                AuthProfile.TestField(Username);
            AuthProfile."Auth Type"::"Bearer Token":
                ;
        end;

        if not this.HasSecret(AuthProfile.Code) then
            Error(MissingSecretErr, AuthProfile.Code);
    end;
}
