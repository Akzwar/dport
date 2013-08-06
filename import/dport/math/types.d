/++
 типы данных vec, mat, rect
 +/
module dport.math.types;

import std.math;

version(unittest) { import std.stdio; }

class TypeException: Exception
{ this( string msg ){ super( "[Types]: " ~ msg ); } }

static if( size_t.sizeof == long.sizeof ) alias long size_s;
else alias int size_s;

// CT_ - compile time assertion

private static pure size_s CT_getIndex( string str, string m )
{
    foreach( i, v; str ) if( m[0] == v ) return i;
    return -1;
}

private static pure bool CT_onlyTrueChars( string str )
{
    foreach( v; str )
        switch( v )
        {
            case 'a': .. case 'z': 
            case 'A': .. case 'Z': 
                break;
            default: 
                assert( 0, "[ [Types]: string '" ~ str ~ 
                        "' contain bad symbol: '" ~ v ~ "' ] " );
        }
    return true;
}

private static pure bool CT_trueString( string S )
{
    CT_onlyTrueChars( S );
    foreach( i; 0 .. S.length - 1 )
        foreach( j; i + 1 .. S.length )
            if( S[i] == S[j] ) 
                assert( 0, "[Types]: duplicates in string \"" ~ 
                        S ~ "\" (" ~ S[i] ~ ")" );
    return true;
}

private static pure bool CT_checkInexAll( string S, string v )
{
    CT_trueString(v);
    foreach( ch; v )
        if( CT_getIndex( S, ""~ch ) < 0 ) return false;
    return true;
}

unittest
{
    assert( CT_getIndex("xyz", "y") == 1 );
    assert( CT_getIndex("xyz", "x") == 0 );
    assert( CT_onlyTrueChars("xyz") );
    assert( CT_onlyTrueChars("rbg") );
}

template isAllConv(D,T...)
{
    static if( T.length == 0 ) enum bool isAllConv = true;
    else static if( T.length == 1 ) enum bool isAllConv = is( T[0] : D );
    else enum bool isAllConv = is( T[0] : D ) && isAllConv!( D, T[1 .. $ ] );
}

private static pure string toStr( size_s x )
{
    enum ch = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" ];
    string buf = x>=0?"":"-";
    x = x>0?x:-x;
    if( x < 10 ) buf ~= ch[x]; 
    else buf ~= toStr(x/10) ~ ch[x%10];
    return buf;
}

unittest
{
    assert( toStr( 124 ) == "124" );
    assert( toStr( -12 ) == "-12" );
}

private static pure string dataComp(string S, string v)
{
    string buf;
    foreach( ch; v )
        buf ~= "data[" ~ toStr( CT_getIndex(S,""~ch) ) ~ "],";
    return buf[0 .. $-1];
}

private template isComp( string A, E, string B, T )
{ enum bool isComp = A.length == B.length && is( E : T ); }

