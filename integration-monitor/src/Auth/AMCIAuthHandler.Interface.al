namespace Addmecode.IntegrationMonitor.Auth;

interface "AMC IAuthHandler"
{
    procedure ApplyAuth(var Request: HttpRequestMessage; AuthProfile: Record "AMC Int. Auth Profile");
    procedure ValidateProfile(AuthProfile: Record "AMC Int. Auth Profile");
}
