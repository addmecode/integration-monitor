namespace Addmecode.IntegrationMonitor.Setup;

using Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Transport;

codeunit 50122 "AMC Int. Message Setup Mgt."
{
    procedure TestRequiredFieldsForEnabled(IntMessageSetup: Record "AMC Int. Message Setup")
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
        TransportHandler: Interface "AMC IHttpTransportHandler";
    begin
        TransportHandler := IntMessageSetup.Transport;
        TransportHandler.ValidateSetup(IntMessageSetup);
        AuthProfileMgt.TestProfileCode(IntMessageSetup."Auth Profile Code");
    end;
}
