//+------------------------------------------------------------------+
//|                                               Confirmation_1.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string CONFIRMATION_1 = "===========================CONFIRMATION 1===========================";


extern int                 ma_period = 10;
extern int                 MaType = 4;
extern int                 maAppliedPrice = 0;
extern double              angleLevel = 4.0;
extern int                 angleBars = 2;
extern int                 atrPeriod = 14;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getC1Signal(int offset)
  {
   eSignal _signal = FLAT;

   double zero = iCustom(Symbol(), _Period, "ATR angle of average",ma_period,MaType,maAppliedPrice,angleLevel,angleBars,atrPeriod, 0, offset);
   double one = iCustom(Symbol(), _Period, "ATR angle of average",ma_period,MaType,maAppliedPrice,angleLevel,angleBars,atrPeriod, 1, offset);

   if(zero != EMPTY_VALUE && one == EMPTY_VALUE)
     {
      _signal = LONG;
     }
   else
      if(zero == EMPTY_VALUE && one != EMPTY_VALUE)
        {
         _signal = SHORT;
        }
      else
         if(zero == EMPTY_VALUE && one == EMPTY_VALUE)
           {
            _signal = FLAT;
           }

   return (_signal);
  }
//+------------------------------------------------------------------+
