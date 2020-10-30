//+------------------------------------------------------------------+
//|                                                     Baseline.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string BASELINE = "===========================BASELINE===========================";

extern int                 _cutOffPeriod = 15;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getBaselineValue(int offset)
  {
   double baseline = iCustom(_Symbol, _Period, "new\\TwoPoleButterworthFilter",_cutOffPeriod,0,offset);

   return baseline;
  }
//+------------------------------------------------------------------+
