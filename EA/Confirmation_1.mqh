//+------------------------------------------------------------------+
//|                                               Confirmation_1.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string CONFIRMATION_1 = "===========================CONFIRMATION 1===========================";

extern int                 MaPeriod = 20;
extern int                 MaType = 4;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getC1Signal(int offset)
  {
   eSignal _signal = FLAT;

   eSignal baseline = getBaselineSignal(offset);


   if(baseline == LONG)
      _signal = LONG;
   else
      if(baseline == SHORT)
         _signal = SHORT;

//if(iCustom(_Symbol, _Period, "ALGO 1\\Angle of Average - Entry",MaPeriod,MaType,3,offset) > 0)
//   _signal = LONG;
//else
//   if(iCustom(_Symbol, _Period, "ALGO 1\\Angle of Average - Entry",MaPeriod,MaType,3,offset) < 0)
//      _signal = SHORT;


   return (_signal);
  }
//+------------------------------------------------------------------+
