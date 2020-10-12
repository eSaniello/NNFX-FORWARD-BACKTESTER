//+------------------------------------------------------------------+
//|                                                         Exit.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string EXIT = "===========================EXIT===========================";

extern int                 SMMA_period = 8;
extern int                 stochastic_period = 5;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getExitSignal(int offset)
  {
   eSignal exitSignal = FLAT;

   eSignal baseline = getBaselineSignal(offset);


   if(baseline == LONG)
      exitSignal = SHORT;
   else
      if(baseline == SHORT)
         exitSignal = LONG;

//if(iCustom(_Symbol, _Period, "ALGO 1\\(B)DSS Bressert",SMMA_period,stochastic_period,0,offset) <
//   iCustom(_Symbol, _Period, "ALGO 1\\(B)DSS Bressert",SMMA_period,stochastic_period,0,offset + 1))
//   exitSignal = LONG;
//else
//   if(iCustom(_Symbol, _Period, "ALGO 1\\(B)DSS Bressert",SMMA_period,stochastic_period,0,offset) >
//      iCustom(_Symbol, _Period, "ALGO 1\\(B)DSS Bressert",SMMA_period,stochastic_period,0,offset + 1))
//      exitSignal = SHORT;

   return exitSignal;
  }
//+------------------------------------------------------------------+
