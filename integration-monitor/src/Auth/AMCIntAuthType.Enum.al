namespace Addmecode.IntegrationMonitor.Auth;

enum 50103 "AMC Int. Auth Type" implements "AMC IAuthHandler"
{
    Extensible = true;

    value(0; Basic)
    {
        Caption = 'Basic';
        Implementation = "AMC IAuthHandler" = "AMC Int. Basic Auth Handler";
    }
    value(1; "Bearer Token")
    {
        Caption = 'Bearer Token';
        Implementation = "AMC IAuthHandler" = "AMC Int. Bearer Auth Handler";
    }
}
