namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Message;

table 50107 "AMC Int. Outbox Entry"
{
    DataClassification = CustomerContent;
    Caption = 'Integration Outbox Entry';
    AllowInCustomizations = AsReadOnly;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            AutoIncrement = true;
            ToolTip = 'Specifies the unique entry number assigned to the integration outbox entry.';
        }
        field(2; "Message Type"; Enum "AMC Int. Message Type")
        {
            DataClassification = SystemMetadata;
            NotBlank = true;
            ToolTip = 'Specifies the integration message type for this outbox entry.';

            trigger OnValidate()
            begin
                this.TestMessageSetupExists();
            end;
        }
        field(3; Status; Enum "AMC Int. Outbox Status")
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the current processing status of the integration outbox entry.';
        }
        field(4; "Created At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the integration outbox entry was created.';
        }
        field(5; "Next Attempt At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the next processing attempt should occur.';
        }
        field(6; "Last Attempt At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the most recent processing attempt occurred.';
        }
        field(7; "Sent At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the integration outbox entry was sent successfully.';
        }
        field(8; "Attempt Count"; Integer)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the number of processing attempts made for the integration outbox entry.';
        }
        field(9; "Request Payload"; Blob)
        {
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the request payload that will be sent for the integration outbox entry.';
        }
        field(10; "Last Error Response"; Blob)
        {
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the error message from the most recent failed processing attempt.';
        }
        field(11; "Source Record ID"; RecordId)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the source record that created the integration outbox entry.';
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
        this.TestMessageSetupExists();

        if "Created At" = 0DT then
            "Created At" := CurrentDateTime();

        if "Next Attempt At" = 0DT then
            "Next Attempt At" := CurrentDateTime();
    end;

    local procedure TestMessageSetupExists()
    var
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
    begin
        OutboxEntryMgt.TestMessageSetupExists(Rec);
    end;

    procedure ResetEntry()
    var
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
    begin
        OutboxEntryMgt.ResetEntry(Rec);
    end;

    procedure CancelEntry()
    var
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
    begin
        OutboxEntryMgt.CancelEntry(Rec);
    end;

    procedure ViewPayload()
    var
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
    begin
        OutboxEntryMgt.ViewPayload(Rec);
    end;

    procedure EditPayload()
    var
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
    begin
        OutboxEntryMgt.EditPayload(Rec);
    end;

    procedure ViewErrorDetails()
    var
        OutboxEntryMgt: Codeunit "AMC Outbox Entry Mgt.";
    begin
        OutboxEntryMgt.ViewErrorDetails(Rec);
    end;
}
