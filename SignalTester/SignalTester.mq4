//+------------------------------------------------------------------+
//|                                                             D9ko |
//|                                            email: d9ko@yandex.ru |
//|                                                    skype: dim9ko |
//+------------------------------------------------------------------+
#property copyright     "Autor: Aleksandr Shokhin"
#property link          "https://www.mql5.com/ru/market/product/8885"
#property description   "Developer: Dmitry D9ko"
#property description   " "
#property icon          "icon.ico"
#property version       "1.05"
#property strict
#property description   "Советник для проверки истории сделок из сигналов с альтернативными параметрами входа (SL, TP, Lot).   "           // описание советника
//--- КОНСТАНТЫ
#define EXPERT_NAME                    "SignalTester"
#define ORDER_SEND_TRY_DELAY           2000        // задержка между попытками открыть ордер
#define ORDER_SEND_MAX_RETRY           3           // максимальное количество попыток открыть ордер
//---
#define CLR_BUY_OPEN                   clrBlue     // цвет стрелок открытия
#define CLR_SELL_OPEN                  clrRed      // цвет стрелок открытия  
//---

//--- СТРУКТУРЫ ---
struct strHistOrders
   {
   //---
   datetime OpenTime;
   ENUM_ORDER_TYPE Type;
   string OrdSymbol;
   double OpenPrice;
   //--- оператор присваивания (в MQL4 так не работает!)
   //strHistOrders operator=(const strHistOrders &in)  
   //   { 
   //   OpenTime=in.OpenTime;
   //   Type=in.Type;
   //   OrdSymbol=in.OrdSymbol;
   //   OpenPrice=in.OpenPrice;
   //   return(this); 
   //   }
   //---
   };
