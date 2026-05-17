namespace Addmecode.IntegrationMonitor.Demo;
using Addmecode.IntegrationMonitor.Message;

enumextension 50123 "AMC Demo Message Type" extends "AMC Int. Message Type"
{
    value(50123; AMCPostalCodeValidation)
    {
        Caption = 'Postal Code Validation';
        Implementation = "AMC IMessageHandler" = "AMC Post Code Valid Msg Hdlr";
    }
}
