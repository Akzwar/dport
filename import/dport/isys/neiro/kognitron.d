module dport.isys.neiro.kognitron;

import dport.math.types, std.math;

version(unittest)
{ 
    import std.stdio, std.conv;
    void print(T)( in tensor!(2,T) t, string str="" )
    {
        if( str.length )
            stderr.writeln( str );
        foreach( x; 0 .. t.dim[0] )
        {
            foreach( y; 0 .. t.dim[1] )
                stderr.writef( "% 3s ", t[y,x] );
            stderr.writeln();
        }
    }
}

abstract class Layer(TYPE=float)
{
protected:
    Square output;
public:
    alias tensor!(2,TYPE) Square;
    abstract void set( Square, bool );
    final @property Square get() { return output; }
}

class InputLayer(TYPE=float): Layer!(TYPE)
{ override void set( Square s, bool dl=false ){ output = s; } }

unittest
{

    size_t[2] res = [ 9, 9 ];
    alias InputLayer!float.Square Square;

    auto map = Square( res );
    map.data[] = [.0f,0,0,0,0,0,0,0,0,
                    0,0,0,1,1,1,0,0,0,
                    0,0,0,0,1,1,0,0,0,
                    0,0,0,0,1,1,0,0,0,
                    0,0,0,0,1,1,0,0,0,
                    0,0,0,0,1,1,0,0,0,
                    0,0,0,0,1,1,0,0,0,
                    0,0,0,1,1,1,1,0,0,
                    0,0,0,0,0,0,0,0,0,
                 ];

    auto il = new InputLayer!float;
    il.set( map );
    auto il_get = il.get;

    assert( il_get.dim == map.dim );
    assert( il_get.data.length == map.data.length );
    foreach( i; 0 .. map.data.length )
        assert( abs(il_get.data[i] - map.data[i]) < 1e-8 );
}

class WorkLayer(TYPE=float): Layer!(TYPE)
{
protected:
    Square buf;
public:
    alias vec!("xy",size_s) vec2s;

    class Link
    {
        Square excit;
        Square inhib;
        Square lateral_inhib;

        Square last_input;
        TYPE last_output, last_inhib, last_excit;

        static void inhib_weight( ref Square s )
        {
            TYPE hx = (s.dim[0]-1)/2.0;
            TYPE hy = (s.dim[1]-1)/2.0;
            foreach( x; 0 .. s.dim[0] )
                foreach( y; 0 .. s.dim[1] )
                    s[x,y] = abs(x - hx) + abs(y - hy) + 0.2;
        }

        static void norm( ref Square s )
        {
            TYPE sum = 0;
            foreach( v; s.data ) sum += v;
            foreach( ref v; s.data ) v /= sum;
        }

        vec2s self;

        this( size_t[2][2] sizes, vec2s pos )
        {
            self = pos;
            excit = Square( sizes[0] );
            excit.data[] = 0;
            last_input = Square( sizes[0] );
            last_input.data[] = 0;

            inhib = Square( sizes[0] );
            inhib_weight( inhib );
            norm( inhib );

            lateral_inhib = Square( sizes[1] );
            inhib_weight( lateral_inhib );
            norm( lateral_inhib );
        }

        TYPE bi = 1;

        TYPE output( TYPE delegate( size_s, size_s ) fun )
        {
            TYPE E = 0, I = 0;
            auto half = vec2s( excit.dim[0]/2, excit.dim[1]/2 );

            foreach( x; 0 .. excit.dim[0] )
                foreach( y; 0 .. excit.dim[1] )
                {
                    auto buf = fun( self.x + x-half.x, self.y + y-half.y );
                    last_input[y,x] = buf; 
                    E += excit[y,x] * buf;
                    I += inhib[y,x] * buf;
                }

            //TYPE I = 0;
            //auto half = vec2s( inhib.dim[0]/2, inhib.dim[1]/2 );
            //foreach( x; inhib.dim[0] )
            //    foreach( y; inhib.dim[1] )
            //        I += inhib[x,y] * fun( self.x + x - half.x, self.y + y - half.y );

            I *= bi;

            last_output = ( E - I ) / ( 1.0 + I );
            last_output = last_output > 0 ? last_output : 0;
            last_excit = E;
            last_inhib = I;
            return last_output;
        }

