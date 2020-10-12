//+------------------------------------------------------------------+
//|                                               Confirmation_2.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string CONFIRMATION_2 = "===========================CONFIRMATION 2===========================";

extern int                 timeframe = 0;
extern int                 averagePeriod = 10;
extern double              sensitivity = 1.0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getC2Signal(int offset)
  {
   eSignal _signal = FLAT;

   if(iCustom(Symbol(), 0, "ALGO 1\\precision trend 2.2 (histo)", timeframe,averagePeriod,sensitivity,0, offset) == 1)
      _signal = LONG;
   else
      if(iCustom(Symbol(), 0, "ALGO 1\\precision trend 2.2 (histo)", timeframe,averagePeriod,sensitivity,1, offset) == 1)
         _signal = SHORT;

   return _signal;
  }
//+------------------------------------------------------------------+
