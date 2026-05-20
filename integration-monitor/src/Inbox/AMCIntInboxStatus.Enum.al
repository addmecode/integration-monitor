namespace Addmecode.IntegrationMonitor.Outbox;

enum 50106 "AMC Int. Inbox Status"
{
    Extensible = false;

    value(0; ReadyToProcess)
    {
        Caption = 'Ready To Process';
    }
    value(1; Processing)
    {
        Caption = 'Processing';
    }
    value(2; Received)
    {
        Caption = 'Received';
    }
    value(3; Failed)
    {
        Caption = 'Failed';
    }
    value(4; Cancelled)
    {
        Caption = 'Cancelled';
    }
}

