/++ Реализация концепции сигналов и слотов +/
module dport.utils.signal;

import std.conv;
import dport.utils.logsys;

mixin( defaultModuleLogUtils( "SignalException" ) );

/++
Структура предназначена для хранения и вызова делегатов,
как бы список необходимых действий.

Параметризуется списком типов.

Хранимые делегаты не возвращают значений, принимают аргументы согласно списку типов.
+/
struct Signal(Args...)
{ 
    /++
        хранит имя и делегат
    +/
    struct slottype { void delegate(Args) fun; }

    /++ "список дел" +/
    slottype[] slots; 

    /++ добавляет в список делегат с определённым именем +/
    void connect( void delegate(Args) f )
    {
        if( f is null ) throw new SignalException( "signal get null delegate" );
        slots ~= slottype( f );
    }

    /++ вызывает все делегаты в прямом порядке +/
    void opCall( Args args )
    { foreach( slot; slots ) slot.fun( args ); }

    /++ вызывает все делегаты в обратном порядке +/
    void callReverse( Args args )
    { foreach_reverse( slot; slots ) slot.fun( args ); }
}

alias Signal!() EmptySignal;

unittest
{
    uint[] array;
    EmptySignal stest;
    stest.connect( (){ array ~= 0; } );
    stest.connect( (){ array ~= 3; } );
    assert( array.length == 0 );
    stest();
    assert( array.length == 2 );
    assert( array == [ 0, 3 ] );
    stest.callReverse();
    assert( array.length == 4 );
    assert( array == [ 0, 3, 3, 0 ] );

    string[] sarr;
    Signal!string strsignal;
    with( strsignal )
    {
        connect( ( str ){ sarr ~= str; } );
        connect( ( str ){ sarr ~= str ~ str; } );
    }

    assert( sarr.length == 0 );
    strsignal( "ok" );
    assert( sarr == [ "ok", "okok" ] );

    debug log.utest( "signal unittest ok" );
}

/++
Расширяет концепцию Signal, выполняет в прямом порядке 
делегаты open из списка пар, затем выполняет в прямом порядке контент,
затем в обратном делегаты close из списка пар.

See_Also: Signal
+/
struct SignalBox(Args...)
{
    /++ тип пары делегатов +/
    struct pairtype
    {
        void delegate(Args) open;
        void delegate(Args) close;
    }

    /++ тип контента +/
    struct cntnttype { void delegate(Args) fun; }

    pairtype[] pairs;
    cntnttype[] content;

    /++ добавляет пару делегатов под определённым именем +/
    void addPair( void delegate(Args) o, void delegate(Args) c )
    {
        if( o is null ) throw new SignalException( "signalbox get null open delegate" );
        if( c is null ) throw new SignalException( "signalbox get null close delegate" );
        pairs ~= pairtype( o, c );
    }

    /++ добавляет контент +/
    void connect( void delegate(Args) f )
    {
        if( f is null ) throw new SignalException( "signalbox get null content delegate" );
        content ~= cntnttype( f );
    }

    /++ производит последовательный вызов всех open, затем контента, затем close +/
    void opCall( Args args )
    {
        open( args );
        cntnt( args );
        close( args );
    }

    void open( Args args ) { foreach( s; pairs ) s.open( args ); }
    void cntnt( Args args ) { foreach( c; content ) c.fun( args ); }
    void close( Args args ) { foreach_reverse( s; pairs ) s.close( args ); }
}

alias SignalBox!() SignalBoxNoArgs;

unittest
{
    string[] arr;
    SignalBoxNoArgs stest;
    stest.addPair( (){ arr ~= "open"; }, (){ arr ~= "close"; } );
    stest.connect( (){ arr ~= "content"; } );
    assert( arr.length == 0 );
    stest();
    assert( arr.length == 3 );
    assert( arr == [ "open", "content", "close" ] );
    auto except_test = false;
    try
        stest.connect( null );
    catch( SignalException e )
        except_test = true;
    assert( except_test );
    debug log.utest( "signalbox unittest ok" );
}

/++ 
Условный вызов всех слотов.

Поведение аналогичное Signal происходит в случае, если
все делегаты из списка условий возвращают значение, принятое за верное.
Иначе выполняется список altslots.
+/
struct IfListSignal(Args...)
{
    /++ тип условия

         если trueval совпадает с возвращаемым значением делегата
         условие считается выполненым
    +/
    struct condition
    {
        /++ делегат +/
        bool delegate(Args) fun; 
        /++ значение, принятое за верное +/
        bool trueval=false; 
    }

    struct slottype
    {
        void delegate(Args) fun;
    }

    condition[] conds;
    slottype[] slots;
    slottype[] altslots;

    /++ добавляет условие в список
        Params:
        f = делегат проверки
        name = имя условия
        trueval = "верное" значение
        +/
    void addCondition( bool delegate(Args) f, bool trueval=false )
    {
        if( f is null ) throw new SignalException( "iflistsignal get null condition delegate" );
        conds ~= condition( f, trueval );
    }

    /++ добавляет слот в список slots
     +/
    void connect( void delegate(Args) f )
    {
        if( f is null ) throw new SignalException( "iflistsignal get null delegate" );
        slots ~= slottype( f );
    }

    /++ добавляет слот в список altslots
     +/
    void connectAlt( void delegate(Args) f )
    {
        if( f is null ) throw new SignalException( "iflistsignal get null delegate" );
        altslots ~= slottype( f );
    }

    /++ вызывает последовательно сначала условия, потом слоты

        при невыполнении условия прекращает проверку
        выполняет вызов слотов из списка altslots
    +/
    void opCall( Args args )
    {
        bool all = true;

        foreach( c; conds )
            if( c.fun( args ) != c.trueval ) 
            {
                all = false;
                break;
            }

        if( all ) foreach( s; slots ) s.fun( args );
        else foreach( a; altslots ) a.fun( args );
    }
}

unittest
{
    bool cond = true;

    int[] arr;

    IfListSignal!() stest;
    stest.addCondition( (){ return true; }, true );
    stest.connect( (){ arr ~= 0; } );
    stest.connectAlt( (){ arr ~= 1; } );

    stest();
    assert( arr == [ 0 ] );
    stest.addCondition( (){ return true; } );
    stest();
    assert( arr == [ 0, 1 ] );

    debug log.utest( "iflistsignal unittest ok" );
}
