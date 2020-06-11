//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright   "Shaniel Samadhan 2020"
#property link        "http://www.github/eSaniello.com"
#property description "NNFX EA"
#property strict
#include <Zmq/Zmq.mqh>
#import "kernel32.dll"
int SleepEx(int dwMilliseconds, bool bAlertable);
#import


input string INDICATORS = "===========================INDICATORS===========================";
input string BASELINE = "===========================BASELINE===========================";
extern int                 _length = 7;


input string CONFIRMATION_1 = "===========================CONFIRMATION 1===========================";
extern int                 MaPeriod = 20;
extern int                 MaType = 4;


input string CONFIRMATION_2 = "===========================CONFIRMATION 2===========================";
extern int                 timeframe = 0;
extern int                 averagePeriod = 10;
extern double              sensitivity = 1.0;



input string VOLUME = "===========================VOLUME===========================";
extern double              bandEgde = 6.0;
extern int                 priceToUse = 21;
extern double              upperLevel = 0.5;
extern double              lowerLevel = -0.5;



input string EXIT = "===========================EXIT===========================";
extern int                 SMMA_period = 8;
extern int                 stochastic_period = 5;



input string MM = "===========================MONEY MANAGEMENT===========================";
extern bool                scaleOut = true;
extern bool                use7CandleRule = true;
extern bool                filterPullbacks = true;
extern bool                baselineATRFilter = true;
extern bool                baselineCrossExit = true;
extern double              RiskPercent=1.0;
extern double              takeProfitPercent = 1.0;
extern double              stoplossPercent = 1.5;
extern int                 ATR_Period = 14;
extern bool                LimitCurrencyRisk = true;     //Limit Risk per Currency (not per Trade)
input string               TimeToTrade="23:50:00"; //Time of day to trade
input int                  signalCheckingShift = 0; //On what candle to check for signal (0 = current candle, 1 = previous etc)



input string OTHER = "===========================OTHER SETTINGS===========================";
extern bool                showInformationIcons = true;
input int                  MagicNumber=5475;



////////////////////////////////////LOCAL VARIABLES/////////////////////////////////////////
string                     Base, Quote;
int                        tickets[];
double                     wins;
double                     losses;
double                     ATR = NULL;
double                     Lots;
MqlDateTime                time_to_open;
bool                       exitAgree = false;
enum                       eSignal {FLAT, LONG, SHORT};
bool                       newbar = false;
string                     signalToSend;

// Prepare our context and socket
Context context("NNFX");
Socket socket(context,ZMQ_REQ);
Socket sub(context,ZMQ_SUB);
////////////////////////////////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("Connecting to server…");
   socket.connect("tcp://127.0.0.1:5555");
   sub.connect("tcp://127.0.0.1:6666");
   sub.subscribe(Symbol());

   TimeToStruct(StringToTime(TimeToTrade),time_to_open);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//Print statistics in journal
   countWinsAndLosses();
   double winrate = NormalizeDouble((wins / (wins + losses)) * 100, 2);
   Print("wins: " + (string)wins + " | " + "losses: " + (string)losses + " | winrate: " + (string)winrate + "%");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//TIME THINGIES
   MqlDateTime time;
   TimeCurrent(time);
   time.hour = time_to_open.hour;
   time.min = time_to_open.min;
   time.sec = time_to_open.sec;
   datetime time_current = TimeCurrent();
   datetime time_trade = StructToTime(time);


//Set initial signal to flat
   eSignal signal = FLAT;


//Check if this is a new bar
   if(NewBar() == true)
      newbar = true;


