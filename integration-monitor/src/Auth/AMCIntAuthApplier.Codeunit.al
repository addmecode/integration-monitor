namespace Addmecode.IntegrationMonitor.Auth;

codeunit 50108 "AMC Int. Auth Applier"
{
    [NonDebuggable]
    procedure ApplyAuth(var Request: HttpRequestMessage; AuthProfileCode: Code[20])
    var
        AuthProfile: Record "AMC Int. Auth Profile";
        AuthHandler: Interface "AMC IAuthHandler";
        MissingProfileErr: Label 'Authentication profile %1 does not exist.', Comment = '%1 = authentication profile code';
    begin
        if AuthProfileCode = '' then
            exit;

        if not AuthProfile.Get(AuthProfileCode) then
            Error(MissingProfileErr, AuthProfileCode);

        AuthProfile.TestProfile();

        AuthHandler := AuthProfile."Auth Type";
        AuthHandler.ApplyAuth(Request, AuthProfile);
    end;
}
