namespace Addmecode.IntegrationMonitor.Transport;

enum 50102 "AMC Int. Transport Type" implements "AMC IHttpTransportHandler"
{
    Extensible = true;

    value(0; Http)
    {
        Caption = 'HTTP/HTTPS';
        Implementation = "AMC IHttpTransportHandler" = "AMC Http Transport Default";
    }
}