//struct strOrdersCount
//   {
//   int Buy,Sell,BuyLimit,SellLimit,BuyStop,SellStop,PendingOrders,TriggeredOrders;
//   };
//--- ВХОДНЫЕ ПАРАМЕТРЫ ---// input - нельзя менять программно // sinput - статический параметр (не может участвовать в оптимизации) // extern - можно менять программно   
sinput int InpTimeZonesDeviation          =0;                           // Смещение времени истории с учетом часовых поясов (час) 
input int InpOpenTimeDeviation            =2;                           // Допустимое отклонение от времени открытия (мин)
input int InpOpenPriceDeviation           =2;                           // Допустимое отклонение от цены открытия (п)
input int InpStopLoss                     =50;                          // Стоп лосс (п)
input int InpTakeProfit                   =50;                          // Тейк профит (п)
input double InpLots                      =0.1;                         // Лот
sinput string InpHistoryFileName          ="xxxxx.history";             // Имя файла с историей сделок
//--- ПЕРЕМЕННЫЕ ---
//strOrdersCount Ord1;
strHistOrders HistOrders[];                                          // список ордеров из истории сигналов
strHistOrders SkippedHistOrders[];                                          // список ордеров из истории сигналов
int Slippage=3;                        // Проскальзывание
int DoneOrdersCount=0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
   {
   //---
   Comment("");                                                      // очистим поле комментария на графике  
   //if(!EventSetTimer(60))                                            // устанавливаем таймер, интервал 60 сек
   //   Alert(Symbol(),"Ошибка: ",GetLastError(),". Не удалось установить таймер!");   
   //--- 
   ArrayResize(HistOrders,0,100);
   ArrayResize(SkippedHistOrders,0,50);
   DoneOrdersCount=0;
   //---
   string file_name=EXPERT_NAME+"\\"+InpHistoryFileName+".csv";             // путь к файлу с историей сделок
   if(FileIsExist(file_name))
      {
      LoadHistOrders(file_name,HistOrders);
      //Print(ArraySize(HistOrders));
      }
   else
      {
      if(FolderCreate(EXPERT_NAME))
         {
         Print("Создана папка: ",EXPERT_NAME);
         }   
      Print("Не найден файл с историей сделок: ",file_name," Работа советника прекращена!");
      return(INIT_PARAMETERS_INCORRECT);
      }   
   //---
   return(INIT_SUCCEEDED);
   //---
   }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
   {
   //---
   //EventKillTimer();                                                 // уничтожаем таймер
   //Comment("");                                                      // очистим поле комментария на графике
   //---
   string comment="";
   comment+="Успешно открыто: "+string(DoneOrdersCount)+" \n";
   comment+="Пропущено ордеров: "+string(ArraySize(SkippedHistOrders))+" \n";
   for(int i=0;i<ArraySize(SkippedHistOrders);++i)
      {
      //---
      string stype=OrderTypeToString(SkippedHistOrders[i].Type);
      if(stype=="Sell") stype+=" ";     // чтоб колонки были ровными
      comment+=TimeToString(SkippedHistOrders[i].OpenTime,TIME_DATE|TIME_SECONDS)+"  "+stype+"  "+DoubleToString(SkippedHistOrders[i].OpenPrice,Digits())+" \n"; 
      //---
      } //for(i)
   Comment(comment);   
   //---   
   }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
   {
   //---
   //---
   if(ArraySize(HistOrders)>0)
      {
      //---
      static datetime next_open_time=0;
      //next_open_time=0; //////!!!!!!!!!!!!!!!!!!!!!
      if(TimeCurrent()>=next_open_time)                              // ограничиваем пробежки по списку ордеров истории, чтоб ускорить тестирование
         {
         //---
         string comment="";
         comment+="Ордеров в списке: "+string(ArraySize(HistOrders))+" \n";
         comment+="Успешно открыто: "+string(DoneOrdersCount)+" \n";
         comment+="Пропущено: "+string(ArraySize(SkippedHistOrders))+" \n";
         //--- 
         next_open_time=HistOrders[0].OpenTime;       
         for(int i=ArraySize(HistOrders)-1;i>=0;--i)
            {
            //--- comment
            string stype=OrderTypeToString(HistOrders[i].Type);
            if(stype=="Sell") stype+=" ";     // чтоб колонки были ровными
            comment+=TimeToString(HistOrders[i].OpenTime,TIME_DATE|TIME_SECONDS)+"  "+stype+"  "+DoubleToString(HistOrders[i].OpenPrice,Digits())+" \n";        
            //--- определяем время открытия
            datetime open_time1=HistOrders[i].OpenTime-InpOpenTimeDeviation*60+InpTimeZonesDeviation*60*60;  // время, начиная с которого нужно открыть позицию + учет смещения часовых поясов
            datetime open_time2=HistOrders[i].OpenTime+InpOpenTimeDeviation*60+InpTimeZonesDeviation*60*60;  // крайний срок, до которого нужно открыть позицию + учет смещения часовых поясов
            if(open_time1<next_open_time) next_open_time=open_time1; // запомним самое раннее время открытия в списке, чтоб лишний раз не перепроверять
            //--- если вписываемся во временной промежуток открытия
            if(TimeCurrent()>=open_time1 && TimeCurrent()<=open_time2)
               {
               //---
               double open_price1=HistOrders[i].OpenPrice-InpOpenPriceDeviation*Point();  // нижний порог цены, по которой можно открыть ордер
               double open_price2=HistOrders[i].OpenPrice+InpOpenPriceDeviation*Point();  // верхний порог цены, по которой можно открыть ордер
               //---
               if(HistOrders[i].Type==OP_BUY)
                  {
                  //--- если вписались в ценовой промежуток
                  if(Ask>=open_price1 && Ask<=open_price2)
                     {
                     Print("Открытие Buy. Цена открытия, реальная (сигнальная): ",DoubleToString(Ask,Digits())," (",DoubleToString(HistOrders[i].OpenPrice,Digits()),")");     
                     double sl_points=ND(InpStopLoss*Point());
                     double tp_points=ND(InpTakeProfit*Point()); 
                     double lot=NormalizeDouble(InpLots,2);   
                     int err;
                     int ticket=OpenOrder(err,Symbol(),OP_BUY,lot,1,sl_points,tp_points,"",0,CLR_BUY_OPEN);
                     if(ticket<=0)   
                        {
                        Print("Не удалось открыть ордер!!! Error: ",ErrorDescriptionRu(err));
                        }
                     ++DoneOrdersCount;                                          // считаем совершенные сделки
                     DeleteOrderFromList(HistOrders,i);                          // удаляем элемент из списка
                     continue;                                                   // продолжим
                     }
                  //---
                  }
               else if(HistOrders[i].Type==OP_SELL)
                  {
                  //--- если вписались в ценовой промежуток
                  if(Bid>=open_price1 && Bid<=open_price2)
                     {
                     Print("Открытие Sell. Цена открытия, реальная (сигнальная): ",DoubleToString(Bid,Digits())," (",DoubleToString(HistOrders[i].OpenPrice,Digits()),")");     
                     double sl_points=ND(InpStopLoss*Point());
                     double tp_points=ND(InpTakeProfit*Point()); 
                     double lot=NormalizeDouble(InpLots,2);   
                     int err;
                     int ticket=OpenOrder(err,Symbol(),OP_SELL,lot,1,sl_points,tp_points,"",0,CLR_SELL_OPEN);
                     if(ticket<=0)   
                        {
                        Print("Не удалось открыть ордер!!! Error: ",ErrorDescriptionRu(err));
                        }
                     ++DoneOrdersCount;                                          // считаем совершенные сделки
                     DeleteOrderFromList(HistOrders,i);                          // удаляем элемент из списка
                     continue;                                                   // продолжим
                     }
                  //---
                  }
               //---
               }
            //--- если ордер уже безвозратно устарел, удалим его из списка и посчитаем
            else if(TimeCurrent()>open_time2)
               {
               //--- добавляем запись в список пропущенных ордеров
               int size=ArraySize(SkippedHistOrders);
               ArrayResize(SkippedHistOrders,size+1);                            // увеличиваем список пропущенных 
               SkippedHistOrders[size].OpenTime=HistOrders[i].OpenTime;
               SkippedHistOrders[size].OpenPrice=HistOrders[i].OpenPrice;
               SkippedHistOrders[size].Type=HistOrders[i].Type;
               SkippedHistOrders[size].OrdSymbol=HistOrders[i].OrdSymbol;
               //--- отрисуем метку в том месте, где должен был быть ордер
               DrawPriceLabel(EXPERT_NAME+"_skipped_"+OrderTypeToString(SkippedHistOrders[size].Type)+"_"+TimeToString(SkippedHistOrders[size].OpenTime,TIME_DATE|TIME_MINUTES),SkippedHistOrders[size].OpenPrice,SkippedHistOrders[size].OpenTime,SkippedHistOrders[size].Type,2);
               //---
               DeleteOrderFromList(HistOrders,i);                                // удаляем элемент из списка
               continue;                                                         // продолжим
               //---
               }              
            //---
            } //for(i)
         //---
         Comment(comment);
         //---
         }
      //---        
      }
   //---
   }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
   {
   //--- 
   //---
   }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
   {
   //---   
   //---
   }
