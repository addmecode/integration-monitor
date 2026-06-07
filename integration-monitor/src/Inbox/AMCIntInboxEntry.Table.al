namespace Addmecode.IntegrationMonitor.Inbox;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Outbox;


table 50106 "AMC Int. Inbox Entry"
{
    DataClassification = CustomerContent;
    Caption = 'Integration Inbox Entry';
    AllowInCustomizations = AsReadOnly;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            AutoIncrement = true;
            ToolTip = 'Specifies the unique entry number assigned to the integration inbox entry.';
        }
        field(2; "Message Type"; Enum "AMC Int. Message Type")
        {
            DataClassification = SystemMetadata;
            NotBlank = true;
            ToolTip = 'Specifies the integration message type for this inbox entry.';
            trigger OnValidate()
            begin
                this.TestMessageSetupExists();
            end;
        }
        field(3; Status; Enum "AMC Int. Inbox Status")
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the current processing status of the integration inbox entry.';
        }
        field(4; "Created At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the integration inbox entry was received.';
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
        field(7; "Processed At"; DateTime)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the date and time when the integration inbox entry was processed successfully.';
        }
        field(8; "Attempt Count"; Integer)
        {
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies the number of processing attempts made for the integration inbox entry.';
        }
        field(9; "Response Payload"; Blob)
        {
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the response payload received for the integration inbox entry.';
        }
        field(10; "Last Error"; Blob)
        {
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the error message from the most recent failed processing attempt.';
        }
        field(11; "Source Record ID"; RecordId)
        {
            DataClassification = CustomerContent;
            ToolTip = 'Specifies the source record that created the related integration outbox entry.';
        }
        field(12; "Outbox Entry No."; Integer)
        {
            DataClassification = SystemMetadata;
            TableRelation = "AMC Int. Outbox Entry"."Entry No.";
            ToolTip = 'Specifies the related integration outbox entry that created this inbox entry.';
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
        key(OutboxEntryNoStatus; "Outbox Entry No.", Status)
        {
        }
    }

    trigger OnInsert()
    var
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
    begin
        InboxEntryMgt.OnInsertInboxEntry(Rec);
    end;

    trigger OnDelete()
    var
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
    begin
        InboxEntryMgt.OnDeleteInboxEntry(Rec);
    end;

    local procedure TestMessageSetupExists()
    var
        MessageMgt: Codeunit "AMC Message Mgt.";
    begin
        MessageMgt.TestMessageSetupExists(Rec."Message Type");
    end;

    procedure ResetEntry()
    var
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
    begin
        InboxEntryMgt.ResetEntry(Rec);
    end;

    procedure CancelEntry()
    var
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
    begin
        InboxEntryMgt.CancelEntry(Rec);
    end;

    procedure ProcessEntry()
    var
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
    begin
        InboxEntryMgt.ProcessEntry(Rec);
    end;

    procedure ViewPayload()
    var
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
    begin
        InboxEntryMgt.ViewPayload(Rec);
    end;

    procedure EditPayload()
    var
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
    begin
        InboxEntryMgt.EditPayload(Rec);
    end;

    procedure ViewErrorDetails()
    var
        InboxEntryMgt: Codeunit "AMC Inbox Entry Mgt.";
    begin
        InboxEntryMgt.ViewErrorDetails(Rec);
    end;
}
