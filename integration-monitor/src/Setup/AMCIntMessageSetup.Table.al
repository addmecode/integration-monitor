namespace Addmecode.IntegrationMonitor.Setup;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Transport;

table 50108 "AMC Int. Message Setup"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Message Type"; Enum "AMC Int. Message Type")
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the integration message type that this setup applies to.';
        }
        field(2; Enabled; Boolean)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies whether entries for this message type can be processed.';

            trigger OnValidate()
            begin
                if Enabled then
                    this.TestRequiredFieldsForEnabled();
            end;
        }
        field(3; "Max Attempts"; Integer)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the maximum number of processing attempts before the entry stops retrying.';
            InitValue = 1;
            MinValue = 1;
        }
        field(4; "Base Retry Delay (sec)"; Integer)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the retry delay in seconds after a failed processing attempt.';
            MinValue = 0;
        }
        field(5; "Endpoint URL"; Text[2048])
        {
            DataClassification = SystemMetadata;
            ExtendedDatatype = URL;
            ToolTip = 'Specifies the external endpoint URL used when sending this message type.';
        }
        field(6; "Timeout (ms)"; Integer)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the HTTP request timeout in milliseconds. Leave blank or zero to use the default timeout.';
            InitValue = 10000;
            MinValue = 1;
        }
        // todo: auth profile table is missing
        field(7; "Auth Profile Code"; Code[20])
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the authentication profile code used when sending requests for this message type.';
        }
        field(8; "Process Response"; Boolean)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies whether a successful response should create an inbox entry for later processing.';
        }
        field(9; Transport; Enum "AMC Int. Transport Type")
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the transport handler used to send requests for this message type.';
        }
    }

    keys
    {
        key(PK; "Message Type")
        {
            Clustered = true;
        }
    }

    local procedure TestRequiredFieldsForEnabled()
    var
        TransportHandler: Interface "AMC IHttpTransportHandler";
    begin
        TransportHandler := Rec.Transport;
        TransportHandler.ValidateSetup(Rec);
    end;
}