//Only take trade at specified time
   if(time_current >= time_trade && time_current < time_trade+(15*PeriodSeconds(PERIOD_M1)))
     {

      if(newbar == true)
        {
         //Get ATR value
         ATR = iATR(NULL, PERIOD_CURRENT, ATR_Period, signalCheckingShift);

         if(ATR == 0 || ATR == NULL)
            return;

         //Calculate the lotsize
         Lots = CalcLots();

         //Monitor open trades and move to break even when first half hits TP
         checkAndMoveToBreakeven(ATR);

         //Get the current algo signal
         signal = getSignal(signalCheckingShift);

         //Placing orders
         if(signal == LONG)
           {
            //check if exit indi agrees or not and save it in a bool
            if(getExitSignal(signalCheckingShift) == SHORT)
              {
               exitAgree = true;
               signalToSend = "LONG";
              }
            else
               if(getExitSignal(signalCheckingShift) == LONG)
                 {
                  exitAgree = false;
                  signalToSend = "LONG";
                 }
           }
         else
            if(signal == SHORT)
              {
               //check if exit indi agrees or not and save it in a bool
               if(getExitSignal(signalCheckingShift) == LONG)//exit
                 {
                  exitAgree = true;
                  signalToSend = "SHORT";
                 }
               else
                  if(getExitSignal(signalCheckingShift) == SHORT)
                    {
                     exitAgree = false;
                     signalToSend = "SHORT";
                    }
              }
            else
               if(signal == FLAT)
                 {
                  signalToSend = "FLAT";
                 }


         //check for exit signals
         if(checkForExits(signalCheckingShift, exitAgree) == LONG)
           {
            CloseOrders("OP_BUY");
           }
         else
            if(checkForExits(signalCheckingShift, exitAgree) == SHORT)
              {
               CloseOrders("OP_SELL");
              }





         ///////////////////////////////////////////////////////////////////////////////////
         //SHIT TO SEND
         //-symbol
         //-date
         //-atr
         //-total open orders
         //-signal


         Print("Sending signal information");
         string tempString;
         string msg;

         //Building the message string in a json object
         tempString = StringFormat("{\"symbol\": \"%s\",", _Symbol);
         StringAdd(msg, tempString);
         tempString = StringFormat("\"date\": \"%s\",", (string)TimeCurrent());
         StringAdd(msg, tempString);
         tempString = StringFormat("\"atr\": \"%s\",", (string)ATR);
         StringAdd(msg, tempString);
         tempString = StringFormat("\"open_orders\": \"%s\",", (string)TotalOpenOrders());
         StringAdd(msg, tempString);
         tempString = StringFormat("\"signal\": \"%s\"}", signalToSend);
         StringAdd(msg, tempString);

         ZmqMsg signalMsg(msg);
         ZmqMsg reply;
         ZmqMsg sigInfo;

         socket.send(signalMsg,true);

         newbar = false;

         while(!IsStopped())
           {
            if(socket.recv(reply,true))
              {
               // OK message sent OK lets read the reply
               Print("Waiting for OK");

               if(reply.getData() == "OK")
                 {
                  Print("Got OK");
                  if(sub.recv(sigInfo, true))
                    {
                     Print("Got signal info");
                     string _msg = sigInfo.getData();
                     string msg_array[];
                     StringSplit(_msg,' ',msg_array);
                     string data = msg_array[1];

                     Print("Data: " + data);

                     if(data == "LONG")
                       {
                        Print("LONG ORDER");
                        break;
                       }
                     else
                        if(data == "SHORT")
                          {
                           Print("SHORT ORDER");
                           break;
                          }
                        else
                           if(data == "FLAT")
                             {
                              Print("NEXT CANDLE");
                              break;
                             }
                    }
                 }
              }
            else
              {
               if(IsTesting() || IsOptimization())
                 {
                  SleepEx(100,false);
                 }
               else
                 {
                  Sleep(100);
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getBaselineValue(int offset)
  {
   double baseline = iCustom(_Symbol, _Period, "ALGO 1\\WMA",_length,0,offset);

   return baseline;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getBaselineSignal(int offset)
  {
   eSignal _signal = FLAT;
   double baseline = iCustom(_Symbol, _Period, "ALGO 1\\WMA",_length,0,offset);


   if(Close[offset] > baseline)
      _signal = LONG;
   else
      if(Close[offset] < baseline)
         _signal = SHORT;


   return _signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getC1Signal(int offset)
  {
   eSignal _signal = FLAT;

   if(iCustom(_Symbol, _Period, "ALGO 1\\Angle of Average - Entry",MaPeriod,MaType,3,offset) > 0)
      _signal = LONG;
   else
      if(iCustom(_Symbol, _Period, "ALGO 1\\Angle of Average - Entry",MaPeriod,MaType,3,offset) < 0)
         _signal = SHORT;


   return (_signal);
  }
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
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getExitSignal(int offset)
  {
   eSignal exitSignal = FLAT;

   if(iCustom(_Symbol, _Period, "ALGO 1\\(B)DSS Bressert",SMMA_period,stochastic_period,0,offset) <
      iCustom(_Symbol, _Period, "ALGO 1\\(B)DSS Bressert",SMMA_period,stochastic_period,0,offset + 1))
      exitSignal = LONG;
   else
      if(iCustom(_Symbol, _Period, "ALGO 1\\(B)DSS Bressert",SMMA_period,stochastic_period,0,offset) >
         iCustom(_Symbol, _Period, "ALGO 1\\(B)DSS Bressert",SMMA_period,stochastic_period,0,offset + 1))
         exitSignal = SHORT;

   return exitSignal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getCandlesSinceBaselineSignal(int offset = 0)
  {
   bool exitloop = false;
   int count=0;
   eSignal curSignal = FLAT,prevSignal = FLAT;


   for(int i=offset; i<=Bars && !exitloop; i++)
     {
      curSignal = getBaselineSignal(i);
      prevSignal = getBaselineSignal(i+1);

      if(curSignal != prevSignal)
        {
         exitloop = true;
        }
      else
        {
         count++;
        }
     }

   return(count);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getCandlesSinceC1Signal(int offset = 0)
  {
   bool exitloop = false;
   int count=0;
   eSignal curSignal = FLAT,prevSignal = FLAT;


   for(int i=offset; i<=Bars && !exitloop; i++)
     {
      curSignal = getC1Signal(i);
      prevSignal = getC1Signal(i+1);

      if(curSignal != prevSignal)
        {
         exitloop = true;
        }
      else
        {
         count++;
        }
     }

   return(count);
  }
//+------------------------------------------------------------------+
//| Limit trading to Risk% per currency (Not per pair)               |
//| Update: Can go up to 4% (2% Long & 2% Short) per 7/1/19 Podcast  |
//+------------------------------------------------------------------+
bool isRiskOkay(int direction)
  {
//Go through currently open orders.  Check if we are already
//trading a currency as a base or quote
   for(int i = 0; i < OrdersTotal() && OrderSelect(i, SELECT_BY_POS) && LimitCurrencyRisk; i++)
     {
      if(OrderMagicNumber() == MagicNumber)
        {
         string orderBase = StringSubstr(OrderSymbol(), 0, 3); // base currency
         string orderQuote = StringSubstr(OrderSymbol(), 3, 3); // quote currency

         if(OrderType() == direction && (Base == orderBase || Quote == orderQuote))
            return false; //too much risk already
         else
            if(OrderType() != direction && (Base == orderQuote || Quote == orderBase))
               return false; //too much risk already
        }
     }
   return true; //we can trade
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalcLots()
  {
   double lots = 2 * MarketInfo(Symbol(), MODE_LOTSTEP);
   double riskAmount = AccountBalance() * (RiskPercent / 100);
   double Stop_Loss = (ATR * 1.5);
   double Spread = MarketInfo(Symbol(), MODE_SPREAD) * Point;
   double Tick = MarketInfo(Symbol(), MODE_TICKVALUE) / MarketInfo(Symbol(), MODE_TICKSIZE);

   if(riskAmount > 0 && Stop_Loss > 0 && Tick > 0)
      lots =(riskAmount / ((Stop_Loss + Spread) * Tick));

   if(lots > MarketInfo(Symbol(), MODE_MAXLOT))
      lots = MarketInfo(Symbol(), MODE_MAXLOT);
   else
      if(lots <= MarketInfo(Symbol(), MODE_MINLOT))
         lots = (MarketInfo(Symbol(), MODE_MINLOT));

   return NormalizeLots(lots);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void countWinsAndLosses()
  {
   for(int cnt = OrdersHistoryTotal()-1; cnt >= 0; cnt--)
     {
      bool o = OrderSelect(cnt, SELECT_BY_POS, MODE_HISTORY);
      if(OrderSymbol() == Symbol())
        {
         if(OrderProfit() > 0)
           {
            wins++;
           }
         else
            if(OrderProfit() < 0)
              {
               losses++;
              }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkAndMoveToBreakeven(double atr)
  {
//check order status
   for(int i = 0; i < ArraySize(tickets); i++)
     {
      if(OrderSelect(tickets[i], SELECT_BY_TICKET, MODE_HISTORY))
        {
         //check tp hit
         if(OrderTakeProfit() != 0.0)
           {
            if(OrderType() == OP_BUY ? OrderClosePrice() >= OrderTakeProfit(): OrderClosePrice() <= OrderTakeProfit())
              {
               //modify trade
               string symbol = OrderSymbol();
               int type = OrderType();

               for(int j = OrdersTotal()-1; j >= 0; j--)
                 {
                  bool o = OrderSelect(j, SELECT_BY_POS);
                  if(OrderSymbol() == symbol)
                    {
                     if(OrderType() == type)
                       {
                        if(OrderTakeProfit() == 0.0)
                          {
                           //move to breakeven   //move to breakeven
                           if(OrderType() == OP_BUY)
                              bool _o = OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice() + (0.1 * atr), OrderTakeProfit(),0,Blue);
                           else
                              if(OrderType() == OP_SELL)
                                 bool __o = OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice() - (0.1 * atr), OrderTakeProfit(),0,Blue);
                          }
                       }
                    }
                 }
              }
           }
        }
     }

//collect orders
   ArrayResize(tickets, OrdersTotal());
   for(int i = 0; i < OrdersTotal(); i++)
     {
      bool o = OrderSelect(i, SELECT_BY_POS);
      tickets[i] = OrderTicket();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TotalOpenOrders()
  {
   int total_orders = 0;

   for(int order = 0; order < OrdersTotal(); order++)
     {
      if(OrderSelect(order,SELECT_BY_POS,MODE_TRADES)==false)
         break;

      if(OrderMagicNumber() == MagicNumber && OrderSymbol() == _Symbol)
        {
         total_orders++;
        }
     }

   return(total_orders);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool checkPendingOrdersBuy()
  {
   for(int i = 1; i <= OrdersTotal(); i++)
     {
      if(OrderSelect(i-1, SELECT_BY_POS))
        {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == _Symbol)
           {
            if(OrderType() == OP_BUY)
               return true;
            else
               return false;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool checkPendingOrdersSell()
  {
   for(int i = 1; i <= OrdersTotal(); i++)
     {
      if(OrderSelect(i-1, SELECT_BY_POS))
        {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == _Symbol)
           {
            if(OrderType() == OP_SELL)
               return true;
            else
               return false;
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void buyOrder(double atr_val)
  {
//Open Buy Order
   int ticket1 = OrderSend(_Symbol,OP_BUY,Lots,Ask,10,0,0,"BUY",MagicNumber);
   if(ticket1<0)
     {
      Print("OrderSend failed with error #",GetLastError());
     }

// Modify Buy Order
   bool res1 = OrderModify(ticket1,OrderOpenPrice(),Ask-(1.5 * atr_val),Ask+atr_val,0,Blue);
   if(!res1)
     {
      Print("Error in OrderModify. Error code=",GetLastError());
     }

   if(scaleOut == true)
     {
      //order 2
      int ticket2 = OrderSend(_Symbol,OP_BUY,Lots,Ask,10,0,0,"BUY",MagicNumber);
      if(ticket2<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Buy Order
      bool res2 = OrderModify(ticket2,OrderOpenPrice(),Ask-(1.5 * atr_val),0,0,Blue);
      if(!res2)
        {
         Print("Error in OrderModify. Error code=",GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sellOrder(double atr_val)
  {
//Open Sell Order
   int ticket1 = OrderSend(_Symbol,OP_SELL,Lots,Bid,10,0,0,"SELL",MagicNumber);
   if(ticket1<0)
     {
      Print("OrderSend failed with error #",GetLastError());
     }

// Modify Sell Order
   bool res1 = OrderModify(ticket1,OrderOpenPrice(),Bid+(1.5 * atr_val),Bid-atr_val,0,Blue);
   if(!res1)
     {
      Print("Error in OrderModify. Error code=",GetLastError());
     }

   if(scaleOut == true)
     {
      //order 2
      int ticket2 = OrderSend(_Symbol,OP_SELL,Lots,Bid,10,0,0,"SELL",MagicNumber);
      if(ticket2<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Sell Order
      bool res2 = OrderModify(ticket2,OrderOpenPrice(),Bid+(1.5 * atr_val),0,0,Blue);
      if(!res2)
        {
         Print("Error in OrderModify. Error code=",GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOrders(string orderType)
  {
   RefreshRates();

   for(int i=(OrdersTotal()-1); i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)
        {
         Print("ERROR - Unable to select the order - ",GetLastError());
         break;
        }

      bool res=false;

      int Slippage=10;

      double BidPrice=MarketInfo(OrderSymbol(),MODE_BID);
      double AskPrice=MarketInfo(OrderSymbol(),MODE_ASK);

      if(OrderMagicNumber() == MagicNumber && OrderSymbol() == _Symbol)
        {
         if(OrderType()==OP_SELL && orderType == "OP_SELL")
           {
            res=OrderClose(OrderTicket(),OrderLots(),AskPrice,Slippage);
           }
         else
            if(OrderType()==OP_BUY && orderType == "OP_BUY")
              {
               res=OrderClose(OrderTicket(),OrderLots(),BidPrice,Slippage);
              }
        }

      if(res==false)
         Print("ERROR - Unable to close the order - ",OrderTicket()," - ",GetLastError());
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeLots(double p)
  {
   double ls = MarketInfo(Symbol(), MODE_LOTSTEP);
   return MathRound(p / ls) * ls;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewBar()
  {
   static datetime lastbar;
   datetime curbar = Time[0];
   if(lastbar!=curbar)
     {
      lastbar=curbar;
      return (true);
     }
   else
     {
      return(false);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PrintChartInformationIcon(double price, int code, color iconColour,string toolTip)
  {
   static int infoNumber = 0;

   if(showInformationIcons)
     {
      price = price + 0.005;

      infoNumber = infoNumber+1;
      string info="info" + IntegerToString(infoNumber);
      datetime time=TimeCurrent();

      ObjectCreate(0,info,OBJ_ARROW,0,0,0,0,0);          // Create an arrow
      ObjectSetInteger(0,info,OBJPROP_ARROWCODE,code);    // Set the arrow code
      ObjectSetInteger(0,info,OBJPROP_COLOR,iconColour);    // Set the Colour
      ObjectSetInteger(0,info,OBJPROP_TIME,time);        // Set time
      ObjectSetDouble(0,info,OBJPROP_PRICE,price-0.005);// Set price
      ObjectSetInteger(0,info,OBJPROP_WIDTH,2);
      ObjectSetString(0,info,OBJPROP_TOOLTIP,toolTip);
      ObjectSetString(0,info,OBJPROP_TEXT,toolTip);
      ChartRedraw(0);                                        // Draw arrow now
     }

   return price;
  }
//+------------------------------------------------------------------+
eSignal checkForExits(int _offset, bool _exitAgree)
  {
   eSignal exitSignal = FLAT;
   double iconHeight = Low[_offset];

   if(_exitAgree == true)
     {
      if(checkPendingOrdersBuy())
        {
         if(getExitSignal(_offset) == LONG)
           {
            exitSignal = LONG;
            iconHeight = PrintChartInformationIcon(iconHeight, 120, clrCrimson,"Exit via Exit Indicator");
           }
         else
            if(getBaselineSignal(_offset) == SHORT && baselineCrossExit == true)
              {
               exitSignal = LONG;
               iconHeight = PrintChartInformationIcon(iconHeight, 120, clrYellow,"Exit via Baseline");
              }
            else
               if(getC1Signal(_offset) == SHORT)
                 {
                  exitSignal = LONG;
                  iconHeight = PrintChartInformationIcon(iconHeight, 120, clrBlue,"Exit Via C1");
                 }
        }
      else
         if(checkPendingOrdersSell())
           {
            if(getExitSignal(_offset) == SHORT)
              {
               exitSignal = SHORT;
               iconHeight = PrintChartInformationIcon(iconHeight, 120, clrCrimson,"Exit via Exit Indicator");
              }
            else
               if(getBaselineSignal(_offset) == LONG && baselineCrossExit == true)
                 {
                  exitSignal = SHORT;
                  iconHeight = PrintChartInformationIcon(iconHeight, 120, clrYellow,"Exit via Baseline");
                 }
               else
                  if(getC1Signal(_offset) == LONG)
                    {
                     exitSignal = SHORT;
                     iconHeight = PrintChartInformationIcon(iconHeight, 120, clrBlue,"Exit Via C1");
                    }
           }
     }
   else
      if(_exitAgree == false)
        {
         if(checkPendingOrdersBuy())
           {
            if(getBaselineSignal(_offset) == SHORT && baselineCrossExit == true)
              {
               exitSignal = LONG;
               iconHeight = PrintChartInformationIcon(iconHeight, 120, clrYellow,"Exit via Baseline");
              }
            else
               if(getC1Signal(_offset) == SHORT)
                 {
                  exitSignal = LONG;
                  iconHeight = PrintChartInformationIcon(iconHeight, 120, clrBlue,"Exit Via C1");
                 }
           }
         else
            if(checkPendingOrdersSell())
              {
               if(getBaselineSignal(_offset) == LONG && baselineCrossExit == true)
                 {
                  exitSignal = SHORT;
                  iconHeight = PrintChartInformationIcon(iconHeight, 120, clrYellow,"Exit via Baseline");
                 }
               else
                  if(getC1Signal(_offset) == LONG)
                    {
                     exitSignal = SHORT;
                     iconHeight = PrintChartInformationIcon(iconHeight, 120, clrBlue,"Exit Via C1");
                    }
              }
        }

   return exitSignal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getSignal(int offset)
  {
   eSignal signal = FLAT;
   int barsSinceC1Signal = getCandlesSinceC1Signal(offset);
   int barsSinceBaselineSignal = getCandlesSinceBaselineSignal(offset);
   eSignal prevC1Signal = FLAT;
   eSignal baseDir = FLAT;
   eSignal prevBaselineSignal = FLAT;
   eSignal c1Dir = FLAT;
   double iconHeight = High[offset] + 0.005;


//Normal entry
   if(signal == FLAT)
     {
      if(getC1Signal(offset) == LONG && getC1Signal(offset + 1) == SHORT)//C1 signal
        {
         if(baselineATRFilter == true)
           {
            if(getBaselineSignal(offset) == LONG)
              {
               if(Close[offset] - getBaselineValue(offset) < ATR)
                 {
                  //OTHER ALGO PARTS
                  if(getC2Signal(offset) == LONG)
                    {
                     if(getVolSignal(offset) == LONG)
                       {
                        signal = LONG;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                       }
                    }
                  else
                    {
                     signal = FLAT;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                    }
                 }
               else
                 {
                  signal = FLAT;
                  if(TotalOpenOrders() == 0)
                     iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                 }
              }
            else
              {
               signal = FLAT;
               if(TotalOpenOrders() == 0)
                  iconHeight = PrintChartInformationIcon(iconHeight, 251, clrYellow,"Baseline disagree");
              }
           }
         else
            if(getBaselineSignal(offset) == LONG)
              {
               //OTHER ALGO PARTS
               if(getC2Signal(offset) == LONG)
                 {
                  if(getVolSignal(offset) == LONG)
                    {
                     signal = LONG;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                    }
                  else
                    {
                     signal = FLAT;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                    }
                 }
               else
                 {
                  signal = FLAT;
                  if(TotalOpenOrders() == 0)
                     iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                 }
              }
            else
              {
               signal = FLAT;
               if(TotalOpenOrders() == 0)
                  iconHeight = PrintChartInformationIcon(iconHeight, 251, clrYellow,"Baseline disagree");
              }
        }
      else
         if(getC1Signal(offset) == SHORT && getC1Signal(offset + 1) == LONG)//C1 signal
           {
            if(baselineATRFilter == true)
              {
               if(getBaselineSignal(offset) == SHORT)
                 {
                  if(getBaselineValue(offset) - Close[offset] < ATR)
                    {
                     //OTHER ALGO PARTS
                     if(getC2Signal(offset) == SHORT)
                       {
                        if(getVolSignal(offset) == SHORT)
                          {
                           signal = SHORT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                       }
                    }
                  else
                    {
                     signal = FLAT;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                    }
                 }
               else
                 {
                  signal = FLAT;
                  if(TotalOpenOrders() == 0)
                     iconHeight = PrintChartInformationIcon(iconHeight, 251, clrYellow,"Baseline disagree");
                 }
              }
            else
               if(getBaselineSignal(offset) == SHORT)
                 {
                  //OTHER ALGO PARTS
                  if(getC2Signal(offset) == SHORT)
                    {
                     if(getVolSignal(offset) == SHORT)
                       {
                        signal = SHORT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                       }
                    }
                  else
                    {
                     signal = FLAT;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                    }
                 }
               else
                 {
                  signal = FLAT;
                  if(TotalOpenOrders() == 0)
                     iconHeight = PrintChartInformationIcon(iconHeight, 251, clrYellow,"Baseline disagree");
                 }
           }
         else
            if(getBaselineSignal(offset) == LONG && getBaselineSignal(offset + 1) == SHORT)//Baseline signal
              {
               if(baselineATRFilter == true)
                 {
                  if(Close[offset] - getBaselineValue(offset) < ATR)
                    {
                     if(use7CandleRule == true)
                       {
                        if(getC1Signal(offset) == LONG)
                          {
                           if(getCandlesSinceC1Signal(offset) < 7)
                             {
                              //OTHER ALGO PARTS
                              if(getC2Signal(offset) == LONG)
                                {
                                 if(getVolSignal(offset) == LONG)
                                   {
                                    signal = LONG;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                   }
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                }
                             }
                           else
                              if(getCandlesSinceC1Signal(offset) > 7)
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 146, clrMistyRose,"Bridge Too Far (7CR)");
                                }

                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrDodgerBlue,"C1 disagree");
                          }
                       }
                     else
                       {
                        if(getC1Signal(offset) == LONG)
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == LONG)
                             {
                              if(getVolSignal(offset) == LONG)
                                {
                                 signal = LONG;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrDodgerBlue,"C1 disagree");
                          }
                       }
                    }
                  else
                    {
                     signal = FLAT;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                    }
                 }
               else
                 {
                  if(use7CandleRule == true)
                    {
                     if(getC1Signal(offset) == LONG)
                       {
                        if(getCandlesSinceC1Signal(offset) < 7)
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == LONG)
                             {
                              if(getVolSignal(offset) == LONG)
                                {
                                 signal = LONG;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                           if(getCandlesSinceC1Signal(offset) > 7)
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 146, clrMistyRose,"Bridge Too Far (7CR)");
                             }

                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrDodgerBlue,"C1 disagree");
                       }
                    }
                  else
                    {
                     if(getC1Signal(offset) == LONG)
                       {
                        //OTHER ALGO PARTS
                        if(getC2Signal(offset) == LONG)
                          {
                           if(getVolSignal(offset) == LONG)
                             {
                              signal = LONG;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrDodgerBlue,"C1 disagree");
                       }
                    }
                 }
              }
            else
               if(getBaselineSignal(offset) == SHORT && getBaselineSignal(offset + 1) == LONG)//Baseline signal
                 {
                  if(baselineATRFilter == true)
                    {
                     if(getBaselineValue(offset) - Close[offset] < ATR)
                       {
                        if(use7CandleRule == true)
                          {
                           if(getC1Signal(offset) == SHORT)
                             {
                              if(getCandlesSinceC1Signal(offset) < 7)
                                {
                                 //OTHER ALGO PARTS
                                 if(getC2Signal(offset) == SHORT)
                                   {
                                    if(getVolSignal(offset) == SHORT)
                                      {
                                       signal = SHORT;
                                       if(TotalOpenOrders() == 0)
                                          iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                      }
                                    else
                                      {
                                       signal = FLAT;
                                       if(TotalOpenOrders() == 0)
                                          iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                      }
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                   }
                                }
                              else
                                 if(getCandlesSinceC1Signal(offset) > 7)
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 146, clrMistyRose,"Bridge Too Far (7CR)");
                                   }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrDodgerBlue,"C1 disagree");
                             }
                          }
                        else
                          {
                           if(getC1Signal(offset) == SHORT)
                             {
                              //OTHER ALGO PARTS
                              if(getC2Signal(offset) == SHORT)
                                {
                                 if(getVolSignal(offset) == SHORT)
                                   {
                                    signal = SHORT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                   }
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrDodgerBlue,"C1 disagree");
                             }
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                       }
                    }
                  else
                     if(use7CandleRule == true)
                       {
                        if(getC1Signal(offset) == SHORT)
                          {
                           if(getCandlesSinceC1Signal(offset) < 7)
                             {
                              //OTHER ALGO PARTS
                              if(getC2Signal(offset) == SHORT)
                                {
                                 if(getVolSignal(offset) == SHORT)
                                   {
                                    signal = SHORT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                   }
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                }
                             }
                           else
                              if(getCandlesSinceC1Signal(offset) > 7)
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 146, clrMistyRose,"Bridge Too Far (7CR)");
                                }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrDodgerBlue,"C1 disagree");
                          }
                       }
                     else
                       {
                        if(getC1Signal(offset) == SHORT)
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == SHORT)
                             {
                              if(getVolSignal(offset) == SHORT)
                                {
                                 signal = SHORT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrDodgerBlue,"C1 disagree");
                          }
                       }
                 }

      if(signal != FLAT)
        {
         if(TotalOpenOrders() == 0)
            iconHeight = PrintChartInformationIcon(iconHeight, 118, clrAntiqueWhite,"Standard Entry");
        }
     }

//pullback entry
   if(filterPullbacks == true)
     {
      // Check for 1 candle rule (last bar was a signal, and price has gotten better
      if(signal == FLAT)
        {
         if(barsSinceC1Signal == 1 && barsSinceBaselineSignal != 1) // OK last bar was a c1 signal
           {
            prevC1Signal = getC1Signal(offset + 1);
            baseDir = getBaselineSignal(offset);

            if(baseDir != prevC1Signal)
              {
               // OK baseline doesnt confirm, so ignore the signal
               prevC1Signal = FLAT;
              }

            if(prevC1Signal == LONG)
              {
               if(baselineATRFilter == true)
                 {
                  if(Close[offset] - getBaselineValue(offset) < ATR)
                    {
                     if(iClose(NULL, PERIOD_CURRENT,offset) < iClose(NULL, PERIOD_CURRENT,offset + 1))
                       {
                        //OTHER ALGO PARTS
                        if(getC2Signal(offset) == LONG)
                          {
                           if(getVolSignal(offset) == LONG)
                             {
                              signal = prevC1Signal;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                          }
                       }
                     else
                       {
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                       }
                    }
                  else
                    {
                     signal = FLAT;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                    }
                 }
               else
                 {
                  if(iClose(NULL, PERIOD_CURRENT,offset) < iClose(NULL, PERIOD_CURRENT,offset + 1))
                    {
                     //OTHER ALGO PARTS
                     if(getC2Signal(offset) == LONG)
                       {
                        if(getVolSignal(offset) == LONG)
                          {
                           signal = prevC1Signal;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                       }
                    }
                  else
                    {
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                    }
                 }
              }
            else
               if(prevC1Signal == SHORT)
                 {
                  if(baselineATRFilter == true)
                    {
                     if(getBaselineValue(offset) - Close[offset] < ATR)
                       {
                        if(iClose(NULL, PERIOD_CURRENT,offset) > iClose(NULL, PERIOD_CURRENT,offset + 1))
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == SHORT)
                             {
                              if(getVolSignal(offset) == SHORT)
                                {
                                 signal = prevC1Signal;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                          {
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                       }
                    }
                  else
                    {
                     if(iClose(NULL, PERIOD_CURRENT,offset) > iClose(NULL, PERIOD_CURRENT,offset + 1))
                       {
                        //OTHER ALGO PARTS
                        if(getC2Signal(offset) == SHORT)
                          {
                           if(getVolSignal(offset) == SHORT)
                             {
                              signal = prevC1Signal;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                          }
                       }
                     else
                       {
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                       }
                    }
                 }
           }
         else
            if(barsSinceBaselineSignal == 1 && barsSinceC1Signal != 1) // OK last bar was a baseline signal
              {
               prevBaselineSignal = getBaselineSignal(offset + 1);
               c1Dir = getC1Signal(offset);

               if(c1Dir != prevBaselineSignal)
                 {
                  // OK C1 doesnt confirm, so ignore the signal
                  prevBaselineSignal = FLAT;
                 }

               if(prevBaselineSignal == LONG)
                 {
                  if(baselineATRFilter == true)
                    {
                     if(Close[offset] - getBaselineValue(offset) < ATR)
                       {
                        if(iClose(NULL, PERIOD_CURRENT,offset) < iClose(NULL, PERIOD_CURRENT,offset + 1))
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == LONG)
                             {
                              if(getVolSignal(offset) == LONG)
                                {
                                 signal = prevC1Signal;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                          {
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                       }
                    }
                  else
                    {
                     if(iClose(NULL, PERIOD_CURRENT,offset) < iClose(NULL, PERIOD_CURRENT,offset + 1))
                       {
                        //OTHER ALGO PARTS
                        if(getC2Signal(offset) == LONG)
                          {
                           if(getVolSignal(offset) == LONG)
                             {
                              signal = prevBaselineSignal;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                          }
                       }
                     else
                       {
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                       }
                    }
                 }
               else
                  if(prevBaselineSignal == SHORT)
                    {
                     if(baselineATRFilter == true)
                       {
                        if(getBaselineValue(offset) - Close[offset] < ATR)
                          {
                           if(iClose(NULL, PERIOD_CURRENT,offset) > iClose(NULL, PERIOD_CURRENT,offset + 1))
                             {
                              //OTHER ALGO PARTS
                              if(getC2Signal(offset) == SHORT)
                                {
                                 if(getVolSignal(offset) == SHORT)
                                   {
                                    signal = prevC1Signal;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                   }
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                }
                             }
                           else
                             {
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                          }
                       }
                     else
                       {
                        if(iClose(NULL, PERIOD_CURRENT,offset) > iClose(NULL, PERIOD_CURRENT,offset + 1))
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == SHORT)
                             {
                              if(getVolSignal(offset) == SHORT)
                                {
                                 signal = prevBaselineSignal;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                          {
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                          }
                       }
                    }
              }
            else
               if(barsSinceBaselineSignal == 1 && barsSinceC1Signal == 1) // OK last bar was both a c1 and baseline signal (other algo parts were not ready)
                 {
                  prevBaselineSignal = getBaselineSignal(offset + 1);
                  prevC1Signal = getC1Signal(offset +1);

                  if(prevC1Signal != prevBaselineSignal)
                    {
                     // OK C1 and baseline don't confirm, so ignore the signal
                     prevBaselineSignal = FLAT;
                     prevC1Signal = FLAT;
                    }

                  if(prevBaselineSignal == LONG && prevC1Signal == LONG)
                    {
                     if(baselineATRFilter == true)
                       {
                        if(Close[offset] - getBaselineValue(offset) < ATR)
                          {
                           if(iClose(NULL, PERIOD_CURRENT,offset) < iClose(NULL, PERIOD_CURRENT,offset + 1))
                             {
                              //OTHER ALGO PARTS
                              if(getC2Signal(offset) == LONG)
                                {
                                 if(getVolSignal(offset) == LONG)
                                   {
                                    signal = prevC1Signal;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                   }
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                }
                             }
                           else
                             {
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                          }
                       }
                     else
                       {
                        if(iClose(NULL, PERIOD_CURRENT,offset) < iClose(NULL, PERIOD_CURRENT,offset + 1))
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == LONG)
                             {
                              if(getVolSignal(offset) == LONG)
                                {
                                 signal = prevBaselineSignal;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                          {
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                          }
                       }
                    }
                  else
                     if(prevBaselineSignal == SHORT && prevC1Signal == SHORT)
                       {
                        if(baselineATRFilter == true)
                          {
                           if(getBaselineValue(offset) - Close[offset] < ATR)
                             {
                              if(iClose(NULL, PERIOD_CURRENT,offset) > iClose(NULL, PERIOD_CURRENT,offset + 1))
                                {
                                 //OTHER ALGO PARTS
                                 if(getC2Signal(offset) == SHORT)
                                   {
                                    if(getVolSignal(offset) == SHORT)
                                      {
                                       signal = prevBaselineSignal;
                                       if(TotalOpenOrders() == 0)
                                          iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                      }
                                    else
                                      {
                                       signal = FLAT;
                                       if(TotalOpenOrders() == 0)
                                          iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                      }
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                   }
                                }
                              else
                                {
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                             }
                          }
                        else
                          {
                           if(iClose(NULL, PERIOD_CURRENT,offset) > iClose(NULL, PERIOD_CURRENT,offset + 1))
                             {
                              //OTHER ALGO PARTS
                              if(getC2Signal(offset) == SHORT)
                                {
                                 if(getVolSignal(offset) == SHORT)
                                   {
                                    signal = prevBaselineSignal;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                   }
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                }
                             }
                           else
                             {
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrMistyRose,"1 Candle Rule stoped because no pullback");
                             }
                          }
                       }
                 }

         if(signal != FLAT)
           {
            if(TotalOpenOrders() == 0)
               iconHeight = PrintChartInformationIcon(iconHeight, 140, clrAntiqueWhite,"Pullback Entry");
           }
        }
     }


//1 Candle rule entry
   if(filterPullbacks == false)
     {
      if(signal == FLAT)
        {
         if(barsSinceC1Signal == 1 && barsSinceBaselineSignal != 1) // OK last bar was a c1 signal
           {
            prevC1Signal = getC1Signal(offset + 1);
            baseDir = getBaselineSignal(offset);

            if(baseDir != prevC1Signal)
              {
               // OK baseline doesnt confirm, so ignore the signal
               prevC1Signal = FLAT;
              }

            if(prevC1Signal == LONG)
              {
               if(baselineATRFilter == true)
                 {
                  if(Close[offset] - getBaselineValue(offset) < ATR)
                    {
                     //OTHER ALGO PARTS
                     if(getC2Signal(offset) == LONG)
                       {
                        if(getVolSignal(offset) == LONG)
                          {
                           signal = prevC1Signal;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                       }
                    }
                  else
                    {
                     signal = FLAT;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                    }
                 }
               else
                 {
                  //OTHER ALGO PARTS
                  if(getC2Signal(offset) == LONG)
                    {
                     if(getVolSignal(offset) == LONG)
                       {
                        signal = prevC1Signal;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                       }
                    }
                  else
                    {
                     signal = FLAT;
                     if(TotalOpenOrders() == 0)
                        iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                    }
                 }
              }
            else
               if(prevC1Signal == SHORT)
                 {
                  if(baselineATRFilter == true)
                    {
                     if(getBaselineValue(offset) - Close[offset] < ATR)
                       {
                        //OTHER ALGO PARTS
                        if(getC2Signal(offset) == SHORT)
                          {
                           if(getVolSignal(offset) == SHORT)
                             {
                              signal = prevC1Signal;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                       }
                    }
                  else
                    {
                     //OTHER ALGO PARTS
                     if(getC2Signal(offset) == SHORT)
                       {
                        if(getVolSignal(offset) == SHORT)
                          {
                           signal = prevC1Signal;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                       }
                    }
                 }
           }
         else
            if(barsSinceBaselineSignal == 1 && barsSinceC1Signal != 1) // OK last bar was a baseline signal
              {
               prevBaselineSignal = getBaselineSignal(offset + 1);
               c1Dir = getC1Signal(offset);

               if(c1Dir != prevBaselineSignal)
                 {
                  // OK C1 doesnt confirm, so ignore the signal
                  prevBaselineSignal = FLAT;
                 }

               if(prevBaselineSignal == LONG)
                 {
                  if(baselineATRFilter == true)
                    {
                     if(Close[offset] - getBaselineValue(offset) < ATR)
                       {
                        //OTHER ALGO PARTS
                        if(getC2Signal(offset) == LONG)
                          {
                           if(getVolSignal(offset) == LONG)
                             {
                              signal = prevC1Signal;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                       }
                    }
                  else
                    {
                     //OTHER ALGO PARTS
                     if(getC2Signal(offset) == LONG)
                       {
                        if(getVolSignal(offset) == LONG)
                          {
                           signal = prevBaselineSignal;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                          }
                       }
                     else
                       {
                        signal = FLAT;
                        if(TotalOpenOrders() == 0)
                           iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                       }
                    }
                 }
               else
                  if(prevBaselineSignal == SHORT)
                    {
                     if(baselineATRFilter == true)
                       {
                        if(getBaselineValue(offset) - Close[offset] < ATR)
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == SHORT)
                             {
                              if(getVolSignal(offset) == SHORT)
                                {
                                 signal = prevC1Signal;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                          }
                       }
                     else
                       {
                        //OTHER ALGO PARTS
                        if(getC2Signal(offset) == SHORT)
                          {
                           if(getVolSignal(offset) == SHORT)
                             {
                              signal = prevBaselineSignal;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                          }
                       }
                    }
              }
            else
               if(barsSinceBaselineSignal == 1 && barsSinceC1Signal == 1) // OK last bar was both a c1 and baseline signal (other algo parts were not ready)
                 {
                  prevBaselineSignal = getBaselineSignal(offset + 1);
                  prevC1Signal = getC1Signal(offset +1);

                  if(prevC1Signal != prevBaselineSignal)
                    {
                     // OK C1 and baseline don't confirm, so ignore the signal
                     prevBaselineSignal = FLAT;
                     prevC1Signal = FLAT;
                    }

                  if(prevBaselineSignal == LONG && prevC1Signal == LONG)
                    {
                     if(baselineATRFilter == true)
                       {
                        if(Close[offset] - getBaselineValue(offset) < ATR)
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == LONG)
                             {
                              if(getVolSignal(offset) == LONG)
                                {
                                 signal = prevC1Signal;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                          }
                       }
                     else
                       {
                        //OTHER ALGO PARTS
                        if(getC2Signal(offset) == LONG)
                          {
                           if(getVolSignal(offset) == LONG)
                             {
                              signal = prevBaselineSignal;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                             }
                          }
                        else
                          {
                           signal = FLAT;
                           if(TotalOpenOrders() == 0)
                              iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                          }
                       }
                    }
                  else
                     if(prevBaselineSignal == SHORT && prevC1Signal == SHORT)
                       {
                        if(baselineATRFilter == true)
                          {
                           if(getBaselineValue(offset) - Close[offset] < ATR)
                             {
                              //OTHER ALGO PARTS
                              if(getC2Signal(offset) == SHORT)
                                {
                                 if(getVolSignal(offset) == SHORT)
                                   {
                                    signal = prevC1Signal;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                   }
                                 else
                                   {
                                    signal = FLAT;
                                    if(TotalOpenOrders() == 0)
                                       iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                   }
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 89, clrMistyRose,"Baseline distance more than 1 ATR");
                             }
                          }
                        else
                          {
                           //OTHER ALGO PARTS
                           if(getC2Signal(offset) == SHORT)
                             {
                              if(getVolSignal(offset) == SHORT)
                                {
                                 signal = prevBaselineSignal;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                                }
                              else
                                {
                                 signal = FLAT;
                                 if(TotalOpenOrders() == 0)
                                    iconHeight = PrintChartInformationIcon(iconHeight, 251, clrBlueViolet,"Volume disagree");
                                }
                             }
                           else
                             {
                              signal = FLAT;
                              if(TotalOpenOrders() == 0)
                                 iconHeight = PrintChartInformationIcon(iconHeight, 251, clrCrimson,"C2 disagree");
                             }
                          }
                       }
                 }

         if(signal != FLAT)
           {
            if(TotalOpenOrders() == 0)
               iconHeight = PrintChartInformationIcon(iconHeight, 140, clrAntiqueWhite,"1 Candle Rule Entry");
           }
        }
     }

   return signal;
  }
//+------------------------------------------------------------------+
