//+------------------------------------------------------------------+
//|                                                          Vol.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string VOLUME = "===========================VOLUME===========================";

extern int vol_sensitive = 225;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getVolSignal(int offset)
  {
   eSignal _signal = FLAT;

   double up = iCustom(Symbol(), _Period, "new\\Waddah_Attar_Explosion_added_atr_and_volume_calculation",vol_sensitive, 0, offset);
   double dn = iCustom(Symbol(), _Period, "new\\Waddah_Attar_Explosion_added_atr_and_volume_calculation",vol_sensitive, 1, offset);
   double one = iCustom(Symbol(), _Period, "new\\Waddah_Attar_Explosion_added_atr_and_volume_calculation",vol_sensitive, 2, offset);
   double two = iCustom(Symbol(), _Period, "new\\Waddah_Attar_Explosion_added_atr_and_volume_calculation",vol_sensitive, 3, offset);
   double three = iCustom(Symbol(), _Period, "new\\Waddah_Attar_Explosion_added_atr_and_volume_calculation",vol_sensitive, 4, offset);
   double four = iCustom(Symbol(), _Period, "new\\Waddah_Attar_Explosion_added_atr_and_volume_calculation",vol_sensitive, 5, offset);

   if(up >= one && up >= two && up >= three && up >= four)
     {
      _signal = LONG;
     }
   else
      if(dn >= one && dn >= two && dn >= three && dn >= four)
        {
         _signal = SHORT;
        }

   return _signal;
  }
//+------------------------------------------------------------------+
