module dport.gui.glsdlapp;

import derelict.sdl2.sdl;
import derelict.opengl3.gl3;

import std.datetime;
import std.getopt;

import dport.gui.base;
import dport.utils.system;

mixin( defaultModuleLogUtils("GLSDLAppException") );

version(Windows){}
else
{
    pragma( lib, "X11" );
    extern(C) int XInitThreads();
}


string toDString( const(char*) c_str )
{
    string buf;
    char *ch = cast(char*)c_str;
    while( *ch != '\0' )
        buf ~= *(ch++);
    return buf;
}

final class GLSDLApp
{
private:
    static GLSDLApp singleton;

    View vh;

    SDL_Window *window = null;
    SDL_GLContext context;

    StopWatch sw;

    isize winsize = isize( 1200, 800 );

    SDL_Joystick *joystick = null;

    this( string[] args )
    {
        string joy_name = "";
        bool audioinit = false;
        bool resizable = true;
        string title = "work";
        ivec2 glver = ivec2( 3, 1 );

        // TODO: parse args 

        auto sdlinitflags = SDL_INIT_VIDEO | 
            ( joy_name.length ? SDL_INIT_JOYSTICK : 0 ) | 
            ( audioinit ? SDL_INIT_AUDIO : 0 );

        if( SDL_Init( sdlinitflags ) < 0 )
            throw new GLSDLAppException( "Couldn't init SDL: " ~ toDString(SDL_GetError()) );

        //SDL_EnableUNICODE(1);

        int num_joys = SDL_NumJoysticks();
        if( num_joys > 0 && joy_name.length )
        {
            SDL_JoystickEventState( SDL_ENABLE );
            int dev_index = 0;
            if( num_joys != 1 || joy_name != "any" )
                while( joy_name != toDString( SDL_JoystickNameForIndex( dev_index ) ) )
                {
                    dev_index++;
                    if( dev_index > num_joys )
                    {
                        dev_index = 0;
                        break;
                    }
                }

            joystick = SDL_JoystickOpen( dev_index );
            debug log.info( "enable joy: ", SDL_JoystickName(joystick) );
        }

        SDL_GL_SetAttribute( SDL_GL_CONTEXT_MAJOR_VERSION, glver.x );
        SDL_GL_SetAttribute( SDL_GL_CONTEXT_MINOR_VERSION, glver.y );

        SDL_GL_SetAttribute( SDL_GL_BUFFER_SIZE, 32 );
        SDL_GL_SetAttribute( SDL_GL_DEPTH_SIZE,  24 );
        SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );

        window = SDL_CreateWindow( title.ptr,
                                   SDL_WINDOWPOS_CENTERED,
                                   SDL_WINDOWPOS_CENTERED,
                                   winsize.w, winsize.h,
                                   SDL_WINDOW_OPENGL | 
                                   SDL_WINDOW_SHOWN | 
                                   ( resizable ? SDL_WINDOW_RESIZABLE : 0 ) );
        if( window is null )
            throw new GLSDLAppException( "Couldn't create SDL window: " ~ toDString(SDL_GetError()) );

        context = SDL_GL_CreateContext( window );

        DerelictGL3.reload();
        debug log.info( "loaded gl", DerelictGL3.loadedVersion ); 

        SDL_GL_SetSwapInterval(1);

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

    void window_eh( ubyte event, long data1, long data2 )
    {
        switch( event ) 
        {
        case SDL_WINDOWEVENT_SHOWN: break;
        case SDL_WINDOWEVENT_HIDDEN: break;
        case SDL_WINDOWEVENT_EXPOSED: break;
        case SDL_WINDOWEVENT_MOVED: break;
        case SDL_WINDOWEVENT_RESIZED:
            winsize.w = cast(uint)data1;
            winsize.h = cast(uint)data2;
            vh.reshape( irect( ivec2(0,0), winsize ) );
            glViewport( 0, 0, cast(int)data1, cast(int)data2 );
            break;
        case SDL_WINDOWEVENT_MINIMIZED: break;
        case SDL_WINDOWEVENT_MAXIMIZED: break;
        case SDL_WINDOWEVENT_RESTORED: break;
        case SDL_WINDOWEVENT_ENTER: break;
        case SDL_WINDOWEVENT_LEAVE: break;
        case SDL_WINDOWEVENT_FOCUS_GAINED: break;
        case SDL_WINDOWEVENT_FOCUS_LOST: break;
        case SDL_WINDOWEVENT_CLOSE: break;
        default: break;
        }
    }

    void keyboard_eh( in ivec2 mpos, ubyte state, int scancode, ulong symchar, ushort mod ) 
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

    void joystick_eh( in ivec2 mpos, uint joy, JoyEvent.Type type, size_t no )
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

public:
    static void loadLibs()
    {
        //version(Windows) {} 
        //else {
        //    XInitThreads();
        //}
        DerelictSDL2.load();
        DerelictGL3.load();
        debug log.info( "loaded gl", DerelictGL3.loadedVersion ); 
    }

    static auto getApp( string[] args )
    {
        if( singleton !is null ) clear( singleton );

        singleton = new GLSDLApp( args );

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

    //void setVideoMode( uint w, uint h )
    //{
    //    debug log.Debug( "set size: (", w, ", ", h, ")" );
    //    winsize.w = w;
    //    winsize.h = h;
    //    if( SDL_SetVideoMode( w, h, 0, SDL_OPENGL ) == null )
    //        throw new GLSDLAppException( "Failed to set video mode: " ~ toDString(SDL_GetError()) );

    //    if( vh !is null )
    //    {
    //        glViewport( 0, 0, winsize.w, winsize.h );
    //        vh.rect = irect( 0, 0, w, h );
    //    }
    //}

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
                    case SDL_WINDOWEVENT:
                        window_eh( event.window.event, 
                                   event.window.data1, 
                                   event.window.data2 );
                        break;
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
            SDL_GL_SwapWindow( window );
            SDL_Delay(1);
        }
        debug log.Debug( "exit mainLoop" );
    }

    ~this() 
    { 
        debug log.Debug( "destruction" );

        if( context !is null )
            SDL_GL_DeleteContext( context );
        if( window !is null )
            SDL_DestroyWindow( window );

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
