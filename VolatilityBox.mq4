//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property version "3.2"
#property strict

input int DaysLimit = 10;
input double _ThresholdInPoint = 1200;
input color InpColor = clrPlum;
input ENUM_LINE_STYLE InpStyle = STYLE_SOLID;
input int InpWidth = 2;
input bool InpFill = true;
input string InpFromTime = "00:00";

double g_ThresholdInPoint;
datetime g_limitDate, g_lastCheck;
const string PREFIX = "DayRangeBox_";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime calculateLimitDate(int daysLimit)
   {
    return iTime(NULL, PERIOD_D1, daysLimit);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime CreateDatetimeFromTimeString(const string &timeStr, datetime currentTime = 0)
   {
    if(!currentTime)
        currentTime = TimeCurrent();

    MqlDateTime struct_time;
    TimeToStruct(currentTime, struct_time);
// Parse time string
    string parts[];
    StringSplit(timeStr, ':', parts);
    int hours = (int)StringToInteger(parts[0]);
    int minutes = (int)StringToInteger(parts[1]);
// Create new datetime with current date but specified time
    struct_time.hour = hours;
    struct_time.min = minutes;
    struct_time.sec = 0;
    return StructToTime(struct_time);
   }

//+------------------------------------------------------------------+
//| Get high and low price within a candle range                     |
//+------------------------------------------------------------------+
void GetHighLowBetweenCandles(int index1, int index2, double &highest, double &lowest, bool &bullishFlag)
   {

    int minIndex = MathMin(index1, index2);
    int maxIndex = MathMax(index1, index2);

    highest = High[minIndex];
    lowest = Low[minIndex];

    int highestIndex = 0;
    int lowestIndex = 0;
    for(int i = minIndex+1; i <= maxIndex; i++)
       {
        if(High[i] > highest)
           {

            highestIndex = i;
            highest = High[i];
           }
        if(Low[i] < lowest)
           {
            lowestIndex = i;
            lowest = Low[i];
           }
       }

    bullishFlag = highestIndex < lowestIndex ? false : true;
   }

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
   {
    IndicatorDigits(_Digits);
    IndicatorShortName("RangeBreakOut (" + InpFromTime + ")");

    g_ThresholdInPoint = _ThresholdInPoint * Point;
    g_limitDate = calculateLimitDate(DaysLimit);

    if(DaysLimit > iBars(_Symbol, PERIOD_D1))
        return (INIT_FAILED);

    return (INIT_SUCCEEDED);
   }

//+------------------------------------------------------------------+
//| Delete all objects with matching prefix                          |
//+------------------------------------------------------------------+
void DeleteObject(const string& prefix)
   {
    for(int i = ObjectsTotal() - 1; i >= 0; i--)
       {
        string name = ObjectName(i);
        if(StringFind(name, prefix) != -1)
            ObjectDelete(0, name);
       }
   }

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
   {
    DeleteObject(PREFIX);
   }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
   {
    static double highest, lowest, recHighest, recLowest;
    static datetime dayTime, zoneStartTime, zoneEndTime;
    static int dayIndex, zoneStartIndex, zoneEndIndex, limit;
    static string rectName;
    static bool isBull;

    limit = rates_total - prev_calculated;
    if(limit == rates_total)
       {
        limit = iBarShift(Symbol(), PERIOD_D1, g_limitDate);
       }

    for(int i = limit; i >= 0; i--)
       {
        dayTime = iTime(Symbol(), PERIOD_D1, i);
        if(dayTime < g_limitDate || dayTime <= g_lastCheck)
            continue;

        dayIndex = iBarShift(Symbol(), PERIOD_D1, dayTime);
        zoneStartTime = CreateDatetimeFromTimeString(InpFromTime, dayTime);
        zoneStartIndex = iBarShift(Symbol(), PERIOD_CURRENT, zoneStartTime);
        zoneEndTime = dayIndex - 1 < 0 ? dayTime + PeriodSeconds(PERIOD_D1) : iTime(Symbol(), PERIOD_D1, dayIndex - 1);
        zoneEndIndex = dayIndex - 1 < 0 ? 0 : iBarShift(Symbol(), PERIOD_CURRENT, zoneEndTime);

        for(int x = zoneStartIndex; x > zoneEndIndex; x--)
           {
            highest = 0;
            lowest = 0;
            recHighest = 0;
            recLowest = 0;

            GetHighLowBetweenCandles(zoneStartIndex, x - 1, highest, lowest, isBull);

            if((highest - lowest) >= g_ThresholdInPoint)
               {
                rectName = PREFIX + TimeToString(dayTime, TIME_DATE);
                if(ObjectFind(0, rectName) != -1)
                    continue;

                if(isBull)
                   {
                    recHighest = highest;
                    recLowest = recHighest - g_ThresholdInPoint;
                   }
                else
                   {
                    recLowest = lowest;
                    recHighest = recLowest + g_ThresholdInPoint;
                   }

                RectangleCreate(0, rectName, zoneStartTime, recHighest, zoneEndTime, recLowest, InpColor, InpStyle, InpWidth, InpFill);
                g_lastCheck = dayTime;

                break;
               }
           }
       }

    return (rates_total);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool RectangleCreate(const long chart_ID,         // chart's ID
                     const string name,           // rectangle name
                     datetime time1,              // first point time
                     double price1,               // first point price
                     datetime time2,              // second point time
                     double price2,               // second point price
                     const color clr,             // rectangle color
                     const ENUM_LINE_STYLE style, // style of rectangle lines
                     const int width,             // width of rectangle lines
                     const bool fill,             // filling rectangle with color
                     const bool back = false,     // in the background
                     const bool selection = true, // highlight to move
                     const bool hidden = false,   // hidden in the object list
                     const long z_order = 0)      // priority for mouse click
   {
    ResetLastError();
//--- create a rectangle by the given coordinates
    if(!ObjectCreate(chart_ID, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2))
       {
        Print(__FUNCTION__,
              ": failed to create a rectangle! Error code = ", GetLastError());
        return (false);
       }
//--- set rectangle color
    ObjectSetInteger(chart_ID, name, OBJPROP_COLOR, clr);
//--- set the style of rectangle lines
    ObjectSetInteger(chart_ID, name, OBJPROP_STYLE, style);
//--- set width of the rectangle lines
    ObjectSetInteger(chart_ID, name, OBJPROP_WIDTH, width);
//--- enable (true) or disable (false) the mode of filling the rectangle
    ObjectSetInteger(chart_ID, name, OBJPROP_FILL, fill);
//--- display in the foreground (false) or background (true)
    ObjectSetInteger(chart_ID, name, OBJPROP_BACK, back);
//--- enable (true) or disable (false) the mode of highlighting the rectangle for moving
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTABLE, selection);
    ObjectSetInteger(chart_ID, name, OBJPROP_SELECTED, false);
//--- hide (true) or display (false) graphical object name in the object list
    ObjectSetInteger(chart_ID, name, OBJPROP_HIDDEN, hidden);
//--- set the priority for receiving the event of a mouse click in the chart
    ObjectSetInteger(chart_ID, name, OBJPROP_ZORDER, z_order);
//--- successful execution
    return (true);
   }
//+------------------------------------------------------------------+
