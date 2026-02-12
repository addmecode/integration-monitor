table 50108 "AMC Int. Message Setup"
{
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Message Type"; Enum "AMC Int. Message Type")
        {
            DataClassification = SystemMetadata;
        }
        field(2; Enabled; Boolean)
        {
            DataClassification = SystemMetadata;
        }
        field(3; "Max Attempts"; Integer)
        {
            DataClassification = SystemMetadata;
        }
        field(4; "Base Retry Delay (sec)"; Integer)
        {
            DataClassification = SystemMetadata;
        }
        field(5; "Endpoint URL"; Text[2048])
        {
            DataClassification = SystemMetadata;
            ExtendedDatatype = URL;
        }
        field(6; "Timeout (ms)"; Integer)
        {
            DataClassification = SystemMetadata;
        }
        // todo: auth profile table is missing
        field(7; "Auth Profile Code"; Code[20])
        {
            DataClassification = SystemMetadata;
        }
        field(8; "Process Response"; Boolean)
        {
            DataClassification = SystemMetadata;
        }
        field(9; Transport; Enum "AMC Int. Transport Type")
        {
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Message Type")
        {
            Clustered = true;
        }
    }
}
