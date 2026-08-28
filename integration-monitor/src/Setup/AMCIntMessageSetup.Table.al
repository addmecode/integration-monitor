namespace Addmecode.IntegrationMonitor.Setup;
using Addmecode.IntegrationMonitor.Auth;
using Addmecode.IntegrationMonitor.Message;
using Addmecode.IntegrationMonitor.Transport;

table 50102 "AMC Int. Message Setup"
{
  DataClassification = CustomerContent;
  Caption = 'Integration Message Setup';
  LookupPageId = "AMC Int. Message Setup List";
  DrillDownPageId = "AMC Int. Message Setup List";

  fields
  {
    field(1; "Message Type"; Enum "AMC Int. Message Type")
    {
      DataClassification = SystemMetadata;
      ToolTip = 'Specifies the integration message type that this setup applies to.';
    }
    field(2; Enabled; Boolean)
    {
      DataClassification = SystemMetadata;
      ToolTip = 'Specifies whether entries for this message type can be processed.';

      trigger OnValidate()
      begin
        if Enabled then
          this.TestRequiredFieldsForEnabled();
      end;
    }
    field(3; "Max Attempts"; Integer)
    {
      DataClassification = SystemMetadata;
      ToolTip = 'Specifies the maximum number of processing attempts before the entry stops retrying.';
      InitValue = 1;
      MinValue = 1;
    }
    field(4; "Base Retry Delay (sec)"; Integer)
    {
      DataClassification = SystemMetadata;
      ToolTip = 'Specifies the retry delay in seconds after a failed processing attempt.';
      MinValue = 0;
    }
    field(5; "Endpoint URL"; Text[2048])
    {
      DataClassification = CustomerContent;
      ExtendedDatatype = URL;
      ToolTip = 'Specifies the external endpoint URL used when sending this message type.';
    }
    field(6; "Timeout (ms)"; Integer)
    {
      DataClassification = SystemMetadata;
      ToolTip = 'Specifies the HTTP request timeout in milliseconds. The value must be at least 1 millisecond.';
      InitValue = 10000;
      MinValue = 1;
    }
    field(7; "Auth Profile Code"; Code[20])
    {
      DataClassification = CustomerContent;
      TableRelation = "AMC Int. Auth Profile".Code;
      ToolTip = 'Specifies the authentication profile code used when sending requests for this message type.';
    }
    field(8; "Process Response"; Boolean)
    {
      DataClassification = SystemMetadata;
      ToolTip = 'Specifies whether a successful response should create an inbox entry for later processing.';
    }
    field(9; Transport; Enum "AMC Int. Transport Type")
    {
      DataClassification = SystemMetadata;
      ToolTip = 'Specifies the transport handler used to send requests for this message type.';
    }
    field(10; "Delete Outbox Entr. Older Than"; DateFormula)
    {
      DataClassification = CustomerContent;
      ToolTip = 'Specifies the formula for deleting old outbox entries.';

      trigger OnValidate()
      begin
        this.ValidateDeleteOutboxEntriesOlderThan();
      end;
    }
  }

  keys
  {
    key(PK; "Message Type")
    {
      Clustered = true;
    }
  }

  local procedure TestRequiredFieldsForEnabled()
  var
    IntMessageSetupMgt: Codeunit "AMC Int. Message Setup Mgt.";
  begin
    IntMessageSetupMgt.TestRequiredFieldsForEnabled(Rec);
  end;

  local procedure ValidateDeleteOutboxEntriesOlderThan()
  var
    IntMessageSetupMgt: Codeunit "AMC Int. Message Setup Mgt.";
  begin
    IntMessageSetupMgt.ValidateDeleteOutboxEntriesOlderThan(Rec);
  end;
}
