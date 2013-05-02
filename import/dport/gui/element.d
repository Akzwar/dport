module dport.gui.element;

import derelict.opengl.gl;

import dport.gl.shader,
       dport.gl.object;

public import dport.gui.base;

import std.conv;

/++
 стандартный шейдер для всех gui элементов

    uniform vec2 winsize - размер окна

    attribute vec2 vertex - позиция в системе координат окна
    attribute vec4 color - цвет вершины
    attribute vec2 uv - текстурная координата

    uniform sampler2D ttu - текстурный сэмплер
    uniform int use_texture - флаг использования текстуры: 
                                0 - не использовать,
                                1 - использовать только альфу
                                2 - использовать все 4 канала текстуры

 +/
enum ShaderSources SS_ELEMENT = 
{
r"
uniform vec2 winsize;

attribute vec2 vertex;
attribute vec4 color;
attribute vec2 uv;

varying vec2 ex_uv;
varying vec4 ex_color;

void main(void)
{
    gl_Position = vec4( 2.0 * vertex / winsize - vec2(1.0,1.0), -0.05, 1 );
    ex_uv = uv;
    ex_color = color;
}
", 

r"
uniform sampler2D ttu;
uniform int use_texture;

varying vec2 ex_uv;
varying vec4 ex_color;

void main(void) 
{ 
    if( use_texture == 0 )
        gl_FragColor = ex_color; 
    else if( use_texture == 1 )
        gl_FragColor = vec4( 1, 1, 1, texture2D( ttu, ex_uv ).a ) * ex_color;
    else if( use_texture == 2 )
        gl_FragColor = texture2D( ttu, ex_uv );
}
"
};

/++
 родоначальник gui элементов
 +/
class Element: View
{
private:
    void predraw()
    {
        glViewport( offset.x, offset.y, bbox.w, bbox.h );
        glDisable( GL_DEPTH_TEST );
        shader.setUniformVec( "winsize", vec2( bbox.size ) );
        shader.setUniform!int( "use_texture", 0 );
        shader.use();
    }
protected:

    Element[] childs;
    Element cur;

    bool processEvent = true;

    bool find( in ivec2 mpos )
    {
        foreach_reverse( v; childs )
        {
            if( ( mpos in v.rect ) && v.processEvent )
            {
                if( cur != v ) 
                {
                    if( cur )
                        cur.release();
                    cur = v;
                    cur.activate();
                }
                return true;
            }
        }
        if( cur ) cur.release();

        cur = null;
        return false;
    }

    ShaderProgram shader;
    Element parent;

public:

    this( Element par=null )
    {
        parent = par;
        if( par ) 
        {
            shader = par.shader;
            par.childs ~= this;
        }
        else 
            shader = new ShaderProgram( SS_ELEMENT );

        draw.addPair( &predraw, 
                (){ foreach_reverse( ch; childs ) ch.draw(); } );

        keyboard.addCondition( (mpos, key){ 
                return find( mpos ); 
                }, 0 );
        keyboard.connectAlt( ( mpos, key ){
                if( cur ) cur.keyboard( mpos-bbox.pos, key );
                });

        mouse.addCondition( (mpos, me){ 
                return find( mpos ); 
                }, 0 );
        mouse.connectAlt( ( mpos, me ){
                if( cur ) cur.mouse( mpos-bbox.pos, me );
                });

        idle.connect( ( dtime ) {
            foreach( ch; childs ) ch.idle( dtime );
                });
    }
    
    /++ возвращает смещение от верхнего левого края +/
    @property ivec2 offset() const
    {
        if( parent ) return bbox.pt[0] + parent.offset; 
        else return bbox.pt[0];
    }
}
