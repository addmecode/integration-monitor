table 50106 "AMC Int. Inbox Entry"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            AutoIncrement = true;
        }
        field(2; "Outbox Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            TableRelation = "AMC Int. Outbox Entry"."Entry No.";
        }
        field(3; "Message Type"; Enum "AMC Int. Message Type")
        {
            DataClassification = SystemMetadata;
        }
        field(4; Status; Enum "AMC Int. Outbox Status")
        {
            DataClassification = SystemMetadata;
        }
        field(5; "Correlation ID"; Guid)
        {
            DataClassification = SystemMetadata;
        }
        field(6; "Received At"; DateTime)
        {
            DataClassification = SystemMetadata;
        }
        field(7; "Next Attempt At"; DateTime)
        {
            DataClassification = SystemMetadata;
        }
        field(8; "Last Attempt At"; DateTime)
        {
            DataClassification = SystemMetadata;
        }
        field(9; "Processed At"; DateTime)
        {
            DataClassification = SystemMetadata;
        }
        field(10; "Attempt Count"; Integer)
        {
            DataClassification = SystemMetadata;
        }
        field(11; "Response Payload"; Blob)
        {
            DataClassification = CustomerContent;
        }
        field(12; "Last Error"; Text[2048])
        {
            DataClassification = CustomerContent;
        }
        field(13; "Error Details"; Blob)
        {
            DataClassification = CustomerContent;
        }
        field(14; "Source Record ID"; RecordId)
        {
            FieldClass = FlowField;
            CalcFormula = lookup("AMC Int. Outbox Entry"."Source Record ID" where("Entry No." = field("Outbox Entry No.")));
            ToolTip = 'Specifies the source record that created the related integration outbox entry.';
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
        if "Received At" = 0DT then
            "Received At" := CurrentDateTime();

        if "Next Attempt At" = 0DT then
            "Next Attempt At" := CurrentDateTime();

        if IsNullGuid("Correlation ID") then
            "Correlation ID" := CreateGuid();
    end;
}
