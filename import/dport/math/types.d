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

private static pure size_t CT_getIndex( string str, string m )
{
    foreach( i, v; str ) if( m[0] == v ) return i;
    assert( 0, "[Types]: string \"" ~ str ~ 
            "\" does not contain symbol: \"" ~ m ~ "\"" );
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
                assert( 0, "[Types]: string \"" ~ str ~ 
                        "\" contain bad symbol: \"" ~ v ~ "\"" );
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
        CT_getIndex( S, ""~ch );
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
    auto ch = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" ];
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

private mixin template _workaround4424() { @disable void opAssign(typeof(this)); }
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

    mixin _workaround4424;

    auto opAssign(string G,E)( in vec!(G,E) b ) if( isComp!(G,E,S,T) )
    {
        foreach( i, ref val; data )
            val = b.data[i];
        return this;
    }

    auto opUnary(string op)() const if( op == "-" )
    {
        auto ret = stype(this);
        ret.data[] *= -1.0;
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
}

alias vec!("wh",int) isize;
alias vec!("wh",size_t) uisize;
alias vec!("xy",int) ivec2;
alias vec!("xy",long) ilvec2;

alias vec!("xy",float) vec2;
alias vec!("xyz",float) vec3;
alias vec!("xyzw",float) vec4;
alias vec!("ijka",float) quat;
alias vec!("rgb",float) col3;
alias vec!("rgba",float) col4;

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

    @property auto T() const
    {
        mat!(W,H) r;
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

    auto opBinary(string op)( in this b ) const
        if( op == "+" || op == "-" )
    {
        self r = this;
        foreach( i, ref v; r.data ) mixin( "v " ~ op ~ "= b.data[i];" );
        return r;
    }

    auto opOpAssign(string op)( in this b )
        if( op == "+" || op == "-" )
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

    auto opBinary(string op, size_t M)( in mat!(W,M) b ) const
        if( op == "*" )
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
            if( S.length == W )
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
            if( S.length == W )
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
    }

    // TODO: move copy frame
    auto resize(int dw, int dh)() const
        if( (dw + W) > 0 && (dh + H) > 0 )
    {
        mat!(dh+H,dw+W) r;
        foreach( i; 0 .. (H+dh)>H?H:(H+dh) )
            foreach( j; 0 .. (W+dw)>W?W:(W+dw) )
                r[i,j] = this[i,j];
        return r;
    }
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

alias mat!(2,2,real) mat2r;
alias mat!(3,3,real) mat3r;
alias mat!(4,4,real) mat4r;
alias mat!(2,3,real) mat2x3r;
alias mat!(3,2,real) mat3x2r;
alias mat!(2,4,real) mat2x4r;
alias mat!(4,2,real) mat4x2r;
alias mat!(3,4,real) mat3x4r;
alias mat!(4,3,real) mat4x3r;


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