struct vec( string S, T=real )
    if( CT_trueString(S) && is( T : real ) )
{
    T[S.length] data;
    alias vec!(S,T) stype;

    this(E)( E[] ext... ) 
        if( is( E : T ) )
    {
        if( ext.length != S.length )
            throw new TypeException( "bad length: " ~ toStr(S.length) ~ 
                    " != " ~ toStr( ext.length ) );
        foreach( i, ref val; data ) 
            val = ext[i];
    }

    this(size_t H, size_t W, E)( in mat!(H,W,E) mtr )
        if( ( ( W == 1 && H == S.length ) || ( H == 1 && W == S.length ) ) && is( E : T ) )
    { foreach( i, ref val; data ) val = mtr[i]; }

    this(E...)( E ext ) 
        if( E.length == S.length && isAllConv!(T,E) )
    {
        foreach( i, val; ext ) 
            data[i] = val;
    }

    this(string G,E)( in vec!(G,E) b ) 
        if( isComp!(G,E,S,T) )
    { 
        foreach( i, val; b.data ) 
            data[i] = val; 
    }

    //TODO: for all combinations
    this(string G,E,Args...)( in vec!(G,E) b, Args args ) 
        if( G.length+Args.length==S.length && is( E : T ) && isAllConv!(T,Args) )
    { 
        foreach( i, val; b.data ) 
            data[i] = val; 
        foreach( i, val; args )
            data[i+b.length] = val;
    }

    auto opAssign(string G,E)( in vec!(G,E) b ) if( isComp!(G,E,S,T) )
    {
        foreach( i, ref val; data )
            val = b.data[i];
        return this;
    }

    auto opUnary(string op)() const if( op == "-" )
    {
        stype ret;
        foreach( i, val; this.data )
            ret.data[i] = -1.0 * val;
        return ret;
    }

    auto elem(string op, string G,E)( in vec!(G,E) b ) const
        if( (op == "+" || op == "-" || op == "*" || op == "/" || op == "^^" ) &&
                isComp!(G,E,S,T) )
    {
        stype ret;
        foreach( i, ref val; ret.data )
            mixin( "val = data[i] " ~ op ~ " b.data[i];" );
        return ret;
    }

    auto elem(string op,E)( E b ) const
        if( is( E :T ) )
    {
        stype ret;
        foreach( i, ref val; ret.data )
            mixin( "val = data[i] " ~ op ~ " b;" );
        return ret;
    }

    auto fun(alias f,Args...)( Args args ) const
        if( is( typeof( f(data[0], args) ) : T ) )
    {
        stype ret; 
        foreach( i, ref val; ret.data )
            val = f( data[i], args );
        return ret;
    }

    auto opBinary(string op,string G,E)( in vec!(G,E) b ) const
        if( (op == "+" || op == "-") && isComp!(G,E,S,T) )
    {
        auto ret = stype(this);
        foreach( i, ref val; ret.data )
            mixin( "val " ~ op ~ "= b.data[i];" );
        return ret;
    }

    auto opOpAssign(string op,string G,E)( in vec!(G,E) b )
        if( ( op == "+" || op == "-" ) && isComp!(G,E,S,T) )
    { return (this = opBinary!op(b)); }

    auto opBinary(string op,E)( E b ) const
        if( is( typeof( data[0] * b ) : T ) && 
                ( op == "*" || op == "/" ) )
    {
        auto ret = stype(this);
        mixin( "ret.data[] " ~ op ~ "= b;" );
        return ret;
    }

    auto opBinaryRight(string op,E)( E b ) const
        if( is( E : T ) && op == "*" )
    { return opBinary!op(b); }

    auto opOpAssign(string op,E)( E b )
        if( is( E : T ) && ( op == "*" || op == "/" ) )
    { return (this = opBinary!op(b)); }

    auto opBinary(string op,string G,E)( in vec!(G,E) b ) const
        if( is( typeof( data[0] * b.data[0] ) : T ) && 
                isComp!(G,E,S,T) && op == "^" )
    {
        T ret = 0;
        foreach( i, m; data )
            ret += m * b.data[i];
        return ret;
    }

    @property auto length() const { return S.length; }
    ref T opIndex( size_t i ){ return data[i]; }
    T opIndex( size_t i ) const { return data[i]; }

    @property auto len2() const { return opBinary!"^"(this); }
    @property auto len() const { return sqrt( cast(real)len2 ); }
    static if( is( T == float ) || is( T == double ) || is( T == real ) )
    @property auto e() const { return this / len; }

    @property T[] dup() const { return data.dup; }

    // vector mlt

    auto opBinary(string op,string G,E)( in vec!(G,E) b ) const
        if( S.length == 3 && op == "*" && isComp!(G,E,S,T) )
    {
        return stype( b.data[2] * this.data[1] - this.data[2] * b.data[1],
                      b.data[0] * this.data[2] - this.data[0] * b.data[2],
                      b.data[1] * this.data[0] - this.data[1] * b.data[0] );
    }

    auto opOpAssign(string op,string G,E)( in vec!(G,E) b ) 
        if( S.length == 3 && op == "*" && isComp!(G,E,S,T) )
    { return ( this = opBinary!op(b) ); }

    /++ для кватернионов +/
    static if( S == "ijka" )
    {
        static stype fromAngle(string G,E)( T alpha, in vec!(G,E) b )
        { return stype( b * sin( alpha / 2.0 ), cos( alpha / 2.0 ) ); }

        auto opBinary(string op,E)( in vec!(S,E) b ) const
            if( is( typeof( data[0] * b.data[0] ) : T ) && op == "*" )
        {
            return stype( this.ijk * b.ijk + this.ijk * b.a + b.ijk * this.a,
                    this.a * b.a - (this.ijk ^ b.ijk) );
        }

        auto rot(string G,E)( in vec!(G,E) b ) const
            if( is( typeof( data[0] * b.data[0] ) : T ) && 
                    G.length == 3 )
        { return vec!(G,T)( (this * stype( b, 0 ) * inv).ijk ); }

        @property {
            T norm() const { return this ^ this; }
            T mag() const { return sqrt( norm ); }
            auto con() const { return stype( -this.ijk, this.a ); }
            auto inv() const { return con / norm; }
        }
    }

    @property ref T opDispatch(string v,Args...)( Args args )
        if( v.length == 1 && CT_getIndex(S,v) >= 0 && Args.length == 0 )
    { return data[CT_getIndex(S,v)]; }

    @property T opDispatch(string v,Args...)( Args args ) const
        if( v.length == 1 && CT_getIndex(S,v) >= 0 && Args.length == 0 )
    { return data[CT_getIndex(S,v)]; }

    @property vec!(v,T) opDispatch(string v,Args...)( Args args ) const
        if( v.length > 1 && v.length <= S.length && 
                CT_checkInexAll(S,v) && Args.length == 0 )
    { mixin( "return vec!(v,T)( " ~ dataComp(S,v) ~ " );" ); }

    bool opEquals(string G,E)( in vec!(G,E) b ) const
        if( isComp!(G,E,S,T) )
    {
        foreach( i, val; data )
            if( val != b.data[i] ) return false;
        return true;
    }

    bool opCast(E)() const
        if( is( E == bool ) )
    { return cast(bool)len2; }
}

unittest
{
    alias vec!("xyz",double) dvec3;
    alias vec!("rgb",real) color;
    alias vec!("rgba",real) colorA;
    assert( dvec3.sizeof == double.sizeof * 3, "size test fails" );
    auto clrA = colorA( 1, 1, 0, 1 );
    assert( clrA.sizeof == real.sizeof * 4, "size test fails" );
    auto a = dvec3( [ 1, 2, 3 ] );
    auto b = dvec3( 1, 2, 3 );
    auto c = a;
    a[0] = 45;
    assert( a[0] == 45 );
    assert( c[0] == 1 );
    auto d = -c;
    assert( d == color( -1, -2, -3 ) );
    auto e = d + c;
    assert( e == dvec3( 0, 0, 0 ) );
    e += d;
    assert( e == d );
    assert( e * (-1) == b );
    assert( -2 * e == dvec3( 2, 4, 6 ) );
    e *= -2;
    assert( e == dvec3( 2, 4, 6 ) );
    assert( (e^e) == 4 + 16 + 36 );
    assert( e.length == 3 );
    assert( (e^e) == e.len2 );
    assert( sqrt(e^e) == e.len );
    assert( e.e.len == 1 );
    auto x = dvec3( 1,0,0 );
    auto y = dvec3( 0,1,0 );
    auto z = dvec3( 0,0,1 );
    assert( x * y == z );
    assert( x[0] == x.x );
    assert( x );
    //assert( is( typeof( clrA.rgb ) == color ) );
    auto xclr = colorA( 1, 1, 0, 1 );
    auto rclr = xclr.rgb;
    assert( is( typeof( rclr ) == color ) );
    xclr = colorA( xclr.bga, 0.0 );
    assert( xclr == colorA( 0, 1, 1, 0 ) );
}

