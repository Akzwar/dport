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
