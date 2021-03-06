//+------------------------------------------------------------------+
//|                                               Moving Average.mq4 |
//|                   Copyright 2005-2014, MetaQuotes Software Corp. |
//|                                              http://www.mql4.com |
//+------------------------------------------------------------------+
#property copyright   "2005-2014, MetaQuotes Software Corp."
#property link        "http://www.mql4.com"
#property description "Moving Average sample expert advisor"

#define MAGICMA  20131111
#define CONDITION_BUY 1
#define CONDITION_SELL  2
#define CONDITION_STOPBUY  3
#define CONDITION_STOPSELL  4

//--- Inputs
input double Lots          =0.1;
input double MaximumRisk   =0.02;
input double DecreaseFactor=3;
input int    MovingPeriod  =12;
input int    MovingShift   =6;
input int    stoppr        =-40;
input int    winpr        =1000;

input int    maperiod1           =13;//短线ma
input int    maperiod1shift      =8;//短线ma偏移
input int    maperiod2           =21;//中线ma
input int    maperiod2shift      =13;//中线ma偏移
input int    maperiod3           =34;//长线ma
input int    maperiod3shift      =21;//长线ma偏移

/*test log
1:
maperiod1shift = 8
maperiod2shift = 13
maperiod3shift = 21
h4:-386/175
h1:-4438/401

2:
maperiod1shift = 0
maperiod2shift = 0
maperiod3shift = 0
h4:-3707
h1:-4195

3:


*/



//+------------------------------------------------------------------+
//| Calculate open positions                                         |
//+------------------------------------------------------------------+
int CalculateCurrentOrders(string symbol)
  {
   int buys=0,sells=0;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA)
        {
         if(OrderType()==OP_BUY)  buys++;
         if(OrderType()==OP_SELL) sells++;
        }
     }
//--- return orders volume
   if(buys>0) return(buys);
   else       return(-sells);
  }
//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
//double LotsOptimized()
//  {
//   double lot=Lots;
//   int    orders=HistoryTotal();     // history orders total
//   int    losses=0;                  // number of losses orders without a break
////--- select lot size
//   lot=NormalizeDouble(AccountFreeMargin()*MaximumRisk/1000.0,1);
////--- calcuulate number of losses orders without a break
//   if(DecreaseFactor>0)
//     {
//      for(int i=orders-1;i>=0;i--)
//        {
//         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==false)
//           {
//            Print("Error in history!");
//            break;
//           }
//         if(OrderSymbol()!=Symbol() || OrderType()>OP_SELL)
//            continue;
//         //---
//         if(OrderProfit()>0) break;
//         if(OrderProfit()<0) losses++;
//        }
//      if(losses>1)
//         lot=NormalizeDouble(lot-lot*losses/DecreaseFactor,1);
//     }
////--- return lot size
//   if(lot<0.1) lot=0.1;
//   return(lot);
//  }
//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
void CheckForOpen()
  {
   int    res;
//--- go trading only for first tiks of new bar
   if(Volume[0]>1) return;
//--- sell conditions
   if(getCondition(CONDITION_SELL))
     {
      res=OrderSend(Symbol(),OP_SELL,Lots,Bid,3,0,0,"",MAGICMA,0,Red);
      return;
     }
//--- buy conditions
   if(getCondition(CONDITION_BUY))
     {
      res=OrderSend(Symbol(),OP_BUY,Lots,Ask,3,0,0,"",MAGICMA,0,Blue);
      return;
     }
//---
  }
//+------------------------------------------------------------------+
//| Check for close order conditions                                 |
//+------------------------------------------------------------------+
void CheckForClose()
  {
//--- go trading only for first tiks of new bar
   //if(Volume[0]>1) return;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) continue;
      //--- check order type 
      if(OrderType()==OP_BUY)
        {
         if(getCondition(CONDITION_STOPBUY))
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,White))
               Print("OrderClose error ",GetLastError());
           }
         break;
        }
      if(OrderType()==OP_SELL)
        {
         if(getCondition(CONDITION_STOPSELL))
           {
            if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,White))
               Print("OrderClose error ",GetLastError());
           }
         break;
        }
     }
//---
  }
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- check for history and trading
   if(Bars<100 || IsTradeAllowed()==false)
      return;
//--- calculate open orders by current symbol
   if(CalculateCurrentOrders(Symbol())==0) CheckForOpen();
   else                                    CheckForClose();
//---
  }
  

bool getCondition(int condition)
{
   double ma短, ma中, ma长;
   double orderprofit;
   ma短=iMA(NULL,0,maperiod1,maperiod1shift,MODE_SMA,PRICE_CLOSE,0);
   ma中=iMA(NULL,0,maperiod2,maperiod2shift,MODE_SMA,PRICE_CLOSE,0);
   ma长=iMA(NULL,0,maperiod3,maperiod3shift,MODE_SMA,PRICE_CLOSE,0);
   
   switch(condition)
   {
      case CONDITION_BUY:
         return (ma短 > ma中 && ma中 > ma长);
      case CONDITION_SELL:
         return (ma短 < ma中 && ma中 < ma长);
      case CONDITION_STOPBUY:
         orderprofit=OrderProfit();
         if(orderprofit < stoppr || orderprofit > winpr)
         {
            Print("orderprofit:"+orderprofit);
         }
         return (ma短 < ma中 || orderprofit < stoppr || orderprofit > winpr);
      case CONDITION_STOPSELL:
         orderprofit=OrderProfit();
         if(orderprofit < stoppr || orderprofit > winpr)
         {
            Print("orderprofit:"+orderprofit);
         }
         return (ma短 > ma中 || orderprofit < stoppr || orderprofit > winpr);
      default:
         return false;
   }
}
