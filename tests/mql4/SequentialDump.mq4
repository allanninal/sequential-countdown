//+------------------------------------------------------------------+
//|                                               SequentialDump.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Test EA (not shipped): dumps the MT4 Sequential Countdown        |
//| buffers and checks repainting in the Strategy Tester (Dump4.mqh).|
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property strict

#define DUMP4_BUFFERS "0,1,2,3,4,5"
#define DUMP4_PROBE   "0,1"
#define DUMP4_LIVE                     // the indicator counts only its last InpHistory bars

input int InpHistory = 1500;

double IndValue(const int buf,const int shift)
  {
   return(iCustom(NULL,0,"SequentialCountdown\\SequentialCountdown",InpHistory,true,true,8,C'38,166,98',C'226,74,70',
                  C'86,156,214',C'214,140,60',1.8,false,false,false,false,"alert.wav",false,false,buf,shift));
  }

#include <IndTest4/Dump4.mqh>
//+------------------------------------------------------------------+