        TYPE lateral( TYPE delegate( size_s, size_s ) fun )
        {
            TYPE I = 0;
            auto half = vec2s( lateral_inhib.dim[0]/2, lateral_inhib.dim[1]/2 );
            foreach( x; 0 .. lateral_inhib.dim[0] )
                foreach( y; 0 .. lateral_inhib.dim[1] )
                {
                    if( x - half.x && y - half.y )
                        I += lateral_inhib[y,x] * fun( self.x + x - half.x, self.y + y - half.y );
                }
            I *= bi;
            auto ret = ( last_output - I ) / ( 1.0 + I );
            ret = ret > 0 ? ret : 0;
            return ret;
        }

        void learn( float q, bool notwinner=false )
        {
            foreach( x; 0 .. excit.dim[0] )
                foreach( y; 0 .. excit.dim[1] )
                    excit[y,x] += q * inhib[y,x] * last_input[y,x];

            if( notwinner ) bi += q * last_inhib;
            else bi += q * last_excit * 0.5 / last_inhib;

            //if( notwinner )
            //    foreach( x; 0 .. lateral_inhib.dim[0] )
            //        foreach( y; 0 .. lateral_inhib.dim[1] )
            //            lateral_inhib[y,x] += q * last_inhib;
            //else
            //{
            //    foreach( x; 0 .. lateral_inhib.dim[0] )
            //        foreach( y; 0 .. lateral_inhib.dim[1] )
            //            lateral_inhib[y,x] += q * last_excit * 0.5 / last_inhib;
            //}
        }
    }

    tensor!(2,Link) links;

    vec2s[] mask_indexs;
    size_t mask_dim;

    void romb_mask( size_t width )
    {
        mask_dim = width;
        size_s c = width;
        mask_indexs.length = 0;
        foreach( i; 0 .. c )
        {
            size_s k = c/2-i >= 0 ? c/2+i+1 : c-i+c/2;
            foreach( j; abs(c/2 - i) .. k )
                mask_indexs ~= vec2s(j-c/2,i-c/2);
        }
    }

    this( size_t[2][3] sizes )
    {
        output = Square( sizes[0] );
        buf = Square( sizes[0] );
        romb_mask( sizes[1][0] );
        //links = new Link[][]( sizes[0][0], sizes[0][1] );
        links = tensor!(2,Link)( sizes[0] ); 
        foreach( x; 0 .. links.dim[0] )
            foreach( y; 0 .. links.dim[1] )
                links[x,y] = new Link( sizes[1 .. 3], vec2s( x,y ) );
    }

    static private
    {
        ref T f1(T)( tensor!(2,T) s, size_s ix, size_s iy )
        {
            size_t x = ( ix >= 0 ) ? ( ix < s.dim[0] ? ix : s.dim[0] - 1 ) : 0;
            size_t y = ( iy >= 0 ) ? ( iy < s.dim[0] ? iy : s.dim[1] - 1 ) : 0;
            return s[y,x];
        }

        ref T f2(T)( tensor!(2,T) s, size_s x, size_s y )
        {
            if( x < 0 || x >= s.dim[0] || y < 0 || y >= s.dim[1] ) return cast(T)false;
            return s[y,x];
        }
    }

    void learn( float q1, float q2 )
    {
        foreach( x; 0 .. output.dim[0] )
            foreach( y; 0 .. output.dim[1] )
            {
                size_s c = mask_dim;
                vec2s win_pos;
                TYPE win_val = 0;
                foreach( ind; mask_indexs )
                {
                    auto bval = f1( output, x + ind.x, y + ind.y );
                    if( win_val < bval )
                    {
                        win_pos = ind;
                        win_val = bval;
                    }
                }
                if( win_val == 0 )
                {
                    foreach( ind; mask_indexs )
                    {
                        auto link = f1( links, x + ind.x, y + ind.y );
                        if( link !is null ) link.learn( q2, true );
                    }
                }
                else
                {
                    foreach( ind; mask_indexs )
                        f1( output, x + ind.x, y + ind.y ) = ind == win_pos ? win_val : 0;
                    auto link = f1( links, win_pos.x, win_pos.y );
                    if( link !is null ) link.learn( q1 );
                }
            }
    }

