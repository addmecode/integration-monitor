namespace Addmecode.IntegrationMonitor.Outbox;

enum 50102 "AMC Int. Outbox Status"
{
    Extensible = false;

    value(0; ReadyToProcess)
    {
        Caption = 'Ready To Process';
    }
    value(1; Sending)
    {
        Caption = 'Sending';
    }
    value(2; Processed)
    {
        Caption = 'Processed';
    }
    value(3; Failed)
    {
        Caption = 'Failed';
    }
    value(4; Cancelled)
    {
        Caption = 'Cancelled';
    }
    value(5; ResponseReceived)
    {
        Caption = 'Response Received';
    }
}