unittest
{
    alias vec!("ijka",float) quat;
    alias vec!("xyz", float) vec3;

    auto q1 = quat.fromAngle( 90/180.0 * PI, vec3( 0, 0, 1 ) );
    auto y = q1.rot( vec3( 1, 0, 0 ) );
    assert( (y - vec3( 0, 1, 0 )).len < 1e-5 );
    auto y2 = q1.rot( vec3( 10, 0, 0 ) );
    assert( (y2 - vec3( 0, 10, 0 )).len < 1e-5 );
    auto mx = (q1*q1).rot( vec3( 1, 0, 0 ) );
    assert( (mx - vec3(-1,0,0)).len < 1e-5 );

    double omega = PI / 2.0, dt = 0.01;
    q1 = quat.fromAngle( 0, vec3( 0, 0, 1 ) );
    auto axis = vec3( 0, 0, 1 );
    foreach( i; 0 .. 100 )
        q1 += ( quat( axis*omega, 0 )*q1*0.5 ) * dt;
    mx = q1.rot( vec3( 1, 0, 0 ) );
    assert( (mx - vec3(0,1,0)).len < 1e-3 );
}

struct vrect(T)
{
    alias vec!("xy",T) ptype;
    alias vec!("xywh",T) rtype;

    union {
        rtype _rect;
        ptype[2] pt;
    }

    alias _rect this;

    this(E)( in vrect!E rr )
        if( is( E : T ) )
    { _rect = rr._rect; }

    this(E...)( E ext )
        if( E.length == 4 && isAllConv!(T,E) )
    { _rect = rtype( ext ); }

    this(string A, E, string B, G)( in vec!(A,E) pos, in vec!(B,G) size )
        if( isComp!(A,E,"xy",T) && isComp!(B,G,"xy",T) )
    { pt[0] = pos; pt[1] = size; }

    @property ref ptype pos(){ return pt[0]; }
    @property ref ptype size(){ return pt[1]; }
    @property ptype pos() const { return pt[0]; }
    @property ptype size() const { return pt[1]; }

    @property T area() const { return abs( w * h ); }

    bool opBinaryRight(string op,string G,E)( in vec!(G,E) p ) const
        if( ( is( E : T ) || is( T : E ) ) && G.length == 2 && op == "in" )
    { return p[0] >= x && p[0] < x+w && p[1] >= y && p[1] < y+h; }

    bool opBinaryRight(string op,E)( in vrect!E rect ) const
        if( ( is( E : T ) || is( T : E ) ) && op == "in" )
    { return ( rect.pos in this ) && ( (rect.pos + rect.size) in this ); }

    bool hitTest(E)( in vrect!E rect ) const
        if( is( E : T ) || is( T : E ) )
    { return ( rect.pos in this ) || ( (rect.pos + rect.size) in this ); }

    auto scale(string G,E)( in vec!(G,E) p ) const if( G.length == 2 )
    {
        auto buf = vrect!E(this);
        buf.x *= p[0];
        buf.y *= p[1];
        buf.w *= p[0];
        buf.h *= p[1];
        return buf;
    }

    F[] points(F,string G,E)( in vec!(G,E) offset = vec!("xy",T)(0,0) ) const
        if( ( is( E : T ) || is( T : E ) ) && ( is( T : F ) && is( E : F ) ) && G.length == 2 )
    {
        return [ cast(F)( offset.data[0] + this.x ), offset.data[1] + this.y,
                          offset.data[0] + this.x + this.w, offset.data[1] + this.y,
                          offset.data[0] + this.x,   offset.data[1] + this.y + this.h,
                          offset.data[0] + this.x + this.w, offset.data[1] + this.y + this.h ];
    }

    auto overlap(E)( in vrect!E rect ) const
        if( is( E : T ) )
    {
        auto p2_self = this.pos + this.size;
        auto p2_rect = rect.pos + rect.size;

        auto p1 = vec!("xy",T)( rect.x >= this.x ? 
                                    ( rect.x < p2_self.x ? rect.x 
                                                         : p2_self.x ) 
                                                 : this.x,
                                rect.y >= this.y ? 
                                    ( rect.y < p2_self.y ? rect.y 
                                                         : p2_self.y ) 
                                                 : this.y );

        auto p2 = vec!("xy",T)( p2_rect.x < p2_self.x ? 
                                    ( p2_rect.x > this.x ? p2_rect.x 
                                                         : this.x ) 
                                                      : p2_self.x,
                                p2_rect.y < p2_self.y ? 
                                    ( p2_rect.y > this.y ? p2_rect.y 
                                                         : this.y ) 
                                                      : p2_self.y );

        return  vrect!T( p1, p2 - p1 );

        //auto buf = vrect!T( p1, p2 - p1 );
        //buf.w = buf.w > 0 ? buf.w : 0;
        //buf.h = buf.h > 0 ? buf.h : 0;
        //return buf;
    }
}

