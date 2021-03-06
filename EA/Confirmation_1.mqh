//+------------------------------------------------------------------+
//|                                               Confirmation_1.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string CONFIRMATION_1 = "===========================CONFIRMATION 1===========================";


extern int                 lookbackperiod = 25;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getC1Signal(int offset)
  {
   eSignal _signal = FLAT;

   double up = iCustom(Symbol(), _Period, "new\\jas\\Quantile_Price_Analysis",lookbackperiod, 6, offset);
   double dn = iCustom(Symbol(), _Period, "new\\jas\\Quantile_Price_Analysis",lookbackperiod, 5, offset);

   if(up != EMPTY_VALUE)
     {
      _signal = LONG;
     }
   else
      if(dn != EMPTY_VALUE)
        {
         _signal = SHORT;
        }

   return (_signal);
  }
//+------------------------------------------------------------------+
