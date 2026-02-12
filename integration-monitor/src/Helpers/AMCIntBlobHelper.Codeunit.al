codeunit 50109 "AMC Int. Blob Helper"
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
        RecRef: RecordRef;
        OutStream: OutStream;
    begin
        TempBlob.CreateOutStream(OutStream);
        OutStream.Write(Value);
        TempBlob.ToRecordRef(AnyRecord, FieldNo);
        RecRef.Modify(true);
    end;
}