//+------------------------------------------------------------------+
//----------------------------------------------------------
//---
//----------------------------------------------------------
bool LoadHistOrders(string file_name,strHistOrders &hist_orders[])
   {
   //---
   if(!FileIsExist(file_name))
      {
      return(false);
      }
   //--- откроем файл
   int handle=FileOpen(file_name,FILE_TXT|FILE_READ|FILE_SHARE_READ);   // ,";"      // открываем как текстовый файл
   if(handle<0) 
      {
      Alert("Не могу открыть файл: ",file_name);
      return(false);
      }
   //--- очищаем  
   int size=0;
   ArrayResize(hist_orders,size,100);
   //---           
   string sep=";";                                 // разделитель в виде символа
   ushort u_sep=StringGetCharacter(sep,0);         // код символа разделителя
   //--- считываем данные
   const int cols=13;
   string str1; 
   while(!FileIsEnding(handle))
      {
      //---
      str1=FileReadString(handle);
      string str[];
      int k=StringSplit(str1,u_sep,str);              // перепишем строку в массив   
      if(k>=cols)                                     // если считано достаточное количество значений, переписываем нужные нам в структуру
         { 
         //--- проверяем, что сделка по текущему символу
         if(str[3]==Symbol())
            {
            string stype=StringTrimLeft(StringTrimRight(str[1]));
            ENUM_ORDER_TYPE type=-1;
            if(stype=="Sell") type=OP_SELL;
            if(stype=="Buy") type=OP_BUY;
            if(type==OP_SELL || type==OP_BUY)
               {
               //---
               ++size;  // увеличиваем размер
               ArrayResize(hist_orders,size);
               hist_orders[size-1].OpenTime=StringToTime(str[0]);
               hist_orders[size-1].Type=type;
               hist_orders[size-1].OrdSymbol=str[3];
               hist_orders[size-1].OpenPrice=StringToDouble(str[4]);
               //---
               }
            }     
         //---  
         }
      //---
      } //while
   //--- закроем файл
   FileClose(handle);
   return(true);   
   //---
   }
