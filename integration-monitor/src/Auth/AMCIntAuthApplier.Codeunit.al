namespace Addmecode.IntegrationMonitor.Auth;

using System.Text;

codeunit 50121 "AMC Int. Auth Applier"
{
    [NonDebuggable]
    procedure ApplyAuth(var Request: HttpRequestMessage; AuthProfileCode: Code[20])
    var
        AuthProfile: Record "AMC Int. Auth Profile";
        MissingProfileErr: Label 'Authentication profile %1 does not exist.', Comment = '%1 = authentication profile code';
    begin
        if AuthProfileCode = '' then
            exit;

        if not AuthProfile.Get(AuthProfileCode) then
            Error(MissingProfileErr, AuthProfileCode);

        AuthProfile.TestProfile();

        case AuthProfile."Auth Type" of
            AuthProfile."Auth Type"::Basic:
                this.ApplyBasicAuth(Request, AuthProfile);
            AuthProfile."Auth Type"::"Bearer Token":
                this.ApplyBearerTokenAuth(Request, AuthProfile);
        end;

        this.OnAfterApplyAuth(Request, AuthProfile);
    end;

    [NonDebuggable]
    local procedure ApplyBasicAuth(var Request: HttpRequestMessage; AuthProfile: Record "AMC Int. Auth Profile")
    var
        Base64Convert: Codeunit "Base64 Convert";
        Password: SecretText;
        Credential: SecretText;
        AuthorizationValue: SecretText;
    begin
        this.GetProfileSecret(AuthProfile, Password);
        Credential := SecretStrSubstNo('%1:%2', AuthProfile.Username, Password);
        AuthorizationValue := SecretStrSubstNo('Basic %1', Base64Convert.ToBase64(Credential));
        this.SetAuthorizationHeader(Request, AuthorizationValue);
    end;

    [NonDebuggable]
    local procedure ApplyBearerTokenAuth(var Request: HttpRequestMessage; AuthProfile: Record "AMC Int. Auth Profile")
    var
        Token: SecretText;
        AuthorizationValue: SecretText;
    begin
        this.GetProfileSecret(AuthProfile, Token);
        AuthorizationValue := SecretStrSubstNo('Bearer %1', Token);
        this.SetAuthorizationHeader(Request, AuthorizationValue);
    end;

    [NonDebuggable]
    local procedure GetProfileSecret(AuthProfile: Record "AMC Int. Auth Profile"; var SecretValue: SecretText)
    var
        MissingSecretErr: Label 'Authentication profile %1 does not have a stored secret.', Comment = '%1 = authentication profile code';
    begin
        if not AuthProfile.GetSecret(SecretValue) then
            Error(MissingSecretErr, AuthProfile.Code);
    end;

    [NonDebuggable]
    local procedure SetAuthorizationHeader(var Request: HttpRequestMessage; AuthorizationValue: SecretText)
    var
        RequestHeaders: HttpHeaders;
        AuthorizationHeaderNameLbl: Label 'Authorization', Locked = true;
    begin
        Request.GetHeaders(RequestHeaders);
        if RequestHeaders.Contains(AuthorizationHeaderNameLbl) or RequestHeaders.ContainsSecret(AuthorizationHeaderNameLbl) then
            RequestHeaders.Remove(AuthorizationHeaderNameLbl);

        RequestHeaders.Add(AuthorizationHeaderNameLbl, AuthorizationValue);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterApplyAuth(var Request: HttpRequestMessage; AuthProfile: Record "AMC Int. Auth Profile")
    begin
    end;
}
