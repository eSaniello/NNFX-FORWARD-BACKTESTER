//+------------------------------------------------------------------+
//|                                                         Exit.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string EXIT = "===========================EXIT===========================";

extern int                 exit_length = 8;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getExitSignal(int offset)
  {
   eSignal exitSignal = FLAT;


   if(iCustom(_Symbol, _Period, "new\\EhlersFisherTransform",exit_length,0,offset) <
      iCustom(_Symbol, _Period, "new\\EhlersFisherTransform",exit_length,1,offset))
      exitSignal = LONG;
   else
      if(iCustom(_Symbol, _Period, "new\\EhlersFisherTransform",exit_length,0,offset) >
         iCustom(_Symbol, _Period, "new\\EhlersFisherTransform",exit_length,1,offset))
         exitSignal = SHORT;

   return exitSignal;
  }
//+------------------------------------------------------------------+