////--------------------------------------------------------------------|
////---                    Учет ордеров                             
////--------------------------------------------------------------------|
//void CountOrders(int magic,string symbol,strOrdersCount &orders_count)  
//   {
//   orders_count.Buy=0;
//   orders_count.Sell=0;
//   orders_count.BuyLimit=0;
//   orders_count.SellLimit=0;
//   orders_count.BuyStop=0;
//   orders_count.SellStop=0;
//   orders_count.PendingOrders=0;
//   orders_count.TriggeredOrders=0;
//   int type;
//   int tiket=-1;                 
//   for(int pos=OrdersTotal()-1;pos>=0;pos--)
//      {
//      if(OrderSelect(pos,SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber()==magic && OrderSymbol()==symbol && OrderTicket()!=tiket)
//         {
//         tiket=OrderTicket();             // c помощью этой переменной исключаем возможность двойного счета, если ордер закроется во время исполнения цикла
//         type=OrderType();
//         switch(type)
//            {
//            case 0:{orders_count.Buy++;         orders_count.TriggeredOrders++;  break;}
//            case 1:{orders_count.Sell++;        orders_count.TriggeredOrders++;  break;}
//            case 2:{orders_count.BuyLimit++;    orders_count.PendingOrders++;    break;}
//            case 3:{orders_count.SellLimit++;   orders_count.PendingOrders++;    break;}
//            case 4:{orders_count.BuyStop++;     orders_count.PendingOrders++;    break;}
//            case 5:{orders_count.SellStop++;    orders_count.PendingOrders++;    break;}
//            }
//         }
//      }   
//   }   
//+------------------------------------------------------------------+
//|   отправка ордера (с sl и tp в поинтах!)                                                              
//+------------------------------------------------------------------+
int OpenOrder(int &err,string symbol,int cmd,double lot,int slippage,double stop_loss,double take_profit,string commentary,int magic=0,color arrow_color=clrNONE)
   {
   //---   
   RefreshRates();                  // обновим цены, для корректной проверки sl и tp
   err=GetLastError();              // номер ошибки (После вызова функции содержимое переменной _LastError обнуляется.)
   err=0;                           // обнулим 
   if(cmd!=OP_BUY && cmd!=OP_SELL) return(-1);        // функция только для открытия рыночных ордеров
   //--- проверяем лот
   lot=NormalizeDouble(lot,2);                        // 2 цифры после запятой
   if(lot<MarketInfo(symbol,MODE_MINLOT)) {Print("Попытка открыть сделку лотом меньше минимально допустимого!"); return(-1);}
   if(lot>MarketInfo(symbol,MODE_MAXLOT)) {Print("Попытка открыть сделку лотом больше максимально допустимого!"); return(-1);}
   //--- проверяем стопы
   int digits=(int)MarketInfo(symbol,MODE_DIGITS);           // получим количество знаков после запятой для символа
   //price=NormalizeDouble(price,digits);
   stop_loss=NormalizeDouble(stop_loss,digits);
   take_profit=NormalizeDouble(take_profit,digits);
   double bid=SymbolInfoDouble(symbol,SYMBOL_BID),
          ask=SymbolInfoDouble(symbol,SYMBOL_ASK);
   double spread=ask-bid;
   double stop_level=MarketInfo(symbol,MODE_STOPLEVEL)*MarketInfo(symbol,MODE_POINT);           // получаем StopLevel
   if(stop_loss<0 || take_profit<0) 
      {
      err=ERR_INVALID_STOPS;
      return(-1);
      }
   //--- sl
   if(stop_loss>0 && stop_loss<stop_level+spread) 
      {
      Alert("StopLoss меньше StopLevel!");
      err=ERR_INVALID_STOPS;
      return(-1);
      }
   //--- tp
   if(take_profit>0 && take_profit<stop_level) 
      {
      Alert("TakeProfit меньше StopLevel!");
      err=ERR_INVALID_STOPS;
      return(-1);
      }            
   //--- проверим, достаточно ли средств для открытия сделки
   if(cmd==OP_BUY || cmd==OP_SELL)                             // для рыночных ордеров проверим достаточно ли средств на счету для открытия сделки   
      if(AccountFreeMarginCheck(symbol,cmd,lot)<=0)            // если средств не хватает 
         {
         err=GetLastError();        // получим номер ошибки
         Alert(__FUNCTION__," Ошибка: ",err," Недостаточно денег для открытия позиции! ");  // отображаем ошибку с описанием  
         return(-1);                // вернем неудачу
         } 
   //---         
   bool exit_loop=false;            // переменная для выхода из цикла
   int ticket=-1;                   // тикет
   int count=0;                     // счетчик попыток
   //--- проверим можно ли торговать в этом направлении
   //if(!IsTesting())
   //   {
   //   if(!IsExpertEnabled()) err=ERR_TRADE_DISABLED;              // если торговля запрещена
   //   if(!IsConnected()) err=ERR_NO_CONNECTION;                   // нет соединения
   //   if(!IsTradeAllowed()) err=ERR_TRADE_NOT_ALLOWED;            // Торговля не разрешена. Необходимо включить опцию "Разрешить советнику торговать"
   //   if(IsTradeContextBusy()) err=ERR_TRADE_CONTEXT_BUSY;        // торговый поток занят
   //   }
   if(err!=0) return(-1);           // не готовы к торговле
   //--- отправляем ордер
   while(!exit_loop)
      {
      //---
      count++;                      // считаем попытки
      //--- посылаем ордер
      RefreshRates();
      double price=0,sl=0,tp=0;
      if(cmd==OP_BUY) 
         {
         price=NormalizeDouble(ask,digits);
         if(stop_loss!=0) sl=NormalizeDouble(price-stop_loss,digits);
         if(take_profit!=0) tp=NormalizeDouble(price+take_profit,digits);
         } 
      else if(cmd==OP_SELL)
         {
         price=NormalizeDouble(bid,digits);
         if(stop_loss!=0) sl=NormalizeDouble(price+stop_loss,digits); 
         if(take_profit!=0) tp=NormalizeDouble(price-take_profit,digits);
         }
      //---
      ticket=OrderSend(symbol,cmd,lot,price,slippage,sl,tp,commentary,magic,0,arrow_color);     // открываем ордер
      err=GetLastError();           // получаем значение ошибки
      if(err==ERR_NO_ERROR && ticket>0)      // если ошибок нет...
         {
         return(ticket);            // вернем тикет
         }   
      //--- если ордер не открылся
      Sleep(ORDER_SEND_TRY_DELAY);  // задержка между попытками             
      if(count>=ORDER_SEND_MAX_RETRY)
         {
         exit_loop=true;            // если количество попыток превышено, выходим из цикла 
         if(err!=ERR_NO_ERROR)      // если мы выходим из цикла, но ошибка осталась (ордер не открылся)
            Print(__FUNCTION__," Ошибка: ",err);  // отображаем ошибку с описанием
         }
      //--- проверяем ошибку
      switch(err)
         {
         case ERR_TOO_FREQUENT_REQUESTS:                    // слишком частые запросы !!!
         case ERR_TOO_MANY_REQUESTS:                        // слишком много запросов !!!       
            Alert("Внимание!!! Ошибка: ",err,". Слишком много запросов!");   /// ? еще никогда не видел эту ошибку в жизни
         case ERR_NO_ERROR:                                 // нет ошибки, значит ордер установлен              
         case ERR_NO_RESULT:                                // результат неизвестен
         case ERR_COMMON_ERROR:                             // общая ошибка !
         case ERR_ACCOUNT_DISABLED:                         // счет заблокирован !
         case ERR_TRADE_DISABLED:                           // торговля запрещена !
         case ERR_NOT_ENOUGH_MONEY:                         // недостаточно денег
         case ERR_MARKET_CLOSED:                            // рынок закрыт
         case ERR_TRADE_TOO_MANY_ORDERS:                    // количество ордеров достигло предела разрешенного брокером
         case ERR_TRADE_NOT_ALLOWED:                        // Торговля не разрешена. Необходимо включить опцию "Разрешить советнику торговать" в свойствах эксперта
         case ERR_LONGS_NOT_ALLOWED:                        // запрещены покупки
         case ERR_SHORTS_NOT_ALLOWED:                       // запрещены продажи
         case ERR_TRADE_EXPERT_DISABLED_BY_SERVER:          // Автоматическая торговля с помощью экспертов/скриптов запрещена на стороне сервера      
         case ERR_INVALID_TRADE_VOLUME:                     // неправильный объем
            return(-1);                                 // выходим из цикла (либо все хорошо, либо все плохо и пытаться больше не стоит
            break;
         //---
         case ERR_SERVER_BUSY:                              // сервер занят
         case ERR_NO_CONNECTION:                            // нет связи с торговым сервером
         case ERR_BROKER_BUSY:                              // брокер занят
         case ERR_TRADE_CONTEXT_BUSY:                       // торговый поток занят
            for(int i=0;i<=5;i++)
               {
               Sleep(5000);                                 // ждем 5 сек
               if(!IsConnected() || IsTradeContextBusy())   // если соединения еще нет или торговый поток занят
                  continue;                                 // следующая итерация...
               }
            if(!IsConnected() || IsTradeContextBusy())      // если соединения еще нет или торговый поток занят
               return(-1);                               // выход из цикла (нет связи)        
            break;
         //---
         case ERR_INVALID_PRICE:                            // если неполадки с ценой 
         case ERR_PRICE_CHANGED:
         case ERR_OFF_QUOTES: 
         case ERR_REQUOTE:      
         case ERR_INVALID_STOPS:
         case ERR_INVALID_PRICE_PARAM:                      // неправильные параметры цены (скорее всего не нормализованные)      
            //RefreshRates(); 
            //return(-1);                                  // выход из цикла
            break;
         //---
         default:
            Print(__FUNCTION__," Ошибка: ",err," ",ErrorDescriptionRu(err));  // отображаем ошибку с описанием
            break;   
         } //switch(err)
      //---
      } //while(!exit_loop)
   Print("Ошибка открытия ордера после ",count," попыток.");
   return(-1);                      // не удалось открыть ордер, вернем -1  
   //---
   } 
