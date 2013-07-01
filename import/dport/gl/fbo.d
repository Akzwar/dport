module dport.gl.fbo;

import std.conv;

import derelict.opengl3.gl3;
import derelict.opengl3.ext;

import dport.math.types;
import dport.utils.system;

import dport.gl.shader;

import dport.gl.object;
import dport.gl.texture;

mixin( defaultModuleLogUtils("FBOException") );

class GLFBO
{
protected:
    ShaderProgram fx;

    alias GLTexture!2 GLTexture2D;

    GLuint fbo, rbo_depth;
    GLuint v_coord, uniform_fbo;
    string v_coord_name = "v_coord",
           uniform_fbo_name = "fbo_texture";

    class Plane: GLVAO
    {
        this( ShaderProgram sp )
        { 
            super( sp ); 
            genBufferWithData( "vert", [ -1.0f, -1, 1, -1, -1,  1, 1,  1, ] );
            setAttribPointer( "vert", v_coord_name, 2, GL_FLOAT );
            draw.connect( (){ glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 ); } );
        }
    }

    Plane plane;

    GLint tex_res;
    string tex_res_name = "resol";

    isize sz;

public:
    GLTexture2D tex;

    this( isize Sz, ShaderProgram FX )
    { 
        fx = FX;
        sz = Sz;
        debug log.Debug( "fbo size: ", sz );

        /* texture */
        tex = new GLTexture2D( sz );
        debug log.Debug( "texture create: ", tex.no );

          /* Depth buffer */
        glGenRenderbuffers( 1, &rbo_depth );
        glBindRenderbuffer( GL_RENDERBUFFER, rbo_depth );
        glRenderbufferStorage( GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, sz.w, sz.h );
        glBindRenderbuffer( GL_RENDERBUFFER, 0 );
        debug log.Debug( "render buffer create: ", rbo_depth );

        /* Framebuffer to link everything together */
        glGenFramebuffers( 1, &fbo );
        glBindFramebuffer( GL_FRAMEBUFFER, fbo );
        glFramebufferTexture2D( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex.no, 0 );
        glFramebufferRenderbuffer( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, rbo_depth );
        GLenum status;
        if( (status = glCheckFramebufferStatus(GL_FRAMEBUFFER)) != GL_FRAMEBUFFER_COMPLETE )
            throw new FBOException( "glCheckFramebufferStatus: error " ~ to!string(status) );
        glBindFramebuffer( GL_FRAMEBUFFER, 0 );
        debug log.Debug( "create & link frame buffer: ", fbo );

        /* plane */
        plane = new Plane( fx );

        /* other */
        uniform_fbo = fx.getUniformLocation( uniform_fbo_name );
        tex_res = fx.getUniformLocation( tex_res_name );
        debug log.info( "FBO construction [success]" );
    }

    final void reshape( isize Sz )
    {
        tex.size = Sz;
        sz = Sz;
        
        glBindRenderbuffer( GL_RENDERBUFFER, rbo_depth );
        glRenderbufferStorage( GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, sz.w, sz.h );
        glBindRenderbuffer( GL_RENDERBUFFER, 0 );
        debug log.Debug( "reshape to ", sz );
    }

    final void bind() 
    { 
        glBindFramebuffer( GL_FRAMEBUFFER, fbo ); 
        glClearColor( 0.0, 0.0, 0.0, 0.0 );
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        debug log.trace( "bind ", fbo );
    }

    final void unbind() 
    { 
        glBindFramebuffer( GL_FRAMEBUFFER, 0 ); 
        debug log.trace( "unbind" );
    }

    final void draw()
    {
        fx.use();
        plane.draw.open();

        fx.setUniform!int( uniform_fbo, GL_TEXTURE0 );
        tex.use(); scope(exit) tex.use(0);
        fx.setUniformVec( tex_res, vec2( 2.0/sz.w, 2.0/sz.h ) );

        plane.draw.cntnt();
        plane.draw.close();
        debug log.trace( "draw" );
    }

    ~this() 
    {
        debug log.start( "destruction" );
        glBindRenderbuffer( GL_RENDERBUFFER, 0 );
        glDeleteRenderbuffers( 1, &rbo_depth );
        glBindFramebuffer( GL_FRAMEBUFFER, 0 );
        glDeleteFramebuffers( 1, &fbo );
        debug log.success( "destruction" );
    }
}
