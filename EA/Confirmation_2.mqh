//+------------------------------------------------------------------+
//|                                               Confirmation_2.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string CONFIRMATION_2 = "===========================CONFIRMATION 2===========================";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getC2Signal(int offset)
  {
   eSignal _signal = FLAT;

   double up1 = iCustom(Symbol(), _Period, "new\\DIDI_Histogram",0, offset);
   double up2 = iCustom(Symbol(), _Period, "new\\DIDI_Histogram",2, offset);
   double dn1 = iCustom(Symbol(), _Period, "new\\DIDI_Histogram",3, offset);
   double dn2 = iCustom(Symbol(), _Period, "new\\DIDI_Histogram",1, offset);

   if(up1 != EMPTY_VALUE || up2 != EMPTY_VALUE)
     {
      _signal = LONG;
     }
   else
      if(dn1 != EMPTY_VALUE || dn2 != EMPTY_VALUE)
        {
         _signal = SHORT;
        }

   return _signal;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