//+------------------------------------------------------------------+
//|    Функция возвращает описание ошибки на русском языке           |
//+------------------------------------------------------------------+
string ErrorDescriptionRu(int error_code)
  {
   string error_string;
//---
   switch(error_code)
     {
      //--- codes returned from trade server
      case 0:   error_string="Нет ошибки";                                                   break;
      case 1:   error_string="Нет ошибки, но результат неизвестен";                          break;
      case 2:   error_string="Общая ошибка";                                                 break;
      case 3:   error_string="Неправильные параметры";                                       break;
      case 4:   error_string="Торговый сервер занят";                                        break;
      case 5:   error_string="Старая версия клиентского терминала";                          break;
      case 6:   error_string="Нет связи с торговым сервером";                                break;
      case 7:   error_string="Недостаточно прав";                                            break;
      case 8:   error_string="Слишком частые запросы";                                       break;
      case 9:   error_string="Недопустимая операция, нарушающая функционирование сервера";   break;
      case 64:  error_string="Счет заблокирован";                                            break;
      case 65:  error_string="Неправильный номер счета";                                     break;
      case 128: error_string="Истек срок ожидания совершения сделки";                        break;
      case 129: error_string="Неправильная цена";                                            break;
      case 130: error_string="Неправильные стопы";                                           break;
      case 131: error_string="Неправильный объем";                                           break;
      case 132: error_string="Рынок закрыт";                                                 break;
      case 133: error_string="Торговля запрещена";                                           break;
      case 134: error_string="Недостаточно денег для совершения операции";                   break;
      case 135: error_string="Цена изменилась";                                              break;
      case 136: error_string="Нет цен";                                                      break;
      case 137: error_string="Брокер занят";                                                 break;
      case 138: error_string="Новые цены";                                                   break;
      case 139: error_string="Ордер заблокирован и уже обрабатывается";                      break;
      case 140: error_string="Разрешена только покупка";                                     break;
      case 141: error_string="Слишком много запросов";                                       break;
      case 145: error_string="Модификация запрещена, так как ордер слишком близок к рынку";  break;
      case 146: error_string="Подсистема торговли занята";                                   break;
      case 147: error_string="Использование даты истечения ордера запрещено брокером";       break;
      case 148: error_string="Количество открытых и отложенных ордеров достигло предела, установленного брокером";    break;
      case 149: error_string="Попытка открыть противоположный ордер в случае, если хеджирование запрещено";           break;
      case 150: error_string="Попытка закрыть позицию по инструменту в противоречии с правилом FIFO";                 break;
      //--- mql4 errors --- еще нужно перевести!
      case 4000: error_string="no error (never generated code)";                             break;
      case 4001: error_string="wrong function pointer";                                      break;
      case 4002: error_string="array index is out of range";                                 break;
      case 4003: error_string="no memory for function call stack";                           break;
      case 4004: error_string="recursive stack overflow";                                    break;
      case 4005: error_string="not enough stack for parameter";                              break;
      case 4006: error_string="no memory for parameter string";                              break;
      case 4007: error_string="no memory for temp string";                                   break;
      case 4008: error_string="non-initialized string";                                      break;
      case 4009: error_string="non-initialized string in array";                             break;
      case 4010: error_string="no memory for array\' string";                                break;
      case 4011: error_string="too long string";                                             break;
      case 4012: error_string="remainder from zero divide";                                  break;
      case 4013: error_string="zero divide";                                                 break;
      case 4014: error_string="unknown command";                                             break;
      case 4015: error_string="wrong jump (never generated error)";                          break;
      case 4016: error_string="non-initialized array";                                       break;
      case 4017: error_string="dll calls are not allowed";                                   break;
      case 4018: error_string="cannot load library";                                         break;
      case 4019: error_string="cannot call function";                                        break;
      case 4020: error_string="expert function calls are not allowed";                       break;
      case 4021: error_string="not enough memory for temp string returned from function";    break;
      case 4022: error_string="system is busy (never generated error)";                      break;
      case 4023: error_string="dll-function call critical error";                            break;
      case 4024: error_string="internal error";                                              break;
      case 4025: error_string="out of memory";                                               break;
      case 4026: error_string="invalid pointer";                                             break;
      case 4027: error_string="too many formatters in the format function";                  break;
      case 4028: error_string="parameters count is more than formatters count";              break;
      case 4029: error_string="invalid array";                                               break;
      case 4030: error_string="no reply from chart";                                         break;
      case 4050: error_string="invalid function parameters count";                           break;
      case 4051: error_string="invalid function parameter value";                            break;
      case 4052: error_string="string function internal error";                              break;
      case 4053: error_string="some array error";                                            break;
      case 4054: error_string="incorrect series array usage";                                break;
      case 4055: error_string="custom indicator error";                                      break;
      case 4056: error_string="arrays are incompatible";                                     break;
      case 4057: error_string="global variables processing error";                           break;
      case 4058: error_string="global variable not found";                                   break;
      case 4059: error_string="function is not allowed in testing mode";                     break;
      case 4060: error_string="function is not confirmed";                                   break;
      case 4061: error_string="send mail error";                                             break;
      case 4062: error_string="string parameter expected";                                   break;
      case 4063: error_string="integer parameter expected";                                  break;
      case 4064: error_string="double parameter expected";                                   break;
      case 4065: error_string="array as parameter expected";                                 break;
      case 4066: error_string="requested history data is in update state";                   break;
      case 4067: error_string="internal trade error";                                        break;
      case 4068: error_string="resource not found";                                          break;
      case 4069: error_string="resource not supported";                                      break;
      case 4070: error_string="duplicate resource";                                          break;
      case 4071: error_string="cannot initialize custom indicator";                          break;
      case 4072: error_string="cannot load custom indicator";                                break;
      case 4099: error_string="end of file";                                                 break;
      case 4100: error_string="some file error";                                             break;
      case 4101: error_string="wrong file name";                                             break;
      case 4102: error_string="too many opened files";                                       break;
      case 4103: error_string="cannot open file";                                            break;
      case 4104: error_string="incompatible access to a file";                               break;
      case 4105: error_string="no order selected";                                           break;
      case 4106: error_string="unknown symbol";                                              break;
      case 4107: error_string="invalid price parameter for trade function";                  break;
      case 4108: error_string="invalid ticket";                                              break;
      case 4109: error_string="trade is not allowed in the expert properties";               break;
      case 4110: error_string="longs are not allowed in the expert properties";              break;
      case 4111: error_string="shorts are not allowed in the expert properties";             break;
      case 4200: error_string="object already exists";                                       break;
      case 4201: error_string="unknown object property";                                     break;
      case 4202: error_string="object does not exist";                                       break;
      case 4203: error_string="unknown object type";                                         break;
      case 4204: error_string="no object name";                                              break;
      case 4205: error_string="object coordinates error";                                    break;
      case 4206: error_string="no specified subwindow";                                      break;
      case 4207: error_string="graphical object error";                                      break;
      case 4210: error_string="unknown chart property";                                      break;
      case 4211: error_string="chart not found";                                             break;
      case 4212: error_string="chart subwindow not found";                                   break;
      case 4213: error_string="chart indicator not found";                                   break;
      case 4220: error_string="symbol select error";                                         break;
      case 4250: error_string="notification error";                                          break;
      case 4251: error_string="notification parameter error";                                break;
      case 4252: error_string="notifications disabled";                                      break;
      case 4253: error_string="notification send too frequent";                              break;
      case 5001: error_string="too many opened files";                                       break;
      case 5002: error_string="wrong file name";                                             break;
      case 5003: error_string="too long file name";                                          break;
      case 5004: error_string="cannot open file";                                            break;
      case 5005: error_string="text file buffer allocation error";                           break;
      case 5006: error_string="cannot delete file";                                          break;
      case 5007: error_string="invalid file handle (file closed or was not opened)";         break;
      case 5008: error_string="wrong file handle (handle index is out of handle table)";     break;
      case 5009: error_string="file must be opened with FILE_WRITE flag";                    break;
      case 5010: error_string="file must be opened with FILE_READ flag";                     break;
      case 5011: error_string="file must be opened with FILE_BIN flag";                      break;
      case 5012: error_string="file must be opened with FILE_TXT flag";                      break;
      case 5013: error_string="file must be opened with FILE_TXT or FILE_CSV flag";          break;
      case 5014: error_string="file must be opened with FILE_CSV flag";                      break;
      case 5015: error_string="file read error";                                             break;
      case 5016: error_string="file write error";                                            break;
      case 5017: error_string="string size must be specified for binary file";               break;
      case 5018: error_string="incompatible file (for string arrays-TXT, for others-BIN)";   break;
      case 5019: error_string="file is directory, not file";                                 break;
      case 5020: error_string="file does not exist";                                         break;
      case 5021: error_string="file cannot be rewritten";                                    break;
      case 5022: error_string="wrong directory name";                                        break;
      case 5023: error_string="directory does not exist";                                    break;
      case 5024: error_string="specified file is not directory";                             break;
      case 5025: error_string="cannot delete directory";                                     break;
      case 5026: error_string="cannot clean directory";                                      break;
      case 5027: error_string="array resize error";                                          break;
      case 5028: error_string="string resize error";                                         break;
      case 5029: error_string="structure contains strings or dynamic arrays";                break;
      //--- позовательские ошибки
      case 65536: error_string="---";                                           break;
      case 65537: error_string="---";                                           break;
      //---
      //---
      default:   error_string="unknown error";
     }
//---
   return(error_string);
  }   
