namespace Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;


table 50106 "AMC Int. Inbox Entry"
{
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            AutoIncrement = true;
            ToolTip = 'Specifies the unique entry number assigned to the integration inbox entry.';
        }
        field(2; "Outbox Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            TableRelation = "AMC Int. Outbox Entry"."Entry No.";
            ToolTip = 'Specifies the related integration outbox entry that created this inbox entry.';
        }
        field(3; "Message Type"; Enum "AMC Int. Message Type")
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the integration message type for this inbox entry.';
        }
        field(4; Status; Enum "AMC Int. Outbox Status")
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the current processing status of the integration inbox entry.';
        }
        field(5; "Correlation ID"; Guid)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the correlation ID used to track the related integration processing flow.';
        }
        field(6; "Received At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the integration inbox entry was received.';
        }
        field(7; "Next Attempt At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the next processing attempt should occur.';
        }
        field(8; "Last Attempt At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the most recent processing attempt occurred.';
        }
        field(9; "Processed At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the integration inbox entry was processed successfully.';
        }
        field(10; "Attempt Count"; Integer)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the number of processing attempts made for the integration inbox entry.';
        }
        field(11; "Response Payload"; Blob)
        {
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the response payload received for the integration inbox entry.';
        }
        field(12; "Last Error"; Text[2048])
        {
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the error message from the most recent failed processing attempt.';
        }
        field(13; "Error Details"; Blob)
        {
            DataClassification = CustomerContent;
            ToolTip = 'Specifies detailed error information from the most recent failed processing attempt.';
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
