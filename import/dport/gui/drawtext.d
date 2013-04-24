/++
Отрисовка текста в gui
 +/
module dport.gui.drawtext;

import derelict.opengl.gl;

import dport.math.types;
import dport.utils.logsys;

import dport.gl.shader;
import dport.gl.object;
import dport.gl.texture;

import std.string;

mixin( defaultModuleLogUtils("DTException") );

alias vrect!int irect; /// прямоугольник целочисленный
alias vrect!float frect; /// прямоугольник плавающеточечный
alias GLTexture!2 GLTexture2D; /// текстура двумерная

/++
содержит информацию о отрендеренном символе
 +/
struct GlyphInfo
{
    irect rect; /// размер изображения символа
    ivec2 next; /// смещение для следующего изображения
    ubyte[] buffer; /// пиксельная информация
}

/++
интерфейс рендера шрифтов
 +/
interface FontRender
{
    /++
        установить размер шрифта
        Params:
        sz = размер шривта 
     +/
    void setSize( uint sz );
    /++
        отрендерить символ
        Params: ch = номер символа в таблице unicode
        Returns: структура с информацией о отрендеренном символе
     +/
    GlyphInfo renderChar( size_t ch );
}

version(Windows)
{

static assert( 0, "no realisation of FontRender for windows" );

class WindowsTypeRender: FontRender
{
public:
    this( string fontname )
    {

    }

    override void setSize( uint sz )
    {

    }

    override GlyphInfo renderChar( size_t ch )
    {

    }
}

} else {

import derelict.freetype.ft;
import derelict.freetype.fttypes;

static this() { DerelictFT.load(); }

/++
    FreeType реализация интерфеса рендеринга символов 
 +/
class FreeTypeRender: FontRender
{
private:
    FT_Library ft;
    FT_Face face;

public:
    /++
        конструктор так то
        Params:
        fontname = полное имя загружаемого шрифта (вместе с путём)
     +/
    this( string fontname )
    {
        if( FT_Init_FreeType( &ft ) )
            throw new DTException( "Couldn't init freetype library" );
        debug log.info( "lib loaded" );

        if( FT_New_Face( ft, fontname.ptr, 0, &face ) )
            throw new DTException( "Couldn't open font \"" ~ fontname ~ "\"" );
        debug log.info( "font \"", fontname, "\" loaded" );

        if( FT_Select_Charmap( face, FT_Encoding.FT_ENCODING_UNICODE ) )
            throw new DTException( "Couldn't select unicode enc" );
        debug log.info( "unicode encoding selected" );
    }

    override void setSize( uint sz ) { FT_Set_Pixel_Sizes(face, 0, sz); }

    override GlyphInfo renderChar( size_t ch )
    {
        if( FT_Load_Char(face, ch, FT_LOAD_RENDER) ) 
            throw new DTException( "Couldn't load character" );
        debug log.trace( "load char: \"", cast(wchar)ch, "\"" );
        auto g = face.glyph;
        
        debug log.trace( "bitmap size: ", g.bitmap.width, "x", g.bitmap.rows );
        auto ret = GlyphInfo( irect( g.bitmap_left, g.bitmap_top, 
                g.bitmap.width, g.bitmap.rows ),
                ivec2( cast(int)(g.advance.x >> 6), cast(int)(g.advance.y >> 6) ) );
        ret.buffer.length = ret.rect.w * ret.rect.h;
        foreach( i, ref buf; ret.buffer  )
                buf = g.bitmap.buffer[i];
        return ret;
    }

    ~this()
    {
        debug log.Debug( "FreeTypeRender destructor start" );
        FT_Done_Face( face );
        debug log.info( "font done" );
        FT_Done_FreeType( ft );
        debug log.info( "lib done" );
        debug log.Debug( "FreeTypeRender destructor end" );
    }
}

}

/++
 исходники шейдера, "рекомендуемого" для отрисовки текста
 +/
private enum ShaderSources SS_Text = 
{
r"
uniform vec2 winsize;

attribute vec2 coord;
attribute vec2 tcrd;

varying vec2 texcoord;

void main(void)
{
    gl_Position = vec4( 2.0 * coord / winsize - vec2( 1.0, 1.0 ), -0.1, 1.0);
    texcoord = tcrd;
}
",

r"
uniform sampler2D ttu;
varying vec2 texcoord;
uniform vec4 color;

void main(void)
{ gl_FragColor = vec4( 1, 1, 1, texture2D( ttu, texcoord ).a ) * color; }
"
};

/++
 информация об отрисовываемом текте
 +/
struct TextParam
{
    wstring str=""; /// как таковой текст
    uint height=12; /// высота шрифта
    col4 color=col4(1,1,1,1); /// цвет
    vec2 pos=vec2(0,0); /// позиция, согласно шейдеру, в оконных координатах
}

/++
 отрисовка строки текста
 +/
class TextString: GLVAO
{
private:

