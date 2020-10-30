//+------------------------------------------------------------------+
//|                                                          Vol.mqh |
//|                                                 Shaniel Samadhan |
//|                                 https://www.github/eSaniello.com |
//+------------------------------------------------------------------+

input string VOLUME = "===========================VOLUME===========================";

extern int    MaMethod  = 3;
extern int    MaFast    = 3;
extern int    MaSlow    = 5;
extern int    _Price    = 6;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getVolSignal(int offset)
  {
   eSignal _signal = FLAT;

   double usd = iCustom(Symbol(), _Period, "new\\CC mtf & alerts 2.03 nmc",MaMethod,MaFast,MaSlow,_Price, 0, offset);
   double eur = iCustom(Symbol(), _Period, "new\\CC mtf & alerts 2.03 nmc",MaMethod,MaFast,MaSlow,_Price, 1, offset);
   double gbp = iCustom(Symbol(), _Period, "new\\CC mtf & alerts 2.03 nmc",MaMethod,MaFast,MaSlow,_Price, 2, offset);
   double chf = iCustom(Symbol(), _Period, "new\\CC mtf & alerts 2.03 nmc",MaMethod,MaFast,MaSlow,_Price, 3, offset);
   double jpy = iCustom(Symbol(), _Period, "new\\CC mtf & alerts 2.03 nmc",MaMethod,MaFast,MaSlow,_Price, 4, offset);
   double aud = iCustom(Symbol(), _Period, "new\\CC mtf & alerts 2.03 nmc",MaMethod,MaFast,MaSlow,_Price, 5, offset);
   double cad = iCustom(Symbol(), _Period, "new\\CC mtf & alerts 2.03 nmc",MaMethod,MaFast,MaSlow,_Price, 6, offset);
   double nzd = iCustom(Symbol(), _Period, "new\\CC mtf & alerts 2.03 nmc",MaMethod,MaFast,MaSlow,_Price, 7, offset);


//check signals for each pair
   if(Symbol() == "EURUSD")
     {
      if(eur > usd)
         _signal = LONG;
      else
         if(eur < usd)
            _signal = SHORT;
     }
   else
      if(Symbol() == "AUDNZD")
        {
         if(aud > nzd)
            _signal = LONG;
         else
            if(aud < nzd)
               _signal = SHORT;
        }
      else
         if(Symbol() == "EURGBP")
           {
            if(eur > gbp)
               _signal = LONG;
            else
               if(eur < gbp)
                  _signal = SHORT;
           }
         else
            if(Symbol() == "GBPUSD")
              {
               if(gbp > usd)
                  _signal = LONG;
               else
                  if(gbp < usd)
                     _signal = SHORT;
              }
            else
               if(Symbol() == "CHFJPY")
                 {
                  if(chf > jpy)
                     _signal = LONG;
                  else
                     if(chf < jpy)
                        _signal = SHORT;
                 }
               else
                  if(Symbol() == "AUDCAD")
                    {
                     if(aud > cad)
                        _signal = LONG;
                     else
                        if(aud < cad)
                           _signal = SHORT;
                    }
                  else
                     if(Symbol() == "AUDUSD")
                       {
                        if(aud > usd)
                           _signal = LONG;
                        else
                           if(aud < usd)
                              _signal = SHORT;
                       }
                     else
                        if(Symbol() == "NZDUSD")
                          {
                           if(nzd > usd)
                              _signal = LONG;
                           else
                              if(nzd < usd)
                                 _signal = SHORT;
                          }
                        else
                           if(Symbol() == "EURCHF")
                             {
                              if(eur > chf)
                                 _signal = LONG;
                              else
                                 if(eur < chf)
                                    _signal = SHORT;
                             }
                           else
                              if(Symbol() == "USDCHF")
                                {
                                 if(usd > chf)
                                    _signal = LONG;
                                 else
                                    if(usd < chf)
                                       _signal = SHORT;
                                }
                              else
                                 if(Symbol() == "USDJPY")
                                   {
                                    if(usd > jpy)
                                       _signal = LONG;
                                    else
                                       if(usd < jpy)
                                          _signal = SHORT;
                                   }
                                 else
                                    if(Symbol() == "USDCAD")
                                      {
                                       if(usd > cad)
                                          _signal = LONG;
                                       else
                                          if(usd < cad)
                                             _signal = SHORT;
                                      }
                                    else
                                       if(Symbol() == "CADCHF")
                                         {
                                          if(cad > chf)
                                             _signal = LONG;
                                          else
                                             if(cad < chf)
                                                _signal = SHORT;
                                         }
                                       else
                                          if(Symbol() == "AUDJPY")
                                            {
                                             if(aud > jpy)
                                                _signal = LONG;
                                             else
                                                if(aud < jpy)
                                                   _signal = SHORT;
                                            }
                                          else
                                             if(Symbol() == "AUDCHF")
                                               {
                                                if(aud > chf)
                                                   _signal = LONG;
                                                else
                                                   if(aud < chf)
                                                      _signal = SHORT;
                                               }
                                             else
                                                if(Symbol() == "EURCAD")
                                                  {
                                                   if(eur > cad)
                                                      _signal = LONG;
                                                   else
                                                      if(eur < cad)
                                                         _signal = SHORT;
                                                  }
                                                else
                                                   if(Symbol() == "EURAUD")
                                                     {
                                                      if(eur > aud)
                                                         _signal = LONG;
                                                      else
                                                         if(eur < aud)
                                                            _signal = SHORT;
                                                     }
                                                   else
                                                      if(Symbol() == "CADJPY")
                                                        {
                                                         if(cad > jpy)
                                                            _signal = LONG;
                                                         else
                                                            if(cad < jpy)
                                                               _signal = SHORT;
                                                        }
                                                      else
                                                         if(Symbol() == "GBPAUD")
                                                           {
                                                            if(gbp > aud)
                                                               _signal = LONG;
                                                            else
                                                               if(gbp < aud)
                                                                  _signal = SHORT;
                                                           }
                                                         else
                                                            if(Symbol() == "EURNZD")
                                                              {
                                                               if(eur > nzd)
                                                                  _signal = LONG;
                                                               else
                                                                  if(eur < nzd)
                                                                     _signal = SHORT;
                                                              }
                                                            else
                                                               if(Symbol() == "EURJPY")
                                                                 {
                                                                  if(eur > jpy)
                                                                     _signal = LONG;
                                                                  else
                                                                     if(eur < jpy)
                                                                        _signal = SHORT;
                                                                 }
                                                               else
                                                                  if(Symbol() == "GBPJPY")
                                                                    {
                                                                     if(gbp > jpy)
                                                                        _signal = LONG;
                                                                     else
                                                                        if(gbp < jpy)
                                                                           _signal = SHORT;
                                                                    }
                                                                  else
                                                                     if(Symbol() == "GBPCHF")
                                                                       {
                                                                        if(gbp > chf)
                                                                           _signal = LONG;
                                                                        else
                                                                           if(gbp < chf)
                                                                              _signal = SHORT;
                                                                       }
                                                                     else
                                                                        if(Symbol() == "GBPCAD")
                                                                          {
                                                                           if(gbp > cad)
                                                                              _signal = LONG;
                                                                           else
                                                                              if(gbp < cad)
                                                                                 _signal = SHORT;
                                                                          }
                                                                        else
                                                                           if(Symbol() == "NZDCHF")
                                                                             {
                                                                              if(nzd > chf)
                                                                                 _signal = LONG;
                                                                              else
                                                                                 if(nzd < chf)
                                                                                    _signal = SHORT;
                                                                             }
                                                                           else
                                                                              if(Symbol() == "NZDCAD")
                                                                                {
                                                                                 if(nzd > cad)
                                                                                    _signal = LONG;
                                                                                 else
                                                                                    if(nzd < cad)
                                                                                       _signal = SHORT;
                                                                                }
                                                                              else
                                                                                 if(Symbol() == "GBPNZD")
                                                                                   {
                                                                                    if(gbp > nzd)
                                                                                       _signal = LONG;
                                                                                    else
                                                                                       if(gbp < nzd)
                                                                                          _signal = SHORT;
                                                                                   }
                                                                                 else
                                                                                    if(Symbol() == "NZDJPY")
                                                                                      {
                                                                                       if(nzd > jpy)
                                                                                          _signal = LONG;
                                                                                       else
                                                                                          if(nzd < jpy)
                                                                                             _signal = SHORT;
                                                                                      }



   return _signal;
  }
//+------------------------------------------------------------------+
