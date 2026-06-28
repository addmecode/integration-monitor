namespace Addmecode.IntegrationMonitor.Test;
using Addmecode.IntegrationMonitor.Transport;

enumextension 50145 "AMC Mock Transport Type" extends "AMC Int. Transport Type"
{
    value(50141; Mock)
    {
        Caption = 'Mock (Test)';
        Implementation = "AMC IHttpTransportHandler" = "AMC Mock Http Transport";
    }
}