unittest
{
    alias vrect!int irect;

    auto a = irect( -1,-1,8,4 );
    {
        auto b = irect( 1,1,6,2 );
        auto c = a.overlap(b);
        assert( b == c );
    }
    {
        auto b = irect( -2, 1, 6, 2 );
        auto c = a.overlap(b);
        assert( c == irect( -1,1,5,2 ) );
    }
    {
        auto b = irect( 1,1, 10, 2 );
        auto c = a.overlap(b);
        assert( c == irect( 1,1, 6, 2 ) );
    }
    {
        auto b = irect( 2,1, 4,6 );
        auto c = a.overlap(b);
        assert( c == irect( 2,1, 4,2 ) );
    }
}

alias vec!("wh",int) isize;
alias vec!("wh",size_t) uisize;
alias vec!("xy",int) ivec2;
alias vec!("xy",long) ilvec2;

alias vec!("xy",float)   vec2;
alias vec!("xyz",float)  vec3;
alias vec!("xyzw",float) vec4;
alias vec!("ijka",float) quat;
alias vec!("rgb",float)  col3;
alias vec!("rgba",float) col4;

alias vec!("xy",real)   vec2r;
alias vec!("xyz",real)  vec3r;
alias vec!("xyzw",real) vec4r;
alias vec!("ijka",real) quatr;
alias vec!("rgb",real)  col3r;
alias vec!("rgba",real) col4r;

unittest
{
    alias vec!("xy",int) intpair;
    alias vrect!int rect;
    auto r = rect( 0, 0, 800, 600 );
    assert( rect.sizeof == int.sizeof * 4 );
    assert( r.x == 0 && r.y == 0 );
    assert( r.w == 800 && r.h == 600 );
    assert( intpair( 10, 20 ) in r );
    auto p1 = intpair( 50, 40 );
    auto p2 = intpair( 10, 20 );
    auto k = rect( p1, p2 );
    assert( k.pt[0] == k.ptype(50,40) );
    assert( k.pt[1] == k.ptype(10,20) );
    k.pt[1] = k.ptype(30,10);
    assert( k.w == 30 && k.h == 10 );
    k.pt[1].x = 10;
    k.pt[1].y = 70;
    assert( k.w == 10 && k.h == 70 );
    rect k2 = k;
    assert( k2 == k );
    k2.pt[1] = p1;
    assert( k2 != k );
    assert( k2[0] == 50 );
}

