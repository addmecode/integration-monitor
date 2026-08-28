namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Message;

enumextension 50132 "AMC Mock Message Type" extends "AMC Int. Message Type"
{
    value(50142; Mock)
    {
        Caption = 'Mock (Test)';
        Implementation = "AMC IMessageHandler" = "AMC Mock Message Handler";
    }
}
