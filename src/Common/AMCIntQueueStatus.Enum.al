enum 50103 "AMC Int. Queue Status"
{
    Extensible = false;

    value(0; ReadyToProcess)
    {
        Caption = 'Ready To Process';
    }
    value(1; Sent)
    {
        Caption = 'Sent';
    }
    value(2; Failed)
    {
        Caption = 'Failed';
    }
    value(3; Cancelled)
    {
        Caption = 'Cancelled';
    }
}

