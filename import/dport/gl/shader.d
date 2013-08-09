module dport.gl.shader;

import dport.math.types;
import dport.utils.system;

import std.conv, std.string;
import derelict.opengl3.gl3;

mixin( defaultModuleLogUtils("ShaderException") );

struct ShaderSources { string vert, frag, geom; }

private string castArgs( string args, string type, uint count, uint start=0 )
{
    string rstr = "cast(" ~ type ~ ")" ~ args ~ "[" ~ to!string(start) ~ "]";
    if( start+1 >= count ) return rstr;
    else return rstr ~", " ~ castArgs( args, type, count, start+1 );
}

class ShaderProgram
{
private:
    static GLint inUse = -1;

    GLuint vert_sh = 0,
           geom_sh = 0,
           frag_sh = 0;

    GLuint program = 0;

    static GLuint makeShader( GLenum type, string src )
    {
        debug log.Debug( "makeShader start" );
        GLuint shader = glCreateShader( type );
        auto srcptr = src.ptr;
        glShaderSource( shader, 1, &srcptr, null );
        glCompileShader( shader );

        int res;
        glGetShaderiv( shader, GL_COMPILE_STATUS, &res );
        if( res == GL_FALSE )
        {
            int logLen;
            glGetShaderiv( shader, GL_INFO_LOG_LENGTH, &logLen );
            if( logLen > 0 )
            {
                auto chlog = new char[logLen];
                glGetShaderInfoLog( shader, logLen, &logLen, chlog.ptr );
                throw new ShaderException( "shader compile error: \n" ~ chlog.idup );
            }
        }

        debug log.Debug( "makeShader: ", shader, " success" );
        return shader;
    }

    void destroy()
    {
        debug log.Debug( "destroy start" );
        if( inUse == program )
            glUseProgram( 0 );
        glDetachShader( program, frag_sh );
        if( geom_sh ) glDetachShader( program, geom_sh );
        glDetachShader( program, vert_sh );

        glDeleteProgram( program );

        glDeleteShader( frag_sh );
        if( geom_sh ) glDeleteShader( geom_sh );
        glDeleteShader( vert_sh );
        debug log.Debug( "destroy success" );
    }

    static void checkProgram( GLuint prog )
    {
        debug log.Debug( "checkProgram start" );
        int res;
        glGetProgramiv( prog, GL_LINK_STATUS, &res );
        if( res == GL_FALSE )
        {
            int logLen;
            glGetProgramiv( prog, GL_INFO_LOG_LENGTH, &logLen );
            if( logLen > 0 )
            {
                auto chlog = new char[logLen];
                glGetProgramInfoLog( prog, logLen, &logLen, chlog.ptr );
                throw new ShaderException( "program link error: \n" ~ chlog.idup );
            }
        }
        debug log.Debug( "checkProgram ", prog, " success" );
    }

    void checkLoc( int loc )
    { 
        if( loc < 0 ) 
            throw new ShaderException( "bad location: " ~ to!string(loc) ); 
    }

public:
    this( in ShaderSources src )
    {
        debug log.Debug( "shader ctor start" );
        if( src.vert.length == 0 || src.frag.length == 0 )
            throw new ShaderException( "source is empty" );

        program = glCreateProgram();
        debug log.Debug( "create program: ", program );

        vert_sh = makeShader( GL_VERTEX_SHADER, src.vert );
        if( src.geom.length )
        {
            geom_sh = makeShader( GL_GEOMETRY_SHADER, src.frag );
            debug log.Debug( "use geom shader" );
        }
        frag_sh = makeShader( GL_FRAGMENT_SHADER, src.frag );

        glAttachShader( program, vert_sh );
        if( geom_sh )
            glAttachShader( program, geom_sh );
        glAttachShader( program, frag_sh );

        glLinkProgram( program );
        checkProgram( program );
        debug log.Debug( "shader construction success" );
    }

    ~this(){ destroy(); }

    final void use()
    {
        if( inUse == program ) return;
        glUseProgram( program );
        inUse = program;
    }

    int getAttribLocation( string name )
    { return glGetAttribLocation( program, name.ptr ); }

