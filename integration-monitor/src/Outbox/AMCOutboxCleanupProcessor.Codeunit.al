namespace Addmecode.IntegrationMonitor.Outbox;
using Addmecode.IntegrationMonitor.Setup;

codeunit 50132 "AMC Outbox Cleanup Processor"
{
    TableNo = "AMC Int. Outbox Entry";

    trigger OnRun()
    begin
        this.DeleteOutboxEntry(Rec);
    end;

    local procedure DeleteOutboxEntry(Outbox: Record "AMC Int. Outbox Entry")
    begin
        Outbox.Delete(true);
    end;
}