// count of rows (H), count of cols(W)
struct mat(size_t H, size_t W,dtype=float)
    if( W > 0 && H > 0 )
{
    alias mat!(H,W,dtype) self;
    enum w = W;
    enum h = H;

    private static string indentstr()
    {
        string buf = "[ ";
        foreach( j; 0 .. H )
            foreach( i; 0 .. W )
                static if( W == H )
                    buf ~= i == j ? "1.0f, " : "0.0f, ";
                else
                    buf ~= "0.0f, ";
        return buf ~ " ]";
    }

    static if( W == H )
    {
        static auto diag(S)( S[] vals... )
        {
            size_t s = vals.length;
            self ret;
            foreach( i; 0 .. H )
                foreach( j; 0 .. W  )
                    ret[i,j] = i==j ? s ? vals[i%s] : 1.0 : 0.0;
            return ret;
        }

        static if( W == 4 )
        {
            static auto fromQuatPos( quat q, vec3 p )
            {
                q /= q.len2;

                float wx, wy, wz, xx, yy, yz, xy, xz, zz, x2, y2, z2;

                x2 = q.i + q.i;
                y2 = q.j + q.j;
                z2 = q.k + q.k;
                xx = q.i * x2;   xy = q.i * y2;   xz = q.i * z2;
                yy = q.j * y2;   yz = q.j * z2;   zz = q.k * z2;
                wx = q.a * x2;   wy = q.a * y2;   wz = q.a * z2;

                self m;

                m[0,0]=1.0f-(yy+zz); m[0,1]=xy-wz;        m[0,2]=xz+wy;
                m[1,0]=xy+wz;        m[1,1]=1.0f-(xx+zz); m[1,2]=yz-wx;
                m[2,0]=xz-wy;        m[2,1]=yz+wx;        m[2,2]=1.0f-(xx+yy);

                m[0,3] = p.x;
                m[1,3] = p.y;
                m[2,3] = p.z;

                m[3,0] = m[3,1] = m[3,2] = 0;
                m[3,3] = 1;

                return m;
            }
        }
        else static if( W == 3 )
        {
            static auto fromQuat( quat q )
            {
                q /= q.len2;

                float wx, wy, wz, xx, yy, yz, xy, xz, zz, x2, y2, z2;

                x2 = q.i + q.i;
                y2 = q.j + q.j;
                z2 = q.k + q.k;
                xx = q.i * x2;   xy = q.i * y2;   xz = q.i * z2;
                yy = q.j * y2;   yz = q.j * z2;   zz = q.k * z2;
                wx = q.a * x2;   wy = q.a * y2;   wz = q.a * z2;

                self m;

                m[0,0]=1.0f-(yy+zz); m[0,1]=xy-wz;        m[0,2]=xz+wy;
                m[1,0]=xy+wz;        m[1,1]=1.0f-(xx+zz); m[1,2]=yz-wx;
                m[2,0]=xz-wy;        m[2,1]=yz+wx;        m[2,2]=1.0f-(xx+yy);

                return m;
            }
        }
    }

    dtype[H*W] data = mixin( indentstr() );

    //this(S)( S[] ex... ) if( is( S : dtype ) )
    //{
    //    if( ex.length != 1 && ex.length != H*W )
    //        throw new TypeException( "bad length" );
    //    foreach( i, ref v; data ) v = ex[i%ex.length];
    //}

    // i - row, j - col
    ref dtype opIndex( size_t i, size_t j ){ return data[j+i*W]; }
    dtype opIndex( size_t i, size_t j ) const { return data[j+i*W]; }

    static if( W == 1 || H == 1 )
    {
        ref dtype opIndex( size_t i ){ return data[i]; }
        dtype opIndex( size_t i ) const { return data[i]; }
        auto length() const { return data.length; }
    }

    /++ row & col access +/
    @property auto col(size_t cno)() const
        if( cno >= 0 && cno < W )
    {
        mat!(H,1,dtype) ret;
        foreach( i; 0 .. H )
            ret[i] = data[cno+i*W];
        return ret;
    }

    @property auto row(size_t cno)() const
        if( cno >= 0 && cno < H )
    {
        mat!(1,W,dtype) ret;
        foreach( i; 0 .. W )
            ret[i] = data[cno*W+i];
        return ret;
    }

    @property mat!(H,1,E) col(size_t cno,E)( in mat!(H,1,E) mtr )
        if( cno >= 0 && cno < W && is( E : dtype ) )
    {
        foreach( i; 0 .. H )
            this.opIndex(i,cno) = mtr[i];
        return mtr;
    }

    @property mat!(1,W,E) row(size_t cno,E)( in mat!(1,W,E) mtr )
        if( cno >= 0 && cno < H && is( E : dtype ) )
    {
        foreach( i; 0 .. W )
            this.opIndex(cno,i) = mtr[i];
        return mtr;
    }

    @property vec!(S,E) col(size_t cno,string S,E)( in vec!(S,E) v )
        if( cno >= 0 && cno < W && is( E : dtype ) && S.length == H )
    {
        foreach( i; 0 .. H )
            this.opIndex(i,cno) = v[i];
        return v;
    }

    @property vec!(S,E) row(size_t cno,string S,E)( in vec!(S,E) v )
        if( cno >= 0 && cno < H && is( E : dtype ) && S.length == W )
    {
        foreach( i; 0 .. W )
            this.opIndex(cno,i) = v[i];
        return v;
    }
    /++/

    @property auto T() const
    {
        mat!(W,H,dtype) r;
        foreach( i; 0 .. H )
            foreach( j; 0 .. W )
                r[j,i] = this[i,j]; 
        return r;
    }

    auto opUnary(string op)() const
        if( op == "-" )
    {
        self r = this;
        r.data[] *= -1;
        return r;
    }

    auto opBinary(string op,E)( in mat!(H,W,E) b ) const
        if( ( op == "+" || op == "-" ) && is( E : dtype ) )
    {
        self r = this;
        foreach( i, ref v; r.data ) mixin( "v " ~ op ~ "= b.data[i];" );
        return r;
    }

    auto opOpAssign(string op,E)( in mat!(H,W,E) b )
        if( ( op == "+" || op == "-" ) && is( E : dtype ) )
    {
        foreach( i, ref v; data ) mixin( "v " ~ op ~ "= b.data[i];" );
        return this;
    }

    auto opBinary(string op,T)( in T b ) const
        if( ( op == "*" || op == "/" ) && is( T : real ) )
    {
        self r = this;
        foreach( i, ref v; r.data ) mixin( "v " ~ op ~ "= b;" );
        return r;
    }

    auto opOpAssign(string op,T)( in T b )
        if( ( op == "*" || op == "/" ) && is( T : real ) )
    {
        foreach( i, ref v; data ) mixin( "v " ~ op ~ "= b;" );
        return this;
    }

    auto opBinary(string op, size_t M,E)( in mat!(W,M,E) b ) const
        if( op == "*" && is( E : dtype ) )
    {
        mat!(H,M) r;
        foreach( i; 0 .. H )
            foreach( j; 0 .. M )
            {
                r[i,j] = 0;
                foreach( k; 0 .. W )
                    r[i,j] += this[i,k] * b[k,j];
            }
        return r;
    }

    static if( W == H )
    {
        auto opBinary(string op, string S,T)( in vec!(S,T) b ) const
            if( op == "*" && S.length == W )
        {
            vec!(S,T) r;
            foreach( i; 0 .. H )
            {
                r[i] = 0;
                foreach( j; 0 .. W )
                    r[i] += this[i,j] * b[j];
            }
            return r;
        }

        auto opBinaryRight(string op, string S,T)( in vec!(S,T) b ) const
            if( op == "*" && S.length == W )
        {
            vec!(S,T) r;
            foreach( i; 0 .. H )
            {
                r[i] = 0;
                foreach( j; 0 .. W )
                    r[i] += this[j,i] * b[j];
            }
            return r;
        }

        @property self inv() const
        {
            dtype[W][H] orig;
            dtype[W*H] invt;
            foreach( r, ref row; orig )
                foreach( c, ref v; row )
                {
                    v = this[r,c];
                    invt[r*W+c] = c == r;
                }

            foreach( r; 0 .. H-1 )
            {
                size_t n = r+1;
                foreach( rr; n .. H )
                {
                    dtype k = orig[rr][r] / orig[r][r];
                    foreach( c; 0 .. W )
                    {
                        orig[rr][c] -= k * orig[r][c];
                        invt[rr*W+c] -= k * invt[r*W+c];
                    }
                }
            }

            foreach_reverse( r; 0 .. H-1 )
            {
                size_t n = r+1;
                foreach( rr; 0 .. n )
                {
                    dtype k = orig[rr][n] / orig[n][n];
                    foreach( c; 0 .. W )
                    {
                        orig[rr][c] -= k * orig[n][c];
                        invt[rr*W+c] -= k * invt[n*W+c];
                    }
                }
            }

            foreach( r; 0 .. H )
            {
                dtype ident = orig[r][r];
                foreach( c; 0 .. W )
                {
                    orig[r][c] /= ident;
                    invt[r*W+c] /= ident;
                }
            }

            return self( invt );
        }

        static if( W == 3 )
        {
            @property self true_inv() const
            {
                alias this a;

                /+ для удобства
                    a.data = [ a[0,0], a[0,1], a[0,2],
                               a[1,0], a[1,1], a[1,2],
                               a[2,0], a[2,1], a[2,2] ];
                 +/

                auto A = self( [
                 (a[1,1]*a[2,2]-a[1,2]*a[2,1]), 
                -(a[1,0]*a[2,2]-a[1,2]*a[2,0]), 
                 (a[1,0]*a[2,1]-a[1,1]*a[2,0]),

                -(a[0,1]*a[2,2]-a[0,2]*a[2,1]), 
                 (a[0,0]*a[2,2]-a[0,2]*a[2,0]), 
                -(a[0,0]*a[2,1]-a[0,1]*a[2,0]),

                 (a[0,1]*a[1,2]-a[0,2]*a[1,1]), 
                -(a[0,0]*a[1,2]-a[0,2]*a[1,0]), 
                 (a[0,0]*a[1,1]-a[0,1]*a[1,0]),
                               ] );
                return A.T / ( a[0,0] * A[0,0] + a[0,1] * A[0,1] + a[0,2] * A[0,2] );
            }
        }

        static if( W == 4 )
        {
            @property self speed_transform_inv() const
            {
                self ret;

                foreach( i; 0 .. 3 )
                    foreach( j; 0 .. 3 )
                        ret[i,j] = this[j,i];


                auto a22k = 1.0 / this[3,3];

                ret[0,3] = -( ret[0,0] * this[0,3] + ret[0,1] * this[1,3] + ret[0,2] * this[2,3] ) * a22k;
                ret[1,3] = -( ret[1,0] * this[0,3] + ret[1,1] * this[1,3] + ret[1,2] * this[2,3] ) * a22k;
                ret[2,3] = -( ret[2,0] * this[0,3] + ret[2,1] * this[1,3] + ret[2,2] * this[2,3] ) * a22k;

                ret[3,0] = -( this[3,0] * ret[0,0] + this[3,1] * ret[1,0] + this[3,2] * ret[2,0] ) * a22k;
                ret[3,1] = -( this[3,0] * ret[0,1] + this[3,1] * ret[1,1] + this[3,2] * ret[2,1] ) * a22k;
                ret[3,2] = -( this[3,0] * ret[0,2] + this[3,1] * ret[1,2] + this[3,2] * ret[2,2] ) * a22k;
                
                ret[3,3] = a22k * ( 1.0 - ( this[3,0] * ret[0,3] + this[3,1] * ret[1,3] + this[3,2] * ret[2,3] ) );

                return ret;
            }
        }
    }

    auto copy(size_t h, size_t w)( size_t sh=0, size_t sw=0 ) const
    {
        mat!(h,w,dtype) ret;

        foreach( i; 0 .. h )
        {
            foreach( j; 0 .. w )
            {
                auto ch = i + sh;
                auto cw = j + sw;
                ret[i,j] = ( ch < H && cw < W )?this[ch,cw]:0;
            }
        }
        return ret;
    }
}

