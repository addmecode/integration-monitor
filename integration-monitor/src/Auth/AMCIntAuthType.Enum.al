namespace Addmecode.IntegrationMonitor.Auth;

enum 50105 "AMC Int. Auth Type"
{
    Extensible = true;

    value(0; Basic)
    {
        Caption = 'Basic';
    }
    value(1; "Bearer Token")
    {
        Caption = 'Bearer Token';
    }
}
