enum 50104 "AMC Int. Message Type" implements "AMC IMessageHandler"
{
    Extensible = true;

    value(0; Generic)
    {
        Caption = 'Generic';
        Implementation = "AMC IMessageHandler" = "AMC Int. Handler Default";
    }
}