    /++ 
        убирает перед отрисовкой GL_DEPTH_TEST 
        выставляет в шейдере uniform текстуру и цвет
     +/
    final void predraw_hook()
    {
        glDisable( GL_DEPTH_TEST );
        shader.setUniform!int( textureShaderName, GL_TEXTURE0 );
        shader.setUniformVec( colorShaderName , tp.color );
        tex.use(); 
    }

    /++ возвращает GL_DEPTH_TEST +/
    final void postdraw_hook()
    {
        glEnable( GL_DEPTH_TEST );
        tex.use(0);
    }
protected:

    string colorShaderName="color"; /// имя униформа цвета в шейдере
    string textureShaderName="ttu"; /// имя униформа текстуры в шейдере
    string coordShaderName="coord"; /// имя атрибута координат в шейдере
    string texcoordShaderName="tcrd"; /// имя атрибута текстурных координат в шейдере

    GLTexture2D tex;
    FontRender fr;
    frect bbox; /// ограничивающий прямоугольник (в оконных координатах)
    TextParam tp;

    /++ рендерит текст, обновляет текстуру и boundingbox (bbox) +/
    void update()
    { 
        uint th = tp.height;
        fr.setSize( th );
        auto pen = ivec2( 0, 0 );

        GlyphInfo[] buf;

        auto min = ivec2( 32000, 32000 );
        auto max = ivec2( -32000, -32000 );

        void findminmax( in ivec2 v )
        {
            if( min.x > v.x ) min.x = v.x;
            if( min.y > v.y ) min.y = v.y;
            if( max.x < v.x ) max.x = v.x;
            if( max.y < v.y ) max.y = v.y;
        }

        foreach( i, ch; tp.str )
        {
            auto g = fr.renderChar( ch );
            g.rect.pt[0] += pen;
            pen += g.next;
            buf ~= g;

            findminmax( g.rect.pt[0] );
            findminmax( g.rect.pt[0] + g.rect.pt[1] );

            //if( min.x > g.rect.x ) min.x = g.rect.x;
            //if( min.y > g.rect.y ) min.y = g.rect.y;
            //if( min.x > g.rect.x + g.rect.w ) min.x = g.rect.x + g.rect.w;
            //if( min.y > g.rect.y - g.rect.h ) min.y = g.rect.y - g.rect.h;

            //if( max.x < g.rect.x ) max.x = g.rect.x;
            //if( max.y < g.rect.y ) max.y = g.rect.y;
            //if( max.x < g.rect.x + g.rect.w ) max.x = g.rect.x + g.rect.w;
            //if( max.y < g.rect.y - g.rect.h ) max.y = g.rect.y - g.rect.h;
        }

        GlyphInfo res;
        // TODO: проверить а минус ли тут (-min.x) 
        res.rect = irect( ivec2(-min.x,min.y), max - min );
        res.buffer.length = res.rect.w * res.rect.h;

        foreach( g; buf )
        {
            auto yy = g.rect.y - min.y;
            auto xx = g.rect.x - min.x;
            foreach( r; 0 .. g.rect.h )
                foreach( v; 0 .. g.rect.w )
                    res.buffer[ (yy - r - 1) * res.rect.w + xx + v ] = 
                        g.buffer[ r * g.rect.w + v ];
        }
        fillTexture( res );
        bbox = frect( res.rect );
    }

    void draw_hook()
    {
        bufferData( "crd", bbox.points!float( tp.pos ) );
        glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );
        debug log.trace( "draw static string: ", tp.str );
    }

    void fillTexture( GlyphInfo g )
    {
        tex.image( GL_ALPHA, isize( g.rect.w, g.rect.h ), GL_ALPHA,
                GL_UNSIGNED_BYTE, g.buffer.ptr );
    }

public:

    /++
        конструктор 

        Params:
        sp = шейдер, предположительно единый для всего gui-текста
        fontname = имя шрифта
     +/
    this( ShaderProgram sp, string fontname="LinBiolinum_Rah.ttf" )
    {
        if( sp is null ) throw new DTException( "text shader is null" );
        super( sp );
        tex = new GLTexture2D( isize( 100, 10 ) );

        version(Windows) 
        { 
            debug log.info( "use WINDOWS_WTF" );
            fr = new WindowsTypeRender( fontname );
        }
        else
        {
            debug log.info( "use FreeType" );
            fr = new FreeTypeRender( fontname );
        }

        genBufferWithData( "crd", [ 0,  0, 100, 0, 0, 10, 100, 10 ] );
        setAttribPointer( "crd", coordShaderName, 2, GL_FLOAT );

        genBufferWithData( "texcrd", [ 0.0f,  0, 1,  0,  0,  1, 1, 1 ] );
        setAttribPointer( "texcrd", texcoordShaderName, 2, GL_FLOAT );

        draw.addPair( &predraw_hook, &postdraw_hook );
        draw.connect( &draw_hook );

        debug log.info( "DynText create" );
    }

    /++ выставляет новые параметры текста +/
    final void setTextParam( in TextParam ntp ){ tp = ntp; update(); }
    /++ возвращает bounding box +/
    @property vrect!float rect() const { return bbox; }
}
