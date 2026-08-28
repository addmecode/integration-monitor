namespace Addmecode.IntegrationMonitor.Test;

/// <summary>
/// Single-instance holder for the response the mock transport should return.
/// Tests configure it before driving the processor; the mock handler reads it on Send.
/// </summary>
codeunit 50135 "AMC Mock Transport State"
{
    SingleInstance = true;

    var
        ConfiguredStatusCode: Integer;
        ConfiguredBody: Text;

    procedure SetResponse(StatusCode: Integer; Body: Text)
    begin
        this.ConfiguredStatusCode := StatusCode;
        this.ConfiguredBody := Body;
    end;

    procedure GetStatusCode(): Integer
    begin
        exit(this.ConfiguredStatusCode);
    end;

    procedure GetBody(): Text
    begin
        exit(this.ConfiguredBody);
    end;

    procedure IsSuccessStatusCode(): Boolean
    begin
        exit((this.ConfiguredStatusCode >= 200) and (this.ConfiguredStatusCode < 300));
    end;

    procedure Reset()
    begin
        this.ConfiguredStatusCode := 0;
        Clear(this.ConfiguredBody);
    end;
}
