namespace Addmecode.IntegrationMonitor.Auth;

codeunit 50122 "AMC Int. Bearer Auth Handler" implements "AMC IAuthHandler"
{
    [NonDebuggable]
    procedure ApplyAuth(var Request: HttpRequestMessage; AuthProfile: Record "AMC Int. Auth Profile")
    var
        Token: SecretText;
        AuthorizationValue: SecretText;
    begin
        this.GetProfileSecret(AuthProfile, Token);
        AuthorizationValue := SecretStrSubstNo('Bearer %1', Token);
        this.SetAuthorizationHeader(Request, AuthorizationValue);
    end;

    procedure ValidateProfile(AuthProfile: Record "AMC Int. Auth Profile")
    begin
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
