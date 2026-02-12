table 50107 "AMC Int. Outbox Entry"
{
    DataClassification = CustomerContent;
    Caption = 'Integration Outbox Entry';

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(2; "Message Type"; Enum "AMC Int. Message Type")
        {
            DataClassification = SystemMetadata;
        }
        field(3; Status; Enum "AMC Int. Queue Status")
        {
            DataClassification = SystemMetadata;
        }
        field(4; "Created At"; DateTime)
        {
            DataClassification = SystemMetadata;
        }
        field(5; "Next Attempt At"; DateTime)
        {
            DataClassification = SystemMetadata;
        }
        field(6; "Last Attempt At"; DateTime)
        {
            DataClassification = SystemMetadata;
        }
        field(7; "Sent At"; DateTime)
        {
            DataClassification = SystemMetadata;
        }
        field(8; "Attempt Count"; Integer)
        {
            DataClassification = SystemMetadata;
        }
        field(9; "Request Payload"; Blob)
        {
            DataClassification = CustomerContent;
        }
        field(10; "Error Message"; Blob)
        {
            DataClassification = CustomerContent;
        }
        field(11; "Source Record ID"; RecordId)
        {
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(StatusNextAttempt; Status, "Next Attempt At")
        {
        }
    }

    trigger OnInsert()
    begin
        if "Created At" = 0DT then
            "Created At" := CurrentDateTime();

        if "Next Attempt At" = 0DT then
            "Next Attempt At" := CurrentDateTime();
    end;
}
