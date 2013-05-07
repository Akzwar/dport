module dport.math.integ;

/++ Рунге-Кутта интегратор
 +  параметризируется: 
 +  f - правая часть, принимает только состояние и время
 +  T - тип состояния
 +  Params:
 +  x = текущее состояние (x_N)
 +  time = текущее время
 +  h = шаг
 +  Returns: x_{N+1}
 +/
T runge(alias f,T)( T x, double time, double h )
    if( is( typeof( f(x,time) ) : T ) && is( typeof(x+x) : T ) && is( typeof(x*h) : T ) )
{
    T k1 = f( x, time ) * h;
    T k2 = f( x + k1 * 0.5, time + h * 0.5 ) * h;
    T k3 = f( x + k2 * 0.5, time + h * 0.5 ) * h;
    T k4 = f( x + k3, time + h ) * h;
    return x + ( k1 + k2 * 2.0 + k3 * 2.0 + k4 ) / 6.0;
}

/++ Рунге-Кутта интегратор
 +  параметризируется: 
 +  f - правая часть, принимает только состояние (время не принимает)
 +  T - тип состояния
 +  Params:
 +  x = текущее состояние (x_N)
 +  h = шаг
 +  Returns: x_{N+1}
 +/
T runge(alias f,T)( T x, double h )
    if( is( typeof( f(x) ) : T ) && is( typeof(x+x) : T ) && is( typeof(x*h) : T ) )
{
    T k1 = f( x ) * h;
    T k2 = f( x + k1 * 0.5 ) * h;
    T k3 = f( x + k2 * 0.5 ) * h;
    T k4 = f( x + k3 ) * h;
    return x + ( k1 + k2 * 2.0 + k3 * 2.0 + k4 ) / 6.0;
}

unittest
{
    import dport.math.types;
    import std.stdio, std.math;

    auto fun( vec2 X ) { return vec2( X.y, 0 ); }

    auto state = vec2( 0, 10 );

    double step = .01;
    foreach( i; 0 .. cast(ulong)(1.0/step)+1 )
        state = runge!fun( state, step );

    assert( abs( state.x - state.y ) <= step*1e-3 );

    double v0 = 10;
    double a = 5;
    double t = 2;
    auto state2 = vec3( 0, v0, a );

    foreach( i; 0 .. cast(ulong)(t/step)+1 )
        state2 = runge!((X){return vec3( X.y, X.z, 0);})( state2, step );

    assert( abs( state2.x - v0*t - a*t*t/2.0 ) <= step*1e-3 );
}


private
{
import std.string;

string opStruct( string[] fields, string op, string bname )
{
    string str = "";
    foreach( field; fields )
        str ~= field ~ op ~ bname ~ "." ~ field ~ ", ";
    return str[0 .. $-2];
}

string opOne( string[] fields, string op, string bname )
{
    string str = "";
    foreach( field; fields )
        str ~= field ~ op ~ bname ~ ", ";
    return str[0 .. $-2];
}

bool isTrueFieldsStr( string str )
{
    bool checkFields( string[] fields )
    {
        foreach( field; fields )
        {
            foreach( i, c; field )
                switch( c )
                {
                    case 'a': .. case 'z':
                    case 'A': .. case 'Z': break;
                    case '0': .. case '9':
                        if( i ) break;
                        else goto default;
                    case '.':
                        if( i && i != field.length-1 && 
                                checkFields( split(field,".") ) ) break;
                        else goto default;
                    /+ TODO: 
                        добавить возможность обращения к полям и индексам
                    +/
                    default:
                        return false;
                        //assert( 0, "[integ]: string \"" ~ str ~ 
                        //        "\" contain bad name: \"" ~ field ~ "\"" );
                }
        }
        return true;
    }

    return checkFields( split( str ) ) ;
}

unittest
{
    assert( isTrueFieldsStr( "pos vel" ) );
    assert( isTrueFieldsStr( "okda" ) );
    assert( !isTrueFieldsStr( "1notok" ) );
    assert( !isTrueFieldsStr( "not 2ok" ) );
    assert( isTrueFieldsStr( "a1 a2" ) );

    auto fstr = "pos.x pos.y vel.x vel.y";
    assert( isTrueFieldsStr( fstr ) );
    assert( split( fstr ) == [ "pos.x", "pos.y", "vel.x", "vel.y" ] );
    assert( !isTrueFieldsStr( fstr[0 .. $-1] ) );
    assert( !isTrueFieldsStr( "ok.1" ) );
    assert( isTrueFieldsStr( "ok.no" ) );
}

}

mixin template IntegState( string fields_str )
    if( isTrueFieldsStr( fields_str ) )
{
    alias typeof(this) self;
    private import std.string;
    private enum fields = split( fields_str );

    auto opBinary(string op)( in self b ) const
        if( op == "+" || op == "-" )
    { mixin( "return self( " ~ opStruct( fields, op, "b" ) ~ "); " ); }

    auto opBinary(string op)( double b ) const
        if( op == "*" || op == "/" )
    { mixin( "return self( " ~ opOne( fields, op, "b" ) ~ "); " ); }
}

unittest
{
    struct vec
    {
        double x, y, z;
        mixin IntegState!"x y z";
    }

    struct point
    {
        vec pos, vel;
        mixin IntegState!"pos vel";
    }

    auto a = vec( 1, 2, 3 );
    auto b = vec( 3, 5, 0 );

    auto c = a * 12 + b / 2.0;
    assert( c.x == a.x * 12 + b.x / 2.0 &&
            c.y == a.y * 12 + b.y / 2.0 &&
            c.z == a.z * 12 + b.z / 2.0 );

    auto p1 = point( a, b );
    auto p2 = point( b, c );
    auto p3 = p1 * 0.5 + p2 * 1.5;
    assert( p3.pos == p1.pos * 0.5 + p2.pos * 1.5 && 
            p3.vel == p1.vel * 0.5 + p2.vel * 1.5 );

    struct inertial
    { 
        double val; 
        mixin IntegState!"val";
    }

    auto i1 = inertial( 10 );
    auto i2 = inertial( 2 );
    auto i3 = i1 * 0.4 - i2 * .1;
    assert( i3.val == i1.val * 0.4 - i2.val * .1 );
}
