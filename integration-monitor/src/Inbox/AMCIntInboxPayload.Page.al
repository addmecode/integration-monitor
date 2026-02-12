// page 50116 "AMC Int. Inbox Payload"
// {
//     PageType = Card;
//     SourceTable = "AMC Int. Inbox Entry";
//     ApplicationArea = All;
//     UsageCategory = None;
//     Caption = 'Inbox Response';
//     InsertAllowed = false;
//     DeleteAllowed = false;

//     layout
//     {
//         area(content)
//         {
//             group(General)
//             {
//                 field(PayloadText; PayloadText)
//                 {
//                     ApplicationArea = All;
//                     Caption = 'Response Payload';
//                     MultiLine = true;
//                 }
//             }
//         }
//     }

//     trigger OnOpenPage()
//     begin
//         LoadPayload();
//         if ReadOnly then
//             CurrPage.Editable(false);
//     end;

//     trigger OnAfterGetRecord()
//     begin
//         LoadPayload();
//     end;

//     trigger OnQueryClosePage(CloseAction: Action): Boolean
//     begin
//         if ReadOnly then
//             exit(true);

//         if CloseAction = Action::OK then
//             SavePayload();

//         exit(true);
//     end;

//     procedure SetReadOnly(IsReadOnly: Boolean)
//     begin
//         ReadOnly := IsReadOnly;
//     end;

//     local procedure LoadPayload()
//     var
//         InboxRef: RecordRef;
//     begin
//         InboxRef.GetTable(Rec);
//         PayloadText := BlobHelper.ReadBlobAsText(InboxRef, Rec.FieldNo("Response Payload"));
//     end;

//     local procedure SavePayload()
//     var
//         InboxRef: RecordRef;
//     begin
//         InboxRef.GetTable(Rec);
//         BlobHelper.WriteTextToBlob(InboxRef, Rec.FieldNo("Response Payload"), PayloadText);
//     end;

//     var
//         BlobHelper: Codeunit "AMC Int. Blob Helper";
//         PayloadText: Text;
//         ReadOnly: Boolean;
// }
