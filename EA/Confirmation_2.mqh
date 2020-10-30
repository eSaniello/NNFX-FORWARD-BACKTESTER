//+------------------------------------------------------------------+
//|                                               Confirmation_2.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string CONFIRMATION_2 = "===========================CONFIRMATION 2===========================";

extern int                 lookbackPeriod = 3;
extern int                 priceField = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getC2Signal(int offset)
  {
   eSignal _signal = FLAT;

   if(iCustom(Symbol(), _Period, "new\\Weis Wave Volume [KHT]", lookbackPeriod,priceField,0, offset) != 0.0)
      _signal = LONG;
   else
      if(iCustom(Symbol(), _Period, "new\\Weis Wave Volume [KHT]", lookbackPeriod,priceField,1, offset) != 0.0)
         _signal = SHORT;

   return _signal;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
