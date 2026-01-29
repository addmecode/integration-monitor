codeunit 50111 "AMC Int. Blob Helper"
{
  /// <summary>
  /// Reads a BLOB field from the provided record and returns it as text.
  /// </summary>
  /// <param name="AnyRecord">Record containing the BLOB field.</param>
  /// <param name="FieldNo">Field number of the BLOB to read.</param>
  /// <returns>Full text content of the BLOB.</returns>
  procedure ReadBlobAsText(AnyRecord: Variant; FieldNo: Integer): Text
  var
    RecRef: RecordRef;
    FieldRef: FieldRef;
    InStream: InStream;
    Chunk: Text;
    Value: Text;
  begin
    RecRef.GetTable(AnyRecord);
    FieldRef := RecRef.Field(FieldNo);
    FieldRef.CalcField();
    FieldRef.CreateInStream(InStream);
    Value := '';
    while not InStream.EOS do begin
      InStream.ReadText(Chunk);
      Value += Chunk;
    end;
    exit(Value);
  end;

  /// <summary>
  /// Writes text content into a BLOB field on the provided record.
  /// </summary>
  /// <param name="AnyRecord">Record containing the BLOB field.</param>
  /// <param name="FieldNo">Field number of the BLOB to write.</param>
  /// <param name="Value">Text content to store.</param>
  procedure WriteTextToBlob(var AnyRecord: Variant; FieldNo: Integer; Value: Text)
  var
    RecRef: RecordRef;
    FieldRef: FieldRef;
    OutStream: OutStream;
  begin
    RecRef.GetTable(AnyRecord);
    FieldRef := RecRef.Field(FieldNo);
    FieldRef.CreateOutStream(OutStream);
    OutStream.WriteText(Value);
    RecRef.Modify(true);
    RecRef.SetTable(AnyRecord);
  end;

  /// <summary>
  /// Copies an InStream into a BLOB field on the provided record.
  /// </summary>
  /// <param name="AnyRecord">Record containing the BLOB field.</param>
  /// <param name="FieldNo">Field number of the BLOB to write.</param>
  /// <param name="SourceStream">Source stream to copy.</param>
  procedure CopyInStreamToBlob(var AnyRecord: Variant; FieldNo: Integer; var SourceStream: InStream)
  var
    RecRef: RecordRef;
    FieldRef: FieldRef;
    OutStream: OutStream;
  begin
    RecRef.GetTable(AnyRecord);
    FieldRef := RecRef.Field(FieldNo);
    FieldRef.CreateOutStream(OutStream);
    CopyStream(OutStream, SourceStream);
    RecRef.Modify(true);
    RecRef.SetTable(AnyRecord);
  end;

  /// <summary>
  /// Attempts to copy an InStream into a BLOB field and suppresses errors.
  /// </summary>
  /// <param name="AnyRecord">Record containing the BLOB field.</param>
  /// <param name="FieldNo">Field number of the BLOB to write.</param>
  /// <param name="SourceStream">Source stream to copy.</param>
  [TryFunction]
  procedure TryCopyInStreamToBlob(var AnyRecord: Variant; FieldNo: Integer; var SourceStream: InStream)
  begin
    CopyInStreamToBlob(AnyRecord, FieldNo, SourceStream);
  end;
}