//+------------------------------------------------------------------+
//|   Норамализация по Digits текущего символа                                                               
//+------------------------------------------------------------------+
double ND(double val) 
   {
   return(NormalizeDouble(val,Digits));
   }  
//----------------------------------------------------------
//--- удаляет указанный элемент списка
//----------------------------------------------------------
bool DeleteOrderFromList(strHistOrders &hist_orders[],int index)
   {
   //---
   if(index<0 || index>=ArraySize(hist_orders)) return(false);
   int size=ArraySize(hist_orders);
   for(int i=index;i<size-1;++i)                            // от указанного элемента и до предпоследнего
      {
      hist_orders[i].OpenTime=hist_orders[i+1].OpenTime;    // переносим следующий элемент на эту позизицию
      hist_orders[i].OpenPrice=hist_orders[i+1].OpenPrice;
      hist_orders[i].Type=hist_orders[i+1].Type;
      hist_orders[i].OrdSymbol=hist_orders[i+1].OrdSymbol;
      } //for(i)
   ArrayResize(hist_orders,size-1);                         // изменяем размер массива, делаем на один элемент меньше
   return(true);
   //---
   }   
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OrderTypeToString(ENUM_ORDER_TYPE type)      
   {
   //---
   switch(type)
      {
      case OP_BUY: return("Buy");
      case OP_SELL: return("Sell");
      case OP_BUYSTOP: return("BuyStop");
      case OP_SELLSTOP: return("SellStop");
      case OP_BUYLIMIT: return("BuyLimit");
      case OP_SELLLIMIT: return("SellLimit");
      default: return(string(type));
      }
   //---
   }     