    int getUniformLocation( string name )
    { return glGetUniformLocation( program, name.ptr ); }

    void setUniform(S,T...)( int loc, T vals )
        if( T.length > 0 && T.length <= 4 && isAllConv!(float,T) &&
            ( is( S == float ) || is( S == int ) || is( S == uint ) ) )
    {
        debug log.trace( "setUniform from loc ", loc, " with data ", vals );
        checkLoc( loc ); use();
        static if( is( S == float ) ) 
        {
            enum string postfix = "f";
            enum string type = "float";
        }
        else static if( is( S == int ) ) 
        {
            enum string postfix = "i";
            enum string type = "int";
        }
        else static if( is( S == uint ) ) 
        {
            enum string postfix = "ui";
            enum string type = "uint";
        }
        mixin( "glUniform" ~ to!string(T.length) ~ postfix ~ "( loc, " ~ 
                castArgs( "vals", type, T.length, 0 ) ~ " );" );
    }

    void setUniform(S,T...)( string name, T vals )
        if( T.length > 0 && T.length <= 4 && isAllConv!(float,T) &&
            ( is( S == float ) || is( S == int ) || is( S == uint ) ) )
    { setUniform!S( getUniformLocation( name ), vals ); }

    void setUniformArr(size_t sz,T)( int loc, in T[] vals )
        if( sz > 0 && sz <= 4 && ( is( T == float ) || is( T == int ) || is( T == uint ) ) )
    {
        debug log.trace( "setUniformArr from loc ", loc, " with data ", vals );
        checkLoc( loc ); 
        auto cnt = vals.length / sz;
        use();
        static if( is( T == float ) ) enum string postfix = "f";
        else static if( is( T == int ) ) enum string postfix = "i";
        else static if( is( T == uint ) ) enum string postfix = "ui";
        mixin( "glUniform" ~ to!string(sz) ~ postfix ~ "v( loc, cast(int)cnt, vals.ptr );" );
    }

    void setUniformArr(uint sz,T)( string name, in T[] vals )
        if( sz > 0 && sz <= 4 && ( is( T == float ) || is( T == int ) || is( T == uint ) ) )
    { setUniformVect!sz( getUniformLocation( name ), vals ); }

    void setUniformVec(string S,T)( int loc, vec!(S,T)[] vals... )
        if( S.length > 0 && S.length <= 4 && ( is( T == float ) || is( T == int ) || is( T == uint ) ) )
    {
        debug log.trace( "setUniformVec from loc ", loc, " with data ", vals );
        enum sz = S.length;
        checkLoc( loc ); 
        auto cnt = vals.length;
        use();
        static if( is( T == float ) ) enum string postfix = "f";
        else static if( is( T == int ) ) enum string postfix = "i";
        else static if( is( T == uint ) ) enum string postfix = "ui";
        mixin( "glUniform" ~ to!string(sz) ~ postfix ~ "v( loc, cast(int)cnt, cast(float*)vals.ptr );" );
    }

    void setUniformVec(string S,T)( string name, vec!(S,T)[] vals... )
        if( S.length > 0 && S.length <= 4 && ( is( T == float ) || is( T == int ) || is( T == uint ) ) )
    { setUniformVec( getUniformLocation( name ), vals ); }

    void setUniformMat(size_t h, size_t w)( int loc, in mat!(h,w) mtr )
        if( h <= 4 && w <= 4 )
    {
        debug log.trace( "setUniformMat from loc ", loc, " with matrix ", mtr );
        checkLoc( loc );
        use();
        static if( w == h )
            mixin( "glUniformMatrix" ~ to!string(w) ~ 
                    "fv( loc, 1, GL_TRUE, mtr.data.ptr ); " );
        else
            mixin( "glUniformMatrix" ~ to!string(h) ~ "x" ~ to!string(w) ~
                    "fv( loc, 1, GL_TRUE, mtr.data.ptr ); " );
    }
    void setUniformMat(size_t h, size_t w)( string name, in mat!(h,w) mtr )
        if( h <= 4 && w <= 4 )
    { setUniformMat( getUniformLocation( name ), mtr ); }

}
