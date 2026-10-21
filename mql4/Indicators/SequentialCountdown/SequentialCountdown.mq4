//+------------------------------------------------------------------+
//|                                          SequentialCountdown.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| MT4 edition of Sequential Countdown: the same engine (Seq.mqh, an|
//| exact copy of the MT5 edition's Seq.mqh). Setup numbers          |
//| 1-9 (perfected 9s marked) and countdown numbers 1-13, on closed  |
//| bars only, so a number never changes once its bar has closed.    |
//| Alerts on 9 and 13. Rules: docs/SPEC.md.                         |
//| MT4 difference: the 13 arrows sit a multiple of ATR(14) away     |
//| from the candle (MT4 has no pixel shift). Buffers for iCustom    |
//| match MT5: 0/1 the 13s, 2/3 setup counts, 4/5 countdown numbers. |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property copyright "Copyright 2026, Allan Niñal <https://www.allanninal.dev/mql5>"
#property link      "https://www.allanninal.dev/mql5"
#property version   "1.00"
#property strict
#property description "9-13 sequential count: setup 1-9 with perfected 9s, countdown 1-13, on the chart. Closed bars only, never repaints."
#property description "Alerts on 9 and 13: pop-up, sound, push, e-mail. Buffers for other programs."
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_color1  C'38,166,98'
#property indicator_width1  2
#property indicator_color2  C'226,74,70'
#property indicator_width2  2

#include "Seq.mqh"

input int    InpHistory   = 1500;    // Closed bars to count on the chart (100-20000)
input bool   InpAllSetup  = true;    // Show setup numbers 1-8 (off: only 9)
input bool   InpCountdown = true;    // Show the countdown 1-13
input int    InpFontSize  = 8;       // Number font size
input color  InpColBuy    = C'38,166,98';   // Buy colour
input color  InpColSell   = C'226,74,70';   // Sell colour
input color  InpColCdBuy  = C'86,156,214';  // Buy countdown colour
input color  InpColCdSell = C'214,140,60';  // Sell countdown colour
input double InpArrowGap  = 1.8;     // 13 arrow distance from the candle (x ATR)
input bool   InpAlert9    = true;    // A completed 9
input bool   InpAlert13   = true;    // A 13

#include "SignalAlerts.mqh"

const string PRODUCT="Sequential Countdown";
const string PREFIX ="SQC_";

//--- series-indexed (0 = live bar), as every MT4 buffer
double   g_b13[],g_s13[],g_bset[],g_sset[],g_bcd[],g_scd[];
SQState  g_s;
int      g_start=0;                        // oldest-based chart bar of engine bar 0
int      g_fed=0;
datetime g_alert_bar=0;

void Clear()
  {
   ObjectsDeleteAll(0,PREFIX);
   SQInit(g_s);
   g_fed=0;
  }

void Num(const string name,const datetime t,const double price,const string txt,const color clr,const bool below,const bool bold)
  {
   if(ObjectFind(0,name)>=0)
      return;
   ObjectCreate(0,name,OBJ_TEXT,0,t,price);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetString(0,name,OBJPROP_FONT,bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,bold ? InpFontSize+2 : InpFontSize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,below ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
  }

int OnInit()
  {
   if(InpHistory<100 || InpHistory>20000 || InpFontSize<6 || InpFontSize>16 || InpArrowGap<0)
     {
      Print(PRODUCT,": history 100-20000, font size 6-16");
      return(INIT_PARAMETERS_INCORRECT);
     }
   SetIndexBuffer(0,g_b13);
   SetIndexBuffer(1,g_s13);
   SetIndexBuffer(2,g_bset);
   SetIndexBuffer(3,g_sset);
   SetIndexBuffer(4,g_bcd);
   SetIndexBuffer(5,g_scd);
   SetIndexStyle(0,DRAW_ARROW,EMPTY,EMPTY,InpColBuy);
   SetIndexStyle(1,DRAW_ARROW,EMPTY,EMPTY,InpColSell);
   SetIndexArrow(0,233);
   SetIndexArrow(1,234);
   for(int b=2; b<6; b++)
      SetIndexStyle(b,DRAW_NONE);
   SetIndexLabel(0,"Buy 13");
   SetIndexLabel(1,"Sell 13");
   SetIndexLabel(2,"Buy setup count (9 = complete, 10 = perfected 9)");
   SetIndexLabel(3,"Sell setup count (9 = complete, 10 = perfected 9)");
   SetIndexLabel(4,"Buy countdown number (-1 = deferred)");
   SetIndexLabel(5,"Sell countdown number (-1 = deferred)");
   for(int b=0; b<6; b++)
      SetIndexEmptyValue(b,EMPTY_VALUE);
   IndicatorShortName(PRODUCT);
   Clear();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,PREFIX);
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<10)
      return(0);
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   if(prev_calculated==0)
     {
      Clear();
      g_start=MathMax(0,rates_total-1-InpHistory);
      ArrayInitialize(g_b13,EMPTY_VALUE); ArrayInitialize(g_s13,EMPTY_VALUE);
      ArrayInitialize(g_bset,EMPTY_VALUE); ArrayInitialize(g_sset,EMPTY_VALUE);
      ArrayInitialize(g_bcd,EMPTY_VALUE); ArrayInitialize(g_scd,EMPTY_VALUE);
     }
   else
      for(int s=rates_total-1-(g_start+g_fed); s>=0; s--)
        {                                          // bars not fed yet, including the live bar
         g_b13[s]=EMPTY_VALUE; g_s13[s]=EMPTY_VALUE; g_bset[s]=EMPTY_VALUE; g_sset[s]=EMPTY_VALUE;
         g_bcd[s]=EMPTY_VALUE; g_scd[s]=EMPTY_VALUE;
        }
   bool live=(prev_calculated>0);
   string events="";
