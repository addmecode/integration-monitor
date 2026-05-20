namespace Addmecode.IntegrationMonitor.Transport;
using Addmecode.IntegrationMonitor.Setup;

interface "AMC IHttpTransportHandler"
{
    procedure ValidateSetup(Setup: Record "AMC Int. Message Setup");
    procedure Send(Request: HttpRequestMessage; Setup: Record "AMC Int. Message Setup"; var Response: HttpResponseMessage);
}
