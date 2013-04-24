/++
базовые вещи для gui
 +/
module dport.gui.base;

public import dport.math.types;
public import dport.utils.signal;

alias vrect!int irect;

/++
 события клавиатуры
 +/
struct KeyboardEvent
{
    /++ нажата или отпущена клавиша +/
    bool pressed; 
    /++ код клавиши +/
    uint code;    
    /++ символ в unicode +/
    wchar symbol; 
    /++ модификаторы (SHIFT, ALT etc) See_Also: SDL key mods +/
    int mod;      
}

/++
 событие мыши
 +/
struct MouseEvent
{
    enum Type { PRESSED, RELEASED, MOTION };
    /++ тип события +/
    Type type; 
    /++ mask for motion, button for pressed/released +/
    long info; 
}

alias const ref ivec2 in_ivec2;
alias const ref KeyboardEvent in_KeyboardEvent;
alias const ref MouseEvent in_MouseEvent;
alias const ref irect in_irect;

alias IfListSignal!(in_ivec2, in_KeyboardEvent) IfKeyboardSignal;
alias IfListSignal!(in_ivec2, in_MouseEvent) IfMouseSignal;
alias Signal!(in_irect) ReshapeSignal;
alias Signal!(real) IdleSignal;

/++
 класс-обработчик событий

 заполнен Signal'ами для каждого события
 See_Also: Signal
 +/
class EventProc
{
    /++ события клавы с условием ( делегаты принимают положение мыши in ivec2 и само событие ) +/
    IfKeyboardSignal keyboard; 
    /++ события мыши с условием ( делегаты принимают положение мыши и само событие для мыши ) +/
    IfMouseSignal mouse;       
    /++ события обновления ( делегаты принимают ничего ) +/
    IdleSignal idle;           
    /++ события изменения размера ( делегаты принимают новый размер in irect ) +/
    ReshapeSignal reshape;     

    /++ события вызываются при "активации" элемента, например наведение мышью или фокус по табу +/
    EmptySignal activate;      
    /++ события вызываются при "деактивации" элемента +/
    EmptySignal release;       
}

/++
 базовый абстрактный класс для прямоугольных областей отрисовки
 +/
abstract class View: EventProc
{
protected:
    /++ ограничивающий прямоугольник +/
    irect bbox; 
public:

    /++ конструктор добавляет в reshape
        код, обновляющий bbox +/
    this() { reshape.connect( (r){ bbox = r; } ); }

    /++ деструктор вызывает сигнал release +/
    ~this() { release(); }

    final @property
    {
        /++ возвращает копию прямоугольника +/
        irect rect() const { return bbox; }

        /++ вызывает сигнал reshape +/
        void rect( in irect r ) { reshape( r ); }
    }

    /++ сигнал отрисовки +/
    SignalBoxNoArgs draw; 
}
