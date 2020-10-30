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


input string MM = "===========================MONEY MANAGEMENT===========================";
extern bool                scaleOut = true;
extern bool                use7CandleRule = true;
extern bool                filterPullbacks = false;
extern bool                baselineATRFilter = false;
extern bool                baselineCrossExit = true;
extern double              RiskPercent=1.0;
extern double              takeProfitPercent = 1.0;
extern double              stoplossPercent = 1.5;
extern int                 ATR_Period = 14;
extern bool                LimitCurrencyRisk = true;     //Limit Risk per Currency (not per Trade)
input int                  signalCheckingShift = 0; //On what candle to check for signal (0 = current candle, 1 = previous etc)



input string OTHER = "===========================OTHER SETTINGS===========================";
enum                       eAlgoTestType {FullAlgo, BL, BL_C1, BL_C1_C2, BL_C1_C2_VOL, BL_C1_C2_EXIT};
extern eAlgoTestType       algoTestType = FullAlgo;
extern bool                showInformationIcons = true;
extern bool                useForwardBacktester = true;
input int                  MagicNumber1 = 1090608;
input int                  MagicNumber2 = 1090609;





////////////////////////////////////LOCAL VARIABLES/////////////////////////////////////////
string                     Base, Quote;
int                        tickets[];
double                     ATR = NULL;
double                     Lots;
MqlDateTime                time_to_open;
bool                       exitAgree = false;
enum                       eSignal {FLAT, LONG, SHORT};
bool                       newbar = false;
string                     signalToSend;
int                        ticket1 = -1;
int                        ticket1type = -1;
int                        ticket2 = -1;
int                        ticket2type = -1;
bool                       finished = false;
double                     startingBalance = 0;
double                     leftTime;
string                     sTime;
// Prepare our context and socket
Context                    context("NNFX");
Socket                     socket(context,ZMQ_REQ);
Socket                     sub(context,ZMQ_SUB);
////////////////////////////////////////////////////////////////////////////////////////////
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(useForwardBacktester)
     {
      Print("Connecting to server…");
      socket.connect("tcp://127.0.0.1:5555");
      sub.connect("tcp://127.0.0.1:6666");
      sub.subscribe(Symbol());

      finished = false;
      startingBalance = AccountBalance();
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(useForwardBacktester)
     {
      finished = true;
      string msg;
      string tempString;
      string stats = getStats();
      double bal = 0;
      double equity = 0;
      bal = ((AccountBalance() - startingBalance) / startingBalance) * 100;
      equity = ((AccountEquity() - startingBalance) / startingBalance) * 100;

      tempString = StringFormat("{\"symbol\": \"%s\",", _Symbol);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"date\": \"%s\",", (string)TimeCurrent());
      StringAdd(msg, tempString);
      tempString = StringFormat("\"trade1\": \"%s\",", (string)-1);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"trade2\": \"%s\",", (string)-1);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"open_orders\": \"%s\",", (string)0);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"finished\": \"%s\",", (string)finished);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"order1\": %s,", (string)0);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"order2\": %s,", (string)0);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"balance\": %.2g,", bal);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"equity\": %.2g,", equity);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"stats\": %s,", stats);
      StringAdd(msg, tempString);
      tempString = StringFormat("\"signal\": \"%s\"}", (string)0);
      StringAdd(msg, tempString);


      ZmqMsg reply;
      ZmqMsg signalMsg(msg);
      socket.send(signalMsg,true);

      while(!IsStopped())
        {
         if(socket.recv(reply,true))
           {
            // OK message sent OK lets read the reply
            Print("Waiting for OK");

            if(reply.getData() == "OK")
              {
               Print("Got OK");
               break;
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

   Print("FINISHED");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   leftTime = (Period() * 60) - (TimeCurrent() - Time[0]);

//Set initial signal to flat
   eSignal signal = FLAT;


//Check if this is a new bar
   if(NewBar() == true)
      newbar = true;

   if(leftTime < 25)
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



         //set correct value for exitAgree bool
         if(checkPendingOrdersSell() && exitAgree == false)
           {
            if(getExitSignal(signalCheckingShift) == LONG)
              {
               exitAgree = true;
              }
            else
              {
               exitAgree = false;
              }
           }

         if(checkPendingOrdersBuy() && exitAgree == false)
           {
            if(getExitSignal(signalCheckingShift) == SHORT)
              {
               exitAgree = true;
              }
            else
              {
               exitAgree = false;
              }
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


         //TRADE ONLY DURING LONDON AND NEW YORK SESSIONS
         if(Hour() >= 8 && Hour() <= 21)
           {
            //Get the current algo signal
            if(algoTestType == FullAlgo)
               signal = getSignal(signalCheckingShift);
            else
               if(algoTestType == BL)
                  signal = getBLSignal(signalCheckingShift);
               else
                  if(algoTestType == BL_C1)
                     signal = getBLC1Signal(signalCheckingShift);

            //Placing orders
            if(signal == LONG)
              {
               //check if exit indi agrees or not and save it in a bool
               if(getExitSignal(signalCheckingShift) == SHORT)
                 {
                  exitAgree = true;

                  if(useForwardBacktester)
                     signalToSend = "LONG";
                  else
                    {
                     if(TotalOpenOrders() == 0)
                        buyOrder(ATR);
                    }
                 }
               else
                  if(getExitSignal(signalCheckingShift) == LONG)
                    {
                     exitAgree = false;

                     if(useForwardBacktester)
                        signalToSend = "LONG";
                     else
                       {
                        if(TotalOpenOrders() == 0)
                           buyOrder(ATR);
                       }
                    }
              }
            else
               if(signal == SHORT)
                 {
                  //check if exit indi agrees or not and save it in a bool
                  if(getExitSignal(signalCheckingShift) == LONG)//exit
                    {
                     exitAgree = true;

                     if(useForwardBacktester)
                        signalToSend = "SHORT";
                     else
                       {
                        if(TotalOpenOrders() == 0)
                           sellOrder(ATR);
                       }
                    }
                  else
                     if(getExitSignal(signalCheckingShift) == SHORT)
                       {
                        exitAgree = false;

                        if(useForwardBacktester)
                           signalToSend = "SHORT";
                        else
                          {
                           if(TotalOpenOrders() == 0)
                              sellOrder(ATR);
                          }
                       }
                 }
               else
                  if(signal == FLAT)
                    {
                     signalToSend = "FLAT";
                    }


            ///////////////////////////////////////////////////////////////////////////////////
            //SHIT TO SEND
            //-symbol
            //-date
            //-atr
            //-total open orders
            //-order1
            //-order2
            //-signal
            //-finished or not

            if(useForwardBacktester)
              {
               Print("Sending signal information");
               string tempString;
               string msg;
               int _signal = 0;

               GetTicketInfo();

               if(signalToSend == "FLAT")
                  _signal = 0;
               else
                  if(signalToSend == "LONG")
                     _signal = 1;
                  else
                     if(signalToSend == "SHORT")
                        _signal = 2;

               //send trade after it's finished
               string order1 = "0";
               string order2 = "0";

               if(ticket1type == -1)
                  order1 = SelectMostRecentClosed(MagicNumber1);

               if(ticket2type == -1)
                  order2 = SelectMostRecentClosed(MagicNumber2);

               double bal = 0;
               double equity = 0;
               bal = ((AccountBalance() - startingBalance) / startingBalance) * 100;
               equity = ((AccountEquity() - startingBalance) / startingBalance) * 100;


               tempString = StringFormat("{\"symbol\": \"%s\",", _Symbol);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"date\": \"%s\",", (string)TimeCurrent());
               StringAdd(msg, tempString);
               tempString = StringFormat("\"atr\": \"%s\",", (string)ATR);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"trade1\": \"%s\",", (string)ticket1type);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"trade2\": \"%s\",", (string)ticket2type);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"open_orders\": \"%s\",", (string)TotalOpenOrders());
               StringAdd(msg, tempString);
               tempString = StringFormat("\"finished\": \"%s\",", (string)finished);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"order1\": %s,", order1);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"order2\": %s,", order2);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"balance\": %.2g,", bal);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"equity\": %.2g,", equity);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"stats\": %s,", (string)0);
               StringAdd(msg, tempString);
               tempString = StringFormat("\"signal\": \"%s\"}", (string)_signal);
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
                        Print("Waiting for signal info");
                        if(sub.recv(sigInfo))
                          {
                           Print("Got signal info");
                           string _msg = sigInfo.getData();
                           string msg_array[];
                           StringSplit(_msg,' ',msg_array);
                           string data = msg_array[1];

                           if(data == "HOLD")
                             {
                              Print("HOLD TF UP, RESEND CURRENT SIGNAL AGAIN");
                              Print(msg);
                              ZmqMsg signalMsg(msg);

                              socket.send(signalMsg, true);

                              //We have to stay on the same candle, send msg again and wait for instructions
                              while(!IsStopped())
                                {
                                 if(socket.recv(reply, true))
                                   {
                                    //OK message sent OK lets read reply
                                    Print("Waiting for hold OK");
                                    if(reply.getData() == "OK")
                                      {
                                       Print("Got hold OK");
                                       if(sub.recv(sigInfo))
                                         {
                                          Print("Got hold signal info");
                                          string _msg = sigInfo.getData();
                                          string msg_array[];
                                          StringSplit(_msg,' ',msg_array);
                                          string data = msg_array[1];

                                          if(data == "HOLD")
                                            {
                                             Print("HOLD TF UP, RESEND CURRENT SIGNAL AGAIN");
                                             Print(msg);
                                             ZmqMsg signalMsg(msg);

                                             socket.send(signalMsg, true);
                                            }
                                          else
                                             break;
                                         }
                                      }
                                    else
                                      {
                                       if(IsTesting() || IsOptimization())
                                         {
                                          SleepEx(100, false);
                                         }
                                       else
                                         {
                                          Sleep(100);
                                         }
                                      }
                                   }
                                }
                              break;
                             }
                           else
                              if(data == "LONG")
                                {
                                 Print("LONG ORDER");
                                 buyOrder(ATR);
                                 break;
                                }
                              else
                                 if(data == "SHORT")
                                   {
                                    Print("SHORT ORDER");
                                    sellOrder(ATR);
                                    break;
                                   }
                                 else
                                    if(data == "NEXT")
                                      {
                                       Print("NEXT CANDLE");
                                       break;
                                      }
                                    else
                                       if(data == "NEWS_CLOSE")
                                         {
                                          Print("NEWS");

                                          if(checkPendingOrdersBuy())
                                             CloseOrders("OP_BUY");
                                          else
                                             if(checkPendingOrdersSell())
                                                CloseOrders("OP_SELL");

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
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

input string INDICATORS = "===========================INDICATORS===========================";
#include <Baseline.mqh>
#include <Confirmation_1.mqh>
#include <Confirmation_2.mqh>
#include <Vol.mqh>
#include <Exit.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getBaselineSignal(int offset)
  {
   eSignal _signal = FLAT;
   double baseline = getBaselineValue(offset);


   if(Close[offset] >= baseline)
      _signal = LONG;
   else
      if(Close[offset] <= baseline)
         _signal = SHORT;


   return _signal;
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
      if(OrderMagicNumber() == MagicNumber1 || OrderMagicNumber() == MagicNumber2)
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
void GetTicketInfo()
  {
   int total = OrdersTotal();
   ticket1 = -1;
   ticket1type = -1;
   ticket2 = -1;
   ticket2type = -1;

   for(int cnt = 0; cnt < total; cnt++)
     {
      if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)==false)
         break;

      if(OrderType() <= OP_SELL && OrderSymbol() == Symbol())
        {
         if(OrderMagicNumber() == MagicNumber1)
           {
            ticket1 = OrderTicket();
            ticket1type = OrderType();
           }
         if(OrderMagicNumber() == MagicNumber2)
           {
            ticket2 = OrderTicket();
            ticket2type = OrderType();
           }
        }
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

      if((OrderMagicNumber() == MagicNumber1 || OrderMagicNumber() == MagicNumber2) && OrderSymbol() == _Symbol)
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
         if((OrderMagicNumber() == MagicNumber1 || OrderMagicNumber() == MagicNumber2) && OrderSymbol() == _Symbol)
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
         if((OrderMagicNumber() == MagicNumber1 || OrderMagicNumber() == MagicNumber2) && OrderSymbol() == _Symbol)
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
   double balance = NormalizeDouble(AccountBalance(), 2);

   if(scaleOut == true)
     {
      //Open Buy Order
      int _ticket1 = OrderSend(_Symbol,OP_BUY,Lots,Ask,10,0,0,(string)balance,MagicNumber1);
      if(_ticket1<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Buy Order
      bool res1 = OrderModify(_ticket1,OrderOpenPrice(),Ask-(stoplossPercent * atr_val),Ask+(atr_val * takeProfitPercent),0,Blue);
      if(!res1)
        {
         Print("Error in OrderModify. Error code=",GetLastError());
        }


      //order 2
      int _ticket2 = OrderSend(_Symbol,OP_BUY,Lots,Ask,10,0,0,(string)balance,MagicNumber2);
      if(_ticket2<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Buy Order
      bool res2 = OrderModify(_ticket2,OrderOpenPrice(),Ask-(stoplossPercent * atr_val),0,0,Blue);
      if(!res2)
        {
         Print("Error in OrderModify. Error code=",GetLastError());
        }
     }
   else
     {
      //Open Buy Order
      int _ticket1 = OrderSend(_Symbol,OP_BUY,Lots,Ask,10,0,0,(string)balance,MagicNumber1);
      if(_ticket1<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Buy Order
      bool res1 = OrderModify(_ticket1,OrderOpenPrice(),Ask-(stoplossPercent * atr_val),Ask+(atr_val * takeProfitPercent),0,Blue);
      if(!res1)
        {
         Print("Error in OrderModify. Error code=",GetLastError());
        }


      //order 2
      int _ticket2 = OrderSend(_Symbol,OP_BUY,Lots,Ask,10,0,0,(string)balance,MagicNumber2);
      if(_ticket2<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Buy Order
      bool res2 = OrderModify(_ticket2,OrderOpenPrice(),Ask-(stoplossPercent * atr_val),Ask+(atr_val * takeProfitPercent),0,Blue);
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
   double balance = NormalizeDouble(AccountBalance(), 2);

   if(scaleOut == true)
     {
      //Open Sell Order
      int _ticket1 = OrderSend(_Symbol,OP_SELL,Lots,Bid,10,0,0,(string)balance,MagicNumber1);
      if(_ticket1<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Sell Order
      bool res1 = OrderModify(_ticket1,OrderOpenPrice(),Bid+(stoplossPercent * atr_val),Bid-(takeProfitPercent * atr_val),0,Blue);
      if(!res1)
        {
         Print("Error in OrderModify. Error code=",GetLastError());
        }


      //order 2
      int _ticket2 = OrderSend(_Symbol,OP_SELL,Lots,Bid,10,0,0,(string)balance,MagicNumber2);
      if(_ticket2<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Sell Order
      bool res2 = OrderModify(_ticket2,OrderOpenPrice(),Bid+(stoplossPercent * atr_val),0,0,Blue);
      if(!res2)
        {
         Print("Error in OrderModify. Error code=",GetLastError());
        }
     }
   else
     {
      //Open Sell Order
      int _ticket1 = OrderSend(_Symbol,OP_SELL,Lots,Bid,10,0,0,(string)balance,MagicNumber1);
      if(_ticket1<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Sell Order
      bool res1 = OrderModify(_ticket1,OrderOpenPrice(),Bid+(stoplossPercent * atr_val),Bid-(takeProfitPercent * atr_val),0,Blue);
      if(!res1)
        {
         Print("Error in OrderModify. Error code=",GetLastError());
        }


      //order 2
      int _ticket2 = OrderSend(_Symbol,OP_SELL,Lots,Bid,10,0,0,(string)balance,MagicNumber2);
      if(_ticket2<0)
        {
         Print("OrderSend failed with error #",GetLastError());
        }

      // Modify Sell Order
      bool res2 = OrderModify(_ticket2,OrderOpenPrice(),Bid+(stoplossPercent * atr_val),Bid-(takeProfitPercent * atr_val),0,Blue);
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

      if((OrderMagicNumber() == MagicNumber1 || OrderMagicNumber() == MagicNumber2) && OrderSymbol() == _Symbol)
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
//|                                                                  |
//+------------------------------------------------------------------+
string SelectMostRecentClosed(int magic_number)
  {
   string order1 = "0";
   string tmpOrder1;
   int _ticket = -1;
   datetime close_time = 0;

   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)
         && OrderSymbol()==_Symbol
         && (OrderMagicNumber() == magic_number)
         && OrderCloseTime() > close_time)
        {
         _ticket = OrderTicket();
         close_time = OrderCloseTime();
        }
     }

   bool closed = OrderSelect(_ticket,SELECT_BY_TICKET);
   if(closed)
     {
      order1 = "";

      tmpOrder1 = StringFormat("{\"ticket\": \"%s\",", (string)OrderTicket());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"symbol\": \"%s\",", Symbol());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"balance\": \"%s\",", (string)OrderComment());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"profit\": \"%s\",", (string)(OrderProfit() + OrderSwap() + OrderCommission()));
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"type\": \"%s\",", (string)OrderType());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"lots\": \"%s\",", (string)OrderLots());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"open_price\": \"%s\",", (string)OrderOpenPrice());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"open_date\": \"%s\",", (string)OrderOpenTime());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"close_price\": \"%s\",", (string)OrderClosePrice());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"close_date\": \"%s\",", (string)OrderCloseTime());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"tp\": \"%s\",", (string)OrderTakeProfit());
      StringAdd(order1, tmpOrder1);
      tmpOrder1 = StringFormat("\"sl\": \"%s\"}", (string)OrderStopLoss());
      StringAdd(order1, tmpOrder1);

      return order1;
     }

   return order1;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string getStats()
  {
   string tmp;
   string stats;

   double winrate = NormalizeDouble((TesterStatistics(STAT_PROFIT_TRADES) / (TesterStatistics(STAT_PROFIT_TRADES) + TesterStatistics(STAT_LOSS_TRADES))) * 100, 2);

   tmp = StringFormat("{\"STAT_INITIAL_DEPOSIT\": \"%s\",", (string)TesterStatistics(STAT_INITIAL_DEPOSIT));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_PROFIT\": \"%s\",", (string)TesterStatistics(STAT_PROFIT));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_GROSS_PROFIT\": \"%s\",", (string)TesterStatistics(STAT_GROSS_PROFIT));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_WINRATE\": \"%s\",", (string)winrate);
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_GROSS_LOSS\": \"%s\",", (string)TesterStatistics(STAT_GROSS_LOSS));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_MAX_PROFITTRADE\": \"%s\",", (string)TesterStatistics(STAT_MAX_PROFITTRADE));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_MAX_LOSSTRADE\": \"%s\",", (string)TesterStatistics(STAT_MAX_LOSSTRADE));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_CONPROFITMAX\": \"%s\",", (string)TesterStatistics(STAT_CONPROFITMAX));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_CONPROFITMAX_TRADES\": \"%s\",", (string)TesterStatistics(STAT_CONPROFITMAX_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_MAX_CONWINS\": \"%s\",", (string)TesterStatistics(STAT_MAX_CONWINS));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_MAX_CONPROFIT_TRADES\": \"%s\",", (string)TesterStatistics(STAT_MAX_CONPROFIT_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_CONLOSSMAX\": \"%s\",", (string)TesterStatistics(STAT_CONLOSSMAX));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_CONLOSSMAX_TRADES\": \"%s\",", (string)TesterStatistics(STAT_CONLOSSMAX_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_MAX_CONLOSSES\": \"%s\",", (string)TesterStatistics(STAT_MAX_CONLOSSES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_MAX_CONLOSS_TRADES\": \"%s\",", (string)TesterStatistics(STAT_MAX_CONLOSS_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_BALANCEMIN\": \"%s\",", (string)TesterStatistics(STAT_BALANCEMIN));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_BALANCE_DD\": \"%s\",", (string)TesterStatistics(STAT_BALANCE_DD));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_BALANCEDD_PERCENT\": \"%s\",", (string)TesterStatistics(STAT_BALANCEDD_PERCENT));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_BALANCE_DDREL_PERCENT\": \"%s\",", (string)TesterStatistics(STAT_BALANCE_DDREL_PERCENT));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_BALANCE_DD_RELATIVE\": \"%s\",", (string)TesterStatistics(STAT_BALANCE_DD_RELATIVE));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_EQUITYMIN\": \"%s\",", (string)TesterStatistics(STAT_EQUITYMIN));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_EQUITY_DD\": \"%s\",", (string)TesterStatistics(STAT_EQUITY_DD));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_EQUITYDD_PERCENT\": \"%s\",", (string)TesterStatistics(STAT_EQUITYDD_PERCENT));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_EQUITY_DDREL_PERCENT\": \"%s\",", (string)TesterStatistics(STAT_EQUITY_DDREL_PERCENT));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_EQUITY_DD_RELATIVE\": \"%s\",", (string)TesterStatistics(STAT_EQUITY_DD_RELATIVE));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_EXPECTED_PAYOFF\": \"%s\",", (string)TesterStatistics(STAT_EXPECTED_PAYOFF));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_PROFIT_FACTOR\": \"%s\",", (string)TesterStatistics(STAT_PROFIT_FACTOR));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_MIN_MARGINLEVEL\": \"%s\",", (string)TesterStatistics(STAT_MIN_MARGINLEVEL));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_TRADES\": \"%s\",", (string)TesterStatistics(STAT_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_PROFIT_TRADES\": \"%s\",", (string)TesterStatistics(STAT_PROFIT_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_LOSS_TRADES\": \"%s\",", (string)TesterStatistics(STAT_LOSS_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_SHORT_TRADES\": \"%s\",", (string)TesterStatistics(STAT_SHORT_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_LONG_TRADES\": \"%s\",", (string)TesterStatistics(STAT_LONG_TRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_PROFIT_SHORTTRADES\": \"%s\",", (string)TesterStatistics(STAT_PROFIT_SHORTTRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_PROFIT_LONGTRADES\": \"%s\",", (string)TesterStatistics(STAT_PROFIT_LONGTRADES));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_PROFITTRADES_AVGCON\": \"%s\",", (string)TesterStatistics(STAT_PROFITTRADES_AVGCON));
   StringAdd(stats, tmp);
   tmp = StringFormat("\"STAT_LOSSTRADES_AVGCON\": \"%s\"}", (string)TesterStatistics(STAT_LOSSTRADES_AVGCON));
   StringAdd(stats, tmp);

   return stats;
  }
//+------------------------------------------------------------------+
//|                                                                  |
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
eSignal getBLSignal(int offset)
  {
   eSignal signal = FLAT;
   double iconHeight = High[offset] + 0.005;

   if(getBaselineSignal(offset) == LONG && getBaselineSignal(offset + 1) == SHORT)
     {
      signal = LONG;
      if(TotalOpenOrders() == 0)
         iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
     }
   else
      if(getBaselineSignal(offset) == SHORT && getBaselineSignal(offset + 1) == LONG)
        {
         signal = SHORT;
         if(TotalOpenOrders() == 0)
            iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
        }

   return signal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
eSignal getBLC1Signal(int offset)
  {
   eSignal signal = FLAT;
   double iconHeight = High[offset] + 0.005;

   if(getC1Signal(offset) == LONG && getC1Signal(offset + 1) == SHORT)
     {
      if(getBaselineSignal(offset) == LONG)
        {
         signal = LONG;
         if(TotalOpenOrders() == 0)
            iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
        }
     }
   else
      if(getC1Signal(offset) == SHORT && getC1Signal(offset + 1) == LONG)
        {
         if(getBaselineSignal(offset) == SHORT)
           {
            signal = SHORT;
            if(TotalOpenOrders() == 0)
               iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
           }
        }
      else
         if(getBaselineSignal(offset) == LONG && getBaselineSignal(offset + 1) == SHORT)
           {
            if(getC1Signal(offset) == LONG)
              {
               signal = LONG;
               if(TotalOpenOrders() == 0)
                  iconHeight = PrintChartInformationIcon(iconHeight, 221, clrBlue,"BUY");
              }
           }
         else
            if(getBaselineSignal(offset) == SHORT && getBaselineSignal(offset + 1) == LONG)
              {
               if(getC1Signal(offset) == SHORT)
                 {
                  signal = SHORT;
                  if(TotalOpenOrders() == 0)
                     iconHeight = PrintChartInformationIcon(iconHeight, 222, clrRed,"SELL");
                 }
              }

   return signal;
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
                                       iconHeight = PrintChartInformationIcon(iconHeight, 221, clrYellow,"BUY");
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
                                    iconHeight = PrintChartInformationIcon(iconHeight, 221, clrYellow,"BUY");
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
                                    iconHeight = PrintChartInformationIcon(iconHeight, 221, clrYellow,"BUY");
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
                                 iconHeight = PrintChartInformationIcon(iconHeight, 221, clrYellow,"BUY");
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
                                          iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                 iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                    iconHeight = PrintChartInformationIcon(iconHeight, 221, clrYellow,"BUY");
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
                                 iconHeight = PrintChartInformationIcon(iconHeight, 221, clrYellow,"BUY");
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
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                          iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                 iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                              iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                 iconHeight = PrintChartInformationIcon(iconHeight, 221, clrYellow,"BUY");
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
                              iconHeight = PrintChartInformationIcon(iconHeight, 221, clrYellow,"BUY");
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
                                    iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                 iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
                                       iconHeight = PrintChartInformationIcon(iconHeight, 222, clrYellow,"SELL");
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
