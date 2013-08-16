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
    /++ модификаторы (SHIFT, ALT etc) +/
    enum Mod
    {
        NONE = 0x0000,
        LSHIFT = 0x0001,
        RSHIFT = 0x0002,
        LCTRL = 0x0040,
        RCTRL = 0x0080,
        LALT = 0x0100,
        RALT = 0x0200,
        LGUI = 0x0400,
        RGUI = 0x0800,
        NUM = 0x1000,
        CAPS = 0x2000,
        MODE = 0x4000,
        CTRL = (LCTRL|RCTRL),
        SHIFT = (LSHIFT|RSHIFT),
        ALT = (LALT|RALT),
        GUI = (LGUI|RGUI),
    }
    /++ нажата или отпущена клавиша +/
    bool pressed;
    /++ если нажата и удерживается +/
    bool repeat;
    /++ код клавиши +/
    uint scan;
    uint key;
    /++ модификатор +/
    uint mod;
}

/++
 событие ввода текста
 +/
struct TextEvent { dchar ch; }

/++
 событие мыши
 +/
struct MouseEvent
{
    enum Type { PRESSED, RELEASED, MOTION, WHEEL };
    enum Button
    {
        LEFT   = 1<<0,
        MIDDLE = 1<<1,
        RIGHT  = 1<<2,
        X1     = 1<<3,
        X2     = 1<<4,
    }
    /++ тип события +/
    Type type; 
    /++ mask for motion, button for pressed/released, 0 for wheel+/
    uint btn; 
    ivec2 scroll = ivec2( 0, 0 );
}

/++
 событие джостика
 +/
struct JoyEvent
{
    /++ номер джостика +/
    uint joy;

    /++ тип события +/
    enum Type { AXIS, BUTTON, BALL, HAT };
    Type type;

    /++ номер изменившегося элемента +/
    size_t no;

    /++ состояние всех осей +/
    float[] axis;
    /++ состояние всех кнопок ( true - нажата, false - нет ) +/
    bool[] buttons;
    /++ состояние всех трэкболов +/
    int[2][] balls;
    /++ состояние всех шляпок +/
    byte[] hats;
}

alias const ref ivec2 in_ivec2;
alias const ref KeyboardEvent in_KeyboardEvent;
alias const ref TextEvent in_TextEvent;
alias const ref MouseEvent in_MouseEvent;
alias const ref JoyEvent in_JoyEvent;
alias const ref irect in_irect;

alias IfListSignal!(in_ivec2, in_KeyboardEvent) IfKeyboardSignal;
alias IfListSignal!(in_ivec2, in_TextEvent ) IfTextSignal;
alias IfListSignal!(in_ivec2, in_MouseEvent) IfMouseSignal;
alias IfListSignal!(in_ivec2, in_JoyEvent) IfJoySignal;
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
    /++ события ввода символов с условием +/
    IfTextSignal evtext;
    /++ события мыши с условием ( делегаты принимают положение мыши и само событие для мыши ) +/
    IfMouseSignal mouse;       
    /++ события джостика с условием +/
    IfJoySignal joystick;
    /++ события обновления ( делегаты принимают ничего ) +/
    IdleSignal idle;           
    /++ события изменения размера ( делегаты принимают новый размер in irect ) +/
    ReshapeSignal reshape;     

    /++ события вызываются при "активации" элемента, например наведение мышью или фокус по табу +/
    EmptySignal activate;      
    /++ события вызываются при "деактивации" элемента +/
    EmptySignal release;       
    /++ события вызываются при обновлении элемента, например смена языка +/
    EmptySignal update;
}

import std.traits;

/++ структура для хранения пределов +/
struct lim_t(T) if( isNumeric!T )
{
    T min=T.min, max=T.max;
    bool fix = false;
    T opCall( T old, T nval ) const
    {
        if( fix ) return old;
        return nval >= min ? ( nval < max ? nval : max ) : min;
    }
}

/++ структура для хранения пределов размера +/
struct size_lim_t(T) if( isNumeric!T )
{
    lim_t!T w, h;
    auto opCall(string A, E, string B, G)( in vec!(A,E) old, in vec!(B,G) nval ) const
        if( A.length == 2 && B.length == 2 && is( typeof( 1 ? E.init : G.init ) : T ) )
    {
        return vec!("wh",T)( w( old[0], nval[0] ), h( old[1], nval[1] ) );
    }
}

/++
 базовый абстрактный класс для прямоугольных областей отрисовки
 +/
abstract class BaseViewRect: EventProc
{
private:
    /++ ограничивающий прямоугольник +/
    irect bbox;
protected:
    /++ пределы для размера bbox +/
    size_lim_t!int size_lim;

    /++ принудительное изменение размера bbox, вне зависимости от фиксированности +/
    final void forceReshape( in irect r )
    {
        bool fw = size_lim.w.fix;
        bool fh = size_lim.h.fix;
        size_lim.w.fix = false;
        size_lim.h.fix = false;
        reshape( r );
        size_lim.w.fix = fw;
        size_lim.h.fix = fh;
    }
public:

    /++ конструктор добавляет в reshape
        код, обновляющий bbox +/
    this() 
    { 
        reshape.connect( (r) { 
                bbox.pos = r.pos;
                bbox.size = size_lim( bbox.size, r.size );
                } ); 
    }

    /++ деструктор вызывает сигнал release +/
    ~this() { release(); }

    final @property
    {
        /++ возвращает копию прямоугольника +/
        nothrow irect rect() const { return bbox; }
        /++ возвращает копию пределов размера прямоугольника +/
        nothrow size_lim_t!int lims() const { return size_lim; }

        /++ вызывает сигнал reshape +/
        void rect( in irect r ) { reshape( r ); }
    }

    /++ сигнал отрисовки +/
    SignalBoxNoArgs draw; 
}
