enum 50105 "AMC Int. Transport" implements "AMC IHttpTransport"
{
  Extensible = true;

  value(0; Http)
  {
    Caption = 'HTTP';
    Implementation = "AMC IHttpTransport" = "AMC Http Transport";
  }
}
