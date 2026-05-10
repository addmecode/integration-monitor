namespace Addmecode.IntegrationMonitor.Outbox;

page 50113 "AMC Int. Outbox Entries"
{
    PageType = List;
    SourceTable = "AMC Int. Outbox Entry";
    ApplicationArea = All;
    UsageCategory = Lists;
    Caption = 'Integration Outbox Entries';
    InsertAllowed = false;
    DeleteAllowed = false;
    Editable = false;

    layout
    {
        area(content)
        {
            repeater(Entries)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                }
                field("Message Type"; Rec."Message Type")
                {
                    ApplicationArea = All;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                }
                field("Created At"; Rec."Created At")
                {
                    ApplicationArea = All;
                }
                field("Next Attempt At"; Rec."Next Attempt At")
                {
                    ApplicationArea = All;
                }
                field("Last Attempt At"; Rec."Last Attempt At")
                {
                    ApplicationArea = All;
                }
                field("Sent At"; Rec."Sent At")
                {
                    ApplicationArea = All;
                }
                field("Attempt Count"; Rec."Attempt Count")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action("Reset")
            {
                ApplicationArea = All;
                Caption = 'Reset';
                Image = Redo;
                ToolTip = 'Reset entry the selected integration outbox entry.';
                trigger OnAction()
                var
                    OutboxProcessor: Codeunit "AMC Outbox Processor";
                begin
                    OutboxProcessor.ResetEntry(Rec);
                end;
            }
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                Image = Cancel;
                ToolTip = 'Cancels processing for the selected integration outbox entry.';
                trigger OnAction()
                var
                    OutboxProcessor: Codeunit "AMC Outbox Processor";
                begin
                    OutboxProcessor.CancelEntry(Rec);
                end;
            }
            action(ViewPayload)
            {
                ApplicationArea = All;
                Caption = 'View Payload';
                Image = View;
                ToolTip = 'Opens the request payload for the selected integration outbox entry in read-only mode.';
                trigger OnAction()
                var
                    OutboxProcessor: Codeunit "AMC Outbox Processor";
                begin
                    OutboxProcessor.ViewPayload(Rec);
                end;
            }
            action(EditPayload)
            {
                ApplicationArea = All;
                Caption = 'Edit Payload';
                Image = Edit;
                ToolTip = 'Opens the request payload for the selected integration outbox entry for editing.';
                trigger OnAction()
                var
                    OutboxProcessor: Codeunit "AMC Outbox Processor";
                begin
                    OutboxProcessor.EditPayload(Rec);
                end;
            }
            action(ViewErrorDetails)
            {
                ApplicationArea = All;
                Caption = 'View Error Details';
                Image = Error;
                ToolTip = 'Opens the error details for the selected integration outbox entry.';
                trigger OnAction()
                var
                    OutboxProcessor: Codeunit "AMC Outbox Processor";
                begin
                    OutboxProcessor.ViewErrorDetails(Rec);
                end;
            }
        }
    }
}
