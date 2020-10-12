//+------------------------------------------------------------------+
//|                                                          Vol.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string VOLUME = "===========================VOLUME===========================";

extern double              bandEgde = 6.0;
extern int                 priceToUse = 21;
extern double              upperLevel = 0.5;
extern double              lowerLevel = -0.5;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getVolSignal(int offset)
  {
   eSignal _signal = FLAT;

   double upper_level = iCustom(Symbol(), 0, "ALGO 1\\Universal oscillator",bandEgde,priceToUse,upperLevel,lowerLevel, 0, offset);
   double lower_level = iCustom(Symbol(), 0, "ALGO 1\\Universal oscillator",bandEgde,priceToUse,upperLevel,lowerLevel, 2, offset);
   double volMa = iCustom(Symbol(), 0, "ALGO 1\\Universal oscillator",bandEgde,priceToUse,upperLevel,lowerLevel, 3, offset);

   if(volMa >= upper_level)
      _signal = LONG;
   else
      if(volMa <= lower_level)
         _signal = SHORT;

   return _signal;
  }
//+------------------------------------------------------------------+
