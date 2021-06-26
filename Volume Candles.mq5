/*
Copyright (C) 2021 Mateus Matucuma Teixeira

This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/
#ifndef VOLUMECANDLES_H
#define VOLUMECANDLES_H
//+------------------------------------------------------------------+
//|                                               Volume Candles.mq5 |
//|                     Copyright (C) 2021, Mateus Matucuma Teixeira |
//|                                            mateusmtoss@gmail.com |
//| GNU General Public License version 2 - GPL-2.0                   |
//| https://opensource.org/licenses/gpl-2.0.php                      |
//+------------------------------------------------------------------+
// https://github.com/BRMateus2/
//---- Main Properties
#property copyright "2021, Mateus Matucuma Teixeira"
#property link "https://github.com/BRMateus2/"
#property description "Volume Colored Candlestick with Bollinger Bands as the Standard Deviation"
#property version "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots 1
//---- Imports
//---- Include Libraries and Modules
#include <MT-Utilities.mqh>
// Metatrader 5 has a limitation of 64 User Input Variable description, for reference this has 64 traces ----------------------------------------------------------------
//---- Definitions
//#define INPUT const
#ifndef INPUT
#define INPUT input
#endif
//---- Input Parameters
//---- Class Definitions
//---- "Basic Settings"
input group "Basic Settings"
string iName = "VolumeCandles";
INPUT int iPeriodInp = 1440; // Period of Bollinger Bands
int iPeriod = 60; // Backup iPeriod if user inserts wrong value
INPUT double iBandsDev = 2.0; // Bollinger Bands Standard Deviation
INPUT double iSensitivity = 0.50; // Sensitivity, default 0.50, lower means less sensitive
INPUT bool iShowIndicators = false; // Calibration: show calculation indicators in chart
INPUT bool iShowGradient = false; // Calibration: show gradients in chart
// Explanation: we want to have three gradients, from [cLow; cMean[ and [cMean; cHigh], but to cHigh be inclusive, we need a module of cGradientSize % cCount equal to 1, as it happens that is the slot needed for cHigh to be correctly placed in the Index - for every extra gradient, there must be one "free slot" to put the last color
INPUT color cLow = 0xE0E080; // Low Volume
INPUT color cAvg = 0x00D0F0; // Average Volume
INPUT color cHigh = 0x2020FF; // High Volume
const int cCount = 2; // Counter of gradient variations (cLow->cMean is one, cMean->cHigh is the second)
const int cGradientSize = 63; // Has a platform limit of 64! There is also some math craziness to make the gradients fit all colors without loss
const int cGradientParts = (cGradientSize / cCount); // Counter of the parts
// Applied to
INPUT ENUM_APPLIED_VOLUME ENUM_APPLIED_VOLUMEInp = VOLUME_TICK; // Volume by "Ticks" or by "Real"
//INPUT ENUM_APPLIED_PRICE ENUM_APPLIED_PRICEInp = PRICE_CLOSE; // Applied Price Equation
//INPUT ENUM_MA_METHOD ENUM_MA_METHODInp = MODE_SMA; // Applied Moving Average Method
//const int iShift = 0; // Shift data
//---- "Adaptive Period"
input group "Adaptive Period"
INPUT bool adPeriodInp = true; // Adapt the Period? Overrides Standard Period Settings
INPUT int adPeriodMinutesInp = 27600; // Period in minutes that all M and H timeframes should adapt to?
INPUT int adPeriodD1Inp = 20; // Period for D1 - Daily Timeframe
INPUT int adPeriodW1Inp = 4; // Period for W1 - Weekly Timeframe
INPUT int adPeriodMN1Inp = 1; // Period for MN - Monthly Timeframe
//---- Indicator Indexes, Buffers and Handlers
int iVolHandle = 0;
//double iVolBuf[] = {};
int iBandsBufUpperI = 5;
int iBandsBufMiddleI = 6;
int iBandsBufLowerI = 7;
int iBandsHandle = 0;
double iBandsBufUpper[] = {};
double iBandsBufMiddle[] = {};
double iBandsBufLower[] = {};
int iBufOpenI = 0; // Index for Open Buffer values, also this is the first index and is the most important for setting the next plots
double iBufOpen[] = {}; // Open Buffer values
int iBufHighI = 1;
double iBufHigh[] = {};
int iBufLowI = 2;
double iBufLow[] = {};
int iBufCloseI = 3;
double iBufClose[] = {};
int iBufColorI = 4;
double iBufColor[] = {}; // Colors have 8+8+8 bits in this representation, value up to 2^(8+8+8) - 1, meaning [0; 16777216[ and it is represented as 0x## for Red, 0x##00 for Green and 0x##0000 for Blue - Alpha at 0xFF000000 is INVALID! Meaning there is no transparency
int subwindow = 0; // Subwindow which iShowIndicators will be used
string iVolName = ""; // Should be released if created
string iBandsName = ""; // Should be released if created
//---- Objects
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
// Constructor or initialization function
// https://www.mql5.com/en/docs/basis/function/events
// https://www.mql5.com/en/articles/100
//+------------------------------------------------------------------+
int OnInit()
{
    // User and Developer Input scrutiny
    if(adPeriodInp == true) { // Calculate iPeriod if period_adaptive_inp == true. Adaptation works flawless for less than D1 - D1, W1 and MN1 are a constant set by the user.
        if((PeriodSeconds(PERIOD_CURRENT) < PeriodSeconds(PERIOD_D1)) && (PeriodSeconds(PERIOD_CURRENT) >= PeriodSeconds(PERIOD_M1))) {
            if(adPeriodMinutesInp > 0) {
                int iPeriodCalc = ((adPeriodMinutesInp * 60) / PeriodSeconds(PERIOD_CURRENT));
                if(iPeriodCalc == 0) { // If the division is less than 1, then we have to complement to a minimum, user can also hide on timeframes that are not needed.
                    iPeriod = iPeriodCalc + 1;
                } else if(iPeriod < 0) {
                    ErrorPrint("calculation error with \"iPeriod = ((adPeriodMinutesInp * 60) / PeriodSeconds(PERIOD_CURRENT))\". Indicator will use value \"" + IntegerToString(iPeriod) + "\" for calculations."); // iPeriod is already defined
                } else { // If iPeriodCalc is not zero, neither negative, them it is valid.
                    iPeriod = iPeriodCalc;
                }
            } else {
                ErrorPrint("wrong value for \"adPeriodMinutesInp\" = \"" + IntegerToString(adPeriodMinutesInp) + "\". Indicator will use value \"" + IntegerToString(iPeriod) + "\" for calculations."); // iPeriod is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_D1)) {
            if(adPeriodD1Inp > 0) {
                iPeriod = adPeriodD1Inp;
            } else {
                ErrorPrint("wrong value for \"adPeriodD1Inp\" = \"" + IntegerToString(adPeriodD1Inp) + "\". Indicator will use value \"" + IntegerToString(iPeriod) + "\" for calculations."); // iPeriod is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_W1)) {
            if(adPeriodW1Inp > 0) {
                iPeriod = adPeriodW1Inp;
            } else {
                ErrorPrint("wrong value for \"adPeriodW1Inp\" = \"" + IntegerToString(adPeriodW1Inp) + "\". Indicator will use value \"" + IntegerToString(iPeriod) + "\" for calculations."); // iPeriod is already defined
            }
        } else if(PeriodSeconds(PERIOD_CURRENT) == PeriodSeconds(PERIOD_MN1)) {
            if(adPeriodMN1Inp > 0) {
                iPeriod = adPeriodMN1Inp;
            } else {
                ErrorPrint("wrong value for \"adPeriodMN1Inp\" = \"" + IntegerToString(adPeriodMN1Inp) + "\". Indicator will use value \"" + IntegerToString(iPeriod) + "\" for calculations."); // iPeriod is already defined
            }
        } else {
            ErrorPrint("untreated condition. Indicator will use value \"" + IntegerToString(iPeriod) + "\" for calculations."); // iPeriod is already defined
        }
    } else if(iPeriodInp <= 0 && adPeriodInp == false) {
        ErrorPrint("wrong value for \"iPeriodInp\" = \"" + IntegerToString(iPeriodInp) + "\". Indicator will use value \"" + IntegerToString(iPeriod) + "\" for calculations."); // iPeriod is already defined
    } else {
        iPeriod = iPeriodInp;
    }
    // Check for free slot in the Color Indexes
    if((cGradientSize % cCount) != 1) {
        ErrorPrint("cGradientSize is not divisible by cCount without there being one free slot, as for the fact that [cGradients; ...; cGradients] can't be closed correctly");
    }
    // Treat Indicator
    // Treat Handlers and Buffers
    iVolHandle = iVolumes(Symbol(), Period(), ENUM_APPLIED_VOLUMEInp);
    if(iVolHandle == INVALID_HANDLE || iVolHandle < 0) {
        ErrorPrint("iVolHandle == INVALID_HANDLE || iVolHandle < 0");
        return INIT_FAILED;
    }
    iBandsHandle = iBands(Symbol(), Period(), iPeriod, 0, iBandsDev, iVolHandle);
    if(iBandsHandle == INVALID_HANDLE || iBandsHandle < 0) {
        ErrorPrint("iBandsHandle == INVALID_HANDLE || iBandsHandle < 0");
        return INIT_FAILED;
    }
    if(iShowIndicators) {
        // Receive the number of a new subwindow, to which we will try to add the indicator
        subwindow = (int) ChartGetInteger(ChartID(), CHART_WINDOWS_TOTAL);
        if(!ChartIndicatorAdd(ChartID(), subwindow, iVolHandle)) {
            ErrorPrint("!ChartIndicatorAdd(ChartID(), subwindow, iVolHandle)");
            return INIT_FAILED;
        }
        iVolName = ChartIndicatorName(ChartID(), subwindow, 0); // Save the name so we can delete at OnDeinit()
        if(!ChartIndicatorAdd(ChartID(), subwindow, iBandsHandle)) {
            ErrorPrint("!ChartIndicatorAdd(ChartID(), subwindow, iBandsHandle)");
            return INIT_FAILED;
        }
        iBandsName = ChartIndicatorName(ChartID(), subwindow, 1);
    }
    // DRAW_COLOR_CANDLES is a specific plotting, which must be coded manually - those are the important sets
    if(!SetIndexBuffer(iBufOpenI, iBufOpen, INDICATOR_DATA)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(iBufHighI, iBufHigh, INDICATOR_DATA)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(iBufLowI, iBufLow, INDICATOR_DATA)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(iBufCloseI, iBufClose, INDICATOR_DATA)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(iBufColorI, iBufColor, INDICATOR_COLOR_INDEX)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    // Treat Plots
    if(!PlotIndexSetInteger(iBufOpenI, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES)) { // You can just set 0 in place of iBufOpenI, but it might be possible to have multiple colored plots, and the first Index for a colored draw is what defines its colors
        ErrorPrint("");
        return INIT_FAILED;
    }
    // Define a value which will not plot, if any of the buffers has this value
    if(!PlotIndexSetDouble(iBufOpenI, PLOT_EMPTY_VALUE, DBL_MIN)) {  // You can set 0.0 in place of DBL_MIN, but it will cause invisible candlesticks if any of the buffers is at 0.0
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, cGradientSize)) { // Set the color indexes to be of size cGradientSize
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(iBandsBufUpperI, iBandsBufUpper, INDICATOR_CALCULATIONS)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(iBandsBufMiddleI, iBandsBufMiddle, INDICATOR_CALCULATIONS)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    if(!SetIndexBuffer(iBandsBufLowerI, iBandsBufLower, INDICATOR_CALCULATIONS)) {
        ErrorPrint("");
        return INIT_FAILED;
    }
    // Set color for each index
    for(int i = 0; i < cGradientParts; i++) {
        PlotIndexSetInteger(iBufOpenI, PLOT_LINE_COLOR, i, argbGradient(cLow, cAvg, (1.0 - (((double) cGradientParts - i) / cGradientParts))));
        PlotIndexSetInteger(iBufOpenI, PLOT_LINE_COLOR, i + cGradientParts, argbGradient(cAvg, cHigh, (1.0 - (((double) cGradientParts - i) / cGradientParts))));
    }
    PlotIndexSetInteger(iBufOpenI, PLOT_LINE_COLOR, (cGradientSize - 1), argbGradient(cAvg, cHigh, 1.0)); // Set the last slot
    //for(int i = 0; i < cGradientSize+1; i++) Print(IntegerToString(i, 2, '0') + " " + ColorToString(PlotIndexGetInteger(iBufOpenI, PLOT_LINE_COLOR, i))); // Debug
    // Indicator Subwindow Short Name
    iName = StringFormat("VC(%d)", iPeriod); // Indicator name in Subwindow
    if(!IndicatorSetString(INDICATOR_SHORTNAME, iName)) { // Set Indicator name
        ErrorPrint("IndicatorSetString(INDICATOR_SHORTNAME, iName)");
        return INIT_FAILED;
    }
    // Set the starting/default formatting for the candles
    PlotIndexSetString(iBufOpenI, PLOT_LABEL, "Open;" + "High;" + "Low;" + "Close"); // A strange formatting where ';' defines the separators, it is always Open;High;Low;Close and there are no additional values
    // Treat Objects
    return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
// Destructor or Deinitialization function
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(iShowIndicators) {
        ChartIndicatorDelete(ChartID(), subwindow, iVolName);
        ChartIndicatorDelete(ChartID(), subwindow, iBandsName);
    }
    IndicatorRelease(iVolHandle);
    IndicatorRelease(iBandsHandle);
    return;
}
//+------------------------------------------------------------------+
// Calculation function
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime & time[],
                const double & open[],
                const double & high[],
                const double & low[],
                const double & close[],
                const long & tick_volume[],
                const long & volume[],
                const int& spread[])
{
    if(rates_total < iPeriod) { // No need to calculate if the data is less than the requested period - it is returned as 0, because if we return rates_total, then the terminal interprets that the indicator has valid data
        return 0;
    } else if((BarsCalculated(iVolHandle) < rates_total) || (BarsCalculated(iBandsHandle) < rates_total)) { // Indicator data is still not ready
        return 0;
    }
    if((CopyBuffer(iBandsHandle, 1, 0, (rates_total - prev_calculated + 1), iBandsBufUpper) <= 0) || (CopyBuffer(iBandsHandle, 0, 0, (rates_total - prev_calculated + 1), iBandsBufMiddle) <= 0) || (CopyBuffer(iBandsHandle, 2, 0, (rates_total - prev_calculated + 1), iBandsBufLower) <= 0)) { // Try to copy, if there is no data copied for some reason, then we don't need to calculate - also, we don't need to copy rates before prev_calculated as they have the same result
        ErrorPrint("");
        return 0;
    }
    static int colors = 0; // Only used if iShowGradient
    static int bars = 0; // Only used if iShowGradient
    // Main loop of calculations
    int i = (((prev_calculated - 1) > iPeriod) ? (prev_calculated - 1) : iPeriod);
    for(; i < rates_total && !IsStopped(); i++) {
        iBufOpen[i] = open[i];
        iBufHigh[i] = high[i];
        iBufLow[i] = low[i];
        iBufClose[i] = close[i];
        if((ENUM_APPLIED_VOLUMEInp == VOLUME_TICK ? tick_volume[i] : volume[i]) > iBandsBufMiddle[i]) {
            double indexColor = MathRound(((iSensitivity * ((ENUM_APPLIED_VOLUMEInp == VOLUME_TICK) ? (tick_volume[i] - iBandsBufMiddle[i]) : (volume[i] - iBandsBufMiddle[i])) / (iBandsBufUpper[i] - iBandsBufMiddle[i])) * (double) cGradientParts) + cGradientParts);
            if(indexColor < cGradientParts) indexColor = cGradientParts;
            else if(indexColor >= cGradientSize) indexColor = cGradientSize - 1;
            iBufColor[i] = indexColor;
        } else { // The comparison of BufLower and 0.0, is because volume should never be negative; the stddev does not consider this fact and biases the lower color indexes to never show, depending on the situation - the comparison fixes the lower indexes not showing, but biases towards a lower-index color below BufMiddle, which seems to be acceptable
            double indexColor = MathRound(((iSensitivity * ((ENUM_APPLIED_VOLUMEInp == VOLUME_TICK) ? (iBandsBufMiddle[i] - tick_volume[i]) : (iBandsBufMiddle[i] - volume[i]))) / (iBandsBufMiddle[i] - (iBandsBufLower[i] > 0.0 ? iBandsBufLower[i] : 0.0))) * (double) cGradientParts);
            if(indexColor < 0.0) indexColor = 0.0; // This seems to be impossible to reach
            else if(indexColor >= cGradientParts) indexColor = cGradientParts - 1;
            iBufColor[i] = indexColor;
        }
        if(iShowGradient) {
            iBufColor[i] = colors;
            if(bars != Bars(Symbol(), PERIOD_CURRENT)) colors++; // Comment this line for color change at every tick, else at every new bar
            //colors++; // Comment this line for color change at every bar, else at every new tick
            if(colors >= cGradientSize) colors = 0; // Upper limit for colors indexer
        }
    }
    //PlotIndexSetString(iBufOpenI, PLOT_LABEL, (
    //                       "Lastest candle values: \n" +
    //                       "O: " + DoubleToString(iBufOpen[i - 1], Digits()) +
    //                       "\nH: " + DoubleToString(iBufHigh[i - 1], Digits()) +
    //                       "\nL: " + DoubleToString(iBufLow[i - 1], Digits()) +
    //                       "\nC: " + DoubleToString(iBufClose[i - 1], Digits()) +
    //                       "\nSpr: " + DoubleToString(spread[i - 1]) +
    //                       "\n Past Open;" +
    //                       "Lastest candle values: \n" +
    //                       "O: " + DoubleToString(iBufOpen[i - 1], Digits()) +
    //                       "\nH: " + DoubleToString(iBufHigh[i - 1], Digits()) +
    //                       "\nL: " + DoubleToString(iBufLow[i - 1], Digits()) +
    //                       "\nC: " + DoubleToString(iBufClose[i - 1], Digits()) +
    //                       "\nSpr: " + DoubleToString(spread[i - 1]) +
    //                       "\n Past High;" +
    //                       "Lastest candle values: \n" +
    //                       "O: " + DoubleToString(iBufOpen[i - 1], Digits()) +
    //                       "\nH: " + DoubleToString(iBufHigh[i - 1], Digits()) +
    //                       "\nL: " + DoubleToString(iBufLow[i - 1], Digits()) +
    //                       "\nC: " + DoubleToString(iBufClose[i - 1], Digits()) +
    //                       "\nSpr: " + DoubleToString(spread[i - 1]) +
    //                       "\n Past Low;" +
    //                       "Lastest candle values: \n" +
    //                       "O: " + DoubleToString(iBufOpen[i - 1], Digits()) +
    //                       "\nH: " + DoubleToString(iBufHigh[i - 1], Digits()) +
    //                       "\nL: " + DoubleToString(iBufLow[i - 1], Digits()) +
    //                       "\nC: " + DoubleToString(iBufClose[i - 1], Digits()) +
    //                       "\nSpr: " + DoubleToString(spread[i - 1]) +
    //                       "\n Past Close;"
    //                   )); // There is no need for this, for performance reasons and because the old data is not saved (it prints only the Lastest ones), and the ';' separator does the job of changing past candles
    if(iShowGradient) {
        bars = Bars(Symbol(), PERIOD_CURRENT);
    }
    return rates_total; // Calculations are done and valid
}
//+------------------------------------------------------------------+
// Extra functions, utilities and conversion
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Header Guard #endif
//+------------------------------------------------------------------+
#endif
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
