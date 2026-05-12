namespace Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Setup;

codeunit 50120 "AMC Int. Auth Profile Mgt."
{
    [NonDebuggable]
    procedure SetSecret(var AuthProfile: Record "AMC Int. Auth Profile"; SecretValue: SecretText)
    var
        EmptySecretErr: Label 'The secret value cannot be empty.';
    begin
        AuthProfile.TestField(Code);
        if SecretValue.IsEmpty() then
            Error(EmptySecretErr);

        IsolatedStorage.Set(this.GetSecretKey(AuthProfile.Code), SecretValue, DataScope::Company);
        AuthProfile.SetSecretStored();
        AuthProfile.Modify(true);
    end;

    [NonDebuggable]
    procedure GetSecret(AuthProfileCode: Code[20]; var SecretValue: SecretText): Boolean
    begin
        if AuthProfileCode = '' then
            exit(false);

        exit(IsolatedStorage.Get(this.GetSecretKey(AuthProfileCode), DataScope::Company, SecretValue));
    end;

    procedure HasSecret(AuthProfileCode: Code[20]): Boolean
    begin
        if AuthProfileCode = '' then
            exit(false);

        exit(IsolatedStorage.Contains(this.GetSecretKey(AuthProfileCode), DataScope::Company));
    end;

    procedure DeleteSecret(AuthProfileCode: Code[20])
    begin
        if AuthProfileCode = '' then
            exit;

        if IsolatedStorage.Contains(this.GetSecretKey(AuthProfileCode), DataScope::Company) then
            IsolatedStorage.Delete(this.GetSecretKey(AuthProfileCode), DataScope::Company);
    end;

    procedure ClearSecret(var AuthProfile: Record "AMC Int. Auth Profile")
    begin
        AuthProfile.TestField(Code);
        this.DeleteSecret(AuthProfile.Code);
        AuthProfile.ClearSecretStored();
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

    local procedure GetSecretKey(AuthProfileCode: Code[20]): Text
    var
        KeyLbl: label 'AMC:IntegrationMonitor:AuthProfile:%1:Secret', Locked = true;
    begin
        exit(StrSubstNo(KeyLbl, AuthProfileCode));
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
}
