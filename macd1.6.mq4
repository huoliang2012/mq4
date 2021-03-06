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

extern int _SlipPage     = 2;   //最大允许滑点数
extern int _StopLoss     = -50;  //止损水平
extern int _TakeProfit   = 1000; //赢利水平

/*test log
h1:-1583/401
h4:-3422/222
m15:-5706/1395
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
double LotsOptimized()
  {
   double lot=Lots;
   int    orders=HistoryTotal();     // history orders total
   int    losses=0;                  // number of losses orders without a break
//--- select lot size
   lot=NormalizeDouble(AccountFreeMargin()*MaximumRisk/1000.0,1);
//--- calcuulate number of losses orders without a break
   if(DecreaseFactor>0)
     {
      for(int i=orders-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==false)
           {
            Print("Error in history!");
            break;
           }
         if(OrderSymbol()!=Symbol() || OrderType()>OP_SELL)
            continue;
         //---
         if(OrderProfit()>0) break;
         if(OrderProfit()<0) losses++;
        }
      if(losses>1)
         lot=NormalizeDouble(lot-lot*losses/DecreaseFactor,1);
     }
//--- return lot size
   if(lot<0.1) lot=0.1;
   return(lot);
  }
//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
void CheckForOpen()
  {
   double stopLoss=0, takeProfit=0;
   int    res;
//--- go trading only for first tiks of new bar
   if(Volume[0]>1) return;
//--- sell conditions
   if(getCondition(CONDITION_SELL))
     {
       //计算止赢点位
//       if(_TakeProfit==0)
//         takeProfit=0;
//       else
//         takeProfit=Bid-_TakeProfit*Point;
//           
//       //计算止损点位   
//       if(_StopLoss==0)
//         stopLoss=0;
//       else
//         stopLoss=Bid+_StopLoss*Point;
       res=OrderSend(Symbol(),OP_SELL,LotsOptimized(),Bid,3,0,0,"",MAGICMA,0,Red);
       //res=OrderSend(Symbol(),OP_SELL,LotsOptimized(),Bid,_SlipPage,NormalizeDouble(stopLoss,Digits),NormalizeDouble(takeProfit,Digits),"",MAGICMA,0,Red);
       //if(res==-1)
       //  Print("Error Occured : "+ErrorDescription(GetLastError()));
       //Print("takeProfit:"+takeProfit+"stopLoss:"+stopLoss+"_SlipPage:"+_SlipPage+"Bid:"+Bid);
       return;
     }
//--- buy conditions
   if(getCondition(CONDITION_BUY))
     {
//       //计算止赢点位
//       if(_TakeProfit==0)
//         takeProfit=0;
//       else
//         takeProfit=Ask+_TakeProfit*Point;
//         
//       //计算止损点位   
//       if(_StopLoss==0)
//         stopLoss=0;
//       else
//         stopLoss=Ask-_StopLoss*Point;
         
       res=OrderSend(Symbol(),OP_BUY,LotsOptimized(),Ask,3,0,0,"",MAGICMA,0,Blue);
       //res=OrderSend(Symbol(),OP_BUY,LotsOptimized(),Ask,_SlipPage,NormalizeDouble(stopLoss,Digits),NormalizeDouble(takeProfit,Digits),"",MAGICMA,0,Blue);
       //if(res==-1)
       //Print("Error Occured : "+ErrorDescription(GetLastError()));
       //Print("takeProfit:"+takeProfit+"stopLoss:"+stopLoss+"_SlipPage:"+_SlipPage+"Ask:"+Ask);
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
   double macd, sig;
   double orderprofit;
   
   //double ma10, ma20, ma60;
   //ma10=iMA(NULL,0,13,8,MODE_SMA,PRICE_CLOSE,0);
   //ma20=iMA(NULL,0,21,13,MODE_SMA,PRICE_CLOSE,0);
   //ma60=iMA(NULL,0,34,21,MODE_SMA,PRICE_CLOSE,0);
   macd=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0);
   sig=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0);
   
   switch(condition)
   {
      case CONDITION_BUY:
         return (macd > sig && macd > 0);
      case CONDITION_SELL:
         return (macd < sig && macd < 0);
      case CONDITION_STOPBUY:
         orderprofit=OrderProfit();
         if(orderprofit < _StopLoss || orderprofit > _TakeProfit)
         {
            Print("orderprofit:"+orderprofit);
         }
         return (macd < sig || orderprofit < _StopLoss || orderprofit > _TakeProfit);
      case CONDITION_STOPSELL:
         //return (macd > sig);
         orderprofit=OrderProfit();
         if(orderprofit < _StopLoss || orderprofit > _TakeProfit)
         {
            Print("orderprofit:"+orderprofit);
         }
         return (macd > sig || orderprofit < _StopLoss || orderprofit > _TakeProfit);
      default:
         return false;
   }
}
