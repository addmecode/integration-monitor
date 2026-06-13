namespace Addmecode.IntegrationMonitor.Helpers;
using System.Utilities;

codeunit 50113 "AMC Int. Blob Helper"
{
    /// <summary>
    /// Reads a BLOB field from the provided record and returns it as text.
    /// </summary>
    /// <param name="SourceRecordRef">Record containing the BLOB field.</param>
    /// <param name="FieldNo">Field number of the BLOB to read.</param>
    /// <returns>Full text content of the BLOB.</returns>
    procedure ReadBlobAsText(SourceRecordRef: RecordRef; FieldNo: Integer): Text
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        this.TestBlobField(SourceRecordRef, FieldNo);
        TempBlob.FromRecordRef(SourceRecordRef, FieldNo);

        exit(this.ReadTempBlobAsText(TempBlob));
    end;

    /// <summary>
    /// Writes text content into a BLOB field on the provided record.
    /// </summary>
    /// <param name="TargetRecordRef">Record containing the BLOB field.</param>
    /// <param name="FieldNo">Field number of the BLOB to write.</param>
    /// <param name="Value">Text content to store.</param>
    procedure WriteTextToBlob(var TargetRecordRef: RecordRef; FieldNo: Integer; Value: Text)
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        this.TestBlobField(TargetRecordRef, FieldNo);
        this.WriteTextToTempBlob(TempBlob, Value);

        TempBlob.ToRecordRef(TargetRecordRef, FieldNo);
        TargetRecordRef.Modify(true);
    end;

    /// <summary>
    /// Reads a BLOB field from the provided record and parses it as a JSON object.
    /// </summary>
    /// <param name="SourceRecordRef">Record containing the BLOB field.</param>
    /// <param name="FieldNo">Field number of the BLOB to read.</param>
    /// <param name="BlobJsonObject">Parsed JSON object from the BLOB field.</param>
    procedure ReadBlobAsJsonObject(SourceRecordRef: RecordRef; FieldNo: Integer; var BlobJsonObject: JsonObject)
    var
        BlobValueAsText: Text;
    begin
        this.TestBlobField(SourceRecordRef, FieldNo);
        BlobValueAsText := this.ReadBlobAsText(SourceRecordRef, FieldNo);
        Clear(BlobJsonObject);
        BlobJsonObject.ReadFrom(BlobValueAsText);
    end;

    /// <summary>
    /// Writes text content into a Temp Blob owned by the caller.
    /// </summary>
    /// <param name="TempBlob">Temp Blob that receives the text; the caller keeps it in scope and creates streams from it where needed.</param>
    /// <param name="Value">Text content to store.</param>
    procedure WriteTextToTempBlob(var TempBlob: Codeunit "Temp Blob"; Value: Text)
    var
        ValueOutStream: OutStream;
    begin
        TempBlob.CreateOutStream(ValueOutStream);
        ValueOutStream.Write(Value);
    end;

    local procedure ReadTempBlobAsText(var TempBlob: Codeunit "Temp Blob"): Text
    var
        ValueInStream: InStream;
        TextValue: Text;
    begin
        TempBlob.CreateInStream(ValueInStream);
        ValueInStream.Read(TextValue);
        exit(TextValue);
    end;

    local procedure TestBlobField(RecordRef: RecordRef; FieldNo: Integer)
    var
        FieldRef: FieldRef;
        FieldMustBeBlobErr: Label 'Field %1 on table %2 must be a BLOB field.', Comment = '%1 = field number, %2 = table number';
    begin
        FieldRef := RecordRef.Field(FieldNo);
        if FieldRef.Type <> FieldType::Blob then
            Error(FieldMustBeBlobErr, FieldNo, RecordRef.Number);
    end;
}
