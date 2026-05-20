namespace Addmecode.IntegrationMonitor.Demo;

enum 50125 "AMC City Validation Status"
{
    Extensible = false;

    value(0; " ")
    {
        Caption = ' ';
    }
    value(1; Sent)
    {
        Caption = 'Sent';
    }
    value(2; Valid)
    {
        Caption = 'Valid';
    }
    value(3; Invalid)
    {
        Caption = 'Invalid';
    }
}
