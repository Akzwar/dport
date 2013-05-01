module dport.gui.element;

import derelict.opengl.gl;

import dport.gl.shader,
       dport.gl.object;

public import dport.gui.base;

import std.conv;

/++
 стандартный шейдер для всех gui элементов

    uniform vec2 winsize - размер окна
    uniform vec2 offset  - смещение, выставляется для правильного позиционирования 
                           дочерних элементов
    attribute vec2 vertex - позиция в системе координат окна
    attribute vec4 color - цвет вершины
 +/
enum ShaderSources SS_ELEMENT = 
{
r"
uniform vec2 winsize;
attribute vec2 vertex;
attribute vec4 color;
varying vec4 ex_color;

void main(void)
{
    gl_Position = vec4( 2.0 * vertex / winsize - vec2(1.0,1.0), -0.05, 1 );
    ex_color = color;
}
", 

r"
varying vec4 ex_color;
void main(void) { gl_FragColor = ex_color; }
"
};

/++
 родоначальник gui элементов
 +/
class Element: View
{
protected:
    Element[] childs;
    Element cur;

    bool find( in ivec2 mpos )
    {
        foreach_reverse( v; childs )
        {
            if( mpos in v.rect )
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

public:
    ShaderProgram shader;
    Element parent;

    void predraw()
    {
        glViewport( offset.x, offset.y, bbox.w, bbox.h );
        shader.setUniformVec( "winsize", vec2( bbox.size ) );
        shader.use();
    }

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
