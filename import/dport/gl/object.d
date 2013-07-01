module dport.gl.object;

import derelict.opengl3.gl;
import derelict.opengl3.ext;

import dport.math.types;
import dport.utils.system;
import dport.utils.signal;

import dport.gl.shader;

mixin( defaultModuleLogUtils("OBJException") );

abstract class GLVAO
{
private:
    static uint _inUse = 0; // vertex array object in use
    static void set_to_use( uint nvao )
    {
        glBindVertexArray( nvao );
        _inUse = nvao;
        debug log.trace( "set to use: ", nvao );
    }
    uint selfNo = 0; // self number of VAO

protected:

    struct buffer
    {
        uint no;
        GLenum type;
        uint[] attribs;
    }

    buffer[string] vbo;

    final void use( bool L=true )
    { 
        if( L ) set_to_use( selfNo );
        else if( ( selfNo == _inUse ) && !L ) set_to_use( 0 );
    }

    final void genBuffer( string name, GLenum type )
    {
        use();
        if( name in vbo )
            throw new OBJException( "buffer \"" ~ name ~ "\" exist" );

        vbo[name] = buffer( 0, type );
        glGenBuffers( 1, &(vbo[name].no) );

        debug log.info( "generate buffer \"", name, "\"" );
    }

    final void bind( string name ) 
    { 
        use();
        if( name !in vbo )
            throw new OBJException( "buffer \"" ~ name ~ "\" not exist" );
        glBindBuffer( vbo[name].type, vbo[name].no ); 
    }

    final void unbind( GLenum type ) { use(); glBindBuffer( type, 0 ); }

    final void unbind( string name ) 
    { 
        use();
        if( name !in vbo )
            throw new OBJException( "buffer \"" ~ name ~ "\" not exist" );
        glBindBuffer( vbo[name].type, 0 ); 
    }

    final void bufferData(E)( string name, E[] data, GLenum mem=GL_DYNAMIC_DRAW )
    {
        use();
        auto size = E.sizeof * data.length;
        if( !size ) throw new OBJException( "buffer data size is 0" );

        bind( name ); scope(exit) unbind( name );
        glBufferData( vbo[name].type, size, data.ptr, mem );

        debug log.trace( "bufferData to vbo ", name, " with arr ", data );
    }

    final void genBufferWithData(E)( string name, E[] data, GLenum type=GL_ARRAY_BUFFER, GLenum mem=GL_DYNAMIC_DRAW )
    {
        genBuffer( name, type );
        bufferData( name, data, mem );
    }

    final void predraw_hook_base()
    {
        debug log.trace( "predraw start" );
        use();
        shader.use();
        scope(exit) unbind( GL_ARRAY_BUFFER );
        foreach( name, buf; vbo )
        {
            bind( name );
            foreach( attr; buf.attribs )
                glEnableVertexAttribArray( attr );
        }
        debug log.trace( "predraw success" );
    }

    final void postdraw_hook_base()
    {
        debug log.trace( "postdraw start" );
        use(0);
        scope(exit) unbind( GL_ARRAY_BUFFER );
        foreach( name, buf; vbo )
        {
            bind( name );
            foreach( attr; buf.attribs )
                glDisableVertexAttribArray( attr );
        }
        debug log.trace( "postdraw success" );
    }

    ShaderProgram shader;

    final void setAttribPointer( string name, string attrname, uint size,
            GLenum type, bool norm=false )
    { setAttribPointer( name, attrname, size, type, 0, 0, norm ); }

    final void setAttribPointer( string name, string attrname, uint size, 
            GLenum type, size_t stride, size_t offset, bool norm=false )
    {
        debug log.trace( "set attrib pointer start" );
        if( shader is null ) throw new OBJException( "shader is null" );

        int atLoc = shader.getAttribLocation( attrname );
        if( atLoc < 0 ) throw new OBJException( "bad attribute name" );

        use();
        bind( name ); scope(exit) unbind( name );

        bool find = 0;
        foreach( attr; vbo[name].attribs )
            if( atLoc == attr ){ find = 1; break; }
        if( !find )
            vbo[name].attribs ~= atLoc;

        glVertexAttribPointer( atLoc, cast(int)size, type, norm, 
                cast(int)stride, cast(void*)offset );
        debug log.info( "set attrib pointer at loc: ", atLoc, ", size: ", size, 
                       ", type: ", type, ", norm: ", norm,  
                       ", stride: ", stride, ", offset: ", offset, " [success]" );
    }

public:
    this( ShaderProgram sh ) 
    { 
        shader = sh;
        glGenVertexArrays( 1, &selfNo ); 
        draw.addPair( &predraw_hook_base, &postdraw_hook_base );
        debug log.info( "create vao: ", selfNo, " [success]" );
    }

    ~this()
    {
        debug log.Debug( "destruct start" );
        foreach( buf; vbo )
        {
            glBindBuffer( buf.type, 0 );
            glDeleteBuffers( 1, &(buf.no) );
        }
        use(0);
        glDeleteVertexArrays( 1, &selfNo );
        debug log.info( "object destruction [success]" );
    }

    SignalBoxNoArgs draw;
}
