module dport.gl.texture;

import std.conv;

import derelict.opengl3.gl3;
import derelict.opengl3.ext;

import dport.math.types;
import dport.gl.shader;
import dport.utils.system;

mixin( defaultModuleLogUtils("TexException") );

class GLTexture(uint DIM)
    if( DIM == 1 || DIM == 2 || DIM == 3 )
{
public: 
    static if( DIM == 1 ) 
    {
        enum GLenum type = GL_TEXTURE_1D;
        enum string vecstr = "w";
    }
    else static if( DIM == 2 ) 
    {
        enum GLenum type = GL_TEXTURE_2D;
        enum string vecstr = "wh";
    }
    else static if( DIM == 3 ) 
    {
        enum GLenum type = GL_TEXTURE_3D;
        enum string vecstr = "whd";
    }
    alias vec!(vecstr,int) texsize;

private:
    static uint _inUse = 0;

    static void set_to_use( uint ntex )
    {
        glBindTexture( type, ntex );
        _inUse = ntex;
        debug log().trace( "set to use: ", ntex );
    }

    uint tex = 0;
protected:

    texsize _size;

    static pure string veccomp( string name, string comp )
    {
        string buf;
        foreach( ch; comp )
            buf ~= name ~ "." ~ ch ~ ", ";
        return buf;
    }

    final void parameteri( GLenum param, int val )
    { 
        //bind(); scope(exit) bind(0);
        glTexParameteri( type, param, val ); 
    }

public:

    this( texsize sz )
    {
        glActiveTexture( GL_TEXTURE0 );
        glGenTextures( 1, &tex );
        use(); scope(exit) use(0);
        parameteri( GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
        parameteri( GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
        parameteri( GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        parameteri( GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        size = sz;
        debug log.Debug( "gen texture: ", tex );
    }

    final void use( bool L=true )
    { 
        if( L ) set_to_use( tex );
        else if( ( tex == _inUse ) && !L ) set_to_use( 0 );
    }

    @property final void size( texsize sz )
    {
        _size = sz;
        image( GL_RGBA, size, GL_RGBA, GL_UNSIGNED_BYTE, null );
        debug log.Debug( "resize texture: ", tex, " to ", sz );
    }

    @property final texsize size() const { return _size; }

    final void image( int texformat, texsize sz, 
            GLenum dataformat, GLenum datatype, void* dataptr )
    {
        _size = sz;
        use();// scope(exit) use(0);
        mixin( "glTexImage" ~ to!string(DIM) ~ "D( type, 0, texformat, " ~ 
                veccomp( "_size", vecstr ) ~ 
                "0, dataformat, datatype, dataptr );" );
        debug log.trace( "new texture: ", tex, " to ", sz );
    }

    @property uint no() const { return tex; }

    ~this()
    {
        debug log.start( "destruction" );
        use(0);
        // TODO: WTF? segmentation failed
        //glDeleteTextures( 1, &tex );
        debug log.success( "destruction" );
    }
}