//--- feed every closed bar not fed yet, oldest first (i counts from the oldest bar, s is the series index)
   for(int i=g_start+g_fed; i<=rates_total-2; i++)
     {
      int s=rates_total-1-i;
      bool ev=SQFeed(g_s,high[s],low[s],close[s]);
      g_fed++;
      g_bset[s]=(g_s.ev_setup==1 && g_s.perf ? 10 : g_s.show_b);
      g_sset[s]=(g_s.ev_setup==-1 && g_s.perf ? 10 : g_s.show_s);
      g_bcd[s]=(g_s.defer==1 ? -1 : g_s.bmark);
      g_scd[s]=(g_s.defer==-1 ? -1 : g_s.smark);
      //--- the text offset: average range of the last 14 bars (countdown numbers sit below/above the setup numbers)
      double rg=0;
      int nr=0;
      for(int j=s; j<s+14 && j<rates_total; j++)
        { rg+=high[j]-low[j]; nr++; }
      double off=(nr>0 ? rg/nr : 0)*0.9;
      string id=PREFIX+IntegerToString((long)time[s]);
      //--- setup numbers; a 9 that is not perfected shows as 9'
      if(g_s.show_b>0 && (InpAllSetup || g_s.show_b==9))
        {
         bool nine=(g_s.show_b==9);
         Num(id+"b",time[s],low[s],nine && !g_s.perf ? "9'" : IntegerToString(g_s.show_b),InpColBuy,true,nine);
         if(nine)
            ObjectSetString(0,id+"b",OBJPROP_TOOLTIP,g_s.perf ? "Buy setup 9, perfected" : "Buy setup 9, not perfected");
        }
      if(g_s.show_s>0 && (InpAllSetup || g_s.show_s==9))
        {
         bool nine=(g_s.show_s==9);
         Num(id+"s",time[s],high[s],nine && !g_s.perf ? "9'" : IntegerToString(g_s.show_s),InpColSell,false,nine);
         if(nine)
            ObjectSetString(0,id+"s",OBJPROP_TOOLTIP,g_s.perf ? "Sell setup 9, perfected" : "Sell setup 9, not perfected");
        }
      if(InpCountdown)
        {
         if(g_s.bmark>0 || g_s.defer==1)
            Num(id+"cb",time[s],low[s]-off,g_s.defer==1 ? "+" : IntegerToString(g_s.bmark),InpColCdBuy,true,g_s.bmark==13);
         if(g_s.smark>0 || g_s.defer==-1)
            Num(id+"cs",time[s],high[s]+off,g_s.defer==-1 ? "+" : IntegerToString(g_s.smark),InpColCdSell,false,g_s.smark==13);
        }
      if(g_s.ev_cd==1)
         g_b13[s]=low[s]-InpArrowGap*iATR(NULL,0,14,s);
      if(g_s.ev_cd==-1)
         g_s13[s]=high[s]+InpArrowGap*iATR(NULL,0,14,s);
      if(ev && live && i==rates_total-2 && time[s]>g_alert_bar)
        {
         g_alert_bar=time[s];
         string tf=TfName();
         if(InpAlert9 && g_s.ev_setup!=0)
            events=StringFormat("%s setup 9%s on %s %s",g_s.ev_setup>0 ? "Buy" : "Sell",g_s.perf ? " (perfected)" : "",_Symbol,tf);
         if(InpAlert13 && g_s.ev_cd!=0)
            events+=(events=="" ? "" : "; ")+StringFormat("%s countdown 13 on %s %s",g_s.ev_cd>0 ? "Buy" : "Sell",_Symbol,tf);
        }
     }
   if(events!="")
      SignalAlertMessage(PRODUCT,events);
   return(rates_total);
  }
//+------------------------------------------------------------------+
