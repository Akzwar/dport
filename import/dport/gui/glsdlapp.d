module dport.gui.glsdlapp;

import derelict.sdl2.sdl;
import derelict.opengl3.gl3;

import std.datetime,
       std.getopt,
       std.conv,
       std.utf,
       std.string;

import dport.gui.base;
import dport.utils.system;

mixin( defaultModuleLogUtils("GLSDLAppException") );

string toDString( const(char*) c_str )
{
    string buf;
    char *ch = cast(char*)c_str;
    while( *ch != '\0' ) buf ~= *(ch++);
    return buf;
}

string toDStringFix(size_t S)( char[S] c_buf )
{
    string buf;
    foreach( c; c_buf )
        buf ~= c;
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
        bool resizable = false;
        string title = "work";
        ivec2 glver = ivec2( 3, 1 );

        // TODO: parse args 

        auto sdlinitflags = SDL_INIT_VIDEO | 
            ( joy_name.length ? SDL_INIT_JOYSTICK : 0 ) | 
            ( audioinit ? SDL_INIT_AUDIO : 0 );

        if( SDL_Init( sdlinitflags ) < 0 )
            throw new GLSDLAppException( "Couldn't init SDL: " ~ toDString(SDL_GetError()) );

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
                                   SDL_WINDOWPOS_UNDEFINED,
                                   SDL_WINDOWPOS_UNDEFINED,
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

    void window_eh( in SDL_WindowEvent ev )
    {
        switch( ev.event ) 
        {
        case SDL_WINDOWEVENT_NONE: break;
        case SDL_WINDOWEVENT_SHOWN: 
            debug log.Debug( format( "window %d shown", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_HIDDEN: 
            debug log.Debug( format( "window %d hidden", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_EXPOSED: 
            debug log.Debug( format( "window %d exposed", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_MOVED: 
            debug log.Debug( format( "window %d moved", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_RESIZED:
            debug log.Debug( format( "window %d resized", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_SIZE_CHANGED: 
            winsize.w = cast(uint)ev.data1;
            winsize.h = cast(uint)ev.data2;
            vh.reshape( irect( ivec2(0,0), winsize ) );
            glViewport( 0, 0, cast(int)ev.data1, cast(int)ev.data2 );
            debug log.Debug( format( "window %d size changed", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_MINIMIZED:    
            debug log.Debug( format( "window %d minimized", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_MAXIMIZED:    
            debug log.Debug( format( "window %d maximized", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_RESTORED:     
            debug log.Debug( format( "window %d restored", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_ENTER:        
            vh.activate();
            debug log.Debug( format( "window %d enter", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_LEAVE:        
            vh.release();
            debug log.Debug( format( "window %d leave", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_FOCUS_GAINED: 
            debug log.Debug( format( "window %d focus gained", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_FOCUS_LOST:   
            debug log.Debug( format( "window %d focus lost", ev.windowID ) );
            break;
        case SDL_WINDOWEVENT_CLOSE:        
            debug log.Debug( format( "window %d close", ev.windowID ) );
            break;
        default: break;
        }
    }

    void keyboard_eh( in ivec2 mpos, in SDL_KeyboardEvent ev ) 
    { 
        KeyboardEvent oev;
        oev.pressed = (ev.state == SDL_PRESSED);
        oev.scan = ev.keysym.scancode;
        oev.key = ev.keysym.sym;
        oev.repeat = cast(bool)ev.repeat;
        
        oev.mod = 
                  ( ev.keysym.mod & KMOD_LSHIFT ? KeyboardEvent.Mod.LSHIFT : 0 ) |
                  ( ev.keysym.mod & KMOD_RSHIFT ? KeyboardEvent.Mod.RSHIFT : 0 ) |
                  ( ev.keysym.mod & KMOD_LCTRL  ? KeyboardEvent.Mod.LCTRL  : 0 ) |
                  ( ev.keysym.mod & KMOD_RCTRL  ? KeyboardEvent.Mod.RCTRL  : 0 ) | 
                  ( ev.keysym.mod & KMOD_LALT   ? KeyboardEvent.Mod.LALT   : 0 ) |
                  ( ev.keysym.mod & KMOD_RALT   ? KeyboardEvent.Mod.RALT   : 0 ) |
                  ( ev.keysym.mod & KMOD_LGUI   ? KeyboardEvent.Mod.LGUI   : 0 ) |
                  ( ev.keysym.mod & KMOD_RGUI   ? KeyboardEvent.Mod.RGUI   : 0 ) |
                  ( ev.keysym.mod & KMOD_NUM    ? KeyboardEvent.Mod.NUM    : 0 ) |
                  ( ev.keysym.mod & KMOD_CAPS   ? KeyboardEvent.Mod.CAPS   : 0 ) |
                  ( ev.keysym.mod & KMOD_MODE   ? KeyboardEvent.Mod.MODE   : 0 ) |
                  ( ev.keysym.mod & KMOD_CTRL   ? KeyboardEvent.Mod.CTRL   : 0 ) |
                  ( ev.keysym.mod & KMOD_SHIFT  ? KeyboardEvent.Mod.SHIFT  : 0 ) |
                  ( ev.keysym.mod & KMOD_ALT    ? KeyboardEvent.Mod.ALT    : 0 ) |
                  ( ev.keysym.mod & KMOD_GUI    ? KeyboardEvent.Mod.GUI    : 0 );

        vh.keyboard( mpos, oev );
    }

    void textinput_eh( in ivec2 mpos, in SDL_TextInputEvent ev )
    {
        auto str = toUTF32( ev.text[0 .. 4].dup );
        vh.evtext( mpos, TextEvent( str[0] ) );
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

    void mouse_button_eh( in ivec2 mpos, in SDL_MouseButtonEvent ev ) 
    { 
        auto me = MouseEvent( ev.state == SDL_PRESSED ? MouseEvent.Type.PRESSED : 
                                MouseEvent.Type.RELEASED, 0 );
        switch( ev.button )
        {
            case SDL_BUTTON_LEFT:   me.btn = MouseEvent.Button.LEFT; break;
            case SDL_BUTTON_MIDDLE: me.btn = MouseEvent.Button.MIDDLE; break;
            case SDL_BUTTON_RIGHT:  me.btn = MouseEvent.Button.RIGHT; break;
            case SDL_BUTTON_X1:     me.btn = MouseEvent.Button.X1; break;
            case SDL_BUTTON_X2:     me.btn = MouseEvent.Button.X2; break;
            default: 
                throw new GLSDLAppException( "Undefined mouse button: " ~ to!string( ev.button ) );
                break;
        }

        vh.mouse( mpos, me );
    }

    void mouse_motion_eh( in ivec2 mpos, in SDL_MouseMotionEvent ev ) 
    { 
        auto me = MouseEvent( MouseEvent.Type.MOTION, 0 );
        me.btn = 
          ( ev.state & SDL_BUTTON_LMASK  ? MouseEvent.Button.LEFT : 0 ) |
          ( ev.state & SDL_BUTTON_MMASK  ? MouseEvent.Button.MIDDLE : 0 ) |
          ( ev.state & SDL_BUTTON_RMASK  ? MouseEvent.Button.RIGHT : 0 ) |
          ( ev.state & SDL_BUTTON_X1MASK ? MouseEvent.Button.X1 : 0 ) |
          ( ev.state & SDL_BUTTON_X2MASK ? MouseEvent.Button.X2 : 0 );
        vh.mouse( mpos, me );
    }

    void mouse_wheel_eh( in ivec2 mpos, in SDL_MouseWheelEvent ev )
    {
        auto me = MouseEvent( MouseEvent.Type.WHEEL, 0 );
        me.scroll = ivec2( ev.x, ev.y );
        vh.mouse( mpos, me );
    }

public:
    static void loadLibs()
    {
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
        debug log.Debug( "set view: ", vh.rect._rect );
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

                    case SDL_WINDOWEVENT: window_eh( event.window ); break;

                    case SDL_TEXTINPUT: textinput_eh( mpos, event.text ); break;

                    case SDL_KEYDOWN: 
                    case SDL_KEYUP: keyboard_eh( mpos, event.key ); break;

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

                    case SDL_MOUSEBUTTONDOWN: 
                    case SDL_MOUSEBUTTONUP:
                        mpos.x = event.button.x;
                        mpos.y = event.button.y;
                        mouse_button_eh( mpos, event.button );
                        break;
                    case SDL_MOUSEMOTION:
                        mpos.x = event.motion.x;
                        mpos.y = event.motion.y;
                        mouse_motion_eh( mpos, event.motion );
                        break;
                    case SDL_MOUSEWHEEL:
                        mouse_wheel_eh( mpos, event.wheel );
                        break;
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
