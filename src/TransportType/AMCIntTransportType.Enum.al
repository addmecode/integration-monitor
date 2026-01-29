enum 50105 "AMC Int. Transport Type" implements "AMC IHttpTransportHandler"
{
    Extensible = true;

    value(0; Http)
    {
        Caption = 'HTTP';
        Implementation = "AMC IHttpTransportHandler" = "AMC Http Transport Default";
    }
}
