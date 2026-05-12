namespace Addmecode.IntegrationMonitor.Auth;

table 50109 "AMC Int. Auth Profile"
{
  DataClassification = CustomerContent;
  Caption = 'Integration Auth Profile';
  LookupPageId = "AMC Int. Auth Profiles";
  DrillDownPageId = "AMC Int. Auth Profiles";

  fields
  {
    field(1; Code; Code[20])
    {
      DataClassification = SystemMetadata;
      Caption = 'Code';
      NotBlank = true;
      ToolTip = 'Specifies the authentication profile code.';
    }
    field(2; Description; Text[100])
    {
      DataClassification = CustomerContent;
      Caption = 'Description';
      ToolTip = 'Specifies a description of the authentication profile.';
    }
    field(3; "Auth Type"; Enum "AMC Int. Auth Type")
    {
      DataClassification = SystemMetadata;
      Caption = 'Auth Type';
      ToolTip = 'Specifies the authentication type used by this profile.';

      trigger OnValidate()
      var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
      begin
        if "Auth Type" = xRec."Auth Type" then
          exit;

        AuthProfileMgt.DeleteSecret(Code);
        this.ClearSecretStored();
      end;
    }
    field(4; Username; Text[250])
    {
      DataClassification = EndUserIdentifiableInformation;
      Caption = 'Username';
      ToolTip = 'Specifies the username used for Basic authentication.';
    }
    field(20; "Has Secret"; Boolean)
    {
      DataClassification = SystemMetadata;
      Caption = 'Has Secret';
      Editable = false;
      ToolTip = 'Specifies whether a password or token is stored for this authentication profile.';
    }
    field(21; "Secret Updated At"; DateTime)
    {
      DataClassification = SystemMetadata;
      Caption = 'Secret Updated At';
      Editable = false;
      ToolTip = 'Specifies when the stored secret was last updated.';
    }
    field(22; "Secret Updated By"; Code[50])
    {
      DataClassification = EndUserIdentifiableInformation;
      Caption = 'Secret Updated By';
      Editable = false;
      ToolTip = 'Specifies the user who last updated the stored secret.';
    }
  }

  keys
  {
    key(PK; Code)
    {
      Clustered = true;
    }
  }

  trigger OnDelete()
  var
    AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
  begin
    AuthProfileMgt.DeleteSecret(Code);
  end;

  trigger OnRename()
  var
    AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    CannotRenameProfileWithSecretErr: Label 'Authentication profile %1 cannot be renamed because it has a stored secret. Clear the secret before renaming the profile.', Comment = '%1 = authentication profile code';
  begin
    if Code = xRec.Code then
      exit;

    if AuthProfileMgt.HasSecret(xRec.Code) then
      Error(CannotRenameProfileWithSecretErr, xRec.Code);
  end;

  procedure SetSecretStored()
  begin
    "Has Secret" := true;
    "Secret Updated At" := CurrentDateTime();
    "Secret Updated By" := CopyStr(UserId(), 1, MaxStrLen("Secret Updated By"));
  end;

  procedure ClearSecretStored()
  begin
    "Has Secret" := false;
    Clear("Secret Updated At");
    Clear("Secret Updated By");
  end;
}
