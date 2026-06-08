namespace Addmecode.IntegrationMonitor.Auth;

codeunit 50133 "AMC Int. Auth Secret Store"
{
    [NonDebuggable]
    procedure SetSecret(AuthProfileCode: Code[20]; SecretValue: SecretText)
    var
        AuthProfileCodeRequiredErr: Label 'Authentication profile code must be specified.';
    begin
        if AuthProfileCode = '' then
            Error(AuthProfileCodeRequiredErr);

        IsolatedStorage.Set(this.GetSecretKey(AuthProfileCode), SecretValue, DataScope::Company);
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
    var
        SecretKey: Text;
    begin
        if AuthProfileCode = '' then
            exit;

        SecretKey := this.GetSecretKey(AuthProfileCode);
        if IsolatedStorage.Contains(SecretKey, DataScope::Company) then
            IsolatedStorage.Delete(SecretKey, DataScope::Company);
    end;

    local procedure GetSecretKey(AuthProfileCode: Code[20]): Text
    var
        SecretKeyLbl: Label 'AMC:IntegrationMonitor:AuthProfile:%1:Secret', Locked = true;
    begin
        exit(StrSubstNo(SecretKeyLbl, AuthProfileCode));
    end;
}