template col( size_t H, mtype = float ){ alias mat!(H,1,mtype) col; }
template row( size_t W, mtype = float ){ alias mat!(1,W,mtype) row; }

unittest
{
    auto r = row!3( [ 3, 2, 1 ] );
    auto c = col!3( [ 1, 2, 3 ] );

    assert( (r * c)[0] == 10 );
    assert( (col!3).sizeof == float.sizeof * 3 );
    assert( (col!7).sizeof == float.sizeof * 7 );

    col!3[] arr = [ c ];

    float *p = cast(float*)arr.ptr;

    assert( *(p+0) == 1 );
    assert( *(p+1) == 2 );
    assert( *(p+2) == 3 );
}

alias mat!(2,2) mat2;
alias mat!(3,3) mat3;
alias mat!(4,4) mat4;

alias mat!(2,3) mat2x3;
alias mat!(3,2) mat3x2;
alias mat!(2,4) mat2x4;
alias mat!(4,2) mat4x2;
alias mat!(3,4) mat3x4;
alias mat!(4,3) mat4x3;

alias mat!(1,2) mat1x2;
alias mat!(1,3) mat1x3;
alias mat!(1,4) mat1x4;
alias mat!(2,1) mat2x1;
alias mat!(3,1) mat3x1;
alias mat!(4,1) mat4x1;

alias mat!(2,2,real) mat2r;
alias mat!(3,3,real) mat3r;
alias mat!(4,4,real) mat4r;

alias mat!(2,3,real) mat2x3r;
alias mat!(3,2,real) mat3x2r;
alias mat!(2,4,real) mat2x4r;
alias mat!(4,2,real) mat4x2r;
alias mat!(3,4,real) mat3x4r;
alias mat!(4,3,real) mat4x3r;

alias mat!(1,2,real) mat1x2r;
alias mat!(1,3,real) mat1x3r;
alias mat!(1,4,real) mat1x4r;
alias mat!(2,1,real) mat2x1r;
alias mat!(3,1,real) mat3x1r;
alias mat!(4,1,real) mat4x1r;


