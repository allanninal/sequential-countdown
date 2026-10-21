//+------------------------------------------------------------------+
//|                                                          Seq.mqh |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| 9-13 setup and countdown engine of Sequential Countdown, one     |
//| CLOSED bar per step (no repaint). Variant: docs/SPEC.md; tested  |
//| against tests/reference.py.                                      |
//|   Buy setup bar: close < close 4 bars earlier; it starts at 1    |
//|   only after a flip (previous close > the close 4 bars before    |
//|   it); 9 in a row completes it. Perfected: low of bar 8 or 9 <=  |
//|   lows of bars 6 and 7. Its resistance = highest high of the 9.  |
//|   Buy countdown (from setup bar 9): close <= low 2 bars earlier, |
//|   not necessarily consecutive; 13 needs low <= close of bar 8    |
//|   (else deferred). Cancelled by a sell setup or a close above    |
//|   its setup's resistance; a new buy setup restarts it.           |
//|   Sell mirrors everything.                                       |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#ifndef SEQ_MQH
#define SEQ_MQH

#define SQ_N 16                          // ring of recent bars

struct SQState
  {
   int    cnt;                           // bars fed; bar k = the k-th fed bar (0-based)
   double h[SQ_N],l[SQ_N],c[SQ_N];
   int    bcnt,scnt;                     // setup counts
   int    bcd,scd;                       // countdown counts
   bool   b_on,s_on;                     // countdowns running
   double b_c8,s_c8;                     // close of countdown bar 8
   double b_lvl,s_lvl;                   // level of the setup that started the running countdown
   //--- the last bar
   int    ev_setup;                      // +1 buy 9, -1 sell 9
   bool   perf;                          // that 9 is perfected
   int    ev_cd;                         // +1 buy 13, -1 sell 13
   int    defer;                         // +1/-1: a countdown bar deferred at 12 ("+")
   int    bmark,smark;                   // countdown number of this bar (0 none)
   int    show_b,show_s;                 // setup count of this bar (9 on completion)
  };

void SQInit(SQState &s)
  {
   s.cnt=0; s.bcnt=0; s.scnt=0; s.bcd=0; s.scd=0; s.b_on=false; s.s_on=false; s.b_c8=0; s.s_c8=0;
   s.b_lvl=0; s.s_lvl=0;
   s.ev_setup=0; s.perf=false; s.ev_cd=0; s.defer=0; s.bmark=0; s.smark=0; s.show_b=0; s.show_s=0;
  }

double SQH(const SQState &s,const int k) { return(s.h[k%SQ_N]); }
double SQL(const SQState &s,const int k) { return(s.l[k%SQ_N]); }
double SQC(const SQState &s,const int k) { return(s.c[k%SQ_N]); }

//--- feed one CLOSED bar; true when it completed a 9 or a 13
bool SQFeed(SQState &s,const double high,const double low,const double close)
  {
   int k=s.cnt;
   s.h[k%SQ_N]=high; s.l[k%SQ_N]=low; s.c[k%SQ_N]=close;
   s.cnt++;
   s.ev_setup=0; s.perf=false; s.ev_cd=0; s.defer=0; s.bmark=0; s.smark=0;
   if(k>=5)
     {
      if(close<SQC(s,k-4))
        {
         if(s.bcnt>0)
            s.bcnt++;
         else
            if(SQC(s,k-1)>SQC(s,k-5))
               s.bcnt=1;
        }
      else
         s.bcnt=0;
      if(close>SQC(s,k-4))
        {
         if(s.scnt>0)
            s.scnt++;
         else
            if(SQC(s,k-1)<SQC(s,k-5))
               s.scnt=1;
        }
      else
         s.scnt=0;
      if(s.bcnt==9)
        {
         s.ev_setup=1;
         s.perf=(MathMin(low,SQL(s,k-1))<=MathMin(SQL(s,k-3),SQL(s,k-2)));
         double hi=high;
         for(int j=1; j<9; j++)
            hi=MathMax(hi,SQH(s,k-j));
         s.bcnt=0;
         s.s_on=false; s.scd=0;                   // a buy setup cancels the sell countdown
         s.b_on=true; s.bcd=0; s.b_lvl=hi;        // and starts (or restarts) the buy countdown
        }
      else
         if(s.scnt==9)
           {
            s.ev_setup=-1;
            s.perf=(MathMax(high,SQH(s,k-1))>=MathMax(SQH(s,k-3),SQH(s,k-2)));
            double lo=low;
            for(int j=1; j<9; j++)
               lo=MathMin(lo,SQL(s,k-j));
            s.scnt=0;
            s.b_on=false; s.bcd=0;
            s.s_on=true; s.scd=0; s.s_lvl=lo;
           }
     }
   if(k>=2)
     {
      if(s.b_on && close>s.b_lvl)
        { s.b_on=false; s.bcd=0; }                 // closed above the setup's resistance: cancelled
      if(s.s_on && close<s.s_lvl)
        { s.s_on=false; s.scd=0; }
      if(s.b_on && close<=SQL(s,k-2))
        {
         if(s.bcd<12)
           {
            s.bcd++;
            s.bmark=s.bcd;
            if(s.bcd==8)
               s.b_c8=close;
           }
         else
            if(low<=s.b_c8)
              { s.bcd=13; s.ev_cd=1; s.b_on=false; s.bmark=13; }
            else
               s.defer=1;
        }
      if(s.s_on && close>=SQH(s,k-2))
        {
         if(s.scd<12)
           {
            s.scd++;
            s.smark=s.scd;
            if(s.scd==8)
               s.s_c8=close;
           }
         else
            if(high>=s.s_c8)
              { s.scd=13; s.ev_cd=-1; s.s_on=false; s.smark=13; }
            else
               s.defer=-1;
        }
     }
   s.show_b=(s.ev_setup==1 ? 9 : s.bcnt);
   s.show_s=(s.ev_setup==-1 ? 9 : s.scnt);
   if(s.ev_cd!=0)
     {
      if(s.ev_cd==1) s.bcd=0; else s.scd=0;
     }
   return(s.ev_setup!=0 || s.ev_cd!=0);
  }

#endif
//+------------------------------------------------------------------+
