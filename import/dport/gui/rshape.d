/++
прямоугольник, удобен для наложения текстур
+/
module dport.gui.rshape;

import derelict.opengl3.gl3;

import dport.math.types;
import dport.utils.system;

import dport.gl.object;
import dport.gl.texture;

mixin( defaultModuleLogUtils( "RShapeException" ) );

alias vrect!int irect;
alias GLTexture!2 GLTexture2D;

class RShape: GLVAO
{
protected:
    static float[] colArray( in col4 c )
    { return c.data ~ c.data ~ c.data ~ c.data; }

    GLTexture2D tex;
    int use_tex = 0;

public:

    this( ShaderProgram sp )
    {
        super( sp );
        genBufferWithData( "pos", [ 0.0f, 0, 1, 0, 0, 1, 1, 1 ] );
        setAttribPointer( "pos", "vertex", 2, GL_FLOAT );

        genBufferWithData( "uv", [ 0.0f, 0, 1, 0, 0, 1, 1, 1 ] );
        setAttribPointer( "uv", "uv", 2, GL_FLOAT );

        genBufferWithData( "col", colArray( col4( 1,1,1,1 ) ) );
        setAttribPointer( "col", "color", 4, GL_FLOAT );

        tex = new GLTexture2D( isize( 1, 1 ) ); 

        draw.connect( (mtr){ glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 ); } );
        draw.addPair( (mtr){ 
                shader.setUniform!int( "use_texture", use_tex );
                shader.setUniform!int( "ttu", GL_TEXTURE0 );
                tex.use(); },
                (mtr){ tex.use(0); } );
    }

    void setColor( in col4 c ){ bufferData( "col", colArray( c ) ); }
    void fillTexture(string A)( in vec!(A,int) sz, ubyte[] data )
        if( A.length == 2 )
    { 
        tex.image( GL_RED, sz, GL_RED, GL_UNSIGNED_BYTE, data.ptr ); 
        use_tex = 1;
    }
    void reshape( in irect r ) { bufferData( "pos", r.points!float ); }
}

