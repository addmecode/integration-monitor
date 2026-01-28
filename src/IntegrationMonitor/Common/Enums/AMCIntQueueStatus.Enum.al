enum 50103 "AMC Int. Queue Status"
{
  Extensible = false;

  value(0; New)
  {
    Caption = 'New';
  }
  value(1; Ready)
  {
    Caption = 'Ready';
  }
  value(2; Sending)
  {
    Caption = 'Sending';
  }
  value(3; Sent)
  {
    Caption = 'Sent';
  }
  value(4; WaitingResponse)
  {
    Caption = 'Waiting Response';
  }
  value(5; Failed)
  {
    Caption = 'Failed';
  }
  value(6; Cancelled)
  {
    Caption = 'Cancelled';
  }
}

