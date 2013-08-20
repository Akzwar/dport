module dport.math.interp;

import std.traits;

/++ табличные данные +/
struct tableVal(E,D) if( isFloatingPoint!E ) { E p; D val; }

/++ 
    линейная интерполяция по одномерному массиву
    данные должны быть отсортированы по полю p для правильной интерполяции
 +/
pure nothrow auto lineInterpolation(E,D)( in tableVal!(E,D)[] tbl, E v )
    if( is( typeof( D.init*E.init + D.init*E.init ) == D ) )
{
    if( v < tbl[0].p ) return tbl[0].val;
    if( v > tbl[$-1].p ) return tbl[$-1].val;

    size_t s = 0;
    size_t e = tbl.length-1;
    size_t c;

    while( e - s > 1 )
    {
        c = (s + e) / 2;

             if( tbl[c].p > v ) e = c;
        else if( tbl[c].p < v ) s = c;
        else if( tbl[c].p == v ) 
        {
            s = c;
            e = c + 1;
            break;
        }
    }

    auto k = ( v - tbl[s].p ) / ( tbl[e].p - tbl[s].p );
    return tbl[s].val * (1.0-k) + tbl[e].val * k;
}
