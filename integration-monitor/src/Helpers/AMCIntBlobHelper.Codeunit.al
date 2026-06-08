namespace Addmecode.IntegrationMonitor.Helpers;
using System.Utilities;

codeunit 50113 "AMC Int. Blob Helper"
{
    // TODO: move to utils

    /// <summary>
    /// Reads a BLOB field from the provided record and returns it as text.
    /// </summary>
    /// <param name="AnyRecord">Record containing the BLOB field.</param>
    /// <param name="FieldNo">Field number of the BLOB to read.</param>
    /// <returns>Full text content of the BLOB.</returns>
    procedure ReadBlobAsText(AnyRecord: RecordRef; FieldNo: Integer): Text
    var
        TempBlob: Codeunit "Temp Blob";
        InStream: InStream;
        BlobValueAsText: Text;
    begin
        TempBlob.FromRecordRef(AnyRecord, FieldNo);
        TempBlob.CreateInStream(InStream);
        InStream.Read(BlobValueAsText);
        exit(BlobValueAsText);
    end;

    /// <summary>
    /// Writes text content into a BLOB field on the provided record.
    /// </summary>
    /// <param name="AnyRecord">Record containing the BLOB field.</param>
    /// <param name="FieldNo">Field number of the BLOB to write.</param>
    /// <param name="Value">Text content to store.</param>
    procedure WriteTextToBlob(var AnyRecord: RecordRef; FieldNo: Integer; Value: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        TempBlob.CreateOutStream(OutStream);
        OutStream.Write(Value);
        TempBlob.ToRecordRef(AnyRecord, FieldNo);
        AnyRecord.Modify(true);
    end;

    /// <summary>
    /// Reads a BLOB field from the provided record and parses it as a JSON object.
    /// </summary>
    /// <param name="AnyRecord">Record containing the BLOB field.</param>
    /// <param name="FieldNo">Field number of the BLOB to read.</param>
    /// <param name="BlobJsonObject">Parsed JSON object from the BLOB field.</param>
    procedure ReadBlobAsJsonObject(AnyRecord: RecordRef; FieldNo: Integer; var BlobJsonObject: JsonObject)
    var
        BlobValueAsText: Text;
    begin
        BlobValueAsText := this.ReadBlobAsText(AnyRecord, FieldNo);
        BlobJsonObject.ReadFrom(BlobValueAsText);
    end;

    /// <summary>
    /// Creates an input stream from text content
    /// </summary>
    /// <param name="Value">Text content to expose through the input stream.</param>
    /// <param name="ValueInStream">Input stream created from the text content.</param>
    procedure CreateTextInStream(Value: Text; var ValueInStream: InStream)
    var
        TextTempBlob: Codeunit "Temp Blob";
        ValueOutStream: OutStream;
    begin
        TextTempBlob.CreateOutStream(ValueOutStream);
        ValueOutStream.Write(Value);
        TextTempBlob.CreateInStream(ValueInStream);
    end;
}
