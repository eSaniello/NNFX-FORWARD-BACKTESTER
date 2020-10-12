//+------------------------------------------------------------------+
//|                                                     Baseline.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string BASELINE = "===========================BASELINE===========================";

extern int                 _length = 7;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getBaselineValue(int offset)
  {
   double baseline = iCustom(_Symbol, _Period, "ALGO 1\\WMA",_length,0,offset);

   return baseline;
  }
//+------------------------------------------------------------------+