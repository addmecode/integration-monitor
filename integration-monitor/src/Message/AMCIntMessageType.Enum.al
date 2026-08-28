namespace Addmecode.IntegrationMonitor.Message;

enum 50101 "AMC Int. Message Type" implements "AMC IMessageHandler"
{
    Extensible = true;

    value(0; Default)
    {
        Caption = 'Default';
        Implementation = "AMC IMessageHandler" = "AMC Message Handler Default";
    }
}