unittest
{
    mat3 a;
    auto b = a;
    assert( a.data == [ 1, 0, 0, 0, 1, 0, 0, 0, 1 ] );
    auto dg = mat3.diag( 1, 2, 3 );
    assert( dg.data == [ 1, 0, 0, 0, 2, 0, 0, 0, 3 ] );
    a[0,0] = 10;
    assert( b.data == [ 1, 0, 0, 0, 1, 0, 0, 0, 1 ] );
    auto c =     mat3([ 1, 0, 4, 0, 2, 0, 0, 0, 1 ]);
    assert( c.data == [ 1, 0, 4, 0, 2, 0, 0, 0, 1 ] );
    auto d = mat3( 2 );
    assert( d.data == [ 2, 2, 2, 2, 2, 2, 2, 2, 2 ] );
    auto e = mat!(3,1)( [3,2,1] );
    assert( e[0,0] == 3 && e[1,0] == 2 && e[2,0] == 1 );
    assert( e[0] == 3 && e[1] == 2 && e[2] == 1 );
    auto f = e.T;
    assert( is( typeof( f ) == mat!(1,3) ) );
    assert( f.data == [3,2,1] );
    assert( f[0,0] == 3 && e[0,1] == 2 && e[0,2] == 1 );
    assert( f[0] == 3 && f[1] == 2 && f[2] == 1 );
    assert( !is( typeof( f != e ) ) );
    e = -e;
    assert( e[0] == -3 && e[1] == -2 && e[2] == -1 );

    auto g = a + b - d;
    assert( g.data == [ 9, -2, -2, -2, 0, -2, -2, -2, 0 ] );
    g += g / 2;
    assert( g.data == [ 13.5, -3, -3, -3, 0, -3, -3, -3, 0 ] );

    mat3 ind;
    auto ff = f * ind;
    assert( is( typeof( ff == f ) ) );
    assert( ff == f );
    auto ee = ind * e;
    assert( is( typeof( ee == e ) ) );
    assert( e == e );

    auto cc = mat!(2,3)( [ 5, 8, 9, 
                           3, 2, 1 ] );
    auto rr = mat!(3,2)( [ 1, 2, 
                           3, 6,
                           5, 4 ] );
    auto qq = cc * rr;
    assert( is( typeof( qq == mat!(2,2) ) ) );
    assert( qq[0,0] == 5 + 8 * 3 + 9 * 5 &&
            qq[1,0] == 3 + 2 * 3 + 1 * 5 );

    auto vm = mat!(2,2)( [ 2, 1, 4, 8 ] );
    auto vv = vec!("xy",real)( 4, 5 );
    auto vmvv = vm * vv;
    assert( is( typeof( vmvv ) == vec!("xy",real) ) );
    assert( vmvv[0] == 13 && vmvv[1] == 56 );
    auto vvvm = vv * vm;
    assert( is( typeof( vvvm ) == vec!("xy",real) ) );
    assert( vvvm[0] == 28 && vvvm[1] == 44 );

    auto big = mat4( [ 2, 3, 8, 1,
                       1, 0, 3, 4,
                       4, 5, 2, 0,
                       6, 3, 2, 1 ] );
    auto gg1 = big * big.inv;
    assert( is( typeof( gg1 ) == typeof( big ) ) );
    foreach( i; 0 .. gg1.h )
        foreach( j; 0 .. gg1.w )
            assert( abs( gg1[i,j] - cast(float)(i==j) ) < 1.0e-6 );
}

unittest
{
    void test_mat3_inv( in mat3 a )
    {
        auto b = a.true_inv;
        auto r = a * b;

        foreach( i; 0 .. r.h )
            foreach( j; 0 .. r.w )
                assert( abs( r[i,j] - cast(float)(i==j) ) < 1.0e-6 );
    }

    auto a = mat3( [ 2, 3, 8,
                     1, 0, 3,
                     4, 5, 2 ] );
    test_mat3_inv( a );

    auto b = mat3( [ 0, 1, 0,
                     1, 0, 0,
                     0, 0, 1 ] );
    test_mat3_inv( b );
}

unittest
{
    auto q1 = quat.fromAngle( 2.7, vec3(0,0,1) );
    auto m1 = mat3.fromQuat( q1 );

    auto v1 = vec3( 1,0,0 );

    auto r1 = q1.rot( v1 );
    auto r2 = m1 * v1;

    assert( (r1 - r2).len < 1e-5 );
}

unittest
{
    auto q1 = quat.fromAngle( 2.7, vec3(0,0,1) );
    auto p1 = vec3( 10, 5, 2 );
    auto m1 = mat4.fromQuatPos( q1, p1 );

    auto v1 = vec3( 1,0,0 );

    auto r1 = q1.rot( v1 ) + p1;
    auto r2 = m1 * vec4( v1 , 1 );

    assert( (r1 - r2.xyz).len < 1e-5 );
}

unittest
{
    auto m = mat3x1( [1,2,3] );
    auto v = vec3( m );
    assert( v == vec3( 1,2,3 ) );

    auto m2 = mat3x2( [1,2,
                       3,4,
                       5,6] );

    assert( !is( typeof( vec3(m2) ) ) );

    auto v2 = vec3( m2.col!1 );
    assert( v2 == vec3( 2,4,6 ) );

    m2.col!0 = m2.col!1;

    assert( m2.data == [ 2,2,4,4,6,6 ] );

    auto pos = vec3( 2,4,8 );
    mat4 mtr;
    mtr.col!3 = vec4( pos, 1 );
    assert( mtr.data == [ 1, 0, 0, pos.x,
                          0, 1, 0, pos.y,
                          0, 0, 1, pos.z,
                          0, 0, 0, 1 ] );
    mtr.row!0 = mtr.col!3 = vec4( pos, 1 );
    assert( mtr.data == [ pos.x, pos.y, pos.z, 1,
                          0, 1, 0, pos.y,
                          0, 0, 1, pos.z,
                          0, 0, 0, 1 ] );
    assert( mtr.row!0[1] == pos.y );
    assert( mtr.col!1[1] == 1 );
    // why float[] not concatinate with float[2UL] ?
    assert( vec4( mtr.col!3 ).xyz == vec3( [ 1.0f ] ~ pos.yz.dup ) );
}

