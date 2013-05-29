module dport.gui.glapp;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.util.compat;

import std.datetime;

import dport.gui.base;
import dport.utils.logsys;

mixin( defaultModuleLogUtils("AppException") );

final class GLApp
{
private:
    static GLApp singleton;

    View vh;
    StopWatch sw;

    isize winsize;

    SDL_Joystick *joystick;

    this()
    {
        DerelictSDL.load();
        DerelictGL.load();
        DerelictGLU.load();

        if( SDL_Init( SDL_INIT_VIDEO | SDL_INIT_JOYSTICK ) < 0 )
            throw new AppException( "Couldn't init SDL: " ~ toDString(SDL_GetError()) );

        SDL_EnableUNICODE(1);

        if( SDL_NumJoysticks() > 0 )
        {
            SDL_JoystickEventState(SDL_ENABLE);
            joystick = SDL_JoystickOpen(0);
            log.info( "enable joy: ", SDL_JoystickName(0) );
        }

        SDL_GL_SetAttribute( SDL_GL_BUFFER_SIZE, 32 );
        SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE,  16 );
        SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );

        setVideoMode( 1400, 800 );

        GLVersion ver = DerelictGL.loadClassicVersions(GLVersion.GL21);
        DerelictGL.loadExtensions();

        glClearColor( .0f, .0f, .0f, .0f );
        glEnable( GL_BLEND );

        glBlendFunc( GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA );
        glPixelStorei( GL_UNPACK_ALIGNMENT, 1 );
        glEnable( GL_DEPTH_TEST );

        //glEnable( GL_MULTISAMPLE );
        //glEnable( GL_LINE_SMOOTH );
        //glEnable(GL_POLYGON_SMOOTH);
        //glEnable(GL_POINT_SMOOTH);

        //glLineWidth(2.5);
        //glPointSize(1.1);
    }

    void idle()
    {
        sw.stop();
        vh.idle( sw.peek().to!("seconds", real)() );
        sw.reset();
        sw.start();
    }

    void draw()
    {
        glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
        vh.draw();
    }

    /+
    void window_eh( ubyte event, long data1, long data2 )
    {
        switch( event ) 
        {
        case SDL_WINDOWEVENT_SHOWN:
            break;
        case SDL_WINDOWEVENT_HIDDEN:
            break;
        case SDL_WINDOWEVENT_EXPOSED:
            break;
        case SDL_WINDOWEVENT_MOVED:
            break;
        case SDL_WINDOWEVENT_RESIZED:
            winsize.x = cast(uint)data1;
            winsize.y = cast(uint)data2;
            vh.reshape( winsize );
            glViewport( 0, 0, cast(int)data1, cast(int)data2 );
            break;
        case SDL_WINDOWEVENT_MINIMIZED:
            break;
        case SDL_WINDOWEVENT_MAXIMIZED:
            break;
        case SDL_WINDOWEVENT_RESTORED:
            break;
        case SDL_WINDOWEVENT_ENTER:
            break;
        case SDL_WINDOWEVENT_LEAVE:
            break;
        case SDL_WINDOWEVENT_FOCUS_GAINED:
            break;
        case SDL_WINDOWEVENT_FOCUS_LOST:
            break;
        case SDL_WINDOWEVENT_CLOSE:
            break;
        default:
            break;
        }
    }
    +/

    void keyboard_eh( in ivec2 mpos, ubyte state, ubyte scancode, ulong symchar, int mod ) 
    { 
        /*
         * SDL mod description
         *
         * KMOD_NONE     * 0 (no modifier is applicable)
         * KMOD_LSHIFT   * the left Shift key is down
         * KMOD_RSHIFT   * the right Shift key is down
         * KMOD_LCTRL    * the left Ctrl (Control) key is down
         * KMOD_RCTRL    * the right Ctrl (Control) key is down
         * KMOD_LALT     * the left Alt key is down
         * KMOD_RALT     * the right Alt key is down
         * KMOD_LGUI     * the left GUI key (often the Windows key) is down
         * KMOD_RGUI     * the right GUI key (often the Windows key) is down
         * KMOD_NUM      * the Num Lock key (may be located on an extended keypad) is down
         * KMOD_CAPS     * the Caps Lock key is down
         * KMOD_MODE     * the AltGr key is down
         * KMOD_CTRL     * (KMOD_LCTRL|KMOD_RCTRL)
         * KMOD_SHIFT    * (KMOD_LSHIFT|KMOD_RSHIFT)
         * KMOD_ALT      * (KMOD_LALT|KMOD_RALT)
         * KMOD_GUI      * (KMOD_LGUI|KMOD_RGUI)
         * KMOD_RESERVED * reserved for future use
         */
        vh.keyboard( ivec2( mpos.x, mpos.y ), 
                KeyboardEvent( state == SDL_PRESSED, 
                               scancode,
                               cast(wchar)symchar, 
                               mod ) );
    }

    void joystick_eh( in ivec2 mpos, ubyte joy, JoyEvent.Type type, size_t no )
    {
        JoyEvent je;

        je.joy = joy;
        je.type = type;
        je.no = no;

        foreach( i; 0 .. SDL_JoystickNumAxes( joystick ) )
            je.axis ~= SDL_JoystickGetAxis( joystick, i ) / 32768.0; 

        foreach( i; 0 .. SDL_JoystickNumBalls( joystick ) )
        {
            int[2] d;
            if( SDL_JoystickGetBall( joystick, i, d.ptr, d.ptr+1 ) )
                je.balls ~= d;
        }

        foreach( i; 0 .. SDL_JoystickNumButtons( joystick ) )
            je.buttons ~= cast(bool)SDL_JoystickGetButton( joystick, i );

        foreach( i; 0 .. SDL_JoystickNumHats( joystick ) )
            je.hats ~= SDL_JoystickGetHat( joystick, i );

        vh.joystick( mpos, je );
    }

    void mouse_button_eh( in ivec2 mpos, ubyte state, uint button ) 
    { 
        /*
         * mouse buttons
         *
         * SDL_BUTTON_LEFT
         * SDL_BUTTON_MIDDLE
         * SDL_BUTTON_RIGHT
         * SDL_BUTTON_X1
         * SDL_BUTTON_X2
         */

        vh.mouse( ivec2( mpos.x, mpos.y ),
                 MouseEvent( 
                    state == SDL_PRESSED ? MouseEvent.Type.PRESSED : MouseEvent.Type.RELEASED,
                    button ) );

    }

    void mouse_motion_eh( in ivec2 mpos, ubyte state ) 
    { 
        /*
         * mouse motion states
         *
         * SDL_BUTTON_LMASK 
         * SDL_BUTTON_MMASK
         * SDL_BUTTON_RMASK
         * SDL_BUTTON_X1MASK
         * SDL_BUTTON_X2MASK
         */
        vh.mouse( ivec2( mpos.x, mpos.y ), 
                MouseEvent( MouseEvent.Type.MOTION, state ) );
    }

    static this() { singleton = new GLApp(); }

