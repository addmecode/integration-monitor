namespace Addmecode.IntegrationMonitor.Auth;

using System.Text;

codeunit 50134 "AMC Int. Basic Auth Handler" implements "AMC IAuthHandler"
{
    [NonDebuggable]
    procedure ApplyAuth(var Request: HttpRequestMessage; AuthProfile: Record "AMC Int. Auth Profile")
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

    procedure ValidateProfile(AuthProfile: Record "AMC Int. Auth Profile")
    begin
        AuthProfile.TestField(Username);
    end;

    [NonDebuggable]
    internal procedure GetProfileSecret(AuthProfile: Record "AMC Int. Auth Profile"; var SecretValue: SecretText)
    var
        MissingSecretErr: Label 'Authentication profile %1 does not have a stored secret.', Comment = '%1 = authentication profile code';
    begin
        if not AuthProfile.GetSecret(SecretValue) then
            Error(MissingSecretErr, AuthProfile.Code);
    end;

    [NonDebuggable]
    internal procedure SetAuthorizationHeader(var Request: HttpRequestMessage; AuthorizationValue: SecretText)
    var
        RequestHeaders: HttpHeaders;
        AuthorizationHeaderNameLbl: Label 'Authorization', Locked = true;
    begin
        Request.GetHeaders(RequestHeaders);
        if RequestHeaders.Contains(AuthorizationHeaderNameLbl) or RequestHeaders.ContainsSecret(AuthorizationHeaderNameLbl) then
            RequestHeaders.Remove(AuthorizationHeaderNameLbl);

        RequestHeaders.Add(AuthorizationHeaderNameLbl, AuthorizationValue);
    end;
}
