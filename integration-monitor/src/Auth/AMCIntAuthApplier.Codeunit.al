namespace Addmecode.IntegrationMonitor.Auth;

using System.Text;

codeunit 50121 "AMC Int. Auth Applier"
{
    procedure ApplyAuth(var Request: HttpRequestMessage; AuthProfileCode: Code[20])
    var
        AuthProfile: Record "AMC Int. Auth Profile";
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        if AuthProfileCode = '' then
            exit;

        AuthProfile.Get(AuthProfileCode);
        AuthProfileMgt.TestProfile(AuthProfile);

        case AuthProfile."Auth Type" of
            AuthProfile."Auth Type"::Basic:
                this.ApplyBasicAuth(Request, AuthProfile);
            AuthProfile."Auth Type"::"Bearer Token":
                this.ApplyBearerTokenAuth(Request, AuthProfile);
        end;
    end;

    [NonDebuggable]
    local procedure ApplyBasicAuth(var Request: HttpRequestMessage; AuthProfile: Record "AMC Int. Auth Profile")
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
        Base64Convert: Codeunit "Base64 Convert";
        Password: SecretText;
        Credential: SecretText;
        AuthorizationValue: SecretText;
    begin
        AuthProfileMgt.GetSecret(AuthProfile.Code, Password);
        Credential := SecretStrSubstNo('%1:%2', AuthProfile.Username, Password);
        AuthorizationValue := SecretStrSubstNo('Basic %1', Base64Convert.ToBase64(Credential));
        this.SetAuthorizationHeader(Request, AuthorizationValue);
    end;

    [NonDebuggable]
    local procedure ApplyBearerTokenAuth(var Request: HttpRequestMessage; AuthProfile: Record "AMC Int. Auth Profile")
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
        Token: SecretText;
        AuthorizationValue: SecretText;
    begin
        AuthProfileMgt.GetSecret(AuthProfile.Code, Token);
        AuthorizationValue := SecretStrSubstNo('Bearer %1', Token);
        this.SetAuthorizationHeader(Request, AuthorizationValue);
    end;

    [NonDebuggable]
    local procedure SetAuthorizationHeader(var Request: HttpRequestMessage; AuthorizationValue: SecretText)
    var
        RequestHeaders: HttpHeaders;
    begin
        Request.GetHeaders(RequestHeaders);
        if RequestHeaders.Contains('Authorization') or RequestHeaders.ContainsSecret('Authorization') then
            RequestHeaders.Remove('Authorization');

        RequestHeaders.Add('Authorization', AuthorizationValue);
    end;
}