//+------------------------------------------------------------------+
//---  Рисует ценовую метку
//+------------------------------------------------------------------+
bool DrawPriceLabel(string name,double price,datetime time,ENUM_ORDER_TYPE type,int width=2)      // type: OP_BUY - left, OP_SELL - right
   {
   long chart_ID=0;              // ID графика
   int sub_window=0;             // номер подокна
   color clr;
   if(type==OP_BUY) 
      clr=clrBlue; 
   else 
      clr=clrRed;  
   //---   
   if(ObjectFind(name)!=sub_window)                // если объекта с таким именем не существует, то создаем его
      {
      ENUM_LINE_STYLE   style=STYLE_SOLID;        // стиль
      bool              back=false;               // на заднем плане 
      ENUM_OBJECT       obj;  
      if(type==OP_BUY) obj=OBJ_ARROW_LEFT_PRICE; else obj=OBJ_ARROW_RIGHT_PRICE;             
      //--- создадим текстовую метку
      if(!ObjectCreate(chart_ID,name,obj,sub_window,time,price))
         {
         Print(__FUNCTION__,": не удалось создать ценовую метку! Код ошибки = ",GetLastError());
         return(false);     // объекта нет и создать не удалось! 
         } 
      //--- установим стиль окаймляющей линии
      ObjectSetInteger(chart_ID,name,OBJPROP_STYLE,style);
      //--- установим размер метки
      ObjectSetInteger(chart_ID,name,OBJPROP_WIDTH,width);
      //--- отобразим на переднем (false) или заднем (true) плане
      ObjectSetInteger(chart_ID,name,OBJPROP_BACK,back);
      }
   //--- установим цвет метки
   ObjectSetInteger(chart_ID,name,OBJPROP_COLOR,clr);
   //--- переместим точку привязки
   if(!ObjectMove(chart_ID,name,0,time,price))
      {
      //Print(__FUNCTION__,": не удалось переместить точку привязки! Код ошибки = ",GetLastError());
      return(false);
      }
   //---
   return(true); // объект либо создан, либо уже существует       
   }   