unittest
{
    mat4 m;

    m[0,0] = 2;
    m[1,0] = 3;

    auto c = m.copy!(3,3);

    assert( is( typeof(c) == mat3 ) );
    assert( c.data == [ 2.0f, 0, 0,
                        3.0,  1, 0,
                        0,    0, 1 ] );

    auto d = m.copy!(2,3)(0,1);
    assert( is( typeof(d) == mat2x3 ) );
    assert( d.data == [ .0f, 0, 0,
                         1,  0, 0 ] );

    auto e = m.copy!(5,1)();
    assert( is( typeof(e) == mat!(5,1,float) ) );
    assert( e.data == [ 2.0f, 3, 0, 0, 0 ] );
}

import std.string: format;

struct tensor( size_t Dim, Type )
{
    alias tensor!(Dim,Type) self;
    Type[] data; 
    size_t[Dim] dim;

    this( size_t[Dim] size... )
    {
        foreach( i, s; size ) if( s == 0 )
            throw new TypeException( "bad tensor dimension #" ~ toStr(i) ~ " = 0" );
        dim[] = size[];
        size_t v = 1;
        foreach( s; dim ) v *= s;
        data.length = v;
    }

    this(this) { data = data.dup; }

    this(self b)
    {
        dim = b.dim;
        data = b.data.dup;
    }

    auto opAssign(self b)
    {
        dim = b.dim;
        data = b.data.dup;
    }

    auto opBinary(string op)( in self b ) const
        if( is( typeof( mixin( "Type.init " ~ op ~ " Type.init" ) ) : Type ) )
    {
        if( dim != b.dim ) throw new TypeException( "bad sizes" ); 

        auto ret = self( dim );
        mixin( "ret.data[] = this.data[] " ~ op ~ "b.data[];" );
        return ret;
    }

    auto opBinary(string op,E)( E b ) const
        if( is( typeof( mixin( "Type.init " ~ op ~ " E.init" ) ) : Type ) )
    {
        auto ret = self( dim );
        mixin( "ret.data[] = this.data[] " ~ op ~ "b;" );
        return ret;
    }

    ref Type opIndex( size_t[Dim] crd... ) 
    {
        size_t index = crd[0];
        foreach( i; 0 .. Dim )
            if( crd[i] >= dim[i] )
                throw new TypeException( "bad index" );
        foreach( i; 1 .. Dim )
        {
            size_t buf = 1;
            foreach( j; 0 .. i )
                buf *= dim[j];
            index += crd[i] * buf;
        }
        return data[index]; 
    }

    Type opIndex( size_t[Dim] crd... ) const
    {
        size_t index = crd[0];
        foreach( i; 0 .. Dim )
            if( crd[i] >= dim[i] )
                throw new TypeException( "bad index" );
        foreach( i; 1 .. Dim )
        {
            size_t buf = 1;
            foreach( j; 0 .. i )
                buf *= dim[j];
            index += crd[i] * buf;
        }
        return cast(Type)data[index]; 
    }
}

unittest
{
    alias tensor!(2,float) dynmat2;
    auto dm = dynmat2( 3,3 );
    dm.data = [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
    assert( dm[1,2] == 8 );

    alias tensor!(3,float) tns3;
    auto t = tns3( 2,2,2 );
    t.data = [ 1, 2, 3, 4, 5, 6, 7, 8 ];
    assert( t[1,0,1] == 6 );
    t[1,1,1] = 12;
    assert( t.data == [ 1, 2, 3, 4, 5, 6, 7, 12 ] );

    auto tt = tns3( 3,3,3 );
    tt.data[] = 0;
    tt[2,1,0] = 1;
    tt[1,1,2] = 1;
    assert( tt.data == [ 0, 0, 0, 
                         0, 0, 1,
                         0, 0, 0,
                         
                         0, 0, 0,
                         0, 0, 0,
                         0, 0, 0,
                         
                         0, 0, 0,
                         0, 1, 0,
                         0, 0, 0 ]
          );
}

unittest
{
    alias tensor!(2,float) dmat2;

    auto dm1 = dmat2( 3, 3 );
    dm1.data = [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ];
    auto dm2 = dmat2( 3, 3 );
    dm2.data = [ 1.0f, 2, 3, 4, 5, 5, 7, 8, 9 ].reverse;
    auto dm_t1 = dm1 + dm2;
    assert( dm_t1.data == [ 10, 10, 10, 9, 10, 10, 10, 10, 10 ] );
    auto dm_t2 = dm1 * dm2;
    assert( dm_t2.data == [ 9, 16, 21, 20, 25, 24, 21, 16, 9 ] );
    auto dm_t3 = dm_t2 / 10.0;
    auto dm_t3_res = [ .9f, 1.6, 2.1, 2.0, 2.5, 2.4, 2.1, 1.6, .9 ];
    float diff = 0;
    foreach( i, v; dm_t3.data )
        diff += (dm_t3_res[i] - v) ^^ 2;
    assert( diff <= 1e-13 );
}