public:
    static auto getApp( View nv )
    {
        if( nv !is null )
            singleton.setView( nv );
        else if( nv is null && singleton.vh is null )
            throw new AppException( "no view in app" );
        debug log.info( "get app" );

        return singleton;
    }

    void setView( View nv )
    {
        if( vh !is null ) vh.release();
        vh = nv;

        glViewport( 0, 0, winsize.w, winsize.h );
        vh.rect = irect( 0, 0, winsize.w, winsize.h );
        vh.activate();
        debug log.Debug( "set view: ", vh.rect._rect );
    }

    void setVideoMode( uint w, uint h )
    {
        debug log.Debug( "set size: (", w, ", ", h, ")" );
        winsize.w = w;
        winsize.h = h;
        if( SDL_SetVideoMode( w, h, 0, SDL_OPENGL ) == null )
            throw new AppException( "Failed to set video mode: " ~ toDString(SDL_GetError()) );

        if( vh !is null )
        {
            glViewport( 0, 0, winsize.w, winsize.h );
            vh.rect = irect( 0, 0, w, h );
        }
    }

    void mainLoop()
    {
        sw.start();
        bool run = true;

        auto mpos = ivec2( 0, 0 );

        SDL_Event event;
        while( run )
        {
            while( SDL_PollEvent(&event) )
            {
                switch( event.type )
                {
                    case SDL_QUIT: 
                        run = false; 
                        debug log.Debug( "SDL_QUIT" );
                        break;
                    //case SDL_WINDOWEVENT:
                    //    window_eh( event.window.event, 
                    //               event.window.data1, 
                    //               event.window.data2 );
                    //    break;
                    case SDL_KEYDOWN: 
                    case SDL_KEYUP:
                        keyboard_eh( mpos, event.key.state,
                                event.key.keysym.scancode,
                                event.key.keysym.unicode,
                                event.key.keysym.mod );
                        break;

                    case SDL_JOYAXISMOTION: 
                        joystick_eh( mpos, event.jaxis.which, 
                                JoyEvent.Type.AXIS, event.jaxis.axis );
                        break;
                    case SDL_JOYBUTTONUP: 
                    case SDL_JOYBUTTONDOWN:
                        joystick_eh( mpos, event.jbutton.which, 
                                JoyEvent.Type.BUTTON, event.jbutton.button );
                        break;
                    case SDL_JOYBALLMOTION:
                        joystick_eh( mpos, event.jball.which, 
                                JoyEvent.Type.BALL, event.jball.ball );
                        break;
                    case SDL_JOYHATMOTION:
                        joystick_eh( mpos, event.jhat.which, 
                                JoyEvent.Type.HAT, event.jhat.hat );
                        break;

                    case SDL_MOUSEBUTTONDOWN: goto case;
                    case SDL_MOUSEBUTTONUP:
                        mpos.x = event.button.x;
                        mpos.y = event.button.y;
                        mouse_button_eh( mpos, 
                                         event.button.state,
                                         event.button.button );
                        break;
                    case SDL_MOUSEMOTION:
                        mpos.x = event.motion.x;
                        mpos.y = event.motion.y;
                        mouse_motion_eh( mpos, event.motion.state );
                        break;
                    //case SDL_MOUSEWHEEL:
                    //    mouse_wheel_eh( intpoint( event.wheel.x, 
                    //                              event.wheel.y ),
                    //                    mousepos );
                    //    break;
                    default:
                        break;
                }
            }

            idle();
            draw();
            SDL_GL_SwapBuffers();
            SDL_Delay(1);
        }
        debug log.Debug( "exit mainLoop" );
    }

    ~this() 
    { 
        debug log.Debug( "destruction" );
        if( SDL_JoystickClose !is null && joystick !is null )
        {
            debug log.Debug( "close joystick" );
            SDL_JoystickClose( joystick );
        }
        if( vh !is null )
        {
            debug log.Debug( "vh not null" );
            vh.release();
        }
        if( SDL_Quit !is null ) 
        {
            debug log.Debug( "SDL_Quit not null" );
            SDL_Quit();
        }
        debug log.success( "destruction" );
    }
}
