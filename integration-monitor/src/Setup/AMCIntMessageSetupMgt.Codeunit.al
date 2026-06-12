namespace Addmecode.IntegrationMonitor.Setup;

using Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Transport;

codeunit 50122 "AMC Int. Message Setup Mgt."
{
    internal procedure TestRequiredFieldsForEnabled(IntMessageSetup: Record "AMC Int. Message Setup")
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
        TransportHandler: Interface "AMC IHttpTransportHandler";
    begin
        TransportHandler := IntMessageSetup.Transport;
        TransportHandler.ValidateSetup(IntMessageSetup);
        AuthProfileMgt.TestProfileCode(IntMessageSetup."Auth Profile Code");
    end;

    internal procedure ValidateDeleteOutboxEntriesOlderThan(IntMessageSetup: Record "AMC Int. Message Setup")
    var
        DateFormulaMustBeBeforeTodayErr: Label 'must calculate to a date before today';
        DeleteOutboxEntrOlderThanDate: Date;
    begin
        if Format(IntMessageSetup."Delete Outbox Entr. Older Than") = '' then
            exit;

        DeleteOutboxEntrOlderThanDate := CalcDate(IntMessageSetup."Delete Outbox Entr. Older Than", Today);
        if DeleteOutboxEntrOlderThanDate >= Today then
            IntMessageSetup.FieldError(IntMessageSetup."Delete Outbox Entr. Older Than", DateFormulaMustBeBeforeTodayErr);
    end;
}
