namespace Addmecode.IntegrationMonitor.Auth;

table 50109 "AMC Int. Auth Profile"
{
    DataClassification = CustomerContent;
    Caption = 'Integration Auth Profile';
    LookupPageId = "AMC Int. Auth Profiles";
    DrillDownPageId = "AMC Int. Auth Profiles";

    fields
    {
        field(1; "Code"; Code[20])
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
            begin
                this.AuthTypeOnValidate();
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
    begin
        this.DeleteSecret();
    end;

    trigger OnRename()
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        AuthProfileMgt.OnRename(Rec, xRec);
    end;

    local procedure AuthTypeOnValidate()
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        AuthProfileMgt.AuthTypeOnValidate(Rec, xRec);
    end;

    [NonDebuggable]
    procedure SetSecret(SecretValue: SecretText)
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        AuthProfileMgt.SetSecret(Rec, SecretValue);
    end;

    [NonDebuggable]
    procedure GetSecret(var SecretValue: SecretText): Boolean
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        exit(AuthProfileMgt.GetSecret(Code, SecretValue));
    end;

    procedure HasSecret(): Boolean
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        exit(AuthProfileMgt.HasSecret(Code));
    end;

    procedure DeleteSecret()
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        AuthProfileMgt.DeleteSecret(Rec);
    end;

    procedure ClearSecret()
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        AuthProfileMgt.ClearSecret(Rec);
    end;

    procedure ClearSecretWithEnabledSetupCheck()
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        AuthProfileMgt.ClearSecretWithEnabledSetupCheck(Rec);
    end;

    procedure TestProfile()
    var
        AuthProfileMgt: Codeunit "AMC Int. Auth Profile Mgt.";
    begin
        AuthProfileMgt.TestProfile(Rec);
    end;

}
