namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Inbox;

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
                field("Processed At"; Rec."Processed At")
                {
                    ApplicationArea = All;
                }
                field("Response Received At"; Rec."Response Received At")
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
        area(Navigation)
        {
            action(ShowRelatedInboxEntries)
            {
                ApplicationArea = All;
                Caption = 'Related Inbox Entries';
                Image = Entries;
                RunObject = page "AMC Int. Inbox Entries";
                RunPageLink = "Outbox Entry No." = field("Entry No.");
                ToolTip = 'Opens the inbox entries created for the selected integration outbox entry.';
            }
        }
        area(processing)
        {
            action(Process)
            {
                ApplicationArea = All;
                Caption = 'Process';
                Image = Process;
                ToolTip = 'Processes the selected integration outbox entry.';
                trigger OnAction()
                begin
                    Rec.ProcessEntry();
                    CurrPage.Update(false);
                end;
            }
            action("Reset")
            {
                ApplicationArea = All;
                Caption = 'Reset';
                Image = Redo;
                ToolTip = 'Resets the selected integration outbox entry.';
                trigger OnAction()
                begin
                    Rec.ResetEntry();
                end;
            }
            action(Cancel)
            {
                ApplicationArea = All;
                Caption = 'Cancel';
                Image = Cancel;
                ToolTip = 'Cancels processing for the selected integration outbox entry.';
                trigger OnAction()
                begin
                    Rec.CancelEntry();
                end;
            }
            action(ViewPayload)
            {
                ApplicationArea = All;
                Caption = 'View Payload';
                Image = View;
                ToolTip = 'Opens the request payload for the selected integration outbox entry in read-only mode.';
                trigger OnAction()
                begin
                    Rec.ViewPayload();
                end;
            }
            action(EditPayload)
            {
                ApplicationArea = All;
                Caption = 'Edit Payload';
                Image = Edit;
                ToolTip = 'Opens the request payload for the selected integration outbox entry for editing.';
                trigger OnAction()
                begin
                    Rec.EditPayload();
                end;
            }
            action(ViewErrorDetails)
            {
                ApplicationArea = All;
                Caption = 'View Error Details';
                Image = Error;
                ToolTip = 'Opens the error details for the selected integration outbox entry.';
                trigger OnAction()
                begin
                    Rec.ViewErrorDetails();
                end;
            }
        }
    }
}
