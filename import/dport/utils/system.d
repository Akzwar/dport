module dport.utils.system;

import std.stdio,
       std.conv,
       std.concurrency,
       std.typecons,
       std.getopt;

enum logType { FATAL=0, ERROR=1, WARN=2, UTEST=3, INFO=4, DEBUG=5, EXCEPT=6, TRACE=7 };

class LogException: Exception { this( string msg ){ super( msg ); } }

class SystemInfo
{
    import std.file,
           std.path,
           std.string,
           core.sync.mutex;

    string path;

    synchronized this( string[] args )
    { 
        path = buildNormalizedPath( dirName( absolutePath( args[0] ) ), "." ); 
    }

    synchronized string getPath( string file ) const
    { 
        return buildNormalizedPath( path, file ).dup; 
    }
}

shared(SystemInfo) sysinfo;

private
{
    enum logthread = "log_thread";

    struct LogCommand
    {
        logType type;
        string name;
        string msg;
    }

    struct ManCommand
    {
        string name;
        logType level;
    }

    import std.string;
    class LogSystem
    {
        File ff;

        class LogGraph
        {
            this( logType ll ){ level = ll; }
            LogGraph[string] children;
            logType level;

            bool check( logType lt, string[] name )
            {
                if( lt > level ) return 0;
                if( name.length && name[0] in children )
                    return children[name[0]].check( lt, name[1 .. $] );
                return 1;
            }

            bool set( logType lt, string[] name )
            {
                if( name[0] in children )
                    return children[name[0]].set( lt, name[1 .. $] );
                else if( name.length > 1 )
                {
                    children[name[0]] = new LogGraph(level);
                    children[name[0]].set( lt, name[1 .. $] );
                    return 1;
                }
                else if( name.length == 1 )
                {
                    children[name[0]] = new LogGraph(lt);
                    return 1;
                }
                else 
                {
                    level = lt;
                    return 0;
                }
            }
        }

        LogGraph root;

        enum prefix = "[LOGSYS] ";

        this( string[] args )
        {
            root = new LogGraph( logType.TRACE );

            string fname = "stderr";

            getopt( args,
                    "loglevel", &root.level,
                    "logfile", &fname );

            stderr.writeln( prefix ~ "max log level: ", root.level );
            stderr.writeln( prefix ~ "log output file: ", fname );

            if( fname == "stderr" ) ff = stderr;
            else if( fname == "stdout" ) ff = stdout;
            else ff = File( fname, "w" );
        }

        ~this() { if( ff != stderr && ff != stdout ) ff.close(); }

        void log( LogCommand lcmd )
        {
            if( root.check( lcmd.type, lcmd.name.split(".") ) )
                ff.writefln( "[% 6s] [%s]: %s", lcmd.type, lcmd.name, lcmd.msg );
        }

        void manage( ManCommand mcmd )
        {
            if( root.set( mcmd.level, mcmd.name.split("." ) ) )
                ff.writeln( prefix ~ "register logger \"", mcmd.name, 
                        "\" with log level ", mcmd.level );
            else
                ff.writeln( prefix ~ "set new level for \"", mcmd.name, 
                        "\": ", mcmd.level );
        }
    }

    void log_loop( immutable(string)[] args )
    {
        auto ls = new LogSystem( args.dup );
        register( logthread, thisTid );
        send( ownerTid, 0 );

        import std.traits;
        bool run = true;
        while( run )
            receive( &(ls.log),
                     &(ls.manage),
                     (OwnerTerminated ot)
                     {
                        ls.log( LogCommand( logType.DEBUG, 
                                moduleName!logthread, 
                                "terminate logging" ) );
                        run = false;
                     }
                   );

    }

    void fnsend(T)( T cmd )
    {
        auto logTid = locate( logthread );
        if( logTid == Tid.init ) return;
        static if( is( T == LogCommand ) )      send( logTid, cmd );
        else static if( is( T == ManCommand ) ) send( logTid, cmd );
    }

}

class DPortException: Exception 
{ 
    this( string name, string msg ) 
    { 
        super( "[" ~ name ~ "]: " ~ msg ); 
        fnsend( LogCommand( logType.EXCEPT, name, msg ) );
    } 
}

void initLogging( string[] args ) 
{ 
    sysinfo = new shared(SystemInfo)( args );

    auto tid = spawn( &log_loop, args.idup );
    receiveOnly!int();
}

class Logger
{
private:
    string name;
    logType maxLT;

public:
    this( string Name, logType lt=logType.TRACE )
    {
        name = Name;
        maxLT = lt;
        fnsend( ManCommand( name, lt ) );
    }

    final void log(T...)( logType lt, T args )
    {
        if( lt > maxLT ) return;
        string msg = "";
        foreach( arg; args )
            msg ~= to!string(arg);
        fnsend( LogCommand( lt, name, msg ) );
    }

    final void fatal(T...)( T args ) { log( logType.FATAL, args ); }
    final void error(T...)( T args ) { log( logType.ERROR, args ); }
    final void warn(T...)( T args )  { log( logType.WARN,  args ); }
    final void utest(T...)( T args ) { log( logType.UTEST, args ); }
    final void info(T...)( T args )  { log( logType.INFO,  args ); }
    final void Debug(T...)( T args ) { log( logType.DEBUG, args ); }
    final void trace(T...)( T args ) { log( logType.TRACE, args ); }

    final void start( string method ) { log( logType.DEBUG, method, " [start]" ); }
    final void success( string method ) { log( logType.INFO, method, " [success]" ); }
}

string defaultModuleLogUtils(string ExceptName)
{
    return r"
    private {
        import std.traits;
        Logger logger;
        Logger log() 
        { 
            if( !logger ) 
                logger = new Logger( moduleName!logger, logType.TRACE ); 
            return logger;
        }
    }

    class " ~ ExceptName ~ r": DPortException
    { this( string msg ){ super( moduleName!(typeof(this)), msg ); } }
    ";
}