    override void set( Square s, bool do_learn=false )
    { 
        foreach( i, link; links.data )
            buf.data[i] = link.output( (x,y){ return f1( s, x, y ); } );
                
        foreach( i, link; links.data )
            output.data[i] = link.lateral( (x,y){ return f1( buf, x, y ); } );

        //TYPE x = 0;
        //foreach( o; output.data ) x += o;
        //if(x) foreach( ref o; output.data ) o /= x;

        if(do_learn) learn( 16, 2 );
    }
}

class Kognitron(TYPE=float)
{
    alias InputLayer!(TYPE).Square Square;

    InputLayer!TYPE input;
    Layer!TYPE[] layers;

    Square output;

    this( size_t lcnt, size_t[2][3] sizes )
    {
        input = new typeof(input);
        layers ~= input;
        foreach( i; 0 .. lcnt )
            layers ~= new WorkLayer!TYPE( sizes );
    }

    Square proc( Square s, bool learn=false )
    {
        input.set( s );
        foreach( i; 1 .. layers.length )
            layers[i].set( layers[i-1].get(), learn );

        return layers[$-1].get();
    }
}

unittest
{
    size_t[2] res = [ 9, 9 ];
    auto k = new Kognitron!float( 5, [ res, [5UL,5], [7UL,7] ] );

    alias Kognitron!float.Square Square;

    auto map1 = Square( res );
    auto map2 = Square( res );

    map1.data[] = [.0f,0,0,0,0,0,0,0,0,
                     0,0,0,1,1,1,0,0,0,
                     0,0,0,0,1,1,0,0,0,
                     0,0,0,0,1,1,0,0,0,
                     0,0,0,0,1,1,0,0,0,
                     0,0,0,0,1,1,0,0,0,
                     0,0,0,0,1,1,0,0,0,
                     0,0,0,1,1,1,1,0,0,
                     0,0,0,0,0,0,0,0,0,
                 ];
    map2.data[] = [.0f,0,0,0,0,0,0,0,0,
                     0,0,1,1,1,1,1,0,0,
                     0,0,1,1,1,1,1,0,0,
                     0,0,0,0,0,1,1,0,0,
                     0,0,0,0,0,1,1,0,0,
                     0,0,0,0,0,1,1,0,0,
                     0,0,1,1,1,1,1,0,0,
                     0,0,1,1,1,1,1,0,0,
                     0,0,0,0,0,0,0,0,0,
                 ];

    Square ret;

    foreach( i; 0 .. 20 )
    {
        ret = k.proc( map1, true );
        //print( ret, " ---- map1 ret --- " ~ to!string(i) );

        ret = k.proc( map2, true );
        //print( ret, " ---- map2 ret --- " ~ to!string(i) );
    }
    auto ret1 = k.proc( map1 );
    auto ret2 = k.proc( map2 );

    print( ret1, " ---- map1 ret --- final" );
    print( ret2, " ---- map2 ret --- final" );

    import dport.isys.neiro.art;

    alias ART!(2,float,(a,b){ return abs(a-b); }) ART_m2;
    auto nart = new ART_m2( 0.01 );

    stderr.writeln( nart( ret1 ).val );
    stderr.writeln( nart( ret2 ).val );

    map1.data[] = [.0f,0,0,0,0,0,0,0,0,
                     0,0,0,1,0,1,0,0,0,
                     0,0,0,0,1,0,0,0,0,
                     0,0,0,0,1,1,0,0,0,
                     1,1,1,0,0,1,0,0,0,
                     0,1,1,0,1,0,0,0,0,
                     0,0,3,0,1,1,0,0,0,
                     0,0,0,1,1,1,1,0,0,
                     0,0,0,0,0,0,0,0,0,
                 ];
    map2.data[] = [.0f,0,0,0,0,0,0,0,0,
                     0,0,1,1,1,1,1,0,0,
                     0,0,1,0,0,0,1,0,0,
                     0,0,0,0,0,0,1,0,0,
                     0,0,0,0,0,0,1,0,0,
                     0,0,0,0,0,0,1,0,0,
                     0,0,1,0,0,0,1,0,0,
                     0,0,1,1,1,1,1,0,0,
                     0,0,0,0,0,0,0,0,0,
                 ];

    ret1 = k.proc( map1 );
    ret2 = k.proc( map2 );

    print( ret1, " ---- map1 ret --- final" );
    print( ret2, " ---- map2 ret --- final" );

    stderr.writeln( nart( ret1 ).val );
    stderr.writeln( nart( ret2 ).val );
}
