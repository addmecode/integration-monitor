namespace Addmecode.IntegrationMonitor.Message;

using Addmecode.IntegrationMonitor.Setup;

codeunit 50112 "AMC Message Mgt."
{
    procedure TestMessageSetupExists(MessageType: Enum "AMC Int. Message Type")
    var
        IntMessageSetup: Record "AMC Int. Message Setup";
    begin
        this.GetMessageSetup(MessageType, IntMessageSetup);
    end;

    procedure GetMessageSetup(MessageType: Enum "AMC Int. Message Type"; var IntMessageSetup: Record "AMC Int. Message Setup")
    var
        MissingMessageSetupErr: Label 'Integration message setup for message type %1 does not exist.', Comment = '%1 = message type';
    begin
        if not IntMessageSetup.Get(MessageType) then
            Error(MissingMessageSetupErr, Format(MessageType));
    end;
}